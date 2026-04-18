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
import PhotosUI
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
    @State private var showMonthlySummary = false
    
    // Settings states
    @ObservedObject private var spotifyManager = SpotifyManager.shared
    @State private var appleMusicStatus: MusicAuthorization.Status = .notDetermined
    @State private var showSpotifyLogoutAlert = false
    
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("streakNotificationsEnabled") private var streakNotificationsEnabled = true
    @AppStorage("weeklySummaryEnabled") private var weeklySummaryEnabled = true
    @AppStorage("discoveryNotificationsEnabled") private var discoveryNotificationsEnabled = true
    @State private var dailyReminderTime = Date()
    @StateObject private var notificationManager = NotificationManager.shared
    
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @AppStorage("isDarkMode") private var isDarkMode = false
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showLanguagePicker = false
    @State private var showEcho = false
    
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

    // Profile photo
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var isUploadingPhoto = false
    @State private var profilePhotoZoomed = false

    // Hesap yönetimi
    @State private var showDeleteAccountAlert = false
    @State private var showAppleMusicInfoAlert = false
    @State private var showICloudInfoAlert = false

    // Dışa aktarma
    @State private var showExportFormatPicker = false
    @State private var exportItems: [Any] = []
    @State private var showExportShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false
    
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
        KeychainHelper.bool(forKey: "hasCreatedProfile") && cloudKitManager.currentUser != nil
    }
    
    var canSaveProfile: Bool {
        !displayName.isEmpty && displayName.count <= 50
    }

    // MARK: - Adaptive Colors (uygulamanın isDarkMode toggle'ına göre)

    /// Kullanıcının profil rengi (avatar color → SwiftUI Color)
    private var profileColor: Color    { Color(hex: selectedAvatarColor) }

    /// Ekran arka planı
    private var screenBG: Color       { isDarkMode ? Color.black : ONETokens.oneCream }
    /// Kart arka planı
    private var cardBG: Color         { isDarkMode ? Color.white.opacity(0.07) : ONETokens.onePaper.opacity(0.55) }
    /// Kart kenarlık rengi
    private var cardBorder: Color     { isDarkMode ? Color.clear : ONETokens.oneSilver }
    /// İstatistik satırı arka planı
    private var statRowBG: Color      { isDarkMode ? Color.white.opacity(0.07) : ONETokens.onePaper.opacity(0.75) }
    /// İstatistik bölücüsü
    private var statDivider: Color    { isDarkMode ? Color.white.opacity(0.12) : ONETokens.oneIvory }
    /// Birincil metin rengi
    private var primaryText: Color    { isDarkMode ? Color.white : ONETokens.oneInk }
    /// İkincil metin rengi
    private var secondaryText: Color  { isDarkMode ? Color.white.opacity(0.45) : ONETokens.oneAsh }
    /// Üçüncül metin rengi
    private var tertiaryText: Color   { isDarkMode ? Color.white.opacity(0.25) : ONETokens.oneStone }
    /// Bölüm başlığı rengi
    private var sectionHeader: Color  { isDarkMode ? Color.white.opacity(0.35) : ONETokens.oneCharcoal }
    /// Bölücü çizgi rengi
    private var dividerColor: Color   { isDarkMode ? Color.white.opacity(0.08) : ONETokens.oneSilver }
    /// Aksiyon ikonu arka planı (kopyala, paylaş vb.)
    private var actionBubble: Color   { isDarkMode ? Color.white.opacity(0.10) : ONETokens.onePaper.opacity(0.8) }
    /// Aksiyon ikonu rengi
    private var actionIcon: Color     { isDarkMode ? Color.white.opacity(0.65) : ONETokens.oneAsh }
    /// Ayar satırı ikon rengi (nötr)
    private var rowIcon: Color        { isDarkMode ? Color.white.opacity(0.75) : ONETokens.oneInk }

    var body: some View {
        ZStack {
            screenBG.ignoresSafeArea()
            
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
                                            .background(ONETokens.onePaper.opacity(0.8))
                                            .clipShape(Circle())
                                    }
                                    .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                                    .contentShape(Rectangle())
                                }
                            }
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
        .overlay {
            if profilePhotoZoomed, let img = profileImage {
                ZStack {
                    Color.black.opacity(0.82)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                profilePhotoZoomed = false
                            }
                        }

                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width - 48)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 16)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: profilePhotoZoomed)
        .alert(NSLocalizedString("profile.spotifyDisconnect", comment: ""), isPresented: $showSpotifyLogoutAlert) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("profile.disconnect", comment: ""), role: .destructive) {
                spotifyManager.logout()
            }
        } message: {
            Text(NSLocalizedString("profile.spotifyDisconnectMsg", comment: ""))
        }
        .alert(NSLocalizedString("profile.appleMusicTitle", comment: ""), isPresented: $showAppleMusicInfoAlert) {
            Button(NSLocalizedString("profile.openSettings", comment: "")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("addFriend.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("profile.appleMusicMsg", comment: ""))
        }
        .alert(NSLocalizedString("profile.icloudDeleteTitle", comment: ""), isPresented: $showICloudInfoAlert) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("profile.deleteData", comment: ""), role: .destructive) {
                cloudKitManager.deleteCurrentUserRecord()
            }
        } message: {
            Text(NSLocalizedString("profile.icloudDeleteMsg", comment: ""))
        }
        .alert(NSLocalizedString("profile.deleteAccountTitle", comment: ""), isPresented: $showDeleteAccountAlert) {
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("profile.deleteAccount", comment: ""), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(NSLocalizedString("profile.deleteAccountMsg", comment: ""))
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
    
    // MARK: - Dashboard View (Read-Only — Dark Immersive)
    private var profileDashboardView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Hero (full-bleed gradient, no horizontal padding) ──
                heroSection
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8), value: appeared)

                let pad: CGFloat = 20

                // ── İstatistikler ────────────────────────────────────
                statsRow
                    .padding(.horizontal, pad)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.06), value: appeared)

                // ── Davet Kodu ───────────────────────────────────────
                if !inviteCode.isEmpty && inviteCode != "------" {
                    inviteCodeSection
                        .padding(.horizontal, pad)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.10), value: appeared)
                }

                // ── Özellikler: Echo + Aylık Özet ───────────────────
                featuresSection
                    .padding(.horizontal, pad)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.14), value: appeared)

                // ── Müzik Servisleri ─────────────────────────────────
                musicServicesSection
                    .padding(.horizontal, pad)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.18), value: appeared)

                // ── Genel Ayarlar + Bildirimler (gruplu) ────────────
                settingsAndNotificationsGroup
                    .padding(.horizontal, pad)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.22), value: appeared)

                // ── Hesap / Diğer ────────────────────────────────────
                otherSection
                    .padding(.horizontal, pad)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.26), value: appeared)

                // ── Footer ───────────────────────────────────────────
                footerSection
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.30), value: appeared)

                Spacer().frame(height: 100)
            }
        }
        .background(screenBG)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showShareSheet) {
            if inviteCode != "------" {
                ShareSheet(items: ["🌙 One uygulamasında beni bul!\nDavet kodum: \(inviteCode)"])
            }
        }
    }

    // MARK: - Hero Section (Gradient yok — temiz, dinamik)

    private var heroSection: some View {
        VStack(spacing: 0) {

            // ── Top bar — Düzenle butonu ──────────────────────────────────────
            HStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(ONEAnimation.cardSpring) { isEditingFromTab = true }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .medium))
                        Text(NSLocalizedString("profile.edit", comment: ""))
                            .monoSM(tracking: 0.5)
                    }
                    .foregroundColor(secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(cardBG)
                            .overlay(Capsule().stroke(cardBorder, lineWidth: 1))
                    )
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, 20)

            // ── Avatar + bilgiler (ortalanmış) ───────────────────────────────
            VStack(spacing: 14) {

                // Avatar
                ZStack {
                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(profileColor.opacity(isDarkMode ? 0.18 : 0.12))
                            .frame(width: 108, height: 108)
                        Text(displayName.prefix(1).uppercased())
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundColor(profileColor)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(profileColor, lineWidth: 3.5)
                        .frame(width: 108, height: 108)
                )
                .shadow(color: profileColor.opacity(isDarkMode ? 0.30 : 0.20), radius: 20, x: 0, y: 8)
                .onTapGesture {
                    guard profileImage != nil else { return }
                    ONEHaptics.feelingSelected()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        profilePhotoZoomed = true
                    }
                }

                // İsim + kullanıcı adı
                VStack(spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(primaryText)
                        .lineLimit(1)

                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Features Section (Echo + Monthly Summary — kompakt satır listesi)

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.features", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Echo
                Button(action: { showEcho = true }) {
                    featureRow(
                        icon: "waveform",
                        iconColor: ONETokens.oneBrand,
                        title: NSLocalizedString("profile.echoTitle", comment: ""),
                        subtitle: NSLocalizedString("profile.echoDesc", comment: ""),
                        showDivider: true,
                        trailing: { Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ONETokens.oneStone) }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .fullScreenCover(isPresented: $showEcho) {
                    EchoFullScreenWrapper(context: viewContext, isPresented: $showEcho)
                }

                // Monthly Summary
                Button(action: { showMonthlySummary = true }) {
                    featureRow(
                        icon: "calendar.badge.clock",
                        iconColor: ONETokens.moodPurple,
                        title: NSLocalizedString("premium.monthlySummary.title", comment: ""),
                        subtitle: NSLocalizedString("premium.feature.monthlySummary.desc", comment: ""),
                        showDivider: false,
                        trailing: {
                            HStack(spacing: 6) {
                                if isMonthlySummaryReady {
                                    Circle()
                                        .fill(ONETokens.oneBrand)
                                        .frame(width: 8, height: 8)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ONETokens.oneStone)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .fullScreenCover(isPresented: $showMonthlySummary) {
                    MonthlySummaryView(context: viewContext)
                        .onAppear { markMonthlySummaryViewed() }
                }
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
        }
    }

    private func featureRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        showDivider: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .bodySMMedium()
                        .foregroundColor(primaryText)
                    Text(subtitle)
                        .monoSM()
                        .foregroundColor(secondaryText)
                }

                Spacer()
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if showDivider {
                Rectangle().fill(dividerColor).frame(height: 1).padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Monthly Summary Ready Badge

    private var isMonthlySummaryReady: Bool {
        let cal = Calendar.current
        let now = Date()
        guard let prevMonthDate = cal.date(byAdding: .month, value: -1, to: now) else { return false }
        let prevMonth = cal.component(.month, from: prevMonthDate)
        let prevYear  = cal.component(.year,  from: prevMonthDate)
        let lastViewedMonth = UserDefaults.standard.integer(forKey: "monthlySummaryLastViewed_month")
        let lastViewedYear  = UserDefaults.standard.integer(forKey: "monthlySummaryLastViewed_year")
        return !(lastViewedMonth == prevMonth && lastViewedYear == prevYear)
    }

    private func markMonthlySummaryViewed() {
        let cal = Calendar.current
        guard let prevMonthDate = cal.date(byAdding: .month, value: -1, to: Date()) else { return }
        UserDefaults.standard.set(cal.component(.month, from: prevMonthDate), forKey: "monthlySummaryLastViewed_month")
        UserDefaults.standard.set(cal.component(.year,  from: prevMonthDate), forKey: "monthlySummaryLastViewed_year")
    }

    // MARK: - Settings + Notifications (grouped — reuses existing section views)

    private var settingsAndNotificationsGroup: some View {
        VStack(spacing: 16) {
            settingsSection
            notificationsSection
        }
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: formattedMemberSince, label: NSLocalizedString("profile.joinDate", comment: ""), isHighlighted: false)
            Rectangle().fill(statDivider).frame(width: 1, height: 32)
            statCell(value: "\(totalDaysCount)", label: NSLocalizedString("profile.days", comment: ""), isHighlighted: true)
            Rectangle().fill(statDivider).frame(width: 1, height: 32)
            statCell(value: musicServiceLabel, label: NSLocalizedString("profile.music", comment: ""), isHighlighted: false)
        }
        .padding(.vertical, 16)
        .background(statRowBG)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        )
        .overlay(
            // Üst kenar vurgusu — profil renginden ince çizgi
            VStack {
                RoundedRectangle(cornerRadius: 16)
                    .frame(height: 3)
                    .foregroundColor(profileColor.opacity(0.55))
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }

    private func statCell(value: String, label: String, isHighlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .displayXS()
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? profileColor : primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .monoLabel()
                .foregroundColor(secondaryText)
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
            formatter.locale = LanguageManager.shared.currentLocale
            return formatter.string(from: date)
        }
        if let creationDate = cloudKitManager.currentUser?.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            formatter.locale = LanguageManager.shared.currentLocale
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
            return NSLocalizedString("profile.musicBoth", comment: "")
        } else if spotifyManager.isAuthenticated {
            return "Spotify"
        } else if appleMusicStatus == .authorized {
            return "Apple"
        }
        return "—"
    }
    
    // MARK: - Invite Code Section
    private var inviteCodeSection: some View {
        HStack(spacing: 14) {
            // ── Kod görünümü ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("profile.inviteCode", comment: ""))
                    .monoBase(tracking: 1.5)
                    .foregroundColor(sectionHeader)

                HStack(spacing: 10) {
                    // Profil renginde ince nokta
                    Circle()
                        .fill(profileColor)
                        .frame(width: 7, height: 7)
                    Text(inviteCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(primaryText)
                }
            }

            Spacer()

            // ── Aksiyon butonları ─────────────────────────────────────────
            HStack(spacing: 6) {
                Button {
                    UIPasteboard.general.string = inviteCode
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(ONEAnimation.micro) { inviteCodeCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { inviteCodeCopied = false }
                    }
                } label: {
                    Image(systemName: inviteCodeCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(inviteCodeCopied ? ONETokens.oneGreen : actionIcon)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(actionBubble))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(actionIcon)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(actionBubble))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(profileColor.opacity(isDarkMode ? 0.25 : 0.18), lineWidth: 1)
        )
    }
    
    // MARK: - Music Services Section
    private var musicServicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.musicServices", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Spotify — v2'de aktif edilecek
                settingsRow(
                    icon: "music.note",
                    iconColor: tertiaryText,
                    title: "Spotify",
                    trailing: {
                        Text(NSLocalizedString("profile.comingSoon", comment: ""))
                            .monoSM(tracking: 0.4)
                            .foregroundColor(tertiaryText)
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
                                text: appleMusicStatus == .authorized
                                    ? NSLocalizedString("profile.appleMusicConnected", comment: "")
                                    : NSLocalizedString("profile.appleMusicConnect", comment: "")
                            )
                        },
                        showDivider: false
                    )
                }
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Settings Section (General)
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.general", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Language
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showLanguagePicker = true
                } label: {
                    settingsRow(
                        icon: "globe",
                        iconColor: rowIcon,
                        title: NSLocalizedString("profile.language", comment: ""),
                        trailing: {
                            HStack(spacing: 4) {
                                Text(languageManager.currentLanguage.displayName)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(secondaryText)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(tertiaryText)
                            }
                        },
                        showDivider: true
                    )
                }
                .sheet(isPresented: $showLanguagePicker) {
                    LanguagePickerView()
                        .environmentObject(languageManager)
                }

                // Dark Mode
                settingsToggleRow(icon: "moon", title: NSLocalizedString("profile.darkMode", comment: ""), isOn: $isDarkMode)

                // Haptic
                settingsToggleRow(icon: "hand.tap", title: NSLocalizedString("profile.haptics", comment: ""), isOn: $hapticFeedbackEnabled)

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
                        iconColor: rowIcon,
                        title: NSLocalizedString("profile.city", comment: ""),
                        trailing: {
                            HStack(spacing: 4) {
                                Text(preferredCity)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(secondaryText)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(tertiaryText)
                            }
                        },
                        showDivider: true
                    )
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
                        iconColor: cloudKitManager.isCloudKitAvailable ? ONETokens.oneGreen : tertiaryText,
                        title: NSLocalizedString("profile.icloud", comment: ""),
                        trailing: {
                            connectionDot(
                                connected: cloudKitManager.isCloudKitAvailable,
                                color: ONETokens.oneGreen,
                                text: cloudKitManager.isCloudKitAvailable ? NSLocalizedString("profile.icloudActive", comment: "") : NSLocalizedString("profile.icloudOff", comment: "")
                            )
                        },
                        showDivider: false
                    )
                }
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.notificationsHeader", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Master toggle
                settingsToggleRow(icon: "bell", title: NSLocalizedString("profile.notifications", comment: ""), isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            NotificationManager.shared.requestAuthorization { granted in
                                if granted {
                                    NotificationManager.shared.scheduleDailyReminder(at: dailyReminderTime)
                                    if weeklySummaryEnabled { NotificationManager.shared.scheduleWeeklySummary() }
                                } else {
                                    DispatchQueue.main.async { notificationsEnabled = false }
                                }
                            }
                        } else {
                            NotificationManager.shared.disableDailyReminder()
                            NotificationManager.shared.disableWeeklySummary()
                            NotificationManager.shared.cancelStreakWarning()
                        }
                    }

                // İzin reddedildiyse Ayarlar'a yönlendir
                if notificationsEnabled && !notificationManager.isAuthorized {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundColor(ONETokens.oneRed)
                            Text(NSLocalizedString("profile.notificationsOff", comment: ""))
                                .bodySM()
                                .foregroundColor(ONETokens.oneRed)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }

                if notificationsEnabled {
                    // Günlük hatırlatıcı saati
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(secondaryText)
                            .frame(width: 20)
                        Text(NSLocalizedString("profile.reminderTime", comment: ""))
                            .bodySM()
                            .foregroundColor(primaryText)
                        Spacer()
                        DatePicker("", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(profileColor)
                            .colorScheme(isDarkMode ? .dark : .light)
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

                    // Streak uyarısı
                    settingsToggleRow(icon: "flame", title: NSLocalizedString("profile.streakAlert", comment: ""), isOn: $streakNotificationsEnabled)
                        .onChange(of: streakNotificationsEnabled) { _, newValue in
                            if !newValue { NotificationManager.shared.cancelStreakWarning() }
                        }

                    // Haftalık özet
                    settingsToggleRow(icon: "chart.bar", title: NSLocalizedString("profile.weeklySummary", comment: ""), isOn: $weeklySummaryEnabled)
                        .onChange(of: weeklySummaryEnabled) { _, newValue in
                            if newValue {
                                NotificationManager.shared.scheduleWeeklySummary()
                            } else {
                                NotificationManager.shared.disableWeeklySummary()
                            }
                        }

                    // Keşfet önerileri
                    settingsToggleRow(icon: "compass.drawing", title: NSLocalizedString("profile.discoveryAlerts", comment: ""), isOn: $discoveryNotificationsEnabled)
                }
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Other Section
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.other", comment: ""))
                .monoBase(tracking: 1.5)
                .foregroundColor(sectionHeader)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Button(action: { showExportFormatPicker = true }) {
                    settingsRow(
                        icon: "square.and.arrow.up",
                        iconColor: rowIcon,
                        title: NSLocalizedString("profile.exportData", comment: ""),
                        trailing: { chevronRight },
                        showDivider: true
                    )
                }
                .confirmationDialog(NSLocalizedString("profile.exportFormat", comment: ""), isPresented: $showExportFormatPicker, titleVisibility: .visible) {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.rawValue) { exportData(as: format) }
                    }
                    Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
                }
                .sheet(isPresented: $showExportShareSheet) {
                    ShareSheet(items: exportItems)
                }
                .alert(NSLocalizedString("profile.exportError", comment: ""), isPresented: $showExportError) {
                    Button(NSLocalizedString("addFriend.ok", comment: ""), role: .cancel) {}
                } message: {
                    Text(exportError ?? NSLocalizedString("profile.unknownError", comment: ""))
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    AppReviewManager.shared.openAppStorePage()
                }) {
                    settingsRow(
                        icon: "star",
                        iconColor: rowIcon,
                        title: NSLocalizedString("profile.rateApp", comment: ""),
                        trailing: { chevronRight },
                        showDivider: false
                    )
                }
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))

            // Hesap silme — ayrı kart, kırmızı vurgu
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showDeleteAccountAlert = true
            }) {
                settingsRow(
                    icon: "trash",
                    iconColor: ONETokens.oneRed,
                    title: NSLocalizedString("profile.deleteAccount", comment: ""),
                    trailing: { chevronRight },
                    showDivider: false
                )
            }
            .background(cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ONETokens.oneRed.opacity(isDarkMode ? 0.40 : 0.25), lineWidth: 1))
        }
    }
    
    // MARK: - Dışa Aktarma

    private func exportData(as format: ExportFormat) {
        do {
            let url = try ExportManager.shared.exportAll(format: format, context: viewContext)
            exportItems = [url]
            showExportShareSheet = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    // MARK: - Hesap Silme

    private func deleteAccount() {
        // 1. Tüm Core Data kayıtlarını sil
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DailySong")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? viewContext.execute(deleteRequest)
        try? viewContext.save()

        // 2. Spotify token ve cache temizle
        spotifyManager.logout()

        // 3. CloudKit profilini sil
        cloudKitManager.deleteCurrentUserRecord()

        // 5. UserDefaults sıfırla
        let defaults = UserDefaults.standard
        KeychainHelper.remove(forKey: "hasCompletedOnboarding")
        KeychainHelper.remove(forKey: "hasCreatedProfile")
        defaults.removeObject(forKey: "dailyReminderHour")
        defaults.removeObject(forKey: "dailyReminderMinute")
        defaults.removeObject(forKey: "notificationsEnabled")
        defaults.removeObject(forKey: "streakNotificationsEnabled")
        defaults.removeObject(forKey: "weeklySummaryEnabled")
        defaults.removeObject(forKey: "discoveryNotificationsEnabled")
        defaults.removeObject(forKey: "hapticFeedbackEnabled")
        defaults.removeObject(forKey: "preferredMusicService")
        defaults.removeObject(forKey: ONETokens.cityPreferenceKey)

        // 6. Onboarding'e dön
        NotificationCenter.default.post(name: NSNotification.Name("resetToOnboarding"), object: nil)
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(NSLocalizedString("profile.appName", comment: ""))
                .bodySM()
                .foregroundColor(tertiaryText)
            Text("v1.0.0")
                .monoLabel(tracking: 1.0)
                .foregroundColor(isDarkMode ? Color.white.opacity(0.15) : ONETokens.onePebble)
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
                .foregroundColor(primaryText)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(
            Group {
                if showDivider {
                    VStack { Spacer(); Rectangle().frame(height: 0.5).foregroundColor(dividerColor) }
                }
            }
        )
    }

    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(rowIcon)
                .frame(width: 20)

            Text(title)
                .bodySM()
                .foregroundColor(primaryText)

            Spacer()

            Toggle("", isOn: isOn)
                .tint(profileColor)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(
            VStack { Spacer(); Rectangle().frame(height: 0.5).foregroundColor(dividerColor) }
        )
    }

    private func connectionDot(connected: Bool, color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connected ? color : tertiaryText)
                .frame(width: 6, height: 6)
            Text(text)
                .monoSM(tracking: 0)
                .foregroundColor(connected ? color : secondaryText)
        }
    }

    private var chevronRight: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(tertiaryText)
    }
    
    // MARK: - Edit/Create Form View
    private var profileFormView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Header — profil rengi subtle gradient + fotoğraf ──────────
                ZStack(alignment: .bottomLeading) {
                    // Subtle gradient banner
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: isFromTab ? 160 : 140)
                        .background(
                            LinearGradient(
                                stops: [
                                    .init(color: profileColor.opacity(0.72), location: 0.0),
                                    .init(color: profileColor.opacity(0.28), location: 0.55),
                                    .init(color: profileColor.opacity(0.00), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                        )

                    VStack(alignment: .leading, spacing: 0) {
                        // Kapat butonu (tab'dan düzenleme modundaysa)
                        if isFromTab {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(ONEAnimation.cardSpring) {
                                        isEditingFromTab = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(.ultraThinMaterial))
                                }
                            }
                            .padding(.top, 56)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        } else {
                            Spacer().frame(height: isFromTab ? 16 : 20)
                        }

                        // Form başlığı — avatar + isim/başlık
                        HStack(spacing: 14) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack {
                                    if let profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 58, height: 58)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [profileColor, profileColor.opacity(0.75)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 58, height: 58)
                                        Text(displayName.isEmpty ? "O" : displayName.prefix(1).uppercased())
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    // Kamera rozeti
                                    Circle()
                                        .fill(ONETokens.oneCreamMid)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(ONETokens.oneAsh)
                                        )
                                        .offset(x: 20, y: 20)

                                    if isUploadingPhoto {
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 58, height: 58)
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    }
                                }
                            }
                            .shadow(color: profileColor.opacity(0.40), radius: 12, x: 0, y: 6)
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                guard let newItem else { return }
                                Task { await loadAndSaveProfilePhoto(from: newItem) }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(isEditMode
                                     ? NSLocalizedString("profile.editProfile", comment: "")
                                     : NSLocalizedString("profile.createProfile", comment: ""))
                                    .displayMD()
                                    .foregroundColor(ONETokens.oneInk)

                                if !isEditMode {
                                    Text(NSLocalizedString("profile.getToKnowYou", comment: ""))
                                        .monoSM(tracking: 0)
                                        .foregroundColor(ONETokens.oneAsh)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)
                    }
                }
                
                // Form fields
                VStack(spacing: 16) {
                    
                    // Display Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("profile.name", comment: ""))
                            .monoBase(tracking: 1.5)
                            .foregroundColor(ONETokens.oneCharcoal)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "person")
                                .font(.system(size: 14))
                                .foregroundColor(focusedField == .displayName ? Color(hex: selectedAvatarColor) : ONETokens.oneAsh)
                                .frame(width: 20)
                            
                            TextField(NSLocalizedString("profile.namePlaceholder", comment: ""), text: $displayName)
                                .focused($focusedField, equals: .displayName)
                                .bodyLG()
                                .fontWeight(.medium)
                                .foregroundColor(ONETokens.oneInk)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .username }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(ONETokens.onePaper.opacity(0.7))
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
                        Text(NSLocalizedString("profile.username", comment: ""))
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
                        .background(ONETokens.onePaper.opacity(0.7))
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
                        Text(NSLocalizedString("profile.color", comment: ""))
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
                        .background(ONETokens.onePaper.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
                    }
                    
                    // ── Kaydet butonu — profil renginde ───────────────────────
                    Button(action: saveProfile) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if showSuccess {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(NSLocalizedString("addFriend.ok", comment: ""))
                                }
                            } else {
                                Text(isEditMode
                                     ? NSLocalizedString("general.save", comment: "")
                                     : NSLocalizedString("profile.createProfile", comment: ""))
                            }
                        }
                        .bodyXS()
                        .fontWeight(.semibold)
                        .foregroundColor(
                            showSuccess ? ONETokens.oneGreen :
                            canSaveProfile ? .white :
                            ONETokens.oneAsh
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    showSuccess
                                        ? ONETokens.oneGreen.opacity(0.12)
                                        : canSaveProfile
                                            ? profileColor
                                            : ONETokens.oneCreamLow
                                )
                                .overlay(
                                    showSuccess
                                        ? RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneGreen.opacity(0.3), lineWidth: 1)
                                        : nil
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
        profileImage = Self.loadProfilePhotoFromDisk()
    }

    // MARK: - Profile Photo

    private func loadAndSaveProfilePhoto(from item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }

        // Resize to max 200x200 for performance
        let resized = resizeImage(original, maxSize: 200)
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return }

        // Save locally
        Self.saveProfilePhotoToDisk(jpegData)
        await MainActor.run { profileImage = resized }

        // Upload to CloudKit
        await uploadProfilePhotoToCloudKit(jpegData)
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private static var profilePhotoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }

    private static func saveProfilePhotoToDisk(_ data: Data) {
        try? data.write(to: profilePhotoURL)
    }

    static func loadProfilePhotoFromDisk() -> UIImage? {
        guard let data = try? Data(contentsOf: profilePhotoURL) else { return nil }
        return UIImage(data: data)
    }

    private func uploadProfilePhotoToCloudKit(_ data: Data) async {
        guard let record = cloudKitManager.currentUser else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("profile_upload.jpg")
        do {
            try data.write(to: tempURL)
            record["profilePhoto"] = CKAsset(fileURL: tempURL)
            let db = CKContainer.default().publicCloudDatabase
            _ = try await db.save(record)
            try? FileManager.default.removeItem(at: tempURL)
            ONELogger.success("Profile photo uploaded to CloudKit", category: .cloudkit)
        } catch {
            ONELogger.error("Profile photo upload failed", error: error, category: .cloudkit)
            try? FileManager.default.removeItem(at: tempURL)
        }
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
            usernameValidationMessage = NSLocalizedString("profile.usernameExisting", comment: "")
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
                        self.usernameValidationMessage = isAvailable
                            ? NSLocalizedString("profile.usernameAvailable", comment: "")
                            : NSLocalizedString("profile.usernameTaken", comment: "")
                    case .failure(let error):
                        ONELogger.error("Username check failed: \(error.localizedDescription)", category: .profile)
                        self.usernameValidationMessage = NSLocalizedString("profile.usernameCheckFailed", comment: "")
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
                        KeychainHelper.set(true, forKey: "hasCreatedProfile")
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
                                    KeychainHelper.set(true, forKey: "hasCreatedProfile")
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

// MARK: - Echo Full Screen Wrapper (swipe-to-dismiss + back button)
private struct EchoFullScreenWrapper: View {
    let context: NSManagedObjectContext
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        EchoView(context: context, onDismiss: { isPresented = false })
            .offset(x: horizontalOffset, y: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dx) > abs(dy) && dx > 0 {
                            // Horizontal swipe (right = back)
                            horizontalOffset = dx
                        } else if dy > 0 {
                            // Vertical swipe (down = dismiss)
                            dragOffset = dy
                        }
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dx) > abs(dy) && dx > 80 {
                            // Horizontal dismiss
                            withAnimation(.easeOut(duration: 0.25)) {
                                horizontalOffset = UIScreen.main.bounds.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                isPresented = false
                                horizontalOffset = 0
                            }
                        } else if dy > 120 || value.predictedEndTranslation.height > 300 {
                            // Vertical dismiss
                            withAnimation(.easeOut(duration: 0.25)) {
                                dragOffset = UIScreen.main.bounds.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                isPresented = false
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                dragOffset = 0
                                horizontalOffset = 0
                            }
                        }
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
            .animation(.interactiveSpring(), value: horizontalOffset)
    }
}

#Preview {
    ProfileView()
}
