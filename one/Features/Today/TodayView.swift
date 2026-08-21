//
//  TodayView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData
import PhotosUI

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var vm: TodayViewModel


    // A4 — İlk entry sonrası Çevre davet kancası
    @State private var showContactsInvite: Bool  = false

    // Kayıt anı — SaveRitualMoment tetikleyicisi
    @State private var showRitual:   Bool    = false
    @State private var ritualMood:   V3Mood? = nil

    // Kayıt sonrası opsiyonel ekler (ritüel 2 adıma indiği için)
    @State private var showExtraPhotoPicker: Bool = false
    @State private var showExtraNoteSheet:   Bool = false
    @State private var extraPhotoItem: PhotosPickerItem? = nil
    @State private var extraNoteText: String = ""

    /// Ritüelin sol üstündeki ✕ — kullanıcıyı geldiği yere (Çevre) döndürür.
    /// nil ise ✕ gizlenir; kapatacak bir yer yoksa ölü bir buton göstermek
    /// yanlış olur.
    var onClose: (() -> Void)? = nil

    init(
        context: NSManagedObjectContext,
        onClose: (() -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: TodayViewModel(context: context))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Ekranlar arası geçiş
            Group {
                // v3 tek ekran akışı — hem boş hem dolu gün V3EntryContainer'a
                // gider. Container mevcut kayıt varsa doğrudan Step 2'yi açar,
                // yoksa Step 0'dan başlar. Handoff kuralı: uygulama tek şey
                // yapar — "Bugün nasılsın?".
                V3EntryContainer(vm: vm, onArchive: onClose)
                    .transition(.opacity)
            }
            .animation(ONEAnimation.screenTransition, value: vm.todayState == .completed)

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

            // Cached-mood echo — dimmed placeholder that fills the first frame
            // while the initial CoreData fetch runs. Fades out the moment the
            // ViewModel hydrates. First-run (no cached mood) falls through to
            // whatever `todayState` renders normally.
            if !vm.hasHydratedTodayEntry, let echo = vm.cachedEchoMood {
                TodayEchoPlaceholder(hex: echo.hex, label: echo.label)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        // Reduce Motion → instant swap; otherwise a soft 0.25s ease-out.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25),
                   value: vm.hasHydratedTodayEntry)
        .overlay(alignment: .bottom) {
            if vm.circleShareFailed {
                HStack(spacing: V3Tokens.spacingSM) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 13, weight: .medium))
                    Text(NSLocalizedString("circle.shareFailed", comment: ""))
                        .font(V3Typography.sans(13, relativeTo: .footnote))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Button {
                        vm.circleShareFailed = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(ONEBrand.bone)
                .padding(.horizontal, V3Tokens.spacingLG)
                .padding(.vertical, V3Tokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                        .fill(Color(hex: "#CC3333"))
                )
                .padding(.horizontal, V3Tokens.spacingXL2)
                .padding(.bottom, 130)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(ONEAnimation.panelSpring, value: vm.circleShareFailed)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Çevre paylaşımı başarısız. İnternet bağlantını kontrol et.")
            }
        }
        .onChange(of: vm.todayEntry) { _, newEntry in
            guard let entry = newEntry else { return }
            // Skip the ritual on the initial hydration transition (nil → cached
            // entry). We only want it firing in response to an actual save.
            // `hasHydratedTodayEntry` is set on the same tick the initial fetch
            // publishes, so any later change is a real save.
            guard vm.hasHydratedTodayEntry else { return }
            // `closest(toHex:)` — tam eşleşme yoksa en yakın v3 rengine düşer.
            // Eskiden `ONEMood(hex:)` idi ve kayıt yolu `V3Mood`'la yazdığı için
            // aynı an iki farklı mood uzayında çözülüyordu.
            triggerRitual(mood: V3Mood.closest(toHex: entry.moodColorHex))
            // VoiceOver kullanıcısı save ritual'ı görmez — sözel duyuru gerekli.
            UIAccessibility.post(
                notification: .announcement,
                argument: NSLocalizedString("today.moodSaved.a11y", comment: "Mood kaydedildi anonsu")
            )
        }
        .sheet(isPresented: $vm.showFirstEntryInvite) {
            FirstEntryInviteSheet(
                moodColor: vm.todayEntry?.moodColor ?? ONEBrand.kor,
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
            .v3Sheet(detents: [.large])
        }
        .sheet(isPresented: $showContactsInvite) {
            ContactsInviteView()
        }
        .v3Sheet()
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
            .v3Sheet(detents: [.height(300)])
        }
        .alert("Dynamic Island Kapalı", isPresented: $vm.showLiveActivityAlert) {
            Button("Ayarları Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(NSLocalizedString("liveActivity.enableHint", comment: ""))
        }
    }

    /// Kayıt anını tetikler. Koreografinin tamamı `SaveRitualMoment`
    /// içinde — burada yalnız hangi mood'la başlayacağı söyleniyor.
    /// Temizliği de o view kendi bitişinde yapıyor (`onFinished`).
    private func triggerRitual(mood: V3Mood?) {
        // mood çözülemezse (ör. arşivin nötr gri placeholder'ı) ritüel hiç
        // açılmıyor — eskiden burada yalnız `ritualMood` nil kalıyor ama
        // shader yine de başlatılıyordu, yani kapatacak kimse olmadan.
        guard let mood else { return }
        ritualMood = mood
        showRitual = true
    }
}


// MARK: - Echo placeholder

/// Softened silhouette of the last recorded mood. Rendered instantly from
/// UserDefaults so the first frame isn't an empty cream field while the
/// initial CoreData fetch runs. Cross-fades out on hydration.
///
/// Deliberately minimal — no interactive elements, no fetches, no timers.
/// Matches the resting layout of `TodayCompletedView` / `TodayEmptyView`
/// (cream background, mood tint) so the transition to real UI is a fade,
/// not a jump cut.
private struct TodayEchoPlaceholder: View {
    let hex: String
    let label: String

    private var moodColor: Color { Color(hex: hex) }

    var body: some View {
        ZStack {
            V3Tokens.paper
                .ignoresSafeArea()

            // Gentle color wash — echoes the mood without asserting it.
            moodColor
                .opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("ONE")
                    .font(V3Typography.display(40))
                    .foregroundColor(V3Tokens.ink)

                Circle()
                    .fill(moodColor)
                    .frame(width: 96, height: 96)
                    .blur(radius: 8)

                Text(label)
                    .font(V3Typography.mono(11, weight: .medium))
                    .foregroundColor(V3Tokens.ink)
            }
            .opacity(0.35)
        }
    }
}

#Preview {
    TodayView(context: PersistenceController.preview.container.viewContext)
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
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            Text(NSLocalizedString("today.howDidItFeel", comment: ""))
                .font(V3Typography.display(20, relativeTo: .title3))
                .fontWeight(.semibold)
                .foregroundStyle(V3Tokens.darkGround)

            TextEditor(text: $text)
                .font(V3Typography.sans(14, relativeTo: .subheadline))
                .foregroundStyle(V3Tokens.ink)
                .scrollContentBackground(.hidden)
                .padding(V3Tokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .fill(V3Tokens.surface)
                )
                .frame(height: 110)
                .focused($focused)

            Button(action: { onSave(text) }) {
                Text("kaydet")
                    .font(V3Typography.sans(15, relativeTo: .callout))
                    .fontWeight(.semibold)
                    .foregroundStyle(ONEBrand.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(V3Tokens.spacingXL2)
        .background(V3Tokens.paper)
        .onAppear { focused = true }
    }
}
