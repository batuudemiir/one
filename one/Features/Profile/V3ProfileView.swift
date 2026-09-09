//
//  V3ProfileView.swift
//  one
//
//  v3 profil ekranı — prototipe uyumlu kompakt yerleşim.
//
//  Bölümler (yukarıdan aşağı):
//   1) Avatar 76pt + ad (Archivo 32pt) + üyelik tarihi (mono, uppercase)
//   2) Hesap — giriş yapılmışsa satır + Çıkış, değilse Apple ile Giriş Yap kartı
//   3) İstatistik ızgarası — 3 hücre: AN · KULLANILAN RENK · EN SIK
//   4) Renk dağılımı — 44pt yığın bar (dokunulabilir) + 2 sütun legend.
//      Sayım `V3Mood.closest(toHex:)` ile yapılır: v1/v2'den kalan hex'ler de
//      bir v3 kovasına düşer, hiçbir kayıt "?" olarak kaybolmaz.
//   5) Aylık özet (Yankı) önizleme kartı — ayın rengi + mini mozaik; dokunulunca
//      Yankı sheet'i açılır (`switchToEchoTab`).
//   6) Ayarlar — üç mono başlıklı blok: AYARLAR / ÇEVRE / VERİ
//   7) Sürüm satırı
//

import SwiftUI
import CoreData
import AuthenticationServices
import PhotosUI

/// Profilin istatistik yüzeylerinin okuduğu **tek** şey: anın günü, saati,
/// rengi ve pas bayrağı.
///
/// Ayrı bir tip olmasının sebebi `Moment`'ın taşıdığı `photoData`: Core
/// Data'da `allowsExternalBinaryDataStorage` ile saklanan bir blob, yani her
/// satır ayrı bir dosya. `Moment(from:)` onu her okumada belleğe alıyor —
/// bugünün üç anı için sorun değil, arşivin tamamı için ekranı kilitleyen bir
/// disk turu. Bu tip o alana hiç sahip olmayarak tuzağı kapatıyor.
struct ProfileStatSlice: Sendable {
    /// Günü normalize edilmiş tarih (00:00).
    let date: Date
    /// Anın gerçek saati — gün içi sıralama için.
    let time: Date
    let moodColorHex: String
    let passed: Bool

    /// `dictionaryResultType` satırından. Zorunlu alan `date`; yoksa satır
    /// düşer (`Moment(from:)` da aynısını yapıyor).
    init?(row: NSDictionary) {
        guard let rawDate = row["date"] as? Date else { return nil }
        let cal = Calendar.current
        self.date = cal.startOfDay(for: rawDate)
        // `createdAt` yoksa 12:00 — `Moment(from:)` ile aynı varsayım, ki iki
        // yol aynı kaydı aynı saatte görsün.
        self.time = (row["createdAt"] as? Date)
            ?? cal.date(bySettingHour: 12, minute: 0, second: 0, of: rawDate)
            ?? rawDate
        self.moodColorHex = (row["moodColorHex"] as? String) ?? ""
        self.passed = (row["passed"] as? Bool) ?? false
    }

    /// Örnek/enjekte veri yolu (`injectedMoments`) için köprü.
    init(moment: Moment) {
        self.date = moment.date
        self.time = moment.time
        self.moodColorHex = moment.moodColorHex
        self.passed = moment.passed
    }
}

struct V3ProfileView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var appleSignIn = AppleSignInService.shared
    @State private var moments: [ProfileStatSlice] = []
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showAvatarPicker: Bool = false
    @State private var showReminder: Bool = false
    @State private var showMusicSource: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showLanguage: Bool = false
    @State private var showFriends: Bool = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showOnboardingPreview: Bool = false
    /// Önizleme akışının "bitti" sinyali — gerçek `hasCompletedOnboarding`
    /// bayrağına dokunulmuyor, sadece cover'ı kapatıyor.
    @State private var onboardingPreviewDone: Bool = false
    /// Renk dağılımı barında seçili dilim — üstteki okuma satırını değiştirir.
    @State private var selectedDistributionIndex: Int = 0
    /// Üst çubuğun 0→1 zemin/başlık ilerlemesi. Scroll offset'inden geliyor.
    @State private var topBarProgress: CGFloat = 0

    // v3 settings — @AppStorage ile persist. iCloud yedeği default açık,
    // uygulama kilidi default kapalı.
    @AppStorage("v3.settings.appLock")     private var appLockEnabled: Bool = false
    @AppStorage("v3.settings.iCloudBackup") private var iCloudBackupEnabled: Bool = true
    /// Görünüm satırı — `oneApp` bu anahtarı okuyup `preferredColorScheme` veriyor.
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    /// DEBUG: Çevre sekmesini örnek arkadaşlarla doldurur (kabuk okuyor).
    @AppStorage("v3.debug.sampleFriends") private var sampleFriendsEnabled: Bool = false
    /// Avatar türü — `V3AvatarKind.current` ile aynı anahtar, ama @AppStorage
    /// olduğu için SwiftUI değişimi görüyor.
    @AppStorage("v3.avatar.kind") private var avatarKindRaw: String = V3AvatarKind.mosaic.rawValue

    /// Fotoğraf seçici — `.photo` avatarını gerçekten doldurabilmek için.
    @State private var photoPickerItem: PhotosPickerItem? = nil

    private var avatarKindValue: V3AvatarKind {
        V3AvatarKind(rawValue: avatarKindRaw) ?? .mosaic
    }

    /// DEBUG örnek veri — dolu ise Core Data okunmaz (preview/QA).
    var injectedMoments: [Moment]? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                // Ekran iki bölgeye ayrılıyor:
                //   SEN     — kimlik + arşivinin özeti (sıkı aralık, 20)
                //   AYARLAR — kontroller (geniş aralık, 24)
                // Aralık farkı, yatay çizgi çekmeden iki bölgeyi ayırıyor.
                VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
                    // Sekme re-tap anchor'ı + scroll-driven tab-bar sensörü.
                    Color.clear.frame(height: 0)
                        .id("profileTop")
                        .scrollOffsetSensor(spaceName: "one.scroll.profile")

                    heroSection
                        // Scroll-driven shrink: avatar+isim aşağı kaydırdıkça
                        // sessizce çekilir. iOS Photos / Instagram profil pattern'i.
                        .scrollTransition(axis: .vertical) { view, phase in
                            let up = max(0, -phase.value)
                            return view
                                .opacity(1 - up * 0.7)
                                .scaleEffect(1 - up * 0.06, anchor: .top)
                        }

                    // Hesap kartı yalnız **giriş yapılmamışken** burada.
                    // O durumda bir eylem (Apple ile Giriş Yap) ve ekranın en
                    // değerli yerini hak ediyor. Giriş yapılmışsa artık bir
                    // durum satırı — ayarların HESAP bloğuna iniyor, içeriğin
                    // önünü kesmiyor.
                    if !isSignedIn {
                        signedOutCard
                    }

                    statsGrid
                    if !distribution.isEmpty {
                        distributionSection
                    }
                    echoPreviewCard

                    settingsList
                        .padding(.top, V3Tokens.spacingMD)   // "sen" bölgesinden ayrılma
                        // Üst çubuğun dişli düğmesinin hedefi.
                        .id("profileSettings")

                    versionFooter
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, V3Tokens.spacingMD)
                // Dinlenme pozisyonunun tek sahibi kabuk: `safeAreaInset`
                // nav yüksekliği kadar pay bırakıyor. Buradaki fazladan 24pt
                // o payın üstüne biniyordu — son satır çubuğun 16pt üstünde
                // duruyor, çubuk boş kağıdın üzerinde asılı kalıyordu. Cam
                // ancak arkasından bir şey geçerse cam gibi okunur.
            }
            .background(V3Tokens.paper)
            .hidesTabBarOnScroll(tab: .profile, spaceName: "one.scroll.profile")
            .topBarProgress($topBarProgress, spaceName: "one.scroll.profile")
            .safeAreaInset(edge: .top, spacing: 0) {
                // Başlık sekmenin adı, kullanıcının adı değil.
                //
                // Bir dönem `vm.displayName` yazıyordu ve gerekçesi "hero
                // kayınca kimlik çubukta kalsın"dı. Başlık artık durağan
                // halde de görünür olduğu için o gerekçe tersine döndü: ad
                // hemen altındaki hero'da 32pt duruyorken çubukta ikinci kez
                // yazılıyordu. Kimlik gövdenin işi, ad çubuğun.
                //
                // Sağdaki eylem ayarlara atlıyor: bu ekran uygulamanın en
                // uzun listesi (hero + istatistik + dağılım + Yankı + dört
                // ayar bloğu) ve ayarlar en altta.
                V3TopBar(
                    style: .root,
                    title: PrimaryTab.profile.screenTitle,
                    progress: topBarProgress
                ) {
                    V3TopBarIconButton(
                        systemName: "gearshape",
                        label: NSLocalizedString("topbar.settings", comment: "")
                    ) {
                        ONEHaptics.tabSwitch()
                        withAnimation(ONEAnimation.screenTransition) {
                            proxy.scrollTo("profileSettings", anchor: .top)
                        }
                    }
                }
            }
            .task {
                vm.loadExistingProfile()
                loadMoments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
                loadMoments()
            }
            // Başka cihazdan inen kayıt: dağılım ve sayaçlar bayat kalmasın.
            // Ekran açıkken sync inerse `.task` bir daha koşmuyor.
            .onReceive(NotificationCenter.default.publisher(for: .momentsDidChangeRemotely)) { _ in
                loadMoments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileTabRetapped)) { _ in
                withAnimation(ONEAnimation.screenTransition) {
                    proxy.scrollTo("profileTop", anchor: .top)
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                avatarPickerSheet
            }
            .v3Sheet()
            .fullScreenCover(isPresented: $showMusicSource) {
                MusicSourceSettingsView(vm: vm, onBack: { showMusicSource = false })
            }
            .fullScreenCover(isPresented: $showPrivacy) {
                PrivacySettingsView(onBack: { showPrivacy = false })
            }
            .sheet(isPresented: $showLanguage) {
                LanguagePickerView().environmentObject(languageManager)
            }
            .v3Sheet()
            .sheet(isPresented: $showFriends) {
                MyFriendsListView(vm: vm)
            }
            .v3Sheet()
            .fullScreenCover(isPresented: $showOnboardingPreview) {
                ZStack(alignment: .topTrailing) {
                    V3OnboardingView(isCompleted: $onboardingPreviewDone, isPreview: true)

                    // Önizlemeden her adımda çıkılabilsin.
                    Button {
                        showOnboardingPreview = false
                    } label: {
                        Text("Kapat")
                            .monoSM(weight: .regular)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundColor(V3Tokens.mutedText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.onePressable)
                    .padding(.trailing, V3Tokens.spacingMD)
                    .padding(.top, 6)
                }
                .onChange(of: onboardingPreviewDone) { _, done in
                    if done {
                        showOnboardingPreview = false
                        onboardingPreviewDone = false
                    }
                }
            }
            .alert(NSLocalizedString("profile.deleteAccountTitle", comment: ""), isPresented: $showDeleteAccountAlert) {
                Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
                Button(NSLocalizedString("profile.deleteAccount", comment: ""), role: .destructive) {
                    vm.deleteAccount()
                }
            } message: {
                Text(NSLocalizedString("profile.deleteAccountMsg", comment: ""))
            }
            .fullScreenCover(isPresented: $showReminder) {
                ZStack {
                    V3Tokens.paper.ignoresSafeArea()
                    V3ReminderView(
                        onBack: { showReminder = false },
                        onSave: { _ in
                            V3ReminderScheduler.reschedule()
                            showReminder = false
                        }
                    )
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, V3Tokens.spacingXL2)
                    .padding(.bottom, V3Tokens.spacingXL2)
                }
            }
        }
    }

    // MARK: - Data

    private func loadMoments() {
        if let injected = injectedMoments {
            apply(injected.map(ProfileStatSlice.init(moment:)))
            return
        }
        Task { await loadMomentsAsync() }
    }

    /// Arşivin tamamını **dilim** olarak okur — `Moment` olarak değil.
    ///
    /// Eskiden `context.fetch` + `Moment(from:)` idi ve ekran donuyordu. İki
    /// ayrı sebepten:
    ///
    /// 1. `Moment(from:)` her satırda `photoData`'ya dokunuyor. O alan Core
    ///    Data'da `allowsExternalBinaryDataStorage` ile saklanıyor, yani her
    ///    fotoğraf ayrı bir dosya: N kayıt = N dosya okuması. Profil geçmişin
    ///    **tamamını** çektiği için sekmeye girer girmez arşiv boyunca disk
    ///    I/O'su başlıyordu. (`ArchiveStore.createEntry` bu tuzağı bilerek
    ///    atlıyor — orada gerekçesi yazılı; profil atlamıyordu.)
    /// 2. Hepsi main thread'deydi.
    ///
    /// `dictionaryResultType` + `propertiesToFetch` ile SQLite'tan yalnız dört
    /// kolon geliyor; blob'a hiç dokunulmuyor, managed object hiç kurulmuyor.
    /// Bu ekranın istatistik yüzeyleri (renk dağılımı, sayaçlar, aylık özet,
    /// üyelik tarihi) zaten yalnız bu dördünü okuyor.
    private func loadMomentsAsync() async {
        let bg = PersistenceController.shared.container.newBackgroundContext()
        let slices: [ProfileStatSlice] = await bg.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "DailySong")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["date", "createdAt", "moodColorHex", "passed"]
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            let rows = (try? bg.fetch(request)) ?? []
            return rows.compactMap(ProfileStatSlice.init(row:))
        }
        apply(slices)
    }

    /// Yeni dilimleri ve onlardan türeyen her şeyi tek geçişte yerleştirir.
    private func apply(_ slices: [ProfileStatSlice]) {
        moments = slices
        let result = Self.computeDistribution(slices)
        distribution = result.items
        countedMomentCount = result.counted
        currentMonth = Self.computeCurrentMonth(slices)
        // Dağılım yeniden sıralanınca eski index başka bir rengi işaret
        // ediyordu — okuma satırı sessizce yanlış kovayı gösteriyordu.
        selectedDistributionIndex = 0
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                // `avatarKind` @AppStorage — eskiden `V3AvatarKind.current`
                // (düz UserDefaults) okunuyordu ve SwiftUI'ın invalidasyon
                // kaynağı yoktu: seçim değişse de hero avatar güncellenmiyordu.
                V3AvatarView(kind: avatarKindValue, side: 76, photo: vm.profileImage)
                Button {
                    showAvatarPicker = true
                } label: {
                    Image(systemName: "pencil")
                        .iconXS(weight: .bold)
                        .foregroundColor(V3Tokens.paper)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(V3Tokens.ink))
                        .overlay(Circle().stroke(V3Tokens.paper, lineWidth: 2))
                }
                .buttonStyle(.onePressable)
                .offset(x: 3, y: 3)
            }

            VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
                Text(vm.displayName.isEmpty ? "Batu" : vm.displayName)
                    .font(ONEBrand.display(32))
                    .tracking(-0.9)
                    .foregroundColor(V3Tokens.ink)

                Text(sinceLabel)
                    .monoSM(weight: .regular)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.faintText)

                if let intent = OnboardingRecord.intent {
                    Text(String(format: NSLocalizedString("profile.intentFor", comment: ""), intent.uppercased()))
                        .monoLabel(weight: .regular)
                        .tracking(1.2)
                        .foregroundColor(V3Tokens.ghostText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, V3Tokens.spacingSM)
    }

    private var sinceLabel: String {
        let f = ONEFormatters.monthYear
        let joined = moments.last?.date ?? Date()
        return "\(f.string(from: joined))'dan beri"
    }

    // MARK: - Account card

    private var isSignedIn: Bool { appleSignIn.status == .signedIn }

    /// Prototip: giriş yapılmış satır — rozet + relay adresi + Çıkış.
    private var signedInRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "applelogo")
                .font(.system(size: 22))
                .foregroundColor(V3Tokens.ink)

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("profile.signedInWithApple", comment: ""))
                    .bodyMDSemibold()
                    .foregroundColor(V3Tokens.ink)
                if !vm.username.isEmpty {
                    Text(vm.username)
                        .monoSM(weight: .regular, tracking: 0)
                        .foregroundColor(V3Tokens.ghostText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button {
                appleSignIn.signOut()
            } label: {
                Text(NSLocalizedString("profile.signOut", comment: ""))
                    .monoSM(weight: .regular)
                    .tracking(1.1)
                    .foregroundColor(V3Tokens.korText)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
            .buttonStyle(.onePressable)
            .accessibilityLabel(NSLocalizedString("profile.a11y.signOut", comment: ""))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // Artık HESAP bloğunun **içinde** bir satır — kendi kart zemini yok
        // (grup zaten kart), altında diğer satırlara giden ayraç var.
        .overlay(alignment: .bottom) {
            Rectangle().fill(V3Tokens.hairline).frame(height: 1)
        }
    }

    /// Prototip: giriş yapılmamış kart — başlık + tek satır açıklama + Apple butonu.
    private var signedOutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HESAP")
                .monoLabel(weight: .regular)
                .tracking(1.5)
                .foregroundColor(V3Tokens.ghostText)

            Text(NSLocalizedString("profile.syncPitch", comment: ""))
                .font(ONEBrand.display(21))
                .tracking(-0.6)
                .lineSpacing(2)
                .foregroundColor(V3Tokens.ink)

            Text(NSLocalizedString("profile.signInOptional", comment: ""))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)

            // Apple'ın kendi butonu zorunlu — prototipteki 50pt / radius 12
            // ölçüsü korunuyor.
            SignInWithAppleButton(
                .signIn,
                onRequest: { appleSignIn.prepare(request: $0) },
                onCompletion: { appleSignIn.handle(result: $0) }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous))
            .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, V3Tokens.spacingXL)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneCardBackground(radius: V3Tokens.radiusPanel)
    }

    // MARK: - Stats grid

    /// Prototip: 3 kolon, aralar 1px `line` — hücreler surface, ızgara çizgisi
    /// zeminin kendisi. Sayı Archivo 26pt, etiket mono 9pt.
    private var statsGrid: some View {
        HStack(spacing: 1) {
            statCell(value: "\(countedMomentCount)", label: NSLocalizedString("profile.stat.moments", comment: ""))
            statCell(value: "\(uniqueColors)", label: NSLocalizedString("profile.stat.colorsUsed", comment: ""))
            statCell(value: topMoodLabel, label: NSLocalizedString("profile.stat.mostFrequent", comment: ""), accentHex: topMoodHex, valueSize: 18)
        }
        .background(V3Tokens.hairline)
        .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                .strokeBorder(V3Tokens.hairline, lineWidth: 1)
        )
    }

    private func statCell(value: String, label: String, accentHex: String? = nil, valueSize: CGFloat = 26) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 7) {
                if let hex = accentHex {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(hex: hex))
                        .frame(width: 11, height: 11)
                }
                Text(value)
                    .font(ONEBrand.display(valueSize))
                    .tracking(-0.9)
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .monoMicro()
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.ghostText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, V3Tokens.spacingLG)
        .background(V3Tokens.surface)
    }

    // MARK: - Stats calc

    /// Gerçek veri: her kayıt bir v3 rengine indirgenip **mood bazında**
    /// toplanır. `closest` sayesinde v1/v2'den kalan hex'ler de bir kovaya
    /// düşer; eskiden `fromHex` nil dönünce aynı duygu birden çok "?" satırına
    /// bölünüyordu.
    /// İstatistiklerin tabanı — pas geçilen günler hariç. `savePassedDay`
    /// gri bir hex (`#9E9E9E`) yazıyor ve `closest` onu en yakın renge
    /// ("Yorgun") yuvarlıyordu; pas günleri "en sık hissettiğin duygu"
    /// sayılıyordu.
    /// Renk dağılımı — `moments` değiştiğinde bir kez hesaplanır.
    ///
    /// Eskiden computed property'di ve dokuz ayrı yerden okunuyordu; üçü
    /// `ForEach` içindeydi (`distribution.prefix(9)`), biri de `totalCount`
    /// üzerinden dolaylı çağırıyordu. Tek bir render, koleksiyonun tamamını
    /// onlarca kez tarayıp her seferinde yeniden sıralıyordu. Kaynak veri
    /// yalnız `loadMoments()` içinde değiştiği için cache'lemek güvenli.
    @State private var distribution: [(hex: String, count: Int, label: String)] = []

    /// İstatistiklerin tabanındaki an sayısı (pas geçilen günler hariç).
    /// `distribution` ile aynı geçişte çıkıyor.
    @State private var countedMomentCount: Int = 0

    /// Kaç farklı renk kullanılmış. `distribution` her mood için tek giriş
    /// taşıdığı için bu doğrudan onun uzunluğu — ayrı bir tarama gereksizdi.
    private var uniqueColors: Int { distribution.count }

    /// Dağılımı ve sayacı tek geçişte üretir.
    private static func computeDistribution(
        _ moments: [ProfileStatSlice]
    ) -> (items: [(hex: String, count: Int, label: String)], counted: Int) {
        var counts: [V3Mood: Int] = [:]
        var counted = 0
        for moment in moments where !moment.passed && !moment.moodColorHex.isEmpty {
            counted += 1
            guard let mood = V3Mood.closest(toHex: moment.moodColorHex) else { continue }
            counts[mood, default: 0] += 1
        }
        let items = counts
            .map { (hex: $0.key.hex, count: $0.value, label: $0.key.label) }
            // Eşit sayıda olan renkler her okumada yer değiştirmesin —
            // ikincil kriter sabit bir sıra (palet sırası).
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.label < $1.label }
        return (items, counted)
    }

    private var topMoodHex: String? {
        distribution.first?.hex
    }

    private var topMoodLabel: String {
        distribution.first?.label ?? "—"
    }

    // MARK: - Renk dağılımı

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("profile.colourBreakdown", comment: ""))
                    .font(ONEBrand.display(21))
                    .tracking(-0.6)
                    .foregroundColor(V3Tokens.ink)
                Spacer()
                if let selected = selectedDistribution {
                    Text(String(format: NSLocalizedString("profile.distribution.selected", comment: ""), selected.label.uppercased(), selected.count))
                        .monoSM(weight: .regular)
                        .tracking(1.1)
                        .foregroundColor(V3Tokens.mutedText)
                }
            }

            // 44pt yığın bar — dilim genişlikleri paya göre.
            //
            // Eskiden `.layoutPriority(ratio)` ile denenmişti: `layoutPriority`
            // genişliği paylaştırmaz, yalnız **kimin önce teklif alacağını**
            // belirler. `maxWidth: .infinity` olan en yüksek öncelikli dilim
            // barın tamamını alıyor, diğerleri 0'a çöküyordu — kullanıcının
            // gördüğü "çalışmıyor" buydu. Genişlik artık ölçülüp bölünüyor.
            GeometryReader { geo in
                let items = Array(distribution.prefix(9).enumerated())
                let gaps = CGFloat(max(0, items.count - 1)) * 2
                let usable = max(0, geo.size.width - gaps)
                HStack(spacing: 2) {
                    ForEach(items, id: \.offset) { index, item in
                        let ratio = totalCount > 0 ? CGFloat(item.count) / CGFloat(totalCount) : 0
                        Rectangle()
                            .fill(Color(hex: item.hex))
                            .frame(width: max(3, usable * ratio), height: 44)
                            // Bar tamamen renkle ayrışıyordu; desen ikinci kanal.
                            .moodPattern(V3Mood.fromHex(item.hex), lineWidth: 0.9)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(V3Tokens.paper, lineWidth: selectedDistributionIndex == index ? 2 : 0)
                            )
                            .onTapGesture {
                                ONEHaptics.feelingSelected()
                                withAnimation(ONEAnimation.easingChip) { selectedDistributionIndex = index }
                            }
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Bar bir **grafik**: ince dilimler 44pt dokunma hedefi olamaz
            // (nadir bir renk 3pt'ye kadar iner). Dokunma bir kısayol olarak
            // duruyor; erişilebilir yol legend satırları — onlar tam genişlik.
            // VoiceOver bara tek bir özet olarak giriyor, dokuz mikro öğe
            // olarak değil.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(NSLocalizedString("profile.a11y.distributionChart", comment: ""))
            .accessibilityValue(
                distribution.prefix(9)
                    .map { String(format: NSLocalizedString("profile.a11y.distributionValue", comment: ""), $0.label, percentage($0.count)) }
                    .joined(separator: ", ")
            )

            // 2-sütun legend. Bar 9 dilim gösterirken legend 6 satır
            // gösteriyordu; kalan renkler yüzdesiyle birlikte kayboluyor ve
            // toplam %100 etmiyordu. Artık barla aynı kümeyi listeliyor.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: V3Tokens.spacingMD), GridItem(.flexible(), spacing: V3Tokens.spacingMD)], spacing: V3Tokens.spacingSM) {
                ForEach(Array(distribution.prefix(9).enumerated()), id: \.offset) { index, item in
                    Button {
                        withAnimation(ONEAnimation.easingChip) { selectedDistributionIndex = index }
                    } label: {
                        HStack(spacing: V3Tokens.spacingSM) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: item.hex))
                                .frame(width: 10, height: 10)
                                .moodPattern(V3Mood.fromHex(item.hex), lineWidth: 0.7)
                            Text(item.label)
                                .font(V3Typography.sans(14, weight: selectedDistributionIndex == index ? .semibold : .medium))
                                .foregroundColor(V3Tokens.ink)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(percentage(item.count))%")
                                .monoSM(weight: .regular, tracking: 0)
                                .foregroundColor(V3Tokens.mutedText)
                        }
                        // Satır 20pt yüksekliğinde metin taşıyor; 44pt'lik
                        // hedefe görünmez dolguyla tamamlanıyor. Bar dilimi
                        // dokunulamayacak kadar inceyken tek erişilebilir yol
                        // bu satırlar.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.onePressable)
                    .accessibilityLabel(String(format: NSLocalizedString("profile.a11y.distributionRow", comment: ""), item.label, item.count, percentage(item.count)))
                    .accessibilityAddTraits(selectedDistributionIndex == index ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var selectedDistribution: (hex: String, count: Int, label: String)? {
        let list = Array(distribution.prefix(9))
        guard !list.isEmpty else { return nil }
        return list[min(selectedDistributionIndex, list.count - 1)]
    }

    private var totalCount: Int { distribution.reduce(0) { $0 + $1.count } }
    private func percentage(_ n: Int) -> Int {
        guard totalCount > 0 else { return 0 }
        return Int(round(Double(n) / Double(totalCount) * 100))
    }

    // MARK: - Aylık özet (Yankı) önizlemesi

    /// Prototip 35'in (Echo kapak) profil içindeki küçültülmüş hali: ayın
    /// renginde kart + ay adı + duygu adı + olgusal satır + ayın mini mozaiği.
    /// Dokununca Yankı açılır (kabuktaki `switchToEchoTab` sheet'i).
    @ViewBuilder
    private var echoPreviewCard: some View {
        if let month = currentMonth {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("profile.monthlySummary", comment: ""))
                    .monoLabel(weight: .regular)
                    .tracking(1.5)
                    .foregroundColor(V3Tokens.ghostText)

                Button {
                    NotificationCenter.default.post(name: .init("switchToEchoTab"), object: nil)
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: NSLocalizedString("profile.monthColour", comment: ""), month.name))
                                    .monoSM(weight: .regular)
                                    .tracking(1.3)
                                    .textCase(.uppercase)
                                    .foregroundColor(month.mood.ink.opacity(0.75))

                                Text(month.mood.label)
                                    .font(ONEBrand.display(34))
                                    .tracking(-1)
                                    .foregroundColor(month.mood.ink)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .iconSM(weight: .semibold)
                                .foregroundColor(month.mood.ink.opacity(0.6))
                                .padding(.top, V3Tokens.spacingXS)
                        }

                        // Ayın mini mozaiği — 7 kolon, çok anlı gün için ilk an.
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                            spacing: 3
                        ) {
                            ForEach(Array(month.cells.enumerated()), id: \.offset) { _, hex in
                                RoundedRectangle(cornerRadius: V3Tokens.radiusMicro, style: .continuous)
                                    .fill(hex.map { Color(hex: $0) } ?? month.mood.ink.opacity(0.16))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }

                        Text(String(format: NSLocalizedString("profile.monthCounts", comment: ""), month.dayCount, month.momentCount))
                            .monoSM(weight: .regular)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundColor(month.mood.ink.opacity(0.8))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(month.mood.color)
                    )
                }
                .buttonStyle(.onePressable)
                .accessibilityLabel(String(format: NSLocalizedString("profile.a11y.monthlySummary", comment: ""), month.name, month.mood.label))
            }
        }
    }

    private struct MonthPreview {
        let name: String
        let mood: V3Mood
        /// Ayın her günü için renk — boş gün `nil`. 1. günden ay sonuna.
        let cells: [String?]
        let dayCount: Int
        let momentCount: Int
    }

    /// İçinde bulunulan ay; hiç kayıt yoksa `nil` (kart çizilmez).
    ///
    /// `distribution` gibi cache'li — ve aynı sebeple. Computed property
    /// olduğu sürece her `body` değerlendirmesinde tüm arşivi filtreleyip
    /// grupluyor ve her an için `V3Mood.closest(toHex:)` (dokuz renge RGB
    /// mesafesi) koşuyordu. `topBarProgress` scroll ile her karede değişen bir
    /// `@State`, yani `body` kaydırma boyunca sürekli yeniden değerlendiriliyor:
    /// tam taramanın kare başına tekrarı demekti. Kaynak veri yalnız
    /// `apply(_:)` içinde değişiyor, orada bir kez hesaplanıyor.
    @State private var currentMonth: MonthPreview? = nil

    private static func computeCurrentMonth(_ moments: [ProfileStatSlice]) -> MonthPreview? {
        let cal = Calendar.current
        let now = Date()
        let monthMoments = moments.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        guard !monthMoments.isEmpty else { return nil }

        var counts: [V3Mood: Int] = [:]
        for moment in monthMoments {
            guard let mood = V3Mood.closest(toHex: moment.moodColorHex) else { continue }
            counts[mood, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value })?.key else { return nil }

        let byDay = Dictionary(grouping: monthMoments) { cal.component(.day, from: $0.date) }
        let range = cal.range(of: .day, in: .month, for: now) ?? 1..<31
        let cells: [String?] = range.map { day in
            byDay[day]?.sorted { $0.time < $1.time }.first
                .flatMap { V3Mood.closest(toHex: $0.moodColorHex)?.hex }
        }

        let f = ONEFormatters.monthStandalone

        return MonthPreview(
            name: f.string(from: now).capitalized(with: LanguageManager.shared.currentLocale),
            mood: top,
            cells: cells,
            dayCount: byDay.keys.count,
            momentCount: monthMoments.count
        )
    }

    // MARK: - Ayarlar

    /// Prototipte tek kart var; üretimde satır sayısı buna sığmıyor
    /// (dil, müzik kaynağı, gizlilik, hesap silme zorunlu). Aynı tipografik
    /// sistem korunarak mono başlıklı bloklara ayrıldı.
    ///
    /// Gruplama, her bloğun cevapladığı soruya göre:
    ///   AYARLAR  — uygulama nasıl davransın?  (hatırlatma, müzik, dil, tema)
    ///   ÇEVRE    — beni kim görsün?           (arkadaşlar, gizlilik)
    ///   HESAP    — kim erişebilir, nasıl çıkarım? (giriş, kilit, silme)
    ///   HAKKINDA — meraklısına                (onboarding'i izle)
    private var settingsList: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL2) {
            settingsGroup(NSLocalizedString("settings.group.settings", comment: "")) {
                // Duruş ilke 4: arşivin sahibi kullanıcıdır. Dışa aktarma
                // gizli bir ayar değil — grubun ilk satırı.
                SettingsRow(
                    title: NSLocalizedString("settings.exportArchive", comment: ""),
                    subtitle: NSLocalizedString("settings.exportArchive.note", comment: ""),
                    showsChevron: false
                ) { exportArchive() }

                SettingsRow(
                    title: NSLocalizedString("settings.reminder", comment: ""),
                    value: reminderTimeLabel
                ) { showReminder = true }

                SettingsRow(
                    title: NSLocalizedString("settings.musicSource", comment: ""),
                    value: musicSourceLabel
                ) { showMusicSource = true }

                SettingsRow(
                    title: NSLocalizedString("profile.language", comment: ""),
                    value: languageManager.currentLanguage.displayName
                ) { showLanguage = true }

                // Görünüm — prototipte satırın altında iki kapsül.
                VStack(alignment: .leading, spacing: 11) {
                    Text(NSLocalizedString("settings.appearance", comment: ""))
                        .bodyLGMedium()
                        .foregroundColor(V3Tokens.ink)
                    HStack(spacing: 6) {
                        themePill(NSLocalizedString("profile.theme.light", comment: ""), isOn: !isDarkMode) { isDarkMode = false }
                        themePill(NSLocalizedString("profile.theme.dark", comment: ""), isOn: isDarkMode) { isDarkMode = true }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
            }

            settingsGroup(NSLocalizedString("settings.group.circle", comment: "")) {
                SettingsRow(
                    title: NSLocalizedString("settings.myFriends", comment: "")
                ) { showFriends = true }

                SettingsRow(
                    title: NSLocalizedString("settings.privacy", comment: ""),
                    isLast: true
                ) { showPrivacy = true }
            }

            settingsGroup("HESAP") {
                // Giriş yapılmış durum satırı buraya indi — ekranın tepesinde
                // bir kez bakılan bir durum, içeriğin önünde durmamalı.
                if isSignedIn { signedInRow }

                // "iCloud yedeği" anahtarı kaldırıldı: hiçbir yer okumuyordu.
                // `Persistence.init` CloudKit container'ını koşulsuz kuruyor,
                // yani kapatmak hiçbir şeyi kapatmıyordu — kullanıcıya yedeği
                // durdurduğunu söyleyen sahte bir kontroldü.
                //
                // Uygulama kilidi artık gerçek: `AppLockManager` Face ID /
                // Touch ID / cihaz parolası ile perdeyi açıyor.
                appLockRow

                SettingsRow(
                    title: NSLocalizedString("settings.deleteAccount", comment: ""),
                    titleColor: V3Tokens.korText,
                    isLast: true
                ) { showDeleteAccountAlert = true }
            }

            // Meraklısına — ayar değil, gezinti. Prototip 43'teki
            // "Onboarding · 7 adım" satırı; önizleme modunda açılır, hiçbir
            // şey yazmaz. Ayarların arasında değil, en sonda.
            settingsGroup(NSLocalizedString("settings.group.about", comment: "")) {
                SettingsRow(
                    title: NSLocalizedString("settings.watchOnboarding", comment: ""),
                    value: NSLocalizedString("profile.sevenSteps", comment: ""),
                    isLast: true
                ) { showOnboardingPreview = true }
            }

            #if DEBUG
            settingsGroup(NSLocalizedString("settings.group.developer", comment: "")) {
                SettingsToggleRow(
                    title: NSLocalizedString("settings.sampleCircleData", comment: ""),
                    subtitle: NSLocalizedString("settings.sampleCircleDataNote", comment: ""),
                    isOn: $sampleFriendsEnabled,
                    isLast: true
                )
            }
            #endif
        }
    }

    /// Kilit satırı. Cihaz hiçbir doğrulama sunmuyorsa anahtar yerine tek
    /// satırlık bir açıklama gösterilir — açılamayacak bir anahtar sunmak
    /// kullanıcıyı yanıltırdı.
    @ViewBuilder
    private var appLockRow: some View {
        // Kilit satırı. Cihaz hiçbir doğrulama sunmuyorsa anahtar yerine tek
        // satırlık bir açıklama gösterilir — açılamayacak bir anahtar sunmak
        // sahte kontrol olurdu.
        Group {
            if AppLockManager.isAvailable() {
                SettingsToggleRow(
                    title: NSLocalizedString("settings.appLock", comment: ""),
                    subtitle: AppLockManager.biometryLabel()
                        ?? NSLocalizedString("settings.appLockGeneric", comment: ""),
                    isOn: $appLockEnabled
                )
                .onChange(of: appLockEnabled) { _, enabled in
                    AppLockManager.shared.settingChanged(to: enabled)
                }
            } else {
                SettingsUnavailableRow(
                    title: NSLocalizedString("settings.appLock", comment: ""),
                    note: NSLocalizedString("applock.noPasscode", comment: "")
                )
            }
        }
    }

    /// Arşivi tek dosyaya yazıp sistem paylaşım sayfasını açar.
    ///
    /// Dosya `ArchiveExporter` tarafından geçici dizine yazılıyor; paylaşım
    /// sayfası kullanıcının seçtiği yere kopyalıyor.
    private func exportArchive() {
        ONEHaptics.feelingSelected()
        do {
            let url = try ArchiveExporter.writeArchive(
                context: PersistenceController.shared.container.viewContext
            )
            ShareManager.shared.shareViaActivityController(items: [url])
        } catch {
            ErrorHandler.shared.handle(
                AppError.unknown(message: NSLocalizedString("export.failed", comment: ""))
            )
        }
    }

    private func settingsGroup<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .monoLabel(weight: .regular)
                .tracking(1.5)
                .foregroundColor(V3Tokens.ghostText)
            VStack(spacing: 0) { content() }
                .oneCardBackground(radius: V3Tokens.radiusPanel)
        }
    }

    private var musicSourceLabel: String {
        // Üçüncü seçenek ("yalnızca arama") vardı ama ikili karşılaştırma
        // onu "Apple Music" gösteriyordu — satır yalan söylüyordu.
        switch UserDefaults.standard.string(forKey: "preferredMusicService") {
        case "Spotify":    return "Spotify"
        case "SearchOnly": return NSLocalizedString("profile.music.searchOnly", comment: "")
        default:           return "Apple Music"
        }
    }

    private var reminderTimeLabel: String {
        V3ReminderSettings.load().formattedTime
    }

    /// Prototipteki `pillBtn` — seçili: ink dolgu + paper metin.
    private func themePill(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(V3Typography.sans(13, weight: isOn ? .semibold : .medium))
                .foregroundColor(isOn ? V3Tokens.paper : V3Tokens.mutedText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isOn ? V3Tokens.ink : Color.clear)
                        .overlay(Capsule().strokeBorder(isOn ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1))
                )
                // Kapsül prototipteki ölçüde kalsın; dokunma hedefi 44pt'ye
                // görünmez dolguyla tamamlanıyor.
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Prototip: "Sürüm 3.0 · N an".
    private var versionFooter: some View {
        Text(String(format: NSLocalizedString("profile.versionLine", comment: ""), appVersion, countedMomentCount))
            .monoLabel(weight: .regular)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.ghostText)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"
    }

    // MARK: - Avatar picker sheet

    private var avatarPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
                Text(NSLocalizedString("profile.pickAvatar", comment: ""))
                    .font(ONEBrand.display(28))
                    .tracking(-0.7)
                    .foregroundColor(V3Tokens.ink)
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, V3Tokens.spacingMD)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        V3AvatarPicker(
                            selection: Binding(
                                get: { avatarKindValue },
                                set: { avatarKindRaw = $0.rawValue }
                            ),
                            userPhoto: vm.profileImage
                        )

                        // "Fotoğraf" karesi seçilebiliyordu ama fotoğrafı
                        // seçecek bir yer yoktu — kare kalıcı olarak boş
                        // yer tutucu kalıyordu. Seçici artık burada.
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            HStack(spacing: V3Tokens.spacingMD) {
                                Image(systemName: vm.profileImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                                    .iconMD(weight: .medium)
                                    .foregroundColor(V3Tokens.ink)
                                Text(vm.profileImage == nil ? NSLocalizedString("profile.photo.pick", comment: "") : NSLocalizedString("entry.photo.change", comment: ""))
                                    .bodyLGMedium()
                                    .foregroundColor(V3Tokens.ink)
                                Spacer()
                                if vm.isUploadingPhoto {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, V3Tokens.spacingLG)
                            .oneCardBackground(radius: V3Tokens.radiusPanel)
                        }
                        .buttonStyle(.onePressable)

                        Text(NSLocalizedString("profile.photoVisibility", comment: ""))
                            .bodyXS()
                            .foregroundColor(V3Tokens.mutedText)
                            .padding(.horizontal, V3Tokens.spacingXS)
                    }
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .padding(.top, V3Tokens.spacingSM)
                }
                Spacer()
            }
            .background(V3Tokens.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { showAvatarPicker = false }
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    await vm.loadAndSaveProfilePhoto(from: item)
                    // Fotoğraf geldiyse avatarı otomatik `.photo`'ya çevir —
                    // kullanıcı iki ayrı adım yapmak zorunda kalmasın.
                    if vm.profileImage != nil { avatarKindRaw = V3AvatarKind.photo.rawValue }
                    photoPickerItem = nil
                }
            }
        }
    }
}

#if DEBUG
#Preview("Profil") {
    V3ProfileView(injectedMoments: V3ProfileSampleData.moments())
}

#Preview("Profil · koyu") {
    V3ProfileView(injectedMoments: V3ProfileSampleData.moments())
        .preferredColorScheme(.dark)
}

/// Profil ekranını gerçek kayıt olmadan görebilmek için örnek arşiv:
/// bu ayın 18 gününe dağılmış 27 an, 6 farklı renk.
enum V3ProfileSampleData {
    static func moments() -> [Moment] {
        let cal = Calendar.current
        let now = Date()
        let palette: [V3Mood] = [.huzurlu, .mutlu, .odakli, .yorgun, .coskulu, .huzunlu]
        var out: [Moment] = []
        for day in 1...18 {
            guard let date = cal.date(bySetting: .day, value: day, of: now) else { continue }
            let perDay = day % 3 == 0 ? 2 : 1
            for index in 0..<perDay {
                let mood = palette[(day + index) % palette.count]
                out.append(
                    Moment(
                        id: UUID(),
                        date: cal.startOfDay(for: date),
                        time: cal.date(bySettingHour: 9 + index * 6, minute: 20, second: 0, of: date) ?? date,
                        moodIndex: V3Mood.allCases.firstIndex(of: mood) ?? 0,
                        moodColorHex: mood.hex,
                        note: index == 0 ? "Kısa bir not." : nil,
                        photoRef: nil,
                        photoData: nil,
                        songName: nil,
                        songArtist: nil,
                        scope: index == 0 ? .friends : .private,
                        entryIndex: index
                    )
                )
            }
        }
        return out.sorted { $0.time > $1.time }
    }
}
#endif
