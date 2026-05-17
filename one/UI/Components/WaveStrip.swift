//
//  WaveStrip.swift
//  One - Günlük Mood
//

import SwiftUI

struct WaveStrip: View {
    let summary: MonthSummary
    @Binding var selectedWaveIdx: Int?
    
    var body: some View {
        GeometryReader { geo in
            let orderedDays = summary.orderedDays
            let barWidth = max(2, (geo.size.width - CGFloat(orderedDays.count)) / CGFloat(orderedDays.count))
            
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(orderedDays.enumerated()), id: \.offset) { idx, date in
                    if let date, let entry = summary.primaryEntry(for: date) {
                        // Filled day bar with mood color
                        if let mood = ONEMood(hex: entry.moodColorHex) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(mood.color
                                    .opacity(selectedWaveIdx == idx ? 1.0 : 0.72))
                                .frame(width: barWidth, height: mood.waveHeight)
                                .onTapGesture {
                                    selectedWaveIdx = idx
                                }
                                .accessibilityElement()
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(Self.accessibilityLabel(for: date, mood: mood))
                                .accessibilityHint(NSLocalizedString("wavestrip.bar.hint", comment: "Günün detayını aç"))
                        } else {
                            // Fallback for unknown mood colors
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: entry.moodColorHex)
                                    .opacity(selectedWaveIdx == idx ? 1.0 : 0.72))
                                .frame(width: barWidth, height: 12)
                                .onTapGesture {
                                    selectedWaveIdx = idx
                                }
                                .accessibilityElement()
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(Self.accessibilityLabel(for: date, mood: nil))
                                .accessibilityHint(NSLocalizedString("wavestrip.bar.hint", comment: "Günün detayını aç"))
                        }
                    } else {
                        // Empty day bar — non-interactive; only label, no .isButton, no hint
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ONETokens.oneCreamMid.opacity(0.6))
                            .frame(width: barWidth, height: 4)
                            .accessibilityElement()
                            .accessibilityLabel(Self.accessibilityLabel(for: date, mood: nil))
                    }
                }
            }
            .frame(maxHeight: 32, alignment: .center)
        }
        .frame(height: 32)
    }
    
    /// Builds the VoiceOver label for a wave bar.
    /// - Format (filled): `"<day>. gün — <mood.label>"`
    /// - Format (empty / unknown mood): `"<day>. gün — kayıt yok"`
    /// - Parameters:
    ///   - date: The date represented by the bar, or `nil` for placeholder slots.
    ///   - mood: The resolved `ONEMood` for the bar, or `nil` when no entry / unknown hex.
    /// - Returns: Localized-friendly Turkish label used by VoiceOver.
    ///
    /// Exposed at `internal` (type-level) so tests can validate the label contract
    /// without constructing the surrounding SwiftUI view. Not part of the public API
    /// surface of `WaveStrip`; callers outside the test target should still rely on
    /// the view's `.accessibilityLabel` modifier output rather than invoking this
    /// helper directly.
    static func accessibilityLabel(for date: Date?, mood: ONEMood?) -> String {
        let day = date.map { Calendar.current.component(.day, from: $0) } ?? 0
        if let mood {
            return "\(day). gün — \(mood.label)"
        } else {
            return "\(day). gün — kayıt yok"
        }
    }
}
