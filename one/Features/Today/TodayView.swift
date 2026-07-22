//
//  TodayView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData
import PhotosUI

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var vm: TodayViewModel
    @Binding var entryStep: Step

    // Streak milestone kutlaması
    @State private var showMilestone:    Bool    = false
    @State private var milestoneScale:   CGFloat = 0.8
    @State private var milestoneOpacity: Double  = 0

    // A4 — İlk entry sonrası Çevre davet kancası
    @State private var showContactsInvite: Bool  = false

    // Faz 3 — telafi: bugün zaten doluyken geçmiş bir günü doldurma sheet'i
    @State private var backfillTarget: BackfillTarget? = nil

    // Kayıt anı — SaveRitualMoment tetikleyicisi
    @State private var showRitual:   Bool    = false
    @State private var ritualMood:   ONEMood? = nil

    // Kayıt sonrası opsiyonel ekler (ritüel 2 adıma indiği için)
    @State private var showExtraPhotoPicker: Bool = false
    @State private var showExtraNoteSheet:   Bool = false
    @State private var extraPhotoItem: PhotosPickerItem? = nil
    @State private var extraNoteText: String = ""

    /// Ritüelin sol üstündeki ✕ — kullanıcıyı geldiği yere (Frekans) döndürür.
    /// nil ise ✕ gizlenir; kapatacak bir yer yoksa ölü bir buton göstermek
    /// yanlış olur.
    var onClose: (() -> Void)? = nil

    init(
        context: NSManagedObjectContext,
        entryStep: Binding<Step>,
        onClose: (() -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: TodayViewModel(context: context))
        _entryStep = entryStep
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Ekranlar arası geçiş
            Group {
                switch vm.todayState {
                case .empty:
                    TodayRitualView(vm: vm, onFinish: onClose)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                case .completed:
                    if let entry = vm.todayEntry {
                        TodayCompletedView(
                            entry: entry,
                            onEdit: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    vm.clearToday()
                                }
                            },
                            streakDays: vm.streakDays,
                            isFreezeActive: vm.streakFreezeUsedRecently,
                            onAddPhoto: { showExtraPhotoPicker = true },
                            onAddNote: { showExtraNoteSheet = true },
                            weekRhythm: vm.weekRhythm,
                            onBackfill: { backfillTarget = BackfillTarget(date: $0) },
                            onReturnToCircle: onClose
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.todayState == .completed)

            // Streak milestone kutlaması
            if showMilestone, let milestone = vm.streakMilestone {
                VStack {
                    Spacer()
                    StreakMilestoneCard(days: milestone)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 130)
                        .scaleEffect(milestoneScale)
                        .opacity(milestoneOpacity)
                        .allowsHitTesting(false)
                }
            }

            // Kayıt anı — tek imza. Eskiden burada üç katman (zemin tint +
            // iki sonar halka + parçacıklar) `CompletionCelebrationView`'ın
            // beş dönüşümlü varyantıyla AYNI ANDA oynuyordu; ikisi birbirini
            // örtüyor, hiçbiri akılda kalmıyordu.
            if showRitual, let mood = ritualMood {
                SaveRitualMoment(mood: mood) {
                    showRitual = false
                    ritualMood = nil
                }
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            if vm.circleShareFailed {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 13, weight: .medium))
                    Text("Çevre paylaşımı başarısız — internet bağlantını kontrol et.")
                        .font(ONETypography.bodyXS)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Button {
                        vm.circleShareFailed = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(ONETokens.oneCream)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#CC3333"))
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 130)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: vm.circleShareFailed)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Çevre paylaşımı başarısız. İnternet bağlantını kontrol et.")
            }
        }
        .onChange(of: vm.todayEntry) { _, newEntry in
            guard let entry = newEntry else { return }
            let mood = ONEMood(hex: entry.moodColorHex)
            triggerRitual(mood: mood)
            // VoiceOver kullanıcısı save ritual'ı görmez — sözel duyuru gerekli.
            UIAccessibility.post(
                notification: .announcement,
                argument: NSLocalizedString("today.moodSaved.a11y", comment: "Mood kaydedildi anonsu")
            )
            // Kayıt tamamlandı — step sıfırla ki tab bar görünsün
            entryStep = .search
        }
        .onChange(of: vm.streakMilestone) { _, milestone in
            guard milestone != nil else { return }
            showMilestone = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
                milestoneScale   = 1.0
                milestoneOpacity = 1.0
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    milestoneOpacity = 0
                    milestoneScale   = 0.92
                }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                showMilestone = false
                vm.clearStreakMilestone()
            }
        }
        .sheet(isPresented: $vm.showFirstEntryInvite) {
            FirstEntryInviteSheet(
                moodColor: vm.todayEntry?.moodColor ?? ONETokens.oneBrand,
                onInvite: {
                    vm.dismissFirstEntryInvite(action: "invite")
                    // Sheet kapandıktan sonra rehber davet ekranını aç
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        showContactsInvite = true
                    }
                },
                onSkip: {
                    vm.dismissFirstEntryInvite(action: "skip")
                }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showContactsInvite) {
            ContactsInviteView()
        }
        // Faz 3 — telafi ritüeli. Bugün dolu olduğu için ana akış
        // TodayCompletedView'da; geçmiş gün burada modal olarak doldurulur.
        .sheet(item: $backfillTarget) { target in
            TodayRitualView(vm: vm, backfillDate: target.date) {
                // Kayıt da vazgeçme de buraya düşer — tek çıkış noktası.
                backfillTarget = nil
            }
            .presentationDetents([.large])
        }
        // ── Kayıt sonrası opsiyonel ekler ──────────────────────────────
        .photosPicker(isPresented: $showExtraPhotoPicker,
                      selection: $extraPhotoItem,
                      matching: .images)
        .onChange(of: extraPhotoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.attachPhotoAndNote(photo: image)
                }
                extraPhotoItem = nil
            }
        }
        .sheet(isPresented: $showExtraNoteSheet) {
            ExtraNoteSheet(text: $extraNoteText) { note in
                vm.attachPhotoAndNote(note: note)
                showExtraNoteSheet = false
            }
            .presentationDetents([.height(300)])
        }
        .alert("Dynamic Island Kapalı", isPresented: $vm.showLiveActivityAlert) {
            Button("Ayarları Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Mood'unu Dynamic Island'da görmek için Ayarlar > ONE > Canlı Etkinlikler'i etkinleştir.")
        }
    }

    /// Kayıt anını tetikler. Koreografinin tamamı `SaveRitualMoment`
    /// içinde — burada yalnız hangi mood'la başlayacağı söyleniyor.
    /// Temizliği de o view kendi bitişinde yapıyor (`onFinished`).
    private func triggerRitual(mood: ONEMood?) {
        // mood çözülemezse (ör. arşivin nötr gri placeholder'ı) ritüel hiç
        // açılmıyor — eskiden burada yalnız `ritualMood` nil kalıyor ama
        // shader yine de başlatılıyordu, yani kapatacak kimse olmadan.
        guard let mood else { return }
        ritualMood = mood
        showRitual = true
    }
}

// MARK: - Streak Milestone Card

struct StreakMilestoneCard: View {
    let days: Int

    private var emoji: String {
        switch days {
        case 3:   return "🌱"
        case 7:   return "🔥"
        case 14:  return "✨"
        case 30:  return "⚡️"
        case 100: return "💎"
        default:  return "🌟"
        }
    }

    private var title: String {
        "\(days) günlük seri!"
    }

    private var subtitle: String {
        switch days {
        case 3:   return "İlk halkayı kapattın. Devam et."
        case 7:   return "Bir haftadır her gün hissediyorsun."
        case 14:  return "İki hafta — ritmin oturdu."
        case 30:  return "Bir ay boyunca hiç bırakmadın."
        case 100: return "100 gün. Bu bir alışkanlık artık."
        default:  return "Bir yıl. Olağanüstü bir bağlılık."
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 32))
                .accessibilityHidden(true) // emoji süs — title zaten gün sayısını söylüyor

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ONETypography.displaySM)
                    .foregroundColor(ONETokens.oneCream)
                Text(subtitle)
                    .font(ONETypography.monoSM)
                    .foregroundColor(ONETokens.oneCream.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ONETokens.oneInk)
                .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    TodayView(context: PersistenceController.preview.container.viewContext, entryStep: .constant(.search))
}

// MARK: - Kayıt sonrası not ekleme

/// Ritüel 2 adıma indiği için not artık akış içinde değil.
/// İsteyen kaydettikten sonra buradan ekliyor.
private struct ExtraNoteSheet: View {
    @Binding var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
            Text("Bugün nasıl hissettirdi?")
                .font(ONETypography.displaySM)
                .fontWeight(.semibold)
                .foregroundStyle(ONETokens.oneVoid)

            TextEditor(text: $text)
                .font(ONETypography.bodySM)
                .foregroundStyle(ONETokens.oneInk)
                .scrollContentBackground(.hidden)
                .padding(ONETokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                        .fill(ONETokens.oneCreamMid)
                )
                .frame(height: 110)
                .focused($focused)

            Button(action: { onSave(text) }) {
                Text("kaydet")
                    .font(ONETypography.bodyMD)
                    .fontWeight(.semibold)
                    .foregroundStyle(ONETokens.oneCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(ONETokens.spacingXL2)
        .background(ONETokens.oneCream)
        .onAppear { focused = true }
    }
}
