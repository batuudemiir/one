//
//  ProfileView.swift
//  one
//
//  User profile setup and management
//

import SwiftUI
import CloudKit
import MusicKit
import CoreData

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var selectedAvatarColor: String = "#5B8DEF"
    
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var isEditMode = false
    @State private var isEditingFromTab = false
    
    // Settings states
    @ObservedObject private var spotifyManager = SpotifyManager.shared
    @State private var appleMusicStatus: MusicAuthorization.Status = .notDetermined
    @State private var showSpotifyLogoutAlert = false
    
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var dailyReminderTime = Date()
    
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage("selectedTheme") private var selectedTheme = "Sistem"
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    
    var isFromTab: Bool = false
    
    // Username validation states
    @State private var usernameValidationMessage: String?
    @State private var isUsernameAvailable: Bool?
    @State private var isCheckingUsername = false
    @State private var usernameCheckTask: Task<Void, Never>?
    
    // UX Focus States
    @FocusState private var focusedField: ProfileField?
    
    // UX Animation States
    @State private var appeared = false
    @State private var inviteCodeCopied = false
    @State private var showShareSheet = false

    // Hesap yönetimi
    @State private var showDeleteAccountAlert = false
    @State private var showAppleMusicInfoAlert = false
    @State private var showICloudInfoAlert = false
    
    enum ProfileField {
        case displayName, username
    }
    
    private let avatarColors = [
        "#5B8DEF", // Blue
        "#E84040", // Red
        "#4CAF82", // Green
        "#F59E0B", // Orange
        "#8B5CF6", // Purple
        "#EC4899", // Pink
        "#10B981", // Emerald
        "#F97316"  // Orange-Red
    ]
    
    var inviteCode: String {
        cloudKitManager.currentUser?["inviteCode"] as? String ?? "------"
    }
    
    var existingName: String {
        cloudKitManager.currentUser?["displayName"] as? String ?? ""
    }
    
    var existingUsername: String {
        cloudKitManager.currentUser?["username"] as? String ?? ""
    }
    
    var existingColor: String {
        cloudKitManager.currentUser?["avatarColor"] as? String ?? "#5B8DEF"
    }
    
    var hasExistingProfile: Bool {
        UserDefaults.standard.bool(forKey: "hasCreatedProfile") && cloudKitManager.currentUser != nil
    }
    
    var canSaveProfile: Bool {
        !displayName.isEmpty && displayName.count <= 50
    }
    
    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()
            
            if isFromTab && hasExistingProfile && !isEditingFromTab {
                profileDashboardView
            } else {
                // Form is presented in a sheet-like manner when coming from tab
                if isFromTab {
                    profileFormView
                } else {
                    NavigationView {
                        profileFormView
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: { dismiss() }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(ONETokens.oneAsh)
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.8))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
        .alert("Spotify Bağlantısını Kes", isPresented: $showSpotifyLogoutAlert) {
            Button("İptal", role: .cancel) { }
            Button("Bağlantıyı Kes", role: .destructive) {
                spotifyManager.logout()
            }
        } message: {
            Text("Spotify bağlantısını kesmek istediğinize emin misiniz? Öneriler ve önbellek temizlenecek.")
        }
        .alert("Apple Music İzni", isPresented: $showAppleMusicInfoAlert) {
            Button("Ayarlar'ı Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Apple Music iznini kaldırmak için Ayarlar > Gizlilik ve Güvenlik > Medya ve Apple Music bölümünden ONE uygulamasını kapatabilirsin.")
        }
        .alert("iCloud Verilerini Sil", isPresented: $showICloudInfoAlert) {
            Button("İptal", role: .cancel) { }
            Button("Verileri Sil", role: .destructive) {
                cloudKitManager.deleteCurrentUserRecord()
            }
        } message: {
            Text("ONE'daki profil ve çevre verilerin iCloud'dan silinecek. Bu işlem geri alınamaz.")
        }
        .alert("Hesabı Sil", isPresented: $showDeleteAccountAlert) {
            Button("İptal", role: .cancel) { }
            Button("Hesabı Sil", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Tüm şarkı kayıtların, profil ve çevre verilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.")
        }
        .task {
            appleMusicStatus = MusicAuthorization.currentStatus
        }
        .onAppear {
            if preferredCity == "İzmit" {
                preferredCity = "Kocaeli"
            }
            loadExistingProfile()
            
            var components = DateComponents()
            components.hour = dailyReminderHour
            components.minute = dailyReminderMinute
            if let date = Calendar.current.date(from: components) {
                dailyReminderTime = date
            }
            
            if cloudKitManager.currentUser != nil {
                isEditMode = true
            }
            
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.1)) {
                appeared = true
            }
        }
    }
    
    // MARK: - Dashboard View (Read-Only)
    private var profileDashboardView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: — Header (Archive tarzında, sol hizalı)
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Üst satır: Meta label + Düzenle
                    HStack(alignment: .center) {
                        Text("PROFİL")
                            .monoBase(tracking: 1.5)
                            .foregroundColor(ONETokens.oneCharcoal)
                        
                        Spacer()
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(ONEAnimation.cardSpring) {
                                isEditingFromTab = true
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Düzenle")
                                    .monoSM(tracking: 0.5)
                            }
                            .foregroundColor(ONETokens.oneAsh)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.8))
                                    .overlay(Capsule().stroke(ONETokens.oneStone, lineWidth: 1))
                            )
                        }
                    }
                    
                    // İsim + avatar inline
                    HStack(spacing: 16) {
                        // Compact avatar
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedAvatarColor))
                                .frame(width: 52, height: 52)
                            Text(displayName.prefix(1).uppercased())
                                .displayMD()
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .displayLG()
                                .foregroundColor(ONETokens.oneInk)
                                .lineLimit(1)
                            
                            if !username.isEmpty {
                                Text("@\(username)")
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top, 52)
                .padding(.horizontal, 22)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                
                // MARK: — İstatistik Satırı (Archive statsRow tarzında)
                statsRow
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.1), value: appeared)
                
                // MARK: — Davet Kodu
                if !inviteCode.isEmpty && inviteCode != "------" {
                    inviteCodeSection
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.15), value: appeared)
                }
                
                // MARK: — Müzik Servisleri
                musicServicesSection
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.2), value: appeared)
                
                // MARK: — Ayarlar
                settingsSection
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.25), value: appeared)
                
                // MARK: — Diğer
                otherSection
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.3), value: appeared)
                
                // MARK: — Footer
                footerSection
                    .padding(.top, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.35), value: appeared)
                
                Spacer().frame(height: 100)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if inviteCode != "------" {
                ShareSheet(items: ["🌙 One uygulamasında beni bul!\nDavet kodum: \(inviteCode)"])
            }
        }
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: formattedMemberSince, label: "Katılım")
            Divider().frame(height: 32).background(ONETokens.oneIvory)
            statCell(value: "\(totalDaysCount)", label: "Gün")
            Divider().frame(height: 32).background(ONETokens.oneIvory)
            statCell(value: musicServiceLabel, label: "Müzik")
        }
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
    }
    
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .displayXS()
                .fontWeight(.semibold)
                .foregroundColor(ONETokens.oneInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .monoLabel()
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var formattedMemberSince: String {
        // İlk Core Data kaydını önce dene; yoksa CloudKit kayıt tarihini kullan
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1
        if let firstEntry = try? viewContext.fetch(request).first,
           let date = firstEntry.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            formatter.locale = Locale(identifier: "tr_TR")
            return formatter.string(from: date)
        }
        if let creationDate = cloudKitManager.currentUser?.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            formatter.locale = Locale(identifier: "tr_TR")
            return formatter.string(from: creationDate)
        }
        return "—"
    }

    private var totalDaysCount: Int {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        return (try? viewContext.count(for: request)) ?? 0
    }
    
    private var musicServiceLabel: String {
        if spotifyManager.isAuthenticated && appleMusicStatus == .authorized {
            return "İkisi"
        } else if spotifyManager.isAuthenticated {
            return "Spotify"
        } else if appleMusicStatus == .authorized {
            return "Apple"
        }
        return "—"
    }
    
    // MARK: - Invite Code Section
    private var inviteCodeSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Code display
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAVET KODU")
                        .monoBase(tracking: 1.5)
                        .foregroundColor(ONETokens.oneCharcoal)
                    Text(inviteCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(ONETokens.oneInk)
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 6) {
                    Button {
                        UIPasteboard.general.string = inviteCode
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(ONEAnimation.micro) {
                            inviteCodeCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { inviteCodeCopied = false }
                        }
                    } label: {
                        Image(systemName: inviteCodeCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(inviteCodeCopied ? ONETokens.oneGreen : ONETokens.oneAsh)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.8)))
                    }
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.8)))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
        }
    }
    
    // MARK: - Music Services Section
    private var musicServicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MÜZİK SERVİSLERİ")
                .monoBase(tracking: 1.5)
                .foregroundColor(ONETokens.oneCharcoal)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Spotify — v2'de aktif edilecek
                settingsRow(
                    icon: "music.note",
                    iconColor: ONETokens.oneStone,
                    title: "Spotify",
                    trailing: {
                        Text("Yakında")
                            .monoSM(tracking: 0.4)
                            .foregroundColor(ONETokens.oneStone)
                    },
                    showDivider: true
                )
                .opacity(0.5)

                // Apple Music — bağla veya bilgi
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if appleMusicStatus == .authorized {
                        showAppleMusicInfoAlert = true
                    } else {
                        Task {
                            let status = await MusicAuthorization.request()
                            appleMusicStatus = status
                            if status == .authorized {
                                NotificationCenter.default.post(name: NSNotification.Name("AppleMusicAuthenticationChanged"), object: nil)
                            }
                        }
                    }
                }) {
                    settingsRow(
                        icon: "applelogo",
                        iconColor: ONETokens.appleMusicRed,
                        title: "Apple Music",
                        trailing: {
                            connectionDot(
                                connected: appleMusicStatus == .authorized,
                                color: ONETokens.appleMusicRed,
                                text: appleMusicStatus == .authorized ? "Bağlı · Ayarlar'dan kes" : "Bağla"
                            )
                        },
                        showDivider: false
                    )
                }
            }
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AYARLAR")
                .monoBase(tracking: 1.5)
                .foregroundColor(ONETokens.oneCharcoal)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Haptic
                settingsToggleRow(icon: "hand.tap", title: "Dokunsal Geri Bildirim", isOn: $hapticFeedbackEnabled)
                
                // Theme
                Menu {
                    Button("Açık") { selectedTheme = "Açık" }
                    Button("Koyu") { selectedTheme = "Koyu" }
                    Button("Sistem") { selectedTheme = "Sistem" }
                } label: {
                    settingsRow(
                        icon: "circle.lefthalf.filled",
                        iconColor: ONETokens.oneInk,
                        title: "Tema",
                        trailing: {
                            HStack(spacing: 4) {
                                Text(selectedTheme)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(ONETokens.oneStone)
                            }
                        },
                        showDivider: true
                    )
                }
                
                // City
                Menu {
                    ForEach(ONETokens.availableCities, id: \.self) { city in
                        Button(action: { preferredCity = city }) {
                            HStack {
                                Text(city)
                                if city == preferredCity {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    settingsRow(
                        icon: "mappin.circle",
                        iconColor: ONETokens.oneInk,
                        title: "Şehir",
                        trailing: {
                            HStack(spacing: 4) {
                                Text(preferredCity)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(ONETokens.oneStone)
                            }
                        },
                        showDivider: true
                    )
                }

                // Notifications
                settingsToggleRow(icon: "bell", title: "Günlük Hatırlatıcı", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            NotificationManager.shared.scheduleDailyReminder(at: dailyReminderTime) { success in
                                if !success {
                                    DispatchQueue.main.async {
                                        notificationsEnabled = false
                                        errorMessage = "Bildirim izni reddedildi, Ayarlar'dan açabilirsiniz."
                                    }
                                }
                            }
                        } else {
                            NotificationManager.shared.disableDailyReminder()
                        }
                    }
                
                if notificationsEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(width: 20)
                        
                        DatePicker("Saat", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                            .bodySM()
                            .tint(ONETokens.oneInk)
                            .onChange(of: dailyReminderTime) { _, newTime in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                                if let hour = components.hour, let minute = components.minute {
                                    dailyReminderHour = hour
                                    dailyReminderMinute = minute
                                    NotificationManager.shared.scheduleDailyReminder(at: newTime)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // iCloud
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if cloudKitManager.isCloudKitAvailable {
                        showICloudInfoAlert = true
                    } else {
                        cloudKitManager.checkCloudKitAvailability()
                    }
                }) {
                    settingsRow(
                        icon: "cloud",
                        iconColor: cloudKitManager.isCloudKitAvailable ? ONETokens.oneGreen : ONETokens.oneAsh,
                        title: "iCloud",
                        trailing: {
                            connectionDot(
                                connected: cloudKitManager.isCloudKitAvailable,
                                color: ONETokens.oneGreen,
                                text: cloudKitManager.isCloudKitAvailable ? "Aktif · Veriyi sil" : "Kapalı"
                            )
                        },
                        showDivider: false
                    )
                }
            }
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
        }
    }
    
    // MARK: - Other Section
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DİĞER")
                .monoBase(tracking: 1.5)
                .foregroundColor(ONETokens.oneCharcoal)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Button(action: {}) {
                    settingsRow(
                        icon: "square.and.arrow.up",
                        iconColor: ONETokens.oneInk,
                        title: "Verilerimi Dışa Aktar",
                        trailing: { chevronRight },
                        showDivider: true
                    )
                }
                
                Button(action: {}) {
                    settingsRow(
                        icon: "star",
                        iconColor: ONETokens.oneInk,
                        title: "Uygulamayı Değerlendir",
                        trailing: { chevronRight },
                        showDivider: false
                    )
                }
            }
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))

            // Hesap silme — ayrı kart, kırmızı vurgu
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showDeleteAccountAlert = true
            }) {
                settingsRow(
                    icon: "trash",
                    iconColor: ONETokens.oneRed,
                    title: "Hesabı Sil",
                    trailing: { chevronRight },
                    showDivider: false
                )
            }
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneRed.opacity(0.20), lineWidth: 1))
        }
    }
    
    // MARK: - Hesap Silme

    private func deleteAccount() {
        // 1. Tüm Core Data kayıtlarını sil
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DailySong")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? viewContext.execute(deleteRequest)
        try? viewContext.save()

        // 2. Spotify token ve cache temizle
        spotifyManager.logout()

        // 3. CloudKit profilini sil
        cloudKitManager.deleteCurrentUserRecord()

        // 5. UserDefaults sıfırla
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: "hasCreatedProfile")
        defaults.removeObject(forKey: "dailyReminderHour")
        defaults.removeObject(forKey: "dailyReminderMinute")
        defaults.removeObject(forKey: "notificationsEnabled")
        defaults.removeObject(forKey: "hapticFeedbackEnabled")
        defaults.removeObject(forKey: "selectedTheme")
        defaults.removeObject(forKey: ONETokens.cityPreferenceKey)
        defaults.removeObject(forKey: "preferredMusicService")

        // 6. Onboarding'e dön
        NotificationCenter.default.post(name: NSNotification.Name("resetToOnboarding"), object: nil)
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("One — Günlük Mood")
                .bodySM()
                .foregroundColor(ONETokens.oneStone)
            Text("v1.0.0")
                .monoLabel(tracking: 1.0)
                .foregroundColor(ONETokens.onePebble)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Reusable Row Components
    
    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing,
        showDivider: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title)
                .bodySM()
                .foregroundColor(ONETokens.oneInk)
            
            Spacer()
            
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(
            Group {
                if showDivider {
                    VStack { Spacer(); Rectangle().frame(height: 0.5).foregroundColor(ONETokens.oneSilver) }
                }
            }
        )
    }
    
    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ONETokens.oneInk)
                .frame(width: 20)
            
            Text(title)
                .bodySM()
                .foregroundColor(ONETokens.oneInk)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .tint(ONETokens.oneInk)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(
            VStack { Spacer(); Rectangle().frame(height: 0.5).foregroundColor(ONETokens.oneSilver) }
        )
    }
    
    private func connectionDot(connected: Bool, color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connected ? color : ONETokens.onePebble)
                .frame(width: 6, height: 6)
            Text(text)
                .monoSM(tracking: 0)
                .foregroundColor(connected ? color : ONETokens.oneAsh)
        }
    }
    
    private var chevronRight: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(ONETokens.onePebble)
    }
    
    // MARK: - Edit/Create Form View
    private var profileFormView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    
                    if isFromTab {
                        // Close button for tab edit mode
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(ONEAnimation.cardSpring) {
                                    isEditingFromTab = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(ONETokens.oneAsh)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, 52)
                    }
                    
                    // Form title
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedAvatarColor))
                                .frame(width: 44, height: 44)
                            Text(displayName.isEmpty ? "O" : displayName.prefix(1).uppercased())
                                .displayXS()
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEditMode ? "Profili Düzenle" : "Profil Oluştur")
                                .displayMD()
                                .foregroundColor(ONETokens.oneInk)
                            
                            if !isEditMode {
                                Text("Seni tanıyalım")
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                    }
                    .padding(.top, isFromTab ? 8 : 20)
                }
                .padding(.horizontal, 22)
                
                // Form fields
                VStack(spacing: 16) {
                    
                    // Display Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("İSİM")
                            .monoBase(tracking: 1.5)
                            .foregroundColor(ONETokens.oneCharcoal)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "person")
                                .font(.system(size: 14))
                                .foregroundColor(focusedField == .displayName ? Color(hex: selectedAvatarColor) : ONETokens.oneAsh)
                                .frame(width: 20)
                            
                            TextField("Nasıl hitap edelim?", text: $displayName)
                                .focused($focusedField, equals: .displayName)
                                .bodyLG()
                                .fontWeight(.medium)
                                .foregroundColor(ONETokens.oneInk)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .username }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    focusedField == .displayName ? Color(hex: selectedAvatarColor).opacity(0.5) : ONETokens.oneSilver,
                                    lineWidth: 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: focusedField)
                    }
                    
                    // Username
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KULLANICI ADI")
                            .monoBase(tracking: 1.5)
                            .foregroundColor(ONETokens.oneCharcoal)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 4) {
                            Text("@")
                                .bodyLG()
                                .fontWeight(.medium)
                                .foregroundColor(focusedField == .username ? Color(hex: selectedAvatarColor) : ONETokens.oneAsh)

                            TextField("kullaniciadi", text: $username)
                                .focused($focusedField, equals: .username)
                                .bodyLG()
                                .foregroundColor(ONETokens.oneInk)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .onChange(of: username) { _, newValue in
                                    let lowercased = newValue.lowercased()
                                    if lowercased != newValue { username = lowercased }
                                    checkUsernameAvailability(newValue)
                                }
                            
                            if isCheckingUsername {
                                ProgressView().scaleEffect(0.7)
                            } else if let isAvailable = isUsernameAvailable {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(isAvailable ? ONETokens.oneGreen : ONETokens.oneRed)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    focusedField == .username ? Color(hex: selectedAvatarColor).opacity(0.5) :
                                    isUsernameAvailable == true ? ONETokens.oneGreen.opacity(0.3) :
                                    isUsernameAvailable == false ? ONETokens.oneRed.opacity(0.3) :
                                    ONETokens.oneSilver,
                                    lineWidth: 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: focusedField)
                        
                        if let message = usernameValidationMessage {
                            Text(message)
                                .monoLabel()
                                .foregroundColor(isUsernameAvailable == true ? ONETokens.oneGreen : ONETokens.oneRed)
                                .padding(.leading, 4)
                        }
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RENK")
                            .monoBase(tracking: 1.5)
                            .foregroundColor(ONETokens.oneCharcoal)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 10) {
                            ForEach(avatarColors, id: \.self) { color in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(ONEAnimation.micro) {
                                        selectedAvatarColor = color
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: selectedAvatarColor == color ? 34 : 28, height: selectedAvatarColor == color ? 34 : 28)
                                        
                                        if selectedAvatarColor == color {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2.5)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
                    }
                    
                    // Save Button
                    Button(action: saveProfile) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if showSuccess {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Tamam")
                                }
                            } else {
                                Text(isEditMode ? "Kaydet" : "Profili Oluştur")
                            }
                        }
                        .bodyXS()
                        .fontWeight(.semibold)
                        .foregroundColor(showSuccess ? ONETokens.oneGreen : (canSaveProfile ? ONETokens.oneCream : ONETokens.oneAsh))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(showSuccess ? ONETokens.oneGreen.opacity(0.12) : (canSaveProfile ? ONETokens.oneInk : ONETokens.oneCreamLow))
                                .overlay(
                                    showSuccess ?
                                    RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneGreen.opacity(0.3), lineWidth: 1) :
                                    nil
                                )
                        )
                    }
                    .disabled(!canSaveProfile || isLoading)
                    .padding(.top, 8)
                    
                    if let error = errorMessage {
                        Text(error)
                            .monoSM()
                            .foregroundColor(ONETokens.oneRed)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.bottom, 120)
            .onTapGesture { focusedField = nil }
        }
    }

    // MARK: - Data Functions
    
    private func loadExistingProfile() {
        if !existingName.isEmpty {
            displayName = existingName
            isEditMode = true
        }
        if !existingUsername.isEmpty {
            username = existingUsername
            isUsernameAvailable = true
        }
        selectedAvatarColor = existingColor
    }
    
    private func checkUsernameAvailability(_ newUsername: String) {
        usernameCheckTask?.cancel()
        isUsernameAvailable = nil
        usernameValidationMessage = nil
        
        let validation = cloudKitManager.validateUsername(newUsername)
        if !validation.isValid {
            usernameValidationMessage = validation.error
            isUsernameAvailable = false
            return
        }
        
        if isEditMode && newUsername.lowercased() == existingUsername.lowercased() {
            isUsernameAvailable = true
            usernameValidationMessage = "Mevcut kullanıcı adın"
            return
        }
        
        usernameCheckTask = Task {
            isCheckingUsername = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { isCheckingUsername = false; return }
            
            cloudKitManager.checkUsernameAvailability(newUsername, excludingCurrentUser: isEditMode) { result in
                DispatchQueue.main.async {
                    self.isCheckingUsername = false
                    switch result {
                    case .success(let isAvailable):
                        self.isUsernameAvailable = isAvailable
                        self.usernameValidationMessage = isAvailable ? "Kullanılabilir ✓" : "Bu kullanıcı adı alınmış"
                    case .failure(let error):
                        ONELogger.error("Username check failed: \(error.localizedDescription)", category: .profile)
                        self.usernameValidationMessage = "Kontrol edilemedi"
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !displayName.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        if cloudKitManager.currentUser != nil {
            let usernameToSave = username.isEmpty ? nil : username
            cloudKitManager.updateUserProfile(displayName: displayName, avatarColor: selectedAvatarColor, username: usernameToSave) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success:
                        withAnimation { showSuccess = true }
                        UserDefaults.standard.set(true, forKey: "hasCreatedProfile")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if isFromTab {
                                withAnimation(ONEAnimation.cardSpring) {
                                    isEditingFromTab = false
                                    showSuccess = false
                                }
                            } else {
                                dismiss()
                            }
                        }
                    case .failure(let error):
                        let nsError = error as NSError
                        errorMessage = nsError.domain == "CKErrorDomain" && nsError.code == 26
                            ? "CloudKit schema deploy edilmemiş."
                            : "Kaydedilemedi: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            cloudKitManager.createOrFetchUser(displayName: displayName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        let usernameToSave = username.isEmpty ? nil : username
                        cloudKitManager.updateUserProfile(displayName: displayName, avatarColor: selectedAvatarColor, username: usernameToSave) { updateResult in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch updateResult {
                                case .success(let record):
                                    withAnimation { showSuccess = true }
                                    UserDefaults.standard.set(true, forKey: "hasCreatedProfile")
                                    if cloudKitManager.currentUser == nil {
                                        cloudKitManager.currentUser = record
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        if isFromTab {
                                            withAnimation(ONEAnimation.cardSpring) {
                                                isEditingFromTab = false
                                                showSuccess = false
                                            }
                                        } else {
                                            dismiss()
                                        }
                                    }
                                case .failure(let error):
                                    let nsError = error as NSError
                                    errorMessage = nsError.domain == "CKErrorDomain" && nsError.code == 26
                                        ? "CloudKit schema deploy edilmemiş."
                                        : "Kaydedilemedi: \(error.localizedDescription)"
                                }
                            }
                        }
                    case .failure(let error):
                        isLoading = false
                        errorMessage = "Oluşturulamadı: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
