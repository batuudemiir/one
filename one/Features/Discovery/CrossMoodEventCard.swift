//  CrossMoodEventCard.swift
//  one

import SwiftUI

struct CrossMoodEventCard: View {
    let event: MoodEvent
    let moodLabel: String
    let moodColor: Color
    let moodPastel: Color
    let isContrast: Bool

    private var timeOnly: String {
        event.timing.components(separatedBy: " · ").last ?? event.timing
    }

    var body: some View {
        Button {
            ONEHaptics.feelingSelected()
            AppAnalytics.shared.track(.eventTapped(category: event.category.rawValue))
            if let url = event.sourceURL, url.scheme == "https" {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(moodColor)
                        .frame(width: 6, height: 6)
                    Text(moodLabel.lowercased())
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(moodColor)
                    if isContrast {
                        Spacer()
                        Text("farklı his")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(moodColor.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(moodPastel)

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !event.venue.isEmpty {
                        Text(event.venue)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(ONETokens.oneAsh)
                            .lineLimit(1)
                    }

                    if !timeOnly.isEmpty {
                        Text(timeOnly)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(ONETokens.oneStone)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ONETokens.onePaper)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(moodPastel, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 220)
        .accessibilityLabel("\(moodLabel): \(event.title), \(event.venue)")
    }
}
