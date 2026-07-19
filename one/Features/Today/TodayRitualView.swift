//
//  TodayRitualView.swift
//  one
//

import SwiftUI

struct TodayRitualView: View {
    @ObservedObject var vm: TodayViewModel
    @StateObject private var coordinator: TodayCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - backfillDate: verilirse ritüel doğrudan o geçmiş gün için telafi
    ///     modunda açılır (bugün zaten doluyken kullanılır).
    ///   - onFinish: telafi oturumu bitince (kayıt ya da vazgeçme) çağrılır.
    ///     Sheet olarak sunulduğunda kapanmayı bu tetikler.
    init(vm: TodayViewModel, backfillDate: Date? = nil, onFinish: (() -> Void)? = nil) {
        self.vm = vm
        let coordinator = TodayCoordinator(vm: vm)
        coordinator.backfillDate = backfillDate
        coordinator.onFinish = onFinish
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ONETokens.oneCream.ignoresSafeArea()

            Group {
                switch coordinator.step {
                case .mood:
                    MoodStepView(coordinator: coordinator)
                        .transition(stepTransition(insertion: .trailing, removal: .leading))
                case .song:
                    SongStepView(coordinator: coordinator, vm: vm)
                        .transition(stepTransition(insertion: .trailing, removal: .leading))
                }
            }
            .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: coordinator.step)
        }
        // Top bar pinned as overlay — independent of scroll content
        .overlay(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                // Prototipteki `.rit-top`: solda çıkış/geri, ortada adım
                // noktaları, sağda "1 / 2". Sayaç noktaların yanında dursun
                // ki kaç adım kaldığı tahmin edilmesin.
                HStack {
                    Button {
                        if coordinator.step.rawValue > 0 {
                            coordinator.back()
                        } else {
                            coordinator.onFinish?()
                        }
                    } label: {
                        Image(systemName: coordinator.step.rawValue > 0 ? "chevron.left" : "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(coordinator.step.rawValue > 0 ? "Geri" : "Kapat")

                    Spacer()

                    RitualProgressDots(
                        current: coordinator.step.rawValue,
                        total: RitualStep.allCases.count
                    )

                    Spacer()

                    Text("\(coordinator.step.rawValue + 1) / \(RitualStep.allCases.count)")
                        .monoLabel(tracking: 1.3)
                        .foregroundColor(ONETokens.oneStone)
                        .frame(width: 44, alignment: .trailing)
                }

                // Faz 3 — telafi modunda hangi günü doldurduğun net olsun.
                if let date = coordinator.backfillDate {
                    backfillBanner(date)
                        .transition(.opacity)
                } else if coordinator.step == .mood {
                    // Haftalık ritim yalnız ilk adımda — şarkı adımı sade kalsın.
                    WeekRhythmView(days: vm.weekRhythm) { date in
                        coordinator.startBackfill(for: date)
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }

                if let items = topBarContextItems {
                    ContextPill(items: items) { coordinator.jumpTo($0) }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeOut(duration: 0.18), value: items.count)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(ONETokens.oneCream)
        }
        .gesture(
            coordinator.step.rawValue > 0
                ? DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { v in
                        if v.translation.width > 60 && abs(v.translation.height) < abs(v.translation.width) {
                            coordinator.back()
                        }
                    }
                : nil
        )
        .onAppear { coordinator.vm = vm } // Ensures vm reference stays fresh on re-appear
    }

    /// Telafi modu göstergesi — suçlayıcı değil, bilgilendirici.
    /// "Kaçırdın" demez; hangi günü doldurduğunu söyler ve çıkış yolu bırakır.
    private func backfillBanner(_ date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ONETokens.oneAsh)

            Text("\(weekdayName(date)) gününü dolduruyorsun")
                .bodyXS()
                .foregroundColor(ONETokens.oneInk)

            Spacer(minLength: 0)

            Button {
                coordinator.cancelBackfill()
            } label: {
                Text("vazgeç")
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(ONETokens.oneAsh)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ONETokens.oneCreamMid.opacity(0.55))
        )
        .accessibilityElement(children: .combine)
    }

    private func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private var topBarContextItems: [PillItem]? {
        var items: [PillItem] = []
        if let mood = coordinator.draft.mood { items.append(.mood(mood)) }
        if let song = coordinator.draft.song { items.append(.song(song)) }
        return items.isEmpty ? nil : items
    }

    private func stepTransition(insertion: Edge, removal: Edge) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: insertion).combined(with: .opacity),
                removal: .move(edge: removal).combined(with: .opacity)
            )
    }
}
