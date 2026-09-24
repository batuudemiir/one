//
//  PlaceholderScreens.swift
//  ONE 2.0
//
//  Henüz yazılmamış hedef ekranlar (UX-3). "Yakında" metni yok: gerçek
//  kabukta başlık ve iskelet. Geri / kapat gerçekten çalışır. Sırası gelen
//  adımda (UX-4…UX-10) gerçek ekranla değişir.
//

import SwiftUI

/// Sekme yığınına itilen ekranın yer tutucusu.
struct RoutePlaceholderScreen<Extra: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        ScreenScaffold(title: title) {
            ONE2RoundButton(icon: .back, accessibilityLabel: one2String("one2.action.back"), action: onBack)
        } center: {
            EmptyView()
        } trailing: {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: ONE2Space.sectionGap) {
                PlaceholderSkeleton()
                extra()
            }
        }
    }
}

extension RoutePlaceholderScreen where Extra == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

/// Tam ekran akış ve sheet yer tutucusu.
struct CoverPlaceholderScreen: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        ScreenScaffold(title: title) {
            EmptyView()
        } center: {
            EmptyView()
        } trailing: {
            ONE2RoundButton(icon: .close, accessibilityLabel: one2String("one2.action.close"), action: onClose)
        } content: {
            PlaceholderSkeleton()
        }
    }
}

private struct PlaceholderSkeleton: View {
    var body: some View {
        Skeleton {
            VStack(spacing: ONE2Space.cardGap) {
                ONE2Card { SkeletonLines(count: 3) }
                ONE2Card { SkeletonLines(count: 2) }
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { RoutePlaceholderScreen(title: "ayarlar") {}.preferredColorScheme(.dark) }
#Preview("Gün") { CoverPlaceholderScreen(title: "check-in") {}.preferredColorScheme(.light) }
#Preview("AX3") {
    RoutePlaceholderScreen(title: "haftalık temalar") {}
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
