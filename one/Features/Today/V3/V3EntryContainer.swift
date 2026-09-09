import SwiftUI
import CoreData
import CloudKit

/// v3 girdi akışının kabuğu — 3 adımlı state machine + shared header +
/// progress bar. Handoff'un tek zorunlu ekranı.
struct V3EntryContainer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var vm: TodayViewModel
    @StateObject private var globalUI = GlobalUIState.shared

    // Geriye dönük giriş yok (duruş ilke 3): akış her zaman bugüne yazar.
    // Eskiden Arşiv'den gelen `pendingEntryDate` ile past-day modu açılıyordu.

    /// Kullanıcı "Arşive git" derse dışa (parent) haber ver. TodayView bunu
    /// tab değiştirmek için kullanacak; nil ise buton yalnızca akışı kapatır.
    var onArchive: (() -> Void)? = nil

    /// Kullanıcı "Baştan" derse akış sıfırlanır — parent bir şey yapmaz.
    var onRestart: (() -> Void)? = nil

    // MARK: - State

    enum Step: Int, Equatable {
        case hub = -1        // v3: gün zaten dolu → time-rail + "Yeni an ekle"
        case pick = 0
        case details = 1
        case saved = 2
    }

    @State private var step: Step = .pick
    /// Hub'dayken "Yeni an ekle" basılınca true olur → pick akışına geçer.
    /// Kayıt biter bitmez tekrar false olur; sonraki açılışta hub görünür.
    @State private var addNew: Bool = false

    /// Adım geçişlerinin yönü — forward (ileri) sağdan gelir, backward (geri)
    /// soldan gelir. Spatial model: "ilerliyorum"/"geri döndüm" hissi.
    @State private var transitionDirection: TransitionDir = .forward

    /// Seçilen mood rengi tile → hero → doneBlock arasında fiziksel taşınır.
    /// Kullanıcı "rengimi seçtim, o renk benimle geliyor" hissi kurar.
    @Namespace private var moodMorph

    enum TransitionDir { case forward, backward }
    @State private var selectedMood: V3Mood?
    @State private var note: String = ""
    @State private var photoEnabled: Bool = false
    @State private var pickedPhoto: UIImage?
    @State private var songEnabled: Bool = false
    @State private var pickedSong: SongResult?
    /// v3: her an için ayrı kapsam. Talimat default `.private`.
    @State private var scope: MomentScope = .private
    /// Bugüne ait tüm anlar. Hub karar verirken bunu okur.
    @State private var todayMoments: [Moment] = []

    @State private var showReminder: Bool = false
    @State private var reminderSettings: V3ReminderSettings = V3ReminderSettings.load()
    @State private var showStoryComposer: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            if showReminder {
                V3ReminderView(
                    settings: reminderSettings,
                    onBack: { showReminder = false },
                    onSave: { saved in
                        reminderSettings = saved
                        V3ReminderScheduler.reschedule(
                            yesterdayMood: yesterdayMoodForCurious()
                        )
                        showReminder = false
                    }
                )
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, V3Tokens.spacingXL2)
                .padding(.bottom, V3Tokens.spacingXL2)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)).combined(with: .opacity))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    V3ProgressBar(activeThrough: progressActiveThrough)

                    contentForStep
                        .padding(.top, V3Tokens.spacingSM)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, V3Tokens.spacingMD)
                .padding(.bottom, V3Tokens.spacingXL2)
                .transition(.opacity)
            }
        }
        // An sekmesinin üst çubuğu artık **akışın tamamında** duruyor, tek
        // yerde tanımlı.
        //
        // Eskiden iki farklı başlık vardı: hub adımı `V3TopBar`'ı kendi
        // içinde çiziyordu (üstelik gövdenin 24pt payının içinde, yani diğer
        // üç sekmenin çubuğuyla hizasız), pick/details/saved adımları ise
        // `V3Header`'ı — tarih + marka işareti. Aynı sekmede iki başlık
        // dili, ve ikisi de ekranın adını hiç söylemiyordu.
        //
        // Hatırlatma düğmesi yalnız dinlenme adımlarında: `.details`'te
        // kullanıcı yazıyor, `.saved`'da kaydı yeni bitirdi — ikisinde de
        // akıştan çıkaran bir düğme sunmak yarım kalmış bir kaydı terk
        // ettirir.
        .safeAreaInset(edge: .top, spacing: 0) {
            if !showReminder {
                V3TopBar(
                    style: .root,
                    title: PrimaryTab.entry.screenTitle,
                    context: headerLabel
                ) {
                    if showsReminderAction {
                        V3TopBarIconButton(
                            systemName: "alarm",
                            label: NSLocalizedString("settings.reminder", comment: "")
                        ) {
                            showReminder = true
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? .none : ONEAnimation.easing, value: step)
        .animation(reduceMotion ? .none : ONEAnimation.easing, value: showReminder)
        .fullScreenCover(isPresented: $showStoryComposer) {
            if let mood = selectedMood {
                V3StoryComposerView(
                    mood: mood,
                    note: note.isEmpty ? nil : note,
                    photo: photoEnabled ? pickedPhoto : nil,
                    songName: pickedSong?.name,
                    songArtist: pickedSong?.artist,
                    dateLabel: storyDateLabel,
                    onClose: { showStoryComposer = false }
                )
            }
        }
        .onAppear {
            if UserDefaults.standard.object(forKey: V3ReminderKeys.minutes) == nil {
                V3ReminderSettings.defaults.save()
                reminderSettings = V3ReminderSettings.defaults
            }
            hydrateExistingEntryIfNeeded()
            // Hatırlatıcı planlaması BİLEREK burada değil.
            //
            // `V3ReminderScheduler.reschedule` içinde `requestAuthorization`
            // var; burada çağrılınca sistem izin prompt'u An sekmesinin ilk
            // karesinde çıkıyordu. `oneApp.setupPushNotifications`'daki yazılı
            // politika bunu yasaklıyor: izin `.notDetermined` olmaktan çıkarsa
            // onboarding'in soft-ask adımı ve tamamlandı banner'ı sessizce
            // ölüyor. Aynı iş zaten Tier 3'te (`oneApp`) yapılıyor.
            //
            // Ayar değişimi yolu (`V3ReminderView.onSave`) kendi reschedule'ını
            // çağırmaya devam ediyor — orada izin istemek doğru, kullanıcı
            // hatırlatıcıyı bilerek açıyor.
            syncTabBarMinimize()
        }
        .onChange(of: vm.todayEntry?.id) { _, _ in
            hydrateExistingEntryIfNeeded()
        }
        .onChange(of: step) { _, _ in
            syncTabBarMinimize()
        }
        .onChange(of: showReminder) { _, _ in
            syncTabBarMinimize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startNewMomentRequested)) { _ in
            startNewFromTabRetap()
        }
        .onDisappear {
            // Sekme değişince çubuk normal boyuta dönsün.
            // (Kabuk `onChange(of: vm.currentScreen)` ile aynı sıfırlamayı
            // ayrıca yapıyor — `TabView` sekmeleri canlı tuttuğu için
            // `onDisappear`'ın tetikleneceğine güvenemeyiz.)
            GlobalUIState.shared.tabBarMinimized     = false
            GlobalUIState.shared.entryFlowLocksSwipe = false
        }
    }

    /// An sekmesine tekrar dokununca "bugün nasılsın?" (`.pick`) ile
    /// "bugünkü momentlar" (`.hub`) arasında toggle. Erişilebilirlik: iki ekran
    /// arası tek dokunuşla geçiş. Kullanıcı yazıyor (details) ya da
    /// hatırlatıcıyı düzenliyorsa dokunma — orada olmak istiyor.
    private func startNewFromTabRetap() {
        if step == .details { return }
        if showReminder { return }

        // Retap anında en güncel liste — hub'a düşmenin anlamlı olup olmadığına
        // buradan karar veriyoruz.
        let today = Calendar.current.startOfDay(for: Date())
        todayMoments = PersistenceController.shared.fetchMoments(for: today, context: vm.context)
        let hasMoments = !todayMoments.isEmpty

        // Toggle hedefini önce hesapla; form reset'i animasyon dışında kalsın
        // ki geçiş sırasında geride kalan form değerleri titremesin.
        let target: Step
        let nextAddNew: Bool
        switch step {
        case .hub:
            target = .pick
            nextAddNew = true
        case .pick, .saved:
            if hasMoments {
                target = .hub
                nextAddNew = false
            } else {
                // Gidilecek başka yer yok — zaten `.pick`'teyiz. Aşağıdaki
                // `resetFormState()` burada çalışırsa kullanıcının seçtiği
                // rengi sessizce siler; sekmeye refleksle ikinci kez dokunmak
                // veri kaybı gibi hissettirmemeli.
                if step == .pick { return }
                target = .pick
                nextAddNew = true
            }
        case .details:
            return
        }

        resetFormState()
        addNew = nextAddNew

        // Retap toggle için yumuşak crossfade — step değişimi ayrıca
        // `stepTransition()` çalıştırıyor; iki animasyon tek eğri altında.
        withAnimation(reduceMotion ? .none : ONEAnimation.easingColor) {
            step = target
        }
    }

    private func resetFormState() {
        selectedMood = nil
        note = ""
        photoEnabled = false
        pickedPhoto = nil
        songEnabled = false
        pickedSong = nil
        scope = .private
    }

    /// Not yazma adımında (details) çubuğu daralt ve sekme swipe'ını kilitle.
    ///
    /// Kabuk artık `TabView(.page)` — yatay swipe her yerde aktif. Kullanıcı
    /// not yazarken ya da fotoğraf/şarkı seçerken parmağını yana kaydırınca
    /// sekme değişip yazdığı şey gitmiş gibi hissetmemeli. Kilit yalnız bu
    /// adımda; renk seçimi (`pick`) ve `saved` serbest.
    private func syncTabBarMinimize() {
        let inFlight = (step == .details)
        GlobalUIState.shared.tabBarMinimized     = inFlight
        GlobalUIState.shared.entryFlowLocksSwipe = inFlight || showReminder
    }

    // MARK: - Step router

    @ViewBuilder
    private var contentForStep: some View {
        switch step {
        case .hub:
            V3HubStepView(
                day: Day(date: Calendar.current.startOfDay(for: Date()), moments: todayMoments),
                onAddNew: {
                    addNew = true
                    transitionDirection = .forward
                    withAnimation(reduceMotion ? .none : ONEAnimation.easing) { step = .pick }
                },
                // Bilerek `nil`: boş bir closure geçmek satırı "bağlı düğme"
                // gösteriyor ve VoiceOver'da kırık bir eylem yaratıyordu.
                // Düzenleme akışı bağlanınca burası doldurulacak.
                onEditMoment: nil
            )
            .transition(stepTransition())
        case .pick:
            V3ColorStepView(
                selectedMood: $selectedMood,
                onContinue: {
                    guard selectedMood != nil else { return }
                    transitionDirection = .forward
                    step = .details
                },
                title: pickTitle,
                greeting: pickGreeting,
                moodMorph: moodMorph
            )
            // Adım 1 kendi içinde kaydırılıyor ve footer'ı alta sabitliyor;
            // bunun için kalan yüksekliğin tamamını alması gerekiyor.
            // `layoutPriority` aşağıdaki `Spacer(minLength: 0)`'ın esnek alanı
            // paylaşmasını engelliyor — yoksa Devam butonu aşağı kayıyor.
            .frame(maxHeight: .infinity, alignment: .top)
            .layoutPriority(1)
            .transition(stepTransition())
        case .details:
            if let mood = selectedMood {
                V3DetailsStepView(
                    mood: mood,
                    note: $note,
                    photoEnabled: $photoEnabled,
                    pickedPhoto: $pickedPhoto,
                    songEnabled: $songEnabled,
                    pickedSong: $pickedSong,
                    scope: $scope,
                    onBack: {
                        transitionDirection = .backward
                        step = .pick
                    },
                    onSave: { commitSave(mood: mood) },
                    moodMorph: moodMorph
                )
                .transition(stepTransition())
            }
        case .saved:
            if let mood = selectedMood {
                V3SavedStepView(
                    mood: mood,
                    note: note.isEmpty ? nil : note,
                    photo: pickedPhoto,
                    last7Days: [],
                    onArchive: { onArchive?() },
                    onRestart: { restart() },
                    onEditReminder: { showReminder = true },
                    onEmptyDayTap: { _ in },
                    reminderTimeLabel: reminderSettings.formattedTime,
                    momentOrdinal: savedMomentOrdinal,
                    momentDateLabel: savedMomentDateLabel,
                    scope: scope,
                    totalMomentsToday: max(1, todayMoments.count),
                    onCreateStoryCard: { showStoryComposer = true }
                )
                .transition(stepTransition())
            }
        }
    }

    // MARK: - Saved ordinal + date label

    /// Yeni kayıt sonrası kaç.ıncı an olduğu. `todayMoments` save sonrası
    /// yeni satırı içeriyor, count kullanılır.
    private var savedMomentOrdinal: Int {
        max(1, todayMoments.count)
    }

    /// "12 TEMMUZ" formatında micro-label.
    private var savedMomentDateLabel: String {
        ONEFormatters.dayMonth.string(from: Date()).uppercased()
    }

    /// Story kart üst köşesindeki tarih — "12 TEMMUZ · CUMA".
    private var storyDateLabel: String {
        ONEFormatters.dayMonthWeekday.string(from: Date()).uppercased()
    }

    // MARK: - Actions

    private func commitSave(mood: V3Mood) {
        vm.saveV3Entry(
            mood: mood,
            note: note,
            photo: photoEnabled ? pickedPhoto : nil,
            song: songEnabled ? pickedSong : nil,
            scope: scope
        )
        // Kayıt haptiği BURADA DEĞİL.
        //
        // Bu blok eskiden dört vuruşluk duygusal yayı kendisi çalıyordu.
        // Ama `SaveRitualMoment` de aynı yayı çalıyor: kayıt `vm.todayEntry`
        // değişimini tetikliyor, `TodayView` ritüeli mount ediyor, o da
        // `ONEHaptics.saveRitual(...)` diyor. Yani uygulamanın imza anı her
        // kayıtta **iki kez** titriyordu — üstelik iki farklı mood eşlemesiyle
        // (`mood.bridgedMood` burada, `ONEMood(hex:)` orada), dolayısıyla iki
        // desen birbirini tutmuyordu bile.
        //
        // Ritüelin tek sahibi `SaveRitualMoment`: görsel ve taktil aynı yerden,
        // aynı zaman çizgisinde çıkıyor.
        // v3: yeni an eklendi — todayMoments'i tazele ki ordinal doğru olsun.
        let today = Calendar.current.startOfDay(for: Date())
        todayMoments = PersistenceController.shared.fetchMoments(for: today, context: vm.context)
        transitionDirection = .forward
        withAnimation(reduceMotion ? .none : ONEAnimation.easingSaved) {
            step = .saved
        }
    }

    private func restart() {
        // v3: "Baştan" artık bugünün TÜM anlarını silmek olmadı — kullanıcı
        // yeni bir an eklemek istiyor sadece. Formu boşalt, hub'a dön.
        selectedMood = nil
        note = ""
        photoEnabled = false
        pickedPhoto = nil
        songEnabled = false
        pickedSong = nil
        scope = .private
        addNew = false
        withAnimation(reduceMotion ? .none : ONEAnimation.easing) {
            hydrateExistingEntryIfNeeded()
        }
        onRestart?()
    }

    /// v3: gün zaten dolu ise **Hub'a** düş (Saved ekranına değil — kullanıcı
    /// bir sonraki an'ı ekleyebilmeli). Kayıt akışının içindeysek karışma.
    private func hydrateExistingEntryIfNeeded() {
        // Refresh today's moments from persistence.
        let today = Calendar.current.startOfDay(for: Date())
        todayMoments = PersistenceController.shared.fetchMoments(for: today, context: vm.context)

        // Kullanıcı yazıyorsa (details) dokunma — devam etsin.
        if step == .details { return }
        if addNew { return }

        // .saved'daydık ve buraya geri döndük (başka sekmeden) → temizle.
        if step == .saved {
            resetFormState()
        }

        // Boş gün → pick; dolu → hub.
        step = todayMoments.isEmpty ? .pick : .hub
    }

    private func stepTransition() -> AnyTransition {
        if reduceMotion { return .opacity }
        let shift: CGFloat = 16
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(x: shift)),
                removal:   .opacity.combined(with: .offset(x: -shift))
            )
        case .backward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(x: -shift)),
                removal:   .opacity.combined(with: .offset(x: shift))
            )
        }
    }

    // MARK: - Pick title variants (v3 spec)

    /// V3 spec:
    ///  • an yok → "Bugün nasılsın?"
    ///  • an var → "Bir an daha?"
    private var pickTitle: String {
        if todayMoments.isEmpty { return NSLocalizedString("entry.title.today", comment: "") }
        return NSLocalizedString("entry.title.another", comment: "")
    }

    /// Sadece günün ilk anı yazılırken selam gösterilir.
    private var pickGreeting: String? {
        guard todayMoments.isEmpty else { return nil }
        // v3: CloudKit currentUser displayName varsa "Günaydın, Batu" olur.
        let name = CloudKitManager.shared.currentUser?["displayName"] as? String
        return V3GreetingHeaderCopy.currentGreeting(name: name)
    }

    // MARK: - Header / progress

    private var headerLabel: String {
        switch step {
        case .hub, .pick, .details, .saved:
            return V3DateFormatter.headerLabel()
        }
    }

    /// Üst çubuğun hatırlatma düğmesi görünür mü? Yalnız akışın dinlenme
    /// adımlarında — bkz. `safeAreaInset` yorumu.
    private var showsReminderAction: Bool {
        step == .hub || step == .pick
    }

    private var progressActiveThrough: Int {
        switch step {
        case .hub:     return -1
        case .pick:    return 0
        case .details: return 1
        case .saved:   return 2
        }
    }

    // MARK: - Data

    private func computeLast7Days() -> [V3Mood?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days: [Date] = []
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: -(6 - i), to: today) {
                days.append(d)
            }
        }
        // v3: gün başına birden fazla an olabilir — duplicate key crash olmasın.
        // Son an günün "temsili" rengi (last wins). 7-gün şeridi tek renk gösteriyor;
        // dilim gösterimi Faz 4'te DayFill'de.
        let indexed = Dictionary(
            vm.thisWeekEntries.map { ($0.date, $0.moodColorHex) },
            uniquingKeysWith: { _, new in new }
        )
        return days.map { d in
            if let hex = indexed[d] {
                return V3Mood.fromHex(hex)
            }
            // Bugün: aslında henüz thisWeekEntries yenilenmemiş olabilir —
            // taze commit için hafızadaki `selectedMood` fallback'i.
            if d == today, let selectedMood {
                return selectedMood
            }
            return nil
        }
    }

    private func yesterdayMoodForCurious() -> V3Mood? {
        let cal = Calendar.current
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if let hex = vm.thisWeekEntries.first(where: { $0.date == yesterday })?.moodColorHex {
            return V3Mood.fromHex(hex)
        }
        return nil
    }
}
