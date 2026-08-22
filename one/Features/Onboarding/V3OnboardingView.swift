//
//  V3OnboardingView.swift
//  one
//
//  v3 onboarding — 7 adım: intent · auth · mood · song · reward · çevre · notif.
//  Talimattan: Archivo 40pt başlık, Instrument Sans 16pt açıklama,
//  ink primary + ghost buton. Üstte 7 nokta ilerleme (aktif geniş kor).
//

import SwiftUI
import AuthenticationServices
import UserNotifications
import CoreData

/// v3 onboarding'de toplanan kalıcı veri. Profil / istatistik ekranları bunu
/// okur ("Ocak 2026'dan beri · kendini tanımak için", vb.).
enum OnboardingRecord {
    private static let defaults = UserDefaults.standard

    static let intentKey       = "v3.onboarding.intent"
    static let firstMoodKey    = "v3.onboarding.firstMoodHex"
    static let completedAtKey  = "v3.onboarding.completedAt"

    static var intent: String? {
        get { defaults.string(forKey: intentKey) }
        set { defaults.set(newValue, forKey: intentKey) }
    }
    static var firstMoodHex: String? {
        get { defaults.string(forKey: firstMoodKey) }
        set { defaults.set(newValue, forKey: firstMoodKey) }
    }
    static var completedAt: Date? {
        get { defaults.object(forKey: completedAtKey) as? Date }
        set { defaults.set(newValue, forKey: completedAtKey) }
    }
}

struct V3OnboardingView: View {
    @Environment(\.managedObjectContext) private var context
    @Binding var isCompleted: Bool

    /// Önizleme modu — Profil › Onboarding satırından açıldığında `true`.
    /// Akış birebir aynı görünür ama **hiçbir kalıcı yazma yapılmaz**:
    /// an kaydedilmez, hatırlatma ayarı değişmez, keychain'e dokunulmaz.
    /// Yalnızca `isCompleted` flip'lenir ki sunan ekran kapatabilsin.
    var isPreview: Bool = false

    enum Step: String, CaseIterable, Identifiable {
        // v3 sıra: intent → mood → auth → song → reward → çevre → notif.
        // Auth mood'dan sonra — kullanıcı önce ilk rengini seçer, sonra
        // Apple ile giriş kararı verir (daha az sürtünme).
        case intent, mood, auth, song, reward, circle, notif
        var id: String { rawValue }
        var label: String {
            switch self {
            case .intent:  return "Niyet"
            case .mood:    return "İlk renk"
            case .auth:    return "Giriş"
            case .song:    return "Şarkı"
            case .reward:  return "İlk kare"
            case .circle: return "Çevre"
            case .notif:   return "Hatırlatma"
            }
        }
    }

    @State private var pos: Int = 0
    @State private var selectedIntent: String? = nil
    @State private var selectedMood: V3Mood? = nil
    @State private var reminderOn: Bool = true

    private var current: Step? {
        pos < Step.allCases.count ? Step.allCases[pos] : nil
    }

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                progressDots
                    .padding(.top, V3Tokens.spacingXL)

                stepLabel
                    .padding(.top, 18)

                content
                    .padding(.top, V3Tokens.spacingXL2)
                    .transition(.opacity.combined(with: .offset(y: 9)))

                Spacer(minLength: 22)

                footer
            }
            .padding(.horizontal, V3Tokens.spacingXL2)
            .padding(.top, V3Tokens.spacingXL4)
            .padding(.bottom, 28)
        }
        .animation(ONEAnimation.easing, value: pos)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(Step.allCases.enumerated()), id: \.offset) { i, _ in
                let isActive = i == pos
                let isPast = i < pos
                Capsule()
                    .fill(isActive ? ONEBrand.kor : (isPast ? V3Tokens.mutedText : V3Tokens.hairline))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: isActive ? .infinity : nil)
                    .layoutPriority(isActive ? 2.4 : 1)
                    .animation(ONEAnimation.easing, value: pos)
            }
        }
    }

    private var stepLabel: some View {
        Text(stepLabelText)
            .font(V3Typography.mono(11, weight: .regular))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.faintText)
    }

    private var stepLabelText: String {
        guard let cur = current else { return "Hazırsın" }
        return "\(pos + 1) / \(Step.allCases.count) · \(cur.label)"
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch current {
        case .intent:  intentStep
        case .auth:    authStep
        case .mood:    moodStep
        case .song:    songStep
        case .reward:  rewardStep
        case .circle: circleStep
        case .notif:   notifStep
        case .none:    doneStep
        }
    }

    // MARK: - Steps

    private var intentStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Neden buradasın?")
            lead("Bir cümle yeter. Sonra değişebilir.")

            VStack(spacing: 10) {
                intentPill("Kendimi tanımak")
                intentPill("Duygularımı takip etmek")
                intentPill("Şarkılarla eşleştirmek")
                intentPill("Sadece merak ettim")
            }
            .padding(.top, V3Tokens.spacingSM)
        }
    }

    private func intentPill(_ title: String) -> some View {
        Button {
            ONEHaptics.feelingSelected()
            selectedIntent = title
        } label: {
            HStack {
                Text(title)
                    .bodyLGMedium()
                    .foregroundColor(V3Tokens.ink)
                Spacer()
                if selectedIntent == title {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONEBrand.kor)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, V3Tokens.spacingLG)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                    .strokeBorder(selectedIntent == title ? V3Tokens.ink : V3Tokens.hairline, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                            .fill(V3Tokens.surface)
                    )
            )
        }
        .buttonStyle(.onePressable)
    }

    private var authStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Apple ile\ngiriş yap.")
            lead("iCloud'da saklanır. Şifre yok.")

            SignInWithAppleButton(
                onRequest: { req in req.requestedScopes = [.fullName, .email] },
                onCompletion: { _ in
                    ONEHaptics.songSaved()
                    next()
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(Capsule())
            .padding(.top, V3Tokens.spacingLG)
        }
    }

    private var moodStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Bugün\nnasılsın?")
            lead("Bir renk seç. Yeter.")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(V3Mood.allCases) { mood in
                    Button {
                        ONEHaptics.moodSelected()
                        selectedMood = mood
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                                .fill(mood.color)
                                .aspectRatio(1, contentMode: .fit)
                            Text(mood.label.lowercased())
                                .bodyXSSemibold()
                                .foregroundColor(mood.ink)
                                .padding(10)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                                .stroke(V3Tokens.ink, lineWidth: selectedMood == mood ? 2 : 0)
                                .padding(-2)
                        )
                    }
                    .buttonStyle(.onePressable)
                }
            }
        }
    }

    private var songStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Bir şarkı\nekle mi?")
            lead("Sonra da ekleyebilirsin.")
            // Simplified — bu adımda picker yerine sadece "Sonra ekle" seçeneği.
            // Gerçek şarkı seçimi ilk kayıt akışında olur.
        }
    }

    private var rewardStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("İlk karen\nhazır.")
            lead("Her an bir renk daha ekler.")
            if let mood = selectedMood {
                DayFill(hexes: [mood.hex], cornerRadius: V3Tokens.radiusTile)
                    .frame(width: 140, height: 140)
                    .padding(.top, V3Tokens.spacingMD)
            }
        }
    }

    private var circleStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Çevrene\nkim girsin?")
            lead("Sonra da davet edebilirsin.")
        }
    }

    private var notifStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Küçük bir\nhatırlatma?")
            lead("İstediğin saatte, bir kez.")

            Toggle(isOn: $reminderOn) {
                Text(NSLocalizedString("reminder.daily", comment: ""))
                    .bodyMDMedium()
                    .foregroundColor(V3Tokens.ink)
            }
            .tint(ONEBrand.kor)
            .padding(.horizontal, 18)
            .padding(.vertical, V3Tokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                    .fill(V3Tokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                            .stroke(V3Tokens.hairline, lineWidth: 1)
                    )
            )
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            heading("Hazırsın.")
            lead("İlk anın seni bekliyor.")
        }
    }

    // MARK: - Text helpers

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(ONEBrand.display(40))
            .tracking(-1.2)
            .foregroundColor(V3Tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func lead(_ text: String) -> some View {
        Text(text)
            .bodyLG()
            .foregroundColor(V3Tokens.mutedText)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: { current == nil ? finish() : next() }) {
                Text(primaryLabel)
                    .displayXS()
                    .foregroundColor(V3Tokens.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Capsule(style: .continuous).fill(canProceed ? V3Tokens.ink : V3Tokens.hairline))
            }
            .buttonStyle(.onePressable)
            .disabled(!canProceed)

            if pos > 0 && current != nil {
                Button(action: { back() }) {
                    Text("Geri")
                        .bodyMDMedium()
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.vertical, 10)
                }
                .contentShape(Rectangle())
                .buttonStyle(.onePressable)
            }
        }
    }

    private var primaryLabel: String {
        if current == nil { return "Başla" }
        if current == .notif { return "Bitir" }
        return "Devam"
    }

    private var canProceed: Bool {
        switch current {
        case .intent: return selectedIntent != nil
        case .mood:   return selectedMood != nil
        default:      return true
        }
    }

    // MARK: - Actions

    private func next() {
        withAnimation(ONEAnimation.easing) { pos += 1 }
        if current == .notif { /* Notif izni izin butonuna bağlı, otomatik değil */ }
    }

    private func back() {
        withAnimation(ONEAnimation.easing) { pos = max(0, pos - 1) }
    }

    private func finish() {
        // Önizleme: akışı gezdik, hiçbir şey yazmıyoruz.
        guard !isPreview else {
            isCompleted = true
            return
        }

        // 1) Kalıcı onboarding kayıtları — Profil / istatistik ekranları bunu okur.
        OnboardingRecord.intent = selectedIntent
        OnboardingRecord.firstMoodHex = selectedMood?.hex
        OnboardingRecord.completedAt = Date()

        // 2) Seçilen ilk mood → gerçek Moment olarak kaydedilir. Böylece
        //    kullanıcı "ilk kare" ödülünü gördüğünde arşiv de aynı kareyi taşır.
        //
        // `MomentWriter` üzerinden yazılıyor. Eskiden burada doğrudan
        // `insertNewMoment` + `context.save()` vardı — satır diske iniyordu
        // ama **yan etkilerin hiçbiri çalışmıyordu**. Kullanıcının ilk anı
        // özellikle bunlara muhtaç:
        //   • widget onboarding'den sonra boş kalıyordu
        //   • bugünün hatırlatması iptal edilmiyordu — kullanıcı renk
        //     seçtikten saatler sonra "bugün nasılsın?" bildirimi alıyordu
        //   • Echo önbelleği ve arşiv tazeleme sinyali hiç gitmiyordu
        //   • ilk mood analitiğe hiç düşmüyordu
        //
        // Yazma yolu tek olsun diye bu tip var; onu atlayan her yol
        // yan etkilerden birini unutuyor.
        if let mood = selectedMood {
            MomentWriter.write(mood: mood, scope: .private, context: context)
        }

        // 3) Hatırlatma tercihi → V3ReminderSettings (persist edilir + schedule).
        var settings = V3ReminderSettings.load()
        settings.enabled = reminderOn
        settings.save()
        if reminderOn {
            // İzin verildikten *sonra* planlama gerekiyor: `MomentWriter` bir
            // adım önce planladı ama o sırada bildirim izni henüz yoktu.
            //
            // `yesterdayMood` olarak az önce seçilen mood geçiliyor. Eskiden
            // burada `nil` yazıyordu ve bu, bir adım önce doğru mood'la
            // kurulan planı **eziyordu** — ertesi günün "meraklı" hatırlatması
            // dünü anamıyor, jenerik metne düşüyordu. Tam da onboarding'den
            // gelen kullanıcıda, yani hatırlatmanın en çok işe yaradığı yerde.
            let firstMood = selectedMood
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        V3ReminderScheduler.reschedule(yesterdayMood: firstMood)
                    }
                }
            }
        }

        KeychainHelper.set(true, forKey: "hasCompletedOnboarding")
        isCompleted = true
    }
}
