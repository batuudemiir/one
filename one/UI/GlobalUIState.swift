import SwiftUI
import Combine

@MainActor
final class GlobalUIState: ObservableObject {
    static let shared = GlobalUIState()

    @Published var isFullScreenPhotoVisible = false

    // Global properties for covering bottom navigation
    @Published var archivePhotoURL: URL?
    /// Arşiv gün detayı — yerel `photoData` fotoğrafını tam ekran gösterir.
    /// URL yoksa (yeni girilen an, henüz CloudKit'e yüklenmemiş) bu kanal kullanılır.
    @Published var archiveMomentImage: UIImage?
    @Published var circlePhotoImage: UIImage?
    @Published var todayPhotoURL: URL?

    /// v3: An akışı adım 2 (not yazarken) — tab çubuğu daralır.
    /// V3EntryContainer set eder, BottomNavigation okur.
    @Published var tabBarMinimized: Bool = false

    // MARK: - Sekme swipe kilidi
    //
    // Kabuk `TabView(.page)` kullandığı için yatay swipe her yerde aktif.
    // İki farklı durum onu kilitlemek istiyor ve **aynı anda** olabiliyorlar,
    // bu yüzden tek bir `Bool` yetmiyor: biri `false` yazınca diğerinin
    // kilidini de açardı. Her kaynağın kendi bayrağı var, kilit türetiliyor.

    /// An akışı adım 2+ (not yazma / fotoğraf / şarkı) — yanlışlıkla sekme
    /// kaydırmak yazılanı kaybettirmiş gibi hissettiriyor.
    @Published var entryFlowLocksSwipe: Bool = false

    /// Bir sekme kendi içinde detaya push etti — `NavigationStack`'in
    /// kenardan-geri jesti ile sayfa swipe'ı aynı parmak hareketi.
    @Published var detailStackLocksSwipe: Bool = false

    /// Kabuk bunu okuyor.
    var tabSwipeLocked: Bool { entryFlowLocksSwipe || detailStackLocksSwipe }

    /// v3: Arşiv'de boş bir güne (veya "Bu güne an ekle") dokununca An
    /// akışını o tarih için açar. Container tüketince nil'e set eder.
    /// nil = bugün, non-nil = past-day mode ("Geçmiş gün" kapsülü + tarih başlığı).
    @Published var pendingEntryDate: Date? = nil
}

// MARK: - Photo hero namespace
// Bugün kartındaki fotoğraf ile tam ekran görüntüleyici arasında morph
// için ortak Namespace. Kök view (ONEColorPickerView) inject eder;
// kart ve viewer environment'tan okur.
private struct TodayPhotoNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct ArchivePhotoNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct ArchiveDayNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var todayPhotoNamespace: Namespace.ID? {
        get { self[TodayPhotoNamespaceKey.self] }
        set { self[TodayPhotoNamespaceKey.self] = newValue }
    }
    /// Arşiv fotoğraf viewer'ı için: DayPreviewCard thumb ↔ FullScreenPhotoView.
    var archivePhotoNamespace: Namespace.ID? {
        get { self[ArchivePhotoNamespaceKey.self] }
        set { self[ArchivePhotoNamespaceKey.self] = newValue }
    }
    /// Arşiv grid → gün detayı morph'u için: DayFill ↔ V3DayDetailView hero.
    var archiveDayNamespace: Namespace.ID? {
        get { self[ArchiveDayNamespaceKey.self] }
        set { self[ArchiveDayNamespaceKey.self] = newValue }
    }
}

// MARK: - Notifications
extension Notification.Name {
    /// An sekmesine tekrar dokunma sinyali. V3EntryContainer dinliyor —
    /// .saved veya .hub'daysa formu sıfırlayıp pick'e dönüyor.
    static let startNewMomentRequested = Notification.Name("startNewMomentRequested")
    /// Arşiv sekmesine tekrar dokunma: gün detayı açıksa kapat, değilse en üste.
    static let archiveTabRetapped = Notification.Name("archiveTabRetapped")
    /// Çevre sekmesine tekrar dokunma: en üste + feed yenile.
    static let circleTabRetapped = Notification.Name("circleTabRetapped")
    /// Profil sekmesine tekrar dokunma: en üste scroll.
    static let profileTabRetapped = Notification.Name("profileTabRetapped")
    /// Üst bardaki arkadaş-istekleri ikonu. Prototip 10: ikonlar üst barda,
    /// ekranın kendi başlığında değil — kabuk gönderiyor, V3CircleView açıyor.
    static let circleOpenRequests = Notification.Name("circleOpenRequests")
    /// Üst bardaki bildirim ikonu.
    static let circleOpenNotifications = Notification.Name("circleOpenNotifications")
}

