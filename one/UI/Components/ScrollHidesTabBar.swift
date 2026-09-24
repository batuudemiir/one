//
//  ScrollHidesTabBar.swift
//  one
//
//  Instagram/Threads pattern: aşağı kaydırınca alt gezinme küçülür, yukarı
//  kaydırınca / en üste dönünce restore. `GlobalUIState.scrollMinimizesBar`
//  üzerinden `BottomNavigation`'a bağlanır.
//
//  Neden PreferenceKey (iOS 18'in `onScrollGeometryChange`'i değil):
//  target iOS 17. GeometryReader + PreferenceKey her frame değeri yayınlıyor
//  ama biz sadece delta > threshold olunca state yazıyoruz — CPU sessiz.
//
//  Reduce Motion açıkken hiç minimize etmiyoruz. Bu bir *ambient* motion —
//  işlevsel değil, kapatılmalı.
//

import SwiftUI

// MARK: - Preference key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Public modifier

extension View {
    /// Bu ScrollView'ı aşağı kaydırdıkça `GlobalUIState.scrollMinimizesBar`
    /// true olur, yukarı kaydırınca / en üste dönünce false.
    ///
    /// - Parameter tab: Bu scroll hangi sekmeye ait. `\.currentPrimaryTab`
    ///   env değeri ile karşılaştırılır — pasif sekmenin scroll olayları
    ///   global bayrağı bozmaz (TabView(.page) komşuları canlı tutar).
    /// - Parameter spaceName: Coord space adı (tab başına benzersiz).
    func hidesTabBarOnScroll(tab: PrimaryTab, spaceName: String) -> some View {
        modifier(ScrollHidesTabBarModifier(tab: tab, spaceName: spaceName))
    }
}

// MARK: - Modifier

private struct ScrollHidesTabBarModifier: ViewModifier {
    let tab: PrimaryTab
    let spaceName: String

    @Environment(\.currentPrimaryTab) private var currentTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastOffset: CGFloat = 0
    @State private var hasBaseline: Bool = false

    /// Sürtünme eşiği. Küçük parmak titreşimleri (safe-area rubber-band, tek
    /// dokunuşta 1-2pt drift) minimize'ı tetiklemesin. 12pt — bir satırlık
    /// hareket kadar.
    private let deltaThreshold: CGFloat = 12
    /// Bu eşiğin altındaki offset'te (en üste yakınken) **her zaman** restore.
    /// Rubber-band ile hafif yukarı gidildiğinde minimize'da takılı kalmasın.
    private let topRestoreThreshold: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: spaceName)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                handle(offset: offset)
            }
            .onChange(of: currentTab) { _, newTab in
                // Sekme dışına çıkılınca baseline sıfırla — geri dönüşte
                // yeni scroll pozisyonundan başlasın, eski delta ile
                // yanıltıcı bir tetikleme olmasın. Ayrıca scroll bayrağı
                // pasif sekmede takılı kalmasın.
                if newTab != tab {
                    hasBaseline = false
                    if GlobalUIState.shared.scrollMinimizesBar {
                        GlobalUIState.shared.scrollMinimizesBar = false
                    }
                }
            }
    }

    private func handle(offset: CGFloat) {
        // Pasif sekme yazmıyor.
        guard currentTab == tab else { return }
        // Reduce Motion — davranış tamamen kapalı.
        guard !reduceMotion else {
            resetIfNeeded()
            return
        }

        // İlk kare — baseline kur, tetikleme.
        guard hasBaseline else {
            lastOffset = offset
            hasBaseline = true
            return
        }

        let delta = offset - lastOffset

        // En üste yakınsak (rubber-band dahil) daima restore.
        if offset >= -topRestoreThreshold {
            setMinimized(false)
            lastOffset = offset
            return
        }

        // Küçük hareketleri yut — flicker yaratmasın.
        guard abs(delta) >= deltaThreshold else { return }

        // Negatif delta = content yukarı gitti = kullanıcı aşağı kaydırıyor.
        setMinimized(delta < 0)
        lastOffset = offset
    }

    private func setMinimized(_ value: Bool) {
        guard GlobalUIState.shared.scrollMinimizesBar != value else { return }
        withAnimation(ONEAnimation.easingColor) {
            GlobalUIState.shared.scrollMinimizesBar = value
        }
    }

    private func resetIfNeeded() {
        guard GlobalUIState.shared.scrollMinimizesBar else { return }
        GlobalUIState.shared.scrollMinimizesBar = false
    }
}

// MARK: - Content-side observer

extension View {
    /// Scroll içeriğinin **en üstüne** yakın koyulacak invisible sensor.
    /// `hidesTabBarOnScroll(...)` ile aynı `spaceName`'i kullanır.
    ///
    /// Neden ayrı: PreferenceKey değerinin *değişmesi* için sensor scrollable
    /// content'in içinde olmalı; ScrollView'ın background'ında değil (o sabit).
    func scrollOffsetSensor(spaceName: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named(spaceName)).minY
                )
            }
        )
    }
}

// MARK: - Üst çubuk ilerlemesi

extension View {
    /// Aynı scroll'un offset'ini `V3TopBar`'ın 0→1 ilerlemesine çevirir.
    ///
    /// `hidesTabBarOnScroll(...)` ile **aynı** `spaceName`'i kullanır ve aynı
    /// `ScrollOffsetPreferenceKey`'i dinler — ikinci bir sensöre gerek yok,
    /// `scrollOffsetSensor` zaten içerikte duruyor.
    ///
    /// Değer 1/8'lik basamaklara yuvarlanıyor. Ham offset her karede değişir;
    /// yuvarlamadan bağlansaydı çubuk (ve onu barındıran ekran) scroll boyunca
    /// her karede yeniden çizilirdi. Sekiz basamak, 0.18s'lik bir sönümleme
    /// için gözle ayırt edilemeyecek kadar ince.
    ///
    /// - Parameter threshold: kaç pt kaydırınca zemin tamamen açılsın.
    func topBarProgress(
        _ progress: Binding<CGFloat>,
        spaceName: String,
        threshold: CGFloat = 28
    ) -> some View {
        coordinateSpace(name: spaceName)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let scrolled = max(0, -offset)
                let raw = min(1, scrolled / threshold)
                let stepped = (raw * 8).rounded() / 8
                if progress.wrappedValue != stepped {
                    progress.wrappedValue = stepped
                }
            }
    }
}
