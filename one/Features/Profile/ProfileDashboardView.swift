//
//  ProfileDashboardView.swift
//  one
//
//  UI component for Profile read-only dashboard.
//  Extracted from ProfileView.swift as part of Faz 3 decomposition.
//
//  Phase 3 decomposition (Task 3.3) further split the body into focused
//  section files under `Features/Profile/`:
//  - `ProfileHeroSection` (hero photo / fallback gradient)
//  - `ProfileFriendStrip` (friend count + share + edit)
//  - `ProfileFeaturesSection` + `ProfileRecentMoodStripSection`
//    + `ProfileLoyaltyCard` (mid-page content)
//  - `ProfileSettingsSection` (right-hand slide-in settings overlay)
//  - `ProfileTopBarOverlay` (sticky top-bar overlay)
//
//  This file now owns the scroll hierarchy, shared state (sheet flags), the
//  ProfilePalette environment injection, and the derived week-of-moods data
//  consumed by hero + recent strip. Public navigation entry points and init
//  signature are preserved (Req 4.4).
//

import SwiftUI
import CoreData

struct ProfileDashboardView: View {
    @ObservedObject var vm: ProfileViewModel
    var isFromTab: Bool

    // CoreData context (for stats & export passed down to extracted sections)
    var context: NSManagedObjectContext

    @State private var appeared = true

    // Shared sheet-presentation flags. Bindings flow down into the extracted
    // section views so they can open/close without owning the flag themselves.
    @State private var showShareSheet = false
    @State private var showEcho = false
    @State private var showMonthlySummary = false
    @State private var showYearlySummary = false
    @State private var showAddFriend = false
    @State private var showSettings = false
    @State private var showFriendsList = false

    // 13 adaptive dark-mode helpers previously defined here have moved to
    // `ProfilePalette` (design.md Component 1). Nested computed subviews read
    // colors through this local palette value; the root of `body` also injects
    // the same palette into the environment so extracted struct views read it
    // via `@Environment(\.profilePalette) var palette` without prop drilling.
    // Req 2.1, 2.4, 2.6.
    private var palette: ProfilePalette { ProfilePalette(isDarkMode: vm.isDarkMode) }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                // Prototipteki profil: hero foto ve özellik kartları yok.
                // Kimlik → üç sayı → renk karnesi → ayar satırları.
                // Yankı/Aylık özet artık kendi sekmesinden ve ayarlardan
                // ulaşılıyor; burada ikinci bir giriş noktası tutmuyoruz.
                // Prototip 26: sayfada yüzen buton yok. Kişi-ekle avatara
                // binen rozetti, dişli sağ üstteydi, altta marka footer'ı
                // vardı — üçü de kalktı. Arkadaş ekleme "arkadaşlar"
                // satırının açtığı ekranda, ayarlar kendi satırında.
                VStack(alignment: .leading, spacing: 14) {
                    ProfileOverviewSection(
                        vm: vm,
                        context: context,
                        showFriendsList: $showFriendsList,
                        showSettings: $showSettings
                    )
                    // Prototip `.scroll` üst boşluğu: 58pt.
                    .padding(.top, 58)
                    .listItemEntrance(isVisible: appeared, index: 0)

                    Spacer().frame(height: 116)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.screenBG)
            .ignoresSafeArea(edges: .top)
            .frame(maxWidth: .infinity)

            // ── Ayarlar full-screen sağdan kayar
            // Reduce Motion: slideTransition sadece opacity'ye düşer (offset/scale yok).
            if showSettings {
                ProfileSettingsSection(
                    vm: vm,
                    context: context,
                    showSettings: $showSettings
                )
                .slideTransition(edge: .trailing)
                .zIndex(20)
            }
        }
        .animation(ONEAnimation.panelSpring, value: showSettings)
        .environment(\.profilePalette, palette)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.1)) {
                appeared = true
            }
            vm.loadFriendCount()
        }
        // Profili Paylaş — markaya uygun görsel davet kartı (Instagram
        // Stories format'ında). InviteShareSheet kart oluşturur, kullanıcı
        // Stories'e veya sistem share sheet'ine yönlendirebilir.
        .sheet(isPresented: $showShareSheet) {
            if vm.inviteCode != "------" {
                InviteShareSheet(
                    inviteCode: vm.inviteCode,
                    userName: vm.displayName.isEmpty ? "ONE" : vm.displayName
                )
            }
        }
        .sheet(isPresented: $showAddFriend, onDismiss: {
            // Arkadaş eklendiyse sayı güncellensin
            vm.loadFriendCount()
        }) {
            AddFriendScreen()
        }
        .fullScreenCover(isPresented: $showFriendsList, onDismiss: {
            vm.loadFriendCount()
        }) {
            MyFriendsListView(vm: vm)
        }
        // Ayarlar artık bir sheet değil — ProfileSettingsSection ZStack overlay
        // olarak sağdan kayarak açılıyor (yukarıda main ZStack içinde).
        // Yankı (Echo)
        .fullScreenCover(isPresented: $showEcho) {
            EchoView(context: context, onDismiss: { showEcho = false })
        }
        // Aylık özet — tam ekran (cinematic, MonthlySummary'nin görsel
        // dilini sheet kısıtlamadan göstermek için)
        .fullScreenCover(isPresented: $showMonthlySummary) {
            ZStack(alignment: .topTrailing) {
                MonthlySummaryView(context: context)
                Button(action: { showMonthlySummary = false }) {
                    Image(systemName: "xmark")
                        .bodySMMedium()
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .liquidGlass(tint: Color.black.opacity(0.18), interactive: true, in: Circle())
                }
                .padding(.top, 56)
                .padding(.trailing, 18)
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))
            }
        }
        // Yıllık özet
        .sheet(isPresented: $showYearlySummary) {
            NavigationStack {
                YearlySummaryView(context: context)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showYearlySummary = false }) {
                                Image(systemName: "xmark")
                                    .bodyXSMedium()
                                    .foregroundColor(ONETokens.oneAsh)
                            }
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .liquidGlassToolbar()
            }
        }
        // Alerts ve export share sheet artık `ProfileSettingsSection` içinde
        // tanımlı — ana ekran sade kaldı.
    }

    // MARK: - Derived data shared by hero + recent strip

    private var totalDaysCount: Int {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        return (try? context.count(for: request)) ?? 0
    }

    private var recentMoodColors: [Color?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let song = PersistenceController.shared.fetchDailySong(for: day, context: context),
                  let hex = song.moodColorHex, !hex.isEmpty else { return nil }
            return Color(hex: hex)
        }
    }
}
