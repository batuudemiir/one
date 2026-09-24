//
//  ShareViewData.swift
//  ONE 2.0
//
//  Paylaşım kartı önizlemesi (07 §5.12): kaynak, biçim, arka plan. Kişisel
//  metin varsayılan gizli; "Yazımı da ekle" anahtarı açar. Alt köşede küçük
//  wordmark (`AppBrand.name`).
//

import CoreGraphics

nonisolated enum ShareSourceKind: Hashable, Sendable {
    case quote
    case quoteReflection
    case changePair
    case yearInReview
}

nonisolated enum ShareCardFormat: String, CaseIterable, Hashable, Sendable {
    /// Hikâye, 1080×1920.
    case story
    /// Kare, 1080×1080.
    case square

    var pixelSize: CGSize {
        switch self {
        case .story:  return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

nonisolated struct SharePreviewData: Identifiable, Equatable, Sendable {
    let id: String
    let source: ShareSourceKind
    /// Söz ya da kartın ana metni.
    let text: String
    /// Düşünür · eser.
    let attribution: String?
    /// Kullanıcının yazısı; `includesPersonalText` kapalıyken çizilmez.
    let personalText: String?
    /// Değişim kartı kaynağında iki cevap.
    let change: ChangePair?
    var format: ShareCardFormat = .story
    var background: QuoteBackground
    var includesPersonalText = false
    /// Instagram yüklüyse doğrudan hikâye hedefi.
    let canShareToInstagram: Bool
}
