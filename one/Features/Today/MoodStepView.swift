//
//  MoodStepView.swift
//  one
//

import SwiftUI

struct MoodStepView: View {
    @ObservedObject var coordinator: TodayCoordinator
    @State private var selectedMood: ONEMood?

    private var titleText: String {
        if let mood = selectedMood {
            return "Bu gün \(mood.label)."
        }
        return "Bu gün ne renk?"
    }

    private var subtitleText: String {
        if selectedMood != nil {
            return "Değiştirmek istersen tekrar kaydır."
        }
        return "12 hisle eşleştirdik. Kaydır, en yakın olana dokun."
    }

    var body: some View {
        ZStack {
            if let mood = selectedMood {
                VStack {
                    LinearGradient(
                        colors: [mood.color.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                    Spacer()
                }
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.35), value: selectedMood)
            }

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(titleText)
                            .font(ONETypography.displayMD)
                            .fontWeight(.semibold)
                            .tracking(-0.36)
                            .foregroundStyle(ONETokens.oneVoid)
                            .animation(.easeOut(duration: 0.18), value: selectedMood)
                            .padding(.bottom, 6)

                        Text(subtitleText)
                            .font(ONETypography.bodyXS)
                            .foregroundStyle(ONETokens.oneAsh)
                            .animation(.easeOut(duration: 0.18), value: selectedMood != nil)
                            .padding(.bottom, 32)

                        MoodPicker(selectedMood: $selectedMood)
                            .padding(.bottom, 32)

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: {
                    guard let mood = selectedMood else { return }
                    coordinator.draft.mood = mood
                    coordinator.next()
                }) {
                    Text(selectedMood == nil ? "Birine dokun" : "Devam et")
                        .monoSM(tracking: 1.2)
                        .foregroundStyle(selectedMood == nil ? ONETokens.oneMist : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedMood == nil ? ONETokens.oneSilver : ONETokens.oneVoid)
                        )
                }
                .disabled(selectedMood == nil)
                .animation(.easeOut(duration: 0.18), value: selectedMood != nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

}
