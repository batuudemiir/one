//
//  MoodPicker.swift
//  one
//

import SwiftUI

struct MoodPicker: View {
    @Binding var selectedMood: ONEMood?
    @State private var centerIndex: Int = 4
    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartIndex: Int = 4
    private let moods = ONEMood.allCases
    private let spacing: CGFloat = 80

    var body: some View {
        VStack(spacing: 16) {
            Text("\(centerIndex + 1) / \(moods.count)")
                .font(ONETypography.monoLabel)
                .tracking(2.6)
                .foregroundStyle(ONETokens.oneStone)
                .textCase(.uppercase)

            carouselView

            VStack(spacing: 4) {
                Text(moods[centerIndex].label)
                    .font(ONETypography.displaySM)
                    .fontWeight(.semibold)
                    .tracking(-0.3)
                    .foregroundStyle(ONETokens.oneVoid)
                Text(moods[centerIndex].subtitle)
                    .font(ONETypography.bodyXS)
                    .foregroundStyle(ONETokens.oneMist)
            }
            .id(centerIndex)
            .animation(.easeOut(duration: 0.14), value: centerIndex)

            MoodIndicatorDots(current: centerIndex)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood seçici")
        .accessibilityValue("\(moods[centerIndex].label), \(moods[centerIndex].subtitle), \(centerIndex + 1) / \(moods.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                guard centerIndex < moods.count - 1 else { return }
                centerIndex += 1
                scrollOffset = -CGFloat(centerIndex) * spacing
                dragStartIndex = centerIndex
                selectedMood = moods[centerIndex]
                ONEHaptics.tabSwitch()
            case .decrement:
                guard centerIndex > 0 else { return }
                centerIndex -= 1
                scrollOffset = -CGFloat(centerIndex) * spacing
                dragStartIndex = centerIndex
                selectedMood = moods[centerIndex]
                ONEHaptics.tabSwitch()
            @unknown default: break
            }
        }
        .onAppear {
            let initial = 4
            centerIndex = initial
            dragStartIndex = initial
            scrollOffset = -CGFloat(initial) * spacing
            // Do NOT pre-select a mood value — require an intentional swipe/tap.
            // selectedMood stays nil until the user makes a deliberate choice.
        }
    }

    private var carouselView: some View {
        ZStack {
            ForEach(Array(moods.enumerated()), id: \.offset) { index, mood in
                let xPos = CGFloat(index) * spacing + scrollOffset
                let absDistance = abs(index - centerIndex)
                if absDistance <= 4 {
                    MoodCircle(
                        mood: mood,
                        distance: absDistance,
                        isSelected: index == centerIndex
                    )
                    .offset(x: xPos)
                    .animation(
                        .spring(response: 0.22, dampingFraction: 0.82),
                        value: scrollOffset
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .local)
                .onChanged { value in
                    // Follow finger continuously
                    let base = -CGFloat(dragStartIndex) * spacing
                    let raw = base + value.translation.width
                    let minOff = -CGFloat(moods.count - 1) * spacing
                    scrollOffset = max(minOff, min(0, raw))

                    // Haptic + selection when center index changes
                    let computed = Int((-scrollOffset / spacing).rounded())
                    let target = max(0, min(moods.count - 1, computed))
                    if target != centerIndex {
                        centerIndex = target
                        selectedMood = moods[target]
                        ONEHaptics.tabSwitch()
                    }
                }
                .onEnded { _ in
                    // Snap to nearest index
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        scrollOffset = -CGFloat(centerIndex) * spacing
                    }
                    dragStartIndex = centerIndex
                }
        )
    }
}
