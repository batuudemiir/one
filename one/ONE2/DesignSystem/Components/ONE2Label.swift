//
//  ONE2Label.swift
//  ONE 2.0
//
//  Mono bölüm etiketi ve rozet yazısı (`label`): büyük harf, 0.2em. Metin
//  Türkçe kurala göre büyütülür ("GENEL İÇGÖRÜLER"); çağıran küçük harf
//  verebilir. VoiceOver metni büyütülmemiş hâliyle okur.
//

import SwiftUI

struct ONE2Label: View {
    let text: String
    var color: Color = ONE2Color.inkMuted

    init(_ text: String, color: Color = ONE2Color.inkMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(ONE2Type.uppercased(text))
            .one2Type(.label)
            .foregroundStyle(color)
            .accessibilityLabel(Text(text))
    }
}

#if DEBUG
private struct LabelSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            ONE2Label("genel içgörüler")
            ONE2Label("haftalık tema · 3/7")
            ONE2Label("yeni", color: ONE2Color.ink)
        }
    }
}

#Preview("Gece") { LabelSamples().one2Preview(.gece) }
#Preview("Gün") { LabelSamples().one2Preview(.gun) }
#Preview("AX3") { LabelSamples().one2Preview(.ax3) }
#endif
