//
//  SpotifyManager.swift
//  one
//
//  Created for Spotify Integration
//

import Foundation
import Combine
import UIKit
import AuthenticationServices
import CommonCrypto

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()
    
    @Published var isAuthenticated = false
    private(set) var accessToken: String?

    private let clientID: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
              !id.isEmpty else {
            ONELogger.error("SpotifyClientID not configured in Info.plist — Spotify integration disabled", category: .spotify)
            return ""
        }
        return id
    }()
    private let redirectURI = "ones://spotify-callback"
    
    private var tokenExpirationDate: Date?
    private var refreshToken: String?
    private var authSession: ASWebAuthenticationSession?
    private let refreshGate = RefreshGate()

    // PKCE parameters
    private var codeVerifier: String?
    private var codeChallenge: String?

    private override init() {
        super.init()
        loadTokenFromKeychain()
        loadRefreshTokenFromKeychain()
    }
    
    // MARK: - Authentication
    func authenticate() {
        guard !clientID.isEmpty else {
            ONELogger.error("Cannot authenticate — SpotifyClientID not configured", category: .spotify)
            return
        }

        // Cancel any existing session
        authSession?.cancel()
        authSession = nil
        
        // Generate PKCE parameters
        generatePKCEParameters()
        
        guard let codeChallenge = codeChallenge else {
            ONELogger.error("Failed to generate PKCE parameters", category: .spotify)
            return
        }
        
        let scope = "user-read-private user-read-email user-read-currently-playing user-read-playback-state playlist-modify-private"
        let authURLString = "https://accounts.spotify.com/authorize?" +
            "client_id=\(clientID)" +
            "&response_type=code" +
            "&redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
            "&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
            "&code_challenge_method=S256" +
            "&code_challenge=\(codeChallenge)" +
            "&show_dialog=true"
        
        guard let url = URL(string: authURLString) else {
            ONELogger.error("Invalid auth URL", category: .spotify)
            return
        }
        
        ONELogger.debug("Starting Spotify auth with PKCE", category: .spotify)
        
        // Create new session with strong reference
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "ones") { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                ONELogger.error("Spotify auth error: \(error.localizedDescription)", category: .spotify)
                // Check if user cancelled
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    ONELogger.info("User cancelled login", category: .spotify)
                }
                return
            }
            
            if let callbackURL = callbackURL {
                ONELogger.success("Received Spotify OAuth callback", category: .spotify)
                self.handleCallback(url: callbackURL)
            }
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        
        // Store session to prevent deallocation
        self.authSession = session
        
        // Start session on main thread
        DispatchQueue.main.async {
            if session.start() {
                ONELogger.success("Auth session started successfully", category: .spotify)
            } else {
                ONELogger.error("Failed to start auth session", category: .spotify)
            }
        }
    }
    
    func handleCallback(url: URL) {
        // Parse query parameters (code comes in query, not fragment)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            ONELogger.error("Failed to parse callback URL", category: .spotify)
            return
        }
        
        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            ONELogger.error("No authorization code found", category: .spotify)
            return
        }
        
        ONELogger.success("Authorization code received, exchanging for token", category: .spotify)
        
        // Exchange code for access token
        exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let codeVerifier = codeVerifier else {
            ONELogger.error("Code verifier not found", category: .spotify)
            return
        }
        
        let tokenURL = "https://accounts.spotify.com/api/token"
        guard let url = URL(string: tokenURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": codeVerifier
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        ONELogger.debug("Exchanging code for token with PKCE...", category: .spotify)
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    ONELogger.network("Token exchange response status: \(httpResponse.statusCode)", category: .spotify)
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let tokenResponse = try decoder.decode(SpotifyTokenResponse.self, from: data)
                
                await MainActor.run {
                    self.accessToken = tokenResponse.accessToken
                    self.isAuthenticated = true
                    self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
                    self.saveTokenToKeychain(tokenResponse.accessToken)

                    // Refresh token'ı kaydet (ilk auth'ta gelir, sonraki refresh'lerde gelmeyebilir)
                    if let rt = tokenResponse.refreshToken {
                        self.refreshToken = rt
                        self.saveRefreshTokenToKeychain(rt)
                    }

                    ONELogger.success("Successfully authenticated with Spotify", category: .spotify)

                    // Notify observers about authentication change
                    NotificationCenter.default.post(name: NSNotification.Name("SpotifyAuthenticationChanged"), object: nil)
                }
            } catch {
                ONELogger.error("Token exchange decode failed", category: .spotify)
                CrashReporter.shared.capture(error: error, context: ["operation": "spotifyTokenExchange"])
#if DEBUG
                ONELogger.error("Token exchange error detail: \(error)", category: .spotify)
#endif
            }
        }
    }
    
    func logout() {
        self.accessToken = nil
        self.isAuthenticated = false
        self.tokenExpirationDate = nil
        self.refreshToken = nil
        deleteTokenFromKeychain()
        deleteRefreshTokenFromKeychain()
        
        // Notify observers about authentication change
        NotificationCenter.default.post(name: NSNotification.Name("SpotifyAuthenticationChanged"), object: nil)
    }
    
    // MARK: - PKCE Helper Methods
    
    private func generatePKCEParameters() {
        // Generate code verifier (random string)
        let verifier = generateRandomString(length: 128)
        self.codeVerifier = verifier
        
        // Generate code challenge (SHA256 hash of verifier, base64url encoded)
        if let challenge = generateCodeChallenge(from: verifier) {
            self.codeChallenge = challenge
            ONELogger.success("PKCE parameters generated", category: .spotify)
        } else {
            ONELogger.error("Failed to generate code challenge", category: .spotify)
        }
    }
    
    private func generateRandomString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        let base64 = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return String(base64.prefix(length))
    }
    
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        let hashData = Data(hash)
        
        // Base64url encoding
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Token Refresh

    /// Token süresinin dolup dolmadığını kontrol eder (5 dakika marj ile)
    var isTokenExpired: Bool {
        guard let expiration = tokenExpirationDate else { return true }
        return Date() >= expiration.addingTimeInterval(-300) // 5 dakika erken expire say
    }

    /// Geçerli bir token sağlar — süresi dolmuşsa refresh eder
    @discardableResult
    private func ensureValidToken() async throws -> String {
        if let token = accessToken, !isTokenExpired {
            return token
        }

        // Refresh token ile yenile
        guard let rt = refreshToken else {
            // Refresh token yok — keychain'deki eski access token'ı da temizle
            await MainActor.run { self.logout() }
            throw NSError(domain: "SpotifyManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Oturum süresi doldu. Lütfen tekrar giriş yapın."])
        }

        // Eşzamanlı refresh isteklerini actor ile serialize et
        guard await refreshGate.begin() else {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let token = accessToken, !isTokenExpired {
                return token
            }
            throw NSError(domain: "SpotifyManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Token yenileme başarısız"])
        }
        defer { Task { await self.refreshGate.end() } }

        let tokenURL = "https://accounts.spotify.com/api/token"
        guard let url = URL(string: tokenURL) else {
            throw NSError(domain: "SpotifyManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": rt,
            "client_id": clientID
        ]
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        ONELogger.debug("Refreshing Spotify token...", category: .spotify)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            ONELogger.error("Token refresh failed with status \(httpResponse.statusCode)", category: .spotify)
            // Refresh token geçersizse oturumu kapat
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                await MainActor.run { self.logout() }
            }
            throw NSError(domain: "SpotifyManager", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Token yenileme başarısız"])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenResponse = try decoder.decode(SpotifyTokenResponse.self, from: data)

        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.isAuthenticated = true
            self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.saveTokenToKeychain(tokenResponse.accessToken)

            if let newRT = tokenResponse.refreshToken {
                self.refreshToken = newRT
                self.saveRefreshTokenToKeychain(newRT)
            }
        }

        ONELogger.success("Spotify token refreshed successfully", category: .spotify)
        return tokenResponse.accessToken
    }

    // MARK: - Search
    func search(query: String, completion: @escaping (Result<[SpotifyTrack], Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "SpotifyManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Spotify'a giriş yapılmadı"])))
            return
        }
        
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=15"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "SpotifyManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz URL"])))
            return
        }

        Task {
            do {
                let token = try await ensureValidToken()

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, _) = try await URLSession.shared.data(for: request)

                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(SpotifySearchResponse.self, from: data)
                completion(.success(searchResponse.tracks.items))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Now Playing

    /// Spotify'da şu an çalan şarkıyı çeker.
    /// Spotify bağlı değilse veya hiçbir şey çalmıyorsa nil döner.
    func getNowPlaying(completion: @escaping (SpotifyNowPlayingTrack?) -> Void) {
        guard isAuthenticated else {
            completion(nil)
            return
        }

        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
            completion(nil)
            return
        }

        Task {
            do {
                let token = try await ensureValidToken()

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                // 204 No Content — hiçbir şey çalmıyor
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                    await MainActor.run { completion(nil) }
                    return
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let nowPlaying = try decoder.decode(SpotifyNowPlayingResponse.self, from: data)

                // Sadece çalan track'i döndür (podcast, reklam veya boş durum değil)
                guard nowPlaying.isPlaying == true,
                      nowPlaying.currentlyPlayingType == "track",
                      let track = nowPlaying.item else {
                    await MainActor.run { completion(nil) }
                    return
                }

                let result = SpotifyNowPlayingTrack(
                    id: track.id,
                    name: track.name,
                    artist: track.artistName,
                    albumName: track.album.name,
                    artworkURL: track.album.artworkURL,
                    spotifyURL: track.externalUrls?.spotify.flatMap { URL(string: $0) }
                )
                await MainActor.run { completion(result) }
            } catch {
                ONELogger.error("getNowPlaying error: \(error)", category: .spotify)
                await MainActor.run { completion(nil) }
            }
        }
    }

    // MARK: - Keychain
    private static let keychainService = "com.batu.ones.spotify"

    private func saveTokenToKeychain(_ token: String) {
        guard let data = token.data(using: .utf8) else {
            ONELogger.error("Failed to encode token for Keychain storage", category: .spotify)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_access_token",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_access_token",
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) {
            self.accessToken = token
            // isAuthenticated sadece token süresi geçerliyse true — L-2 fix
            if let expiry = tokenExpirationDate, Date() < expiry.addingTimeInterval(-300) {
                self.isAuthenticated = true
            }
        }
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_access_token"
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Refresh Token Keychain

    private func saveRefreshTokenToKeychain(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_refresh_token",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadRefreshTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_refresh_token",
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) {
            self.refreshToken = token
        }
    }

    private func deleteRefreshTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "spotify_refresh_token"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window more reliably
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        
        if let window = window {
            ONELogger.success("Found presentation anchor window", category: .spotify)
            return window
        }
        
        ONELogger.warning("Using fallback presentation anchor", category: .spotify)
        return ASPresentationAnchor()
    }

}

// MARK: - Spotify Errors

enum SpotifyError: LocalizedError {
    case noToken
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noToken: return "No Spotify access token"
        case .invalidResponse: return "Invalid Spotify API response"
        }
    }
}

// MARK: - Models
struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String
}

struct SpotifySearchResponse: Codable, Sendable {
    let tracks: SpotifyTracks
}

struct SpotifyTracks: Codable, Sendable {
    let items: [SpotifyTrack]
}

struct SpotifyTrack: Codable, Sendable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    var artistName: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
}

struct SpotifyArtist: Codable, Sendable {
    let name: String
}

struct SpotifyAlbum: Codable, Sendable {
    let name: String
    let images: [SpotifyImage]
    
    var artworkURL: URL? {
        images.first?.url
    }
}

struct SpotifyImage: Codable, Sendable {
    let url: URL
    let height: Int?
    let width: Int?
}

// MARK: - Now Playing Models

struct SpotifyNowPlayingResponse: Codable, Sendable {
    let isPlaying: Bool?               // Optional: Spotify omits this when context exists but nothing active
    let currentlyPlayingType: String?  // Optional: missing on some ad/episode responses
    let item: SpotifyNowPlayingItem?
}

struct SpotifyNowPlayingItem: Codable, Sendable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let externalUrls: SpotifyExternalUrls?

    var artistName: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
}

struct SpotifyExternalUrls: Codable, Sendable {
    let spotify: String?
}

/// UI'a taşınan sade model
struct SpotifyNowPlayingTrack: Equatable {
    let id: String
    let name: String
    let artist: String
    let albumName: String
    let artworkURL: URL?
    let spotifyURL: URL?
}

// MARK: - Refresh Gate

private actor RefreshGate {
    private var refreshing = false
    func begin() -> Bool {
        guard !refreshing else { return false }
        refreshing = true
        return true
    }
    func end() { refreshing = false }
}
