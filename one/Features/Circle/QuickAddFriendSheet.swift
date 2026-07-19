import SwiftUI
import CloudKit

struct QuickAddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

    // MARK: - State

    @State private var smartQuery      = ""
    @State private var searchPhase     = SearchPhase.idle
    @State private var foundUser: CKRecord? = nil
    @State private var foundRelationship = FoundUserState.checking
    @State private var isLoading       = false
    @State private var showSuccess     = false
    @State private var successMessage  = ""
    @State private var codeCopied      = false

    // Suggestions
    @State private var suggestions: [SuggestedUser] = []
    @State private var suggestionsLoading = false
    @State private var sendingIDs: Set<String> = []
    @State private var sentIDs: Set<String> = []

    // MARK: - Enums

    private enum SearchPhase: Equatable {
        case idle
        case searching
        case found
        case notFound
        case networkError
    }

    private enum FoundUserState {
        case checking       // ilişki kontrol ediliyor
        case canAdd         // eklenebilir
        case alreadyFriends // zaten arkadaş
        case pendingSent    // istek zaten gönderilmiş, bekliyor
        case pendingReceived// karşı taraf seni eklemiş, sen kabul etmedin
        case isSelf         // kullanıcı kendini arıyor
        case blocked        // engelleme var (privacy: not-found gibi göster)
    }

    // MARK: - Derived

    private var myInviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? ""
    }

    private var codeReady: Bool { !myInviteCode.isEmpty }

    private var queryTrimmed: String { smartQuery.trimmingCharacters(in: .whitespaces) }

    private var isCodeQuery: Bool {
        let upper = queryTrimmed.uppercased().filter { $0.isLetter || $0.isNumber }
        return upper.count == 6
    }

    private var isQueryReady: Bool {
        if queryTrimmed.hasPrefix("@") { return queryTrimmed.count >= 4 }
        return isCodeQuery || queryTrimmed.count >= 3
    }

    private var searchBorderColor: Color {
        switch searchPhase {
        case .found:         return ONETokens.oneGreen
        case .notFound, .networkError: return Color.red.opacity(0.4)
        default:             return isQueryReady ? ONETokens.oneInk.opacity(0.3) : Color.clear
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(ONETokens.oneStone.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 18)

            HStack(alignment: .center) {
                Text("Hızlı Ekle")
                    .displaySM()
                    .foregroundColor(ONETokens.oneInk)
                Spacer()
                copyCodeChip
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    searchArea
                    if !showSuccess {
                        suggestedSection
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
        .onAppear {
            resetState()
            loadSuggestions()
        }
    }

    // MARK: - Copy chip

    private var copyCodeChip: some View {
        Button(action: copyCode) {
            HStack(spacing: 5) {
                Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                Text(codeCopied ? "Kopyalandı" : (codeReady ? myInviteCode : "Yükleniyor…"))
                    .monoLabel(tracking: 1.2)
            }
            .foregroundColor(codeCopied ? ONETokens.oneGreen : (codeReady ? ONETokens.oneInk : ONETokens.oneStone))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(ONETokens.oneSilver.opacity(0.7)))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!codeReady || codeCopied)
        .animation(ONEAnimation.micro, value: codeCopied)
        .animation(ONEAnimation.micro, value: codeReady)
    }

    private func copyCode() {
        guard codeReady else { return }
        UIPasteboard.general.string = myInviteCode
        ONEHaptics.songSaved()
        codeCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
    }

    // MARK: - Search area

    @ViewBuilder
    private var searchArea: some View {
        if showSuccess {
            successView
        } else {
            VStack(spacing: 12) {
                // Arama kutusu
                HStack(spacing: 10) {
                    Image(systemName: queryTrimmed.hasPrefix("@") ? "at" : (isCodeQuery ? "number" : "magnifyingglass"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ONETokens.oneAsh)
                        .frame(width: 20)

                    TextField("@kullanıcı adı veya 6 haneli kod", text: $smartQuery)
                        .monoLabel(tracking: 0.3)
                        .foregroundColor(ONETokens.oneInk)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { performSearch() }
                        .onChange(of: smartQuery) { _, _ in clearResult() }

                    Group {
                        if searchPhase == .searching {
                            ProgressView().scaleEffect(0.75)
                        } else if isQueryReady {
                            Button(action: performSearch) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(ONETokens.oneInk)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .frame(width: 24)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ONETokens.onePaper)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(searchBorderColor, lineWidth: 1.5))
                )

                // Sonuç durumları
                switch searchPhase {
                case .notFound:
                    inlineMessage(
                        icon: "person.fill.questionmark",
                        text: "Kullanıcı bulunamadı. Kodu veya @kullanıcı adını kontrol et.",
                        color: Color.red.opacity(0.7)
                    )

                case .networkError:
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13))
                            .foregroundColor(ONETokens.oneAsh)
                        Text("Bağlantı hatası.")
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneAsh)
                        Spacer()
                        Button("Tekrar dene", action: performSearch)
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONETokens.oneInk)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ONETokens.onePaper))
                    .transition(.opacity)

                case .found:
                    if let user = foundUser {
                        foundUserCard(user: user)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                default:
                    EmptyView()
                }
            }
            .animation(ONEAnimation.micro, value: searchPhase)
        }
    }

    // MARK: - Found user card

    private func foundUserCard(user: CKRecord) -> some View {
        let displayName = user["displayName"] as? String ?? "Kullanıcı"
        let colorHex    = user["avatarColor"] as? String ?? "#888888"
        let username    = user["username"]    as? String
        let initial     = String(displayName.prefix(1)).uppercased()

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle().fill(Color(hex: colorHex)).frame(width: 44, height: 44)
                    Text(initial)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }

                // İsim + username
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName).bodySM().foregroundColor(ONETokens.oneInk)
                    if let un = username {
                        Text("@\(un)").monoLabel(tracking: 0.3).foregroundColor(ONETokens.oneAsh)
                    }
                }

                Spacer()

                // Relationship durumuna göre aksiyon
                relationshipAction(displayName: displayName, userID: user["userID"] as? String ?? "")
            }
            .padding(14)

            // Relationship açıklama satırı (gerekirse)
            relationshipSubline
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(ONETokens.onePaper))
    }

    @ViewBuilder
    private func relationshipAction(displayName: String, userID: String) -> some View {
        switch foundRelationship {
        case .checking:
            ProgressView().scaleEffect(0.75).frame(width: 60)

        case .canAdd:
            Button(action: sendRequest) {
                if isLoading {
                    ProgressView().scaleEffect(0.75).tint(ONETokens.oneCream).frame(width: 60)
                } else {
                    Text("Ekle")
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(ONETokens.oneCream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(ONETokens.oneInk))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isLoading)

        case .alreadyFriends:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("Arkadaş")
                    .monoLabel(tracking: 0.3)
            }
            .foregroundColor(ONETokens.oneGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(ONETokens.oneGreen.opacity(0.12)))

        case .pendingSent:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("Bekliyor")
                    .monoLabel(tracking: 0.3)
            }
            .foregroundColor(ONETokens.oneAsh)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(ONETokens.oneSilver.opacity(0.7)))

        case .pendingReceived:
            Button(action: { goToFriendRequests() }) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 11))
                    Text("Kabul Et")
                        .monoLabel(tracking: 0.3)
                }
                .foregroundColor(ONETokens.oneCream)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(ONETokens.oneBrand))
            }
            .buttonStyle(ScaleButtonStyle())

        case .isSelf:
            Text("Bu sensin 👋")
                .monoLabel(tracking: 0.3)
                .foregroundColor(ONETokens.oneAsh)

        case .blocked:
            // Privacy: dışarıdan not-found gibi görünmeli
            EmptyView()
        }
    }

    @ViewBuilder
    private var relationshipSubline: some View {
        switch foundRelationship {
        case .pendingSent:
            Text("İsteklerin zaten gönderildi. Kabul etmesini bekle.")
                .monoLabel(tracking: 0.3)
                .foregroundColor(ONETokens.oneMist)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

        case .pendingReceived:
            Text("Bu kişi seni çevresine eklemiş. Kabul etmek için İstekler ekranına git.")
                .monoLabel(tracking: 0.3)
                .foregroundColor(ONETokens.oneMist)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

        case .alreadyFriends:
            Text("Bu kişi zaten çevrende.")
                .monoLabel(tracking: 0.3)
                .foregroundColor(ONETokens.oneMist)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

        default:
            EmptyView()
        }
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(ONETokens.oneGreen)
            Text(successMessage)
                .bodySM()
                .foregroundColor(ONETokens.oneInk)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Suggested section (Friends of Friends)

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ÖNERİLEN")
                    .monoLabel(tracking: 1.8)
                    .foregroundColor(ONETokens.oneAsh)
                Spacer()
                if suggestionsLoading {
                    ProgressView().scaleEffect(0.7)
                } else if !suggestions.isEmpty {
                    Button(action: { loadSuggestions(force: true) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if suggestionsLoading && suggestions.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    suggestionSkeleton
                }
            } else if suggestions.isEmpty {
                Text("Henüz öneri yok. Arkadaşların arttıkça burası dolar.")
                    .bodySM()
                    .foregroundColor(ONETokens.oneMist)
            } else {
                ForEach(suggestions) { user in
                    suggestionRow(user)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(ONEAnimation.micro, value: suggestions.map { $0.id })
        .animation(ONEAnimation.micro, value: suggestionsLoading)
    }

    private var suggestionSkeleton: some View {
        HStack(spacing: 12) {
            Circle().fill(ONETokens.oneSilver.opacity(0.5)).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(ONETokens.oneSilver.opacity(0.5)).frame(width: 120, height: 11)
                Capsule().fill(ONETokens.oneSilver.opacity(0.3)).frame(width: 80, height: 9)
            }
            Spacer()
            Capsule().fill(ONETokens.oneSilver.opacity(0.4)).frame(width: 56, height: 26)
        }
        .padding(.vertical, 6)
    }

    private func suggestionRow(_ user: SuggestedUser) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: user.avatarColorHex)).frame(width: 40, height: 40)
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .bodySM()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let un = user.username {
                        Text("@\(un)")
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneAsh)
                            .lineLimit(1)
                    }
                    if user.mutualFriendCount > 0 {
                        Text("• \(user.mutualFriendCount) ortak")
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(ONETokens.oneMist)
                    }
                }
            }

            Spacer()

            suggestionAction(user)

            Button(action: { dismissSuggestion(user) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ONETokens.oneStone)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(ONETokens.oneSilver.opacity(0.5)))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Bu öneriyi gizle")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func suggestionAction(_ user: SuggestedUser) -> some View {
        if sentIDs.contains(user.id) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Gönderildi")
                    .monoLabel(tracking: 0.3)
            }
            .foregroundColor(ONETokens.oneGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(ONETokens.oneGreen.opacity(0.12)))
        } else if sendingIDs.contains(user.id) {
            ProgressView().scaleEffect(0.65).frame(width: 56, height: 28)
        } else {
            Button(action: { sendSuggestionRequest(user) }) {
                Text("+ Ekle")
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Helpers

    private func inlineMessage(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
            Text(text).monoLabel(tracking: 0.3).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func resetState() {
        smartQuery       = ""
        searchPhase      = .idle
        foundUser        = nil
        foundRelationship = .checking
        isLoading        = false
        showSuccess      = false
        successMessage   = ""
        codeCopied       = false
    }

    private func clearResult() {
        guard searchPhase != .idle else { return }
        searchPhase      = .idle
        foundUser        = nil
        foundRelationship = .checking
    }

    // MARK: - CloudKit actions

    private func performSearch() {
        let q = queryTrimmed
        guard !q.isEmpty, isQueryReady else { return }

        searchPhase       = .searching
        foundUser         = nil
        foundRelationship = .checking

        let searchTerm = q.hasPrefix("@") ? q : (isCodeQuery ? q.uppercased() : q)

        cloudKitManager.findUserByCodeOrUsername(searchTerm) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    // Kendini arıyor mu?
                    let foundID    = user["userID"] as? String ?? ""
                    let currentID  = self.cloudKitManager.currentUser?["userID"] as? String ?? ""
                    if foundID == currentID {
                        ONEHaptics.tabSwitch()
                        self.foundUser    = user
                        self.searchPhase  = .found
                        self.foundRelationship = .isSelf
                        return
                    }

                    ONEHaptics.songSaved()
                    self.foundUser   = user
                    self.searchPhase = .found

                    // İlişki durumunu kontrol et
                    self.cloudKitManager.checkExistingRelationship(with: foundID) { status in
                        withAnimation(ONEAnimation.micro) {
                            switch status {
                            case .alreadyFriends:    self.foundRelationship = .alreadyFriends
                            case .pendingSent:        self.foundRelationship = .pendingSent
                            case .pendingReceived:    self.foundRelationship = .pendingReceived
                            case .blocked:            self.foundRelationship = .blocked
                            case .none:               self.foundRelationship = .canAdd
                            }
                        }
                    }

                case .failure(let error):
                    ONEHaptics.error()
                    let nsError = error as NSError
                    // CKError 1 = network failure
                    if nsError.domain == CKError.errorDomain && nsError.code == CKError.networkFailure.rawValue {
                        withAnimation(ONEAnimation.micro) { self.searchPhase = .networkError }
                    } else {
                        withAnimation(ONEAnimation.micro) { self.searchPhase = .notFound }
                    }
                }
            }
        }
    }

    private func sendRequest() {
        guard let user = foundUser, foundRelationship == .canAdd else { return }
        let userID      = user["userID"]      as? String ?? ""
        let displayName = user["displayName"] as? String ?? "Kullanıcı"

        isLoading = true
        cloudKitManager.sendFriendRequest(toUserID: userID) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success:
                    ONEHaptics.songSaved()
                    withAnimation(ONEAnimation.micro) {
                        self.successMessage = "\(displayName) adlı kullanıcıya istek gönderildi!"
                        self.showSuccess    = true
                        self.foundUser      = nil
                        self.smartQuery     = ""
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }

                case .failure(let error):
                    ONEHaptics.error()
                    let nsError = error as NSError
                    if nsError.code == -2 {
                        // Zaten istek gönderilmiş
                        withAnimation(ONEAnimation.micro) {
                            self.foundRelationship = .pendingSent
                        }
                    }
                }
            }
        }
    }

    private func goToFriendRequests() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .init("OpenFriendRequests"), object: nil)
        }
    }

    // MARK: - Suggestions actions

    private func loadSuggestions(force: Bool = false) {
        suggestionsLoading = true
        cloudKitManager.fetchSuggestedUsers(limit: 5, forceRefresh: force) { users in
            withAnimation(ONEAnimation.micro) {
                self.suggestions = users.filter { !self.sentIDs.contains($0.id) }
                self.suggestionsLoading = false
            }
        }
    }

    private func sendSuggestionRequest(_ user: SuggestedUser) {
        guard !sendingIDs.contains(user.id), !sentIDs.contains(user.id) else { return }
        sendingIDs.insert(user.id)
        cloudKitManager.sendFriendRequest(toUserID: user.id) { result in
            DispatchQueue.main.async {
                self.sendingIDs.remove(user.id)
                switch result {
                case .success:
                    ONEHaptics.songSaved()
                    withAnimation(ONEAnimation.micro) {
                        self.sentIDs.insert(user.id)
                    }
                    // 1.2sn göster, sonra listeden kaldır + cache invalidate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(ONEAnimation.micro) {
                            self.suggestions.removeAll { $0.id == user.id }
                        }
                        self.cloudKitManager.invalidateSuggestionsCache()
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code == -2 {
                        // Zaten istek gönderilmiş — başarı gibi göster
                        ONEHaptics.tabSwitch()
                        withAnimation(ONEAnimation.micro) {
                            self.sentIDs.insert(user.id)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(ONEAnimation.micro) {
                                self.suggestions.removeAll { $0.id == user.id }
                            }
                        }
                    } else {
                        ONEHaptics.error()
                    }
                }
            }
        }
    }

    private func dismissSuggestion(_ user: SuggestedUser) {
        DismissedSuggestionsStore.dismiss(user.id)
        ONEHaptics.tabSwitch()
        withAnimation(ONEAnimation.micro) {
            suggestions.removeAll { $0.id == user.id }
        }
    }
}
