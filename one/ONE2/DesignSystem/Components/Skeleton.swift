//
//  Skeleton.swift
//  ONE 2.0
//
//  Yükleniyor durumu (components/States.md): `raised` iskelet çubukları,
//  gerçek yerleşimde; spinner ve shimmer yok. Hafif opaklık nefesi;
//  Reduce Motion'da sabit. VoiceOver "Yükleniyor" okur. 300 ms'den kısa
//  yüklemelerde hiç görünmez (07 §6).
//

import SwiftUI

/// Tek iskelet çubuğu; `width` nil ise satırı doldurur.
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = ONE2Size.skeletonLine

    var body: some View {
        Capsule()
            .fill(ONE2Color.raised)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// İskelet grubu: içeriği nefes alır ve tek bir erişilebilirlik öğesidir.
struct Skeleton<Content: View>: View {
    static var showDelayMS: Int { 300 }
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false
    /// 07 §6: 300 ms'den kısa yüklemelerde iskelet görünmez.
    @State private var isShown = false

    var body: some View {
        content()
            .opacity(isShown ? (dimmed ? ONE2Motion.breathLowOpacity : 1) : 0)
            .task {
                try? await Task.sleep(for: .milliseconds(Self.showDelayMS))
                isShown = true
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: ONE2Motion.breathDuration).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            .onChange(of: reduceMotion) { _, reduce in
                if reduce { dimmed = false }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(one2String("one2.state.loading")))
    }
}

extension Skeleton where Content == SkeletonLines {
    /// Kart içi metin satırları; son satır kısa.
    init(lines: Int) {
        self.init { SkeletonLines(count: lines) }
    }
}

struct SkeletonLines: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                SkeletonBar()
                    .padding(.trailing, i == count - 1 && count > 1 ? ONE2Space.s14 : 0)
            }
        }
    }
}

#if DEBUG
private struct SkeletonSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.cardGap) {
            Skeleton {
                ONE2Card {
                    VStack(alignment: .leading, spacing: ONE2Space.s3) {
                        SkeletonBar(width: ONE2Size.iconWell * 2, height: ONE2Size.icon)
                        SkeletonLines(count: 3)
                    }
                }
            }
            Skeleton(lines: 2)
        }
    }
}

#Preview("Gece") { SkeletonSamples().one2Preview(.gece) }
#Preview("Gün") { SkeletonSamples().one2Preview(.gun) }
#Preview("AX3") { SkeletonSamples().one2Preview(.ax3) }
#endif
