//
//  TodayView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var vm: TodayViewModel
    @Binding var entryStep: Step

    // Streak milestone kutlaması
    @State private var showMilestone:    Bool    = false
    @State private var milestoneScale:   CGFloat = 0.8
    @State private var milestoneOpacity: Double  = 0

    // A4 — İlk entry sonrası Çevre davet kancası
    @State private var showContactsInvite: Bool  = false

    // Save Ritual — Still Water (3 katman: halka + zemin tint + haptic)
    @State private var showRitual:   Bool    = false
    @State private var ritualMood:   ONEMood? = nil
    @State private var ringScale:    CGFloat = 0
    @State private var ringOpacity:  Double  = 0
    @State private var bgTinted:     Bool    = false
    @State private var ring2Scale:   CGFloat = 0
    @State private var ring2Opacity: Double  = 0
    @State private var showParticles: Bool   = false
    @State private var particleMood: ONEMood? = nil

    init(context: NSManagedObjectContext, entryStep: Binding<Step>) {
        _vm = StateObject(wrappedValue: TodayViewModel(context: context))
        _entryStep = entryStep
    }

    var body: some View {
        ZStack {
            // Ekranlar arası geçiş
            Group {
                switch vm.todayState {
                case .empty:
                    TodayEmptyView(vm: vm, currentStep: $entryStep)
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
                            isFreezeActive: vm.streakFreezeUsedRecently
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

            // Save Ritual — Still Water (3 katman: zemin tint + sonar halka + haptic)
            if showRitual, let mood = ritualMood {
                ZStack {
                    // Katman 1: pastel zemin tint
                    mood.pastelColor.opacity(bgTinted ? 0.06 : 0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 1.1), value: bgTinted)

                    // Katman 2: sonar halka — merkezden dışa genişler, söner
                    GeometryReader { geo in
                        let maxDim = max(geo.size.width, geo.size.height)
                        Circle()
                            .stroke(mood.pastelColor, lineWidth: 1.2)
                            .frame(width: maxDim * 2.6, height: maxDim * 2.6)
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .allowsHitTesting(false)

                        // Katman 3: İkinci sonar halka (pastel, gecikmeli)
                        Circle()
                            .stroke(mood.pastelColor, lineWidth: 0.8)
                            .frame(width: maxDim * 2.6, height: maxDim * 2.6)
                            .scaleEffect(ring2Scale)
                            .opacity(ring2Opacity)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            if showRitual && showParticles, let pm = particleMood {
                MoodParticleView(mood: pm, triggered: $showParticles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .ignoresSafeArea()
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

    // swiftlint:disable function_body_length
    // Still Water ritual — tüm mood'lar için tek rafine akış.
    // Reduce Motion: halka atlanır, yalnız zemin tint + haptic.
    private func triggerRitual(mood: ONEMood?) {
        ringScale = 0; ringOpacity = 0; bgTinted = false
        ring2Scale = 0; ring2Opacity = 0; showParticles = false; particleMood = mood
        ritualMood = mood
        showRitual = true
        ONEHaptics.saveRitual(mood: mood)

        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 1.1)) { bgTinted = true }
            scheduleCleanup(after: 1.35)
            return
        }

        withAnimation(.easeOut(duration: 0.65)) { ringScale = 1.0; ringOpacity = 0.22 }
        withAnimation(.easeIn(duration: 0.25).delay(0.40)) { ringOpacity = 0 }
        withAnimation(.easeInOut(duration: 1.1)) { bgTinted = true }

        // İkinci sonar halka
        withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
            ring2Scale = 1.0; ring2Opacity = 0.18
        }
        withAnimation(.easeIn(duration: 0.30).delay(0.55)) {
            ring2Opacity = 0
        }

        // Particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showParticles = true
        }

        // Peak haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            ONEHaptics.saveRitualPeak()
        }

        scheduleCleanup(after: 2.6)
    }

    private func scheduleCleanup(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.35)) {
                bgTinted   = false
                showRitual = false
            }
            // Particle view'ı fade-out animasyonu bittikten sonra temizle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                ritualMood = nil
                ring2Scale = 0
                ring2Opacity = 0
                showParticles = false
                particleMood = nil
            }
        }
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
