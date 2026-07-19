//
//  TodayRitualView.swift
//  one
//

import SwiftUI

struct TodayRitualView: View {
    @ObservedObject var vm: TodayViewModel
    @StateObject private var coordinator: TodayCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(vm: TodayViewModel) {
        self.vm = vm
        _coordinator = StateObject(wrappedValue: TodayCoordinator(vm: vm))
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
                RitualProgressDots(current: coordinator.step.rawValue, total: RitualStep.allCases.count)
                    .frame(maxWidth: .infinity)

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
