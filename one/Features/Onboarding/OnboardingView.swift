//
//  OnboardingView.swift
//  one
//
//  Inspired by HTML onboarding flow
//

import SwiftUI
import MusicKit

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            ONETokens.oneCream
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // Page 1: Main Question
                MainQuestionPage(goToNext: { currentPage = 1 }, skip: completeOnboarding)
                    .tag(0)
                
                // Page 2: Music Info
                FeatureInfoPage(
                    title: "Müzik Ekle",
                    desc: "Seni bugün en iyi anlatan\nşarkıyı seç ve anı başlat.",
                    buttonText: "BİR SONRAKİ ADIM",
                    pose: .oneMusic,
                    goBack: { currentPage = 0 },
                    goToNext: { currentPage = 2 }
                )
                .tag(1)
                
                // Page 3: Photo Info
                FeatureInfoPage(
                    title: "Fotoğraf Ekle",
                    desc: "Bugünün mood'unu bir fotoğrafla\ndaha görünür hale getir.",
                    buttonText: "SERVİS BAĞLANTILARI",
                    pose: .onePicture,
                    goBack: { currentPage = 1 },
                    goToNext: { currentPage = 3 }
                )
                .tag(2)
                
                // Page 4: Music Service Connection
                MusicConnectionPage(goBack: { currentPage = 2 }, goToNext: { currentPage = 4 })
                    .tag(3)

                // Page 5: Apple Music
                AppleMusicConnectionPage(goBack: { currentPage = 3 }, complete: completeOnboarding)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
    }
    
    private func completeOnboarding() {
        // Request notification permission before completing
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                if granted {
                    UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                    
                    // Create default 20:00 time
                    var components = DateComponents()
                    components.hour = UserDefaults.standard.integer(forKey: "dailyReminderHour") == 0 ? 20 : UserDefaults.standard.integer(forKey: "dailyReminderHour")
                    components.minute = UserDefaults.standard.integer(forKey: "dailyReminderMinute")
                    
                    if components.hour == 0 { components.hour = 20 }
                    
                    if let defaultTime = Calendar.current.date(from: components) {
                        UserDefaults.standard.set(components.hour, forKey: "dailyReminderHour")
                        UserDefaults.standard.set(components.minute, forKey: "dailyReminderMinute")
                        NotificationManager.shared.scheduleDailyReminder(at: defaultTime)
                    }
                }
                
                withAnimation(.easeInOut(duration: ONEAnimation.durationMedium)) {
                    isCompleted = true
                }
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
    }
}

// MARK: - Main Question Page
struct MainQuestionPage: View {
    let goToNext: () -> Void
    let skip: () -> Void
    
    @State private var logoOpacity: Double = 0
    @State private var questionOpacity: Double = 0
    @State private var subOpacity: Double = 0
    @State private var ctaOpacity: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mascot
            OneMascotView(pose: .oneQuestions, size: 120)
                .opacity(logoOpacity)
                .padding(.top, 14)
            
            Spacer()
            
            // Hero question
            Text("Bugün nasıl\nbir şarkı?")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(4)
                .tracking(-0.9)
                .opacity(questionOpacity)
            
            // Sub text
            Text("Hisset. Keşfet. Paylaş.\nŞarkını seç, mood'unu bırak, çevrenle bağ kur.")
                .monoBase(tracking: 0.1)
                .foregroundColor(ONETokens.oneAsh)
                .lineSpacing(6)
                .padding(.top, 14)
                .opacity(subOpacity)
            
            Spacer()
            
            // CTA group
            VStack(spacing: 10) {
                Button(action: goToNext) {
                    Text("Müzik servisine bağlan")
                        .tracking(-0.3)
                        .bodySMMedium()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                
                Button(action: skip) {
                    Text("DAHA SONRA")
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.vertical, 12)
                }
                
                Text("Günde bir bildirim gönderebiliriz.\nBugünkü şarkını ve çevreni kaçırma.")
                    .monoLabel()
                    .foregroundColor(ONETokens.oneStone)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }
            .opacity(ctaOpacity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.1)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                questionOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.35)) {
                subOpacity = 1
            }
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.5)) {
                ctaOpacity = 1
            }
        }
    }
}

// MARK: - Feature Info Page
struct FeatureInfoPage: View {
    let title: String
    let desc: String
    let buttonText: String
    let pose: MascotPose
    let goBack: () -> Void
    let goToNext: () -> Void
    
    @State private var opacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button
            Button(action: goBack) {
                Text("← GERI")
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            .padding(.top, 14)
            
            Spacer()
            
            VStack(spacing: 32) {
                // Mascot
                OneMascotView(pose: pose, size: 160)
                    .padding(.bottom, 16)
                
                // Title
                Text(title)
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .tracking(-0.5)
                
                // Subtext
                Text(desc)
                    .monoBase(tracking: 0.5)
                    .foregroundColor(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .offset(y: contentOffset)
            
            Spacer()
            
            // Continue button
            Button(action: goToNext) {
                Text(buttonText)
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ONETokens.oneInk)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium)) {
                opacity = 1
                contentOffset = 0
            }
        }
    }
}

// MARK: - Music Connection Page
struct MusicConnectionPage: View {
    let goBack: () -> Void
    let goToNext: () -> Void
    
    @State private var opacity: Double = 0
    @State private var isConnecting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var connectedService: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button
            Button(action: goBack) {
                Text("← GERI")
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            .padding(.top, 14)
            
            // Title
            Text("Nereden\ndinliyorsun?")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)
                .lineSpacing(4)
                .tracking(-0.75)
                .padding(.top, 28)
            
            // Sub
            Text("Bağlanırsan daha hızlı seçer, daha kolay keşfeder, daha rahat paylaşırsın.")
                .monoBase()
                .foregroundColor(ONETokens.oneAsh)
                .lineSpacing(6)
                .padding(.top, 12)
            
            // Services
            VStack(spacing: 10) {
                ServiceButton(
                    icon: "♪",
                    iconBg: "#FC3C44",
                    name: "Apple Music",
                    desc: connectedService == "AppleMusic" ? "✓ Bağlandı" : "Arama ve şarkı geçmişi",
                    action: connectAppleMusic,
                    isConnected: connectedService == "AppleMusic"
                )
            }
            .padding(.top, 36)
            
            Spacer()
            
            // Continue or Skip button
            if connectedService != nil {
                Button(action: goToNext) {
                    Text("DEVAM ET")
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(ONETokens.oneInk)
                        .cornerRadius(16)
                }
            } else {
                Button(action: goToNext) {
                    Text("BAĞLAMADAN DEVAM ET")
                        .monoSM(tracking: 1.4)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity)
            }
            
            Text("Verilerini satmıyoruz.\nHer şey cihazında saklanır.")
                .monoLabel()
                .foregroundColor(ONETokens.oneStone)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium)) {
                opacity = 1
            }
            
            // Check if already connected
            if let service = UserDefaults.standard.string(forKey: "preferredMusicService") {
                connectedService = service
            }
            
        }
        .alert("Bilgi", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .overlay(
            Group {
                if isConnecting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Bağlanıyor...")
                                .monoBase()
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(ONETokens.oneInk)
                        .cornerRadius(16)
                    }
                }
            }
        )
    }
    
    private func connectAppleMusic() {
        isConnecting = true
        
        Task {
            let status = await MusicAuthorization.request()
            
            await MainActor.run {
                isConnecting = false
                
                if status == .authorized {
                    // Save preference
                    UserDefaults.standard.set("AppleMusic", forKey: "preferredMusicService")
                    connectedService = "AppleMusic"
                    
                    alertMessage = "Apple Music başarıyla bağlandı!"
                    showAlert = true
                } else {
                    alertMessage = "Apple Music erişimi reddedildi. Ayarlardan izin verebilirsin."
                    showAlert = true
                }
            }
        }
    }
}


// MARK: - Apple Music Connection Page
struct AppleMusicConnectionPage: View {
    let goBack: () -> Void
    let complete: () -> Void

    @State private var opacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var showDeniedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button
            Button(action: goBack) {
                Text("← GERI")
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.vertical, 4)
            }
            .padding(.top, 14)

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(hex: "#FC3C44"))
                        .frame(width: 64, height: 64)
                    Text("♪")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 28)

                // Title
                Text("Apple Music\nbağlansın mı?")
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                    .lineSpacing(4)
                    .tracking(-0.75)

                // Info pills
                VStack(alignment: .leading, spacing: 10) {
                    InfoPill(icon: "checkmark.circle.fill", color: Color(hex: "#FC3C44"),
                             text: "Abonelik gerekmez")
                    InfoPill(icon: "sparkles", color: Color(hex: "#FC3C44"),
                             text: "Sadece şarkı önerileri için kullanılır")
                    InfoPill(icon: "lock.fill", color: ONETokens.oneAsh,
                             text: "Müzik kütüphanen paylaşılmaz")
                }
                .padding(.top, 24)
            }
            .offset(y: contentOffset)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                if isConnected {
                    Button(action: complete) {
                        Text("HARIKA, DEVAM ET")
                            .monoSM(tracking: 1.4)
                            .foregroundColor(ONETokens.oneCream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color(hex: "#FC3C44"))
                            .cornerRadius(16)
                    }
                } else {
                    Button(action: connectAppleMusic) {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ONETokens.oneCream))
                                    .scaleEffect(0.85)
                            }
                            Text(isConnecting ? "Bağlanıyor..." : "Apple Music'e İzin Ver")
                                .monoSM(tracking: 1.4)
                                .foregroundColor(ONETokens.oneCream)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(ONETokens.oneInk)
                        .cornerRadius(16)
                    }
                    .disabled(isConnecting)

                    Button(action: complete) {
                        Text("ŞIMDILIK GEÇ")
                            .monoSM(tracking: 1.4)
                            .foregroundColor(ONETokens.oneAsh)
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("İzni istediğin zaman ayarlardan değiştirebilirsin.")
                    .monoLabel()
                    .foregroundColor(ONETokens.oneStone)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 56)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium)) {
                opacity = 1
                contentOffset = 0
            }
            // Already connected?
            if UserDefaults.standard.string(forKey: "preferredMusicService") == "AppleMusic" {
                isConnected = true
            }
        }
        .alert("Apple Music Erişimi", isPresented: $showDeniedAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Apple Music erişimi reddedildi. Ayarlar → Gizlilik → Medya ve Apple Music'ten izin verebilirsin.")
        }
    }

    private func connectAppleMusic() {
        isConnecting = true
        Task {
            let status = await MusicAuthorization.request()
            await MainActor.run {
                isConnecting = false
                if status == .authorized {
                    UserDefaults.standard.set("AppleMusic", forKey: "preferredMusicService")
                    withAnimation(.easeOut(duration: ONEAnimation.durationShort)) {
                        isConnected = true
                    }
                } else {
                    showDeniedAlert = true
                }
            }
        }
    }
}

// MARK: - Info Pill
private struct InfoPill: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .monoSM()
                .foregroundColor(ONETokens.oneAsh)
        }
    }
}

// MARK: - Service Button
struct ServiceButton: View {
    let icon: String
    let iconBg: String
    let name: String
    let desc: String
    let action: () -> Void
    let isConnected: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: iconBg))
                        .frame(width: 36, height: 36)
                    
                    Text(icon)
                        .font(.system(size: 18))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .monoBase(tracking: -0.1)
                        .foregroundColor(ONETokens.oneInk)
                    
                    Text(desc)
                        .monoSM()
                        .foregroundColor(isConnected ? ONETokens.spotifyGreen : ONETokens.oneAsh)
                }
                
                Spacer()
                
                // Arrow or Checkmark
                if isConnected {
                    Text("✓")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ONETokens.spotifyGreen)
                } else {
                    Text("›")
                        .font(.system(size: 20))
                        .foregroundColor(ONETokens.oneAsh)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isConnected ? ONETokens.oneCreamMid.opacity(0.5) : ONETokens.oneCreamMid)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isConnected ? ONETokens.spotifyGreen.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isConnected)
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
