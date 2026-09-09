//
//  BottomNavigation.swift
//  one
//
//  v3 alt gezinme — yüzen Liquid Glass kapsül.
//
//  - 4 sekme: An · Arşiv · Çevre · Profil (`PrimaryTab.allCases`)
//  - Aktif: ink metin + 18×5 kor nokta üstte.
//  - Pasif: faint metin + 5×5 line nokta üstte.
//  - **Malzeme:** iOS 26'da native `.glassEffect(.clear)`, altında
//    `.ultraThinMaterial` (`liquidGlassBackground`). `.regular` varyantı kağıt
//    zeminde ten rengi bir plakaya dönüşüyordu — `.clear` arkayı olduğu gibi
//    geçiriyor, sadece hafif bir kırınım bırakıyor.
//  - **Drag-to-select:** parmağını çubuk üzerinde gezdirdikçe seçim takip eder;
//    her sekme sınırında bir haptic. Kaldırınca parmağın altındaki sekme kalır.
//    Tek dokunuş yolu (Button) bozulmadan duruyor.
//  - Kenar payı 14pt (minimize'da 96pt), alt pay 4pt.
//  - `minimized` — An akışı adım 2 (not yazarken) kısaltır: kenar 14→96,
//    yükseklik 52→38.
//  - Reduce Transparency açıkken düz `surface` yüzeyine düşer — cam yok.
//

import SwiftUI
import Combine

struct BottomNavigation: View {
    @Binding var currentScreen: ScreenType
    @StateObject private var globalUI = GlobalUIState.shared

    /// Çevre sekmesindeki kor nokta — bugün görülmemiş paylaşım sayısı.
    ///
    /// Eskiden `@StateObject private var cloudKitManager = CloudKitManager.shared`
    /// vardı. Bu, çubuğu manager'ın **dokuz** `@Published` alanının tamamına
    /// abone ediyordu; oysa kullanılan tek şey bu sayı. `syncStatus` ya da
    /// `isFetchingUser` her değiştiğinde — yani her CloudKit turunda — cam
    /// kapsül, gölge ve dört pill yeniden çiziliyordu. Çubuk her ekranda
    /// duruyor, yani bu bedel her yerde ödeniyordu.
    ///
    /// Tek alana abone olmak aynı sonucu veriyor, gereksiz çizimi kesiyor.
    @State private var unseenFriendShareCount: Int = CloudKitManager.shared.unseenFriendShareCount

    /// v3 spec: çubuk üç kaynaktan biri isteyince daralır:
    ///  - `tabBarMinimized` — An akışı (V3EntryContainer, kabuğun currentScreen reset'i)
    ///  - `scrollMinimizesBar` — Arşiv/Çevre/Profil scroll'unda ambient küçülme
    ///  - `focusedContentMinimizes` — gün detayı, Echo poster gibi odaklı içerik
    /// Üçü OR'lanır. Explicit override (preview/test) hepsini ezer.
    var minimizedOverride: Bool? = nil
    private var minimized: Bool {
        minimizedOverride ?? (
            globalUI.tabBarMinimized
            || globalUI.scrollMinimizesBar
            || globalUI.focusedContentMinimizes
        )
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Çubuğun ölçülen genişliği — sürükleme x'ini sekme index'ine çevirmek için.
    @State private var barWidth: CGFloat = 0
    /// Bu jestte sürükleyerek seçim yapıldı mı. Parmak kalkınca altındaki
    /// `Button` de tetiklenirse "aynı sekmeye tekrar dokunma" davranışı
    /// (en üste kaydır / yeni an) yanlışlıkla çalışırdı — bayrak onu yutuyor.
    @State private var didDragSelect = false

    /// Sürükleme x'ini çubuğa bağlayan koordinat uzayı adı.
    private static let barSpace = "one.tabbar"

    private var tabs: [PrimaryTab] { PrimaryTab.allCases }

    // Geometry — spec: 14pt normal / 96pt minimized kenar payı.
    // Alt pay 10pt: Instagram'ın yeni Liquid Glass bar'ı gibi home indicator
    // ile arasında hafif bir boşluk bırakıyor — bar "yüzer" görünüyor,
    // safe-area alt kenarına yapışmıyor.
    private var sideInset: CGFloat { minimized ? 96 : 14 }
    private var bottomInset: CGFloat { minimized ? 6 : 10 }

    /// Sekme yüksekliği metinle birlikte ölçekleniyor. Sabit 52pt'de büyük
    /// metin ayarlarında etiketler kapsülün dışına taşıyordu.
    @ScaledMetric(relativeTo: .caption) private var baseTabHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var minimizedTabHeight: CGFloat = 38
    private var tabHeight: CGFloat { minimized ? minimizedTabHeight : baseTabHeight }

    var body: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            ForEach(tabs, id: \.self) { tab in
                // An sekmesi retap toggle'ı (bugünkü momentlar ↔ bugün
                // nasılsın) VoiceOver kullanıcısı için custom action olarak
                // rotor'dan tetiklenebilir hale geliyor. Ternary'ler
                // type-inference'ı zorluyordu, explicit local'lar.
                let customTitle: String? = tab == .entry ? NSLocalizedString("nav.a11y.showTodayMoments", comment: "") : nil
                let customAction: (() -> Void)? = tab == .entry
                    ? { NotificationCenter.default.post(name: .startNewMomentRequested, object: nil) }
                    : nil
                TabPill(
                    label: tab.title,
                    isSelected: isSelected(tab.screen),
                    height: tabHeight,
                    minimized: minimized,
                    badge: tab == .circle ? unseenFriendShareCount : 0,
                    accessibilityCustomActionTitle: customTitle,
                    onAccessibilityCustomAction: customAction
                ) {
                    // Sürükleyerek seçim bittiğinde parmağın kalktığı yerdeki
                    // Button da tetiklenebiliyor. O dokunuş "tekrar dokunma"
                    // sayılıp en üste kaydırma / yeni an açardı — yut.
                    if didDragSelect { return }

                    let wasOnTab = isSelected(tab.screen)
                    // Sekme değişimi haptiği artık kabukta (`ONEColorPickerView`),
                    // çünkü swipe ile geçişte burası hiç çalışmıyor. Aynı sekmeye
                    // yeniden dokunmak ise sekme değiştirmiyor — o geri bildirimi
                    // burada vermeye devam ediyoruz.
                    if wasOnTab { ONEHaptics.nudge() }
                    withAnimation(ONEAnimation.easingColor) {
                        currentScreen = tab.screen
                    }
                    // Sekmeye tekrar dokunma → o sekmeye özgü akıcı davranış.
                    // Her view kendi bildirimini dinleyip tepkisini kendisi verir.
                    if wasOnTab {
                        switch tab {
                        case .entry:   NotificationCenter.default.post(name: .startNewMomentRequested, object: nil)
                        case .archive: NotificationCenter.default.post(name: .archiveTabRetapped, object: nil)
                        case .circle:  NotificationCenter.default.post(name: .circleTabRetapped, object: nil)
                        case .profile: NotificationCenter.default.post(name: .profileTabRetapped, object: nil)
                        }
                    }
                }
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(barBackground)
        // Genişliği ölç — sürükleme x'ini sekme index'ine bölmek için gerekli.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { barWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in barWidth = new }
            }
        )
        .coordinateSpace(name: Self.barSpace)
        // Tek dokunuş yolu `Button`'larda kalıyor; sürükleme onunla yarışmasın
        // diye `simultaneousGesture` ve 8pt eşik. 8pt'nin altındaki hareket
        // dokunuş sayılır, üstü sürükleme.
        .simultaneousGesture(dragToSelect)
        .padding(.horizontal, sideInset)
        .padding(.bottom, bottomInset)
        .opacity(minimized ? 0.9 : 1)
        .animation(.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.30), value: minimized)
        // Manager'ın tamamına değil, yalnız bu alana abone ol.
        // `receive(on:)` — sayaç CloudKit tamamlama bloklarından set ediliyor
        // ve hepsi main thread'e geçmiyor.
        .onReceive(
            CloudKitManager.shared.$unseenFriendShareCount.receive(on: RunLoop.main)
        ) { count in
            unseenFriendShareCount = count
        }
    }

    // MARK: - Drag to select

    /// Parmağı çubuk üzerinde gezdirdikçe seçim takip eder. Her sekme
    /// sınırında bir haptic; parmak kalkınca altındaki sekme kalır.
    private var dragToSelect: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.barSpace))
            .onChanged { value in
                guard !minimized, let tab = tab(atX: value.location.x) else { return }
                didDragSelect = true
                guard !isSelected(tab.screen) else { return }
                ONEHaptics.tabSwitch()
                withAnimation(ONEAnimation.easingColor) {
                    currentScreen = tab.screen
                }
            }
            .onEnded { _ in
                // Button'ın touch-up'ı jest bitişinden sonra da gelebiliyor;
                // bayrağı bir tick geç indir ki o dokunuş yutulsun.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    didDragSelect = false
                }
            }
    }

    /// Çubuk içindeki x → sekme. Sekmeler eşit genişlikte, kenarlarda kırpılır.
    private func tab(atX x: CGFloat) -> PrimaryTab? {
        guard barWidth > 0, !tabs.isEmpty else { return nil }
        let slot = barWidth / CGFloat(tabs.count)
        let index = min(max(Int(floor(x / slot)), 0), tabs.count - 1)
        return tabs[index]
    }

    // MARK: - Bar background

    /// iOS 26'da gerçek Liquid Glass, altında `.ultraThinMaterial`.
    /// Reduce Transparency açıkken düz `surface` — cam yok, kenar hairline.
    ///
    /// Kenar + gölge neden var: `.clear` cam arkasını olduğu gibi geçiriyor,
    /// yani kağıt zeminin üstünde çubuğun **hiçbir sınırı** kalmıyordu. Sonuç
    /// ters okunuyordu — cam gibi değil, düz bir şerit gibi. Hairline kenar
    /// kapsülün nerede başladığını söylüyor, gölge onu içerikten koparıyor:
    /// altından geçen mozaik artık çubuğun *arkasında* olduğu belli oluyor.
    /// v3 spec zaten yüzen çubuğa gölge veriyor (0.14 · r15 · y10).
    @ViewBuilder
    private var barBackground: some View {
        let shape = RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
        if reduceTransparency {
            shape
                .fill(V3Tokens.surface)
                .overlay(shape.strokeBorder(V3Tokens.hairline, lineWidth: 1))
        } else {
            Color.clear
                .liquidGlassBackground(.clear, in: shape)
                .overlay(
                    shape.strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.06),
                        lineWidth: 0.75
                    )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.14),
                    radius: 15,
                    y: 10
                )
        }
    }

    private func isSelected(_ screen: ScreenType) -> Bool {
        // Eskiden `.today`, `.confirm` ve `.done` birlikte An sekmesine aitti.
        // `.confirm` / `.done` v2 ritüelinin adımlarıydı ve `ScreenType`'tan
        // kalktılar — akış artık `V3EntryContainer` içinde tek ekran.
        currentScreen == screen
    }
}

// MARK: - Tab pill (text + dot indicator)

private struct TabPill: View {
    let label: String
    let isSelected: Bool
    let height: CGFloat
    let minimized: Bool
    var badge: Int = 0
    var accessibilityCustomActionTitle: String? = nil
    var onAccessibilityCustomAction: (() -> Void)? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // v3 dot indicator: 18×5 kor (active) / 5×5 line (inactive).
                // Spring animasyonu indicator'a fiziksel bir "yerine oturma"
                // hissi veriyor; renk geçişleri hâlâ mevcut easing eğrisinde.
                Capsule()
                    .fill(isSelected ? ONEBrand.kor : dotInactiveColor)
                    .frame(width: isSelected ? 18 : 5, height: 5)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 22),
                               value: isSelected)

                if !minimized {
                    HStack(spacing: V3Tokens.spacingXS) {
                        Text(label)
                            .font(V3Typography.sans(12, weight: isSelected ? .semibold : .medium,
                                                    relativeTo: .caption1))
                            .tracking(0.3)
                            // Dört sekme genişliği paylaşıyor; büyük metin
                            // ayarlarında etiket kesilmesin diye bir miktar
                            // sıkışabilsin.
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if badge > 0 {
                            Circle()
                                .fill(ONEBrand.kor)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .foregroundColor(isSelected ? textActive : textInactive)
            .frame(maxWidth: .infinity, minHeight: height)
            // Aktif sekmenin beyaz plakası kaldırıldı. Çubuğun kendi cam
            // kapsülü varken bir "kabartma" olarak anlamlıydı; plakasız
            // zeminde havada duran ikinci bir dikdörtgene dönüşüyordu.
            // Seçimi kor nokta + ink metin ağırlığı taşıyor.
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(String(format: NSLocalizedString("nav.tabAccessibility", comment: ""), label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(TabRetapCustomAction(
            title: accessibilityCustomActionTitle,
            action: onAccessibilityCustomAction
        ))
    }

    // Bu üçü elle `colorScheme == .dark ? ... : ...` yazıyordu ve değerleri
    // token ölçeğinin birebir kopyasıydı — yani token'lar değişse sekme çubuğu
    // geride kalırdı.
    //
    // Kopyalardan biri hatalıydı: `textInactive`'in açık tema değeri #A8A59C,
    // `V3Tokens` içinde "2.36:1 — AA'yı geçmiyor" diye **reddedilmiş** olan
    // eski `ghostText`. Seçili olmayan sekme etiketi hâlâ o kontrasttaydı.
    // Token'a bağlanınca AA'yı geçen değere (4.55:1) çıkıyor.
    private var textActive: Color { V3Tokens.ink }

    private var textInactive: Color { V3Tokens.ghostText }

    private var dotInactiveColor: Color { V3Tokens.hairline }
}

/// Optional custom accessibility action modifier — VoiceOver rotor'undan
/// tetiklenebilir alternatif eylem. Title nil ise hiçbir şey uygulamıyor.
private struct TabRetapCustomAction: ViewModifier {
    let title: String?
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let title, let action {
            content.accessibilityAction(named: Text(title), action)
        } else {
            content
        }
    }
}
