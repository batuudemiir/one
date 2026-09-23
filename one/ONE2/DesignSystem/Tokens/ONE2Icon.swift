//
//  ONE2Icon.swift
//  ONE 2.0
//
//  SF Symbols eşlemesi (README İkonografi). Ağırlık `regular`; seçili sekme
//  ikon değiştirmez. Emoji ve yüz ifadesi yok.
//

import SwiftUI

enum ONE2Icon: String, CaseIterable, Sendable {
    // Sekmeler
    case today = "sun.max"
    case quotes = "quote.opening"
    case explore = "safari"
    case journey = "book"
    case insights = "chart.bar"

    // Kontroller ve içerik
    case streak = "flame"
    case profile = "person.crop.circle"
    case search = "magnifyingglass"
    case filter = "line.3.horizontal.decrease"
    case chevronDown = "chevron.down"
    case chevronRight = "chevron.right"
    case add = "plus"
    case share = "square.and.arrow.up"
    case like = "heart"
    case liked = "heart.fill"
    case brush = "paintbrush"
    case play = "play"
    case sliders = "slider.horizontal.3"
    case lock = "lock"
    case check = "checkmark"
    case format = "textformat"
    case photo = "photo"
    case mic = "mic"
    case music = "music.note"
    case tag = "tag"
    case offline = "wifi.slash"
    case leaf = "leaf"
    case moon = "moon"

    var systemName: String { rawValue }

    /// Sabit boyutlu ikon (kontrol ölçüleri sabit; metin değil).
    func image(size: CGFloat = ONE2Size.icon) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .regular))
    }
}
