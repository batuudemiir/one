//
//  TimeStamp.swift
//  ONE 2.0
//
//  Mono saat (`time`): kart sağ üstü, tabular rakam, ink-faint. Saat 24
//  saat biçiminde; takvim ve saat dilimi çağırandan (AppClock) gelir.
//

import SwiftUI

struct TimeStamp: View {
    let date: Date
    var calendar: Calendar = .current

    private var text: String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    var body: some View {
        Text(verbatim: text)
            .one2Type(.time)
            .foregroundStyle(ONE2Color.inkFaint)
    }
}

#if DEBUG
private struct TimeStampSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            TimeStamp(date: Date(timeIntervalSince1970: 0), calendar: .init(identifier: .gregorian))
            TimeStamp(date: .now)
        }
    }
}

#Preview("Gece") { TimeStampSamples().one2Preview(.gece) }
#Preview("Gün") { TimeStampSamples().one2Preview(.gun) }
#Preview("AX3") { TimeStampSamples().one2Preview(.ax3) }
#endif
