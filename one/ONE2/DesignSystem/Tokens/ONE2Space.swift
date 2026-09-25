//
//  ONE2Space.swift
//  ONE 2.0
//
//  Boşluk (tokens.json › spacing) ve ölçü token'ları. Ölçüler tokens.json'da
//  yok; README ve components/*.md'de yazılı sabitler burada toplanır ki
//  bileşenler elle sayı yazmasın.
//

import CoreGraphics

nonisolated enum ONE2Space {
    /// İkon–metin arası.
    static let s1: CGFloat = 4
    /// Chip içi dikey, ilişkili öğeler arası.
    static let s2: CGFloat = 8
    /// Chip yatay dolgu, liste satırı; bir gruptaki kartlar arası.
    static let s3: CGFloat = 12
    /// Ekran kenarı, kart iç dolgusu.
    static let s4: CGFloat = 16
    /// Kart içi bölümler arası.
    static let s5: CGFloat = 20
    /// Kart iç dolgusu (geniş).
    static let s6: CGFloat = 24
    /// Ekran bölümleri arası.
    static let s8: CGFloat = 32
    /// Büyük bölüm ayrımı, tamamlama ekranı.
    static let s10: CGFloat = 40
    /// Onboarding üst boşluğu.
    static let s14: CGFloat = 56

    // Anlamsal takma adlar (README "Boşluk, köşe, yüzey").
    static let gutter = s4
    static let cardGap = s3
    static let sectionGap = s8
}

/// Bileşen ölçüleri (README ve components/*.md).
nonisolated enum ONE2Size {
    /// En küçük dokunma hedefi.
    static let minTouch: CGFloat = 44
    /// Hap ve yuvarlak kontroller (TopBar).
    static let control: CGFloat = 48
    /// Buton yüksekliği; kart içinde `buttonCompact`.
    static let button: CGFloat = 52
    static let buttonCompact: CGFloat = 48
    /// Skor diski ve küçük varyantı.
    static let scoreDisc: CGFloat = 60
    static let scoreDiscSmall: CGFloat = 20
    /// Tab bar ikonu.
    static let tabIcon: CGFloat = 24
    /// Yüzen + hapı.
    static let addButtonWidth: CGFloat = 72
    static let addButtonHeight: CGFloat = 56
    /// PracticeTile ikon kuyusu.
    static let iconWell: CGFloat = 72
    /// Badge diski.
    static let badgeDisc: CGFloat = 64
    /// Seal diski.
    static let sealDisc: CGFloat = 96
    /// PracticeTile kuyu içi ikon (`.o-tile__well .o-ico`).
    static let iconWellGlyph: CGFloat = 34
    /// Hafta şeridi: hücre arası (`.o-week` 2px), tarih/tik satırı.
    static let weekCellGap: CGFloat = 2
    static let weekGlyph: CGFloat = 24
    /// Hafta şeridi diskindeki tik ve `gap` halkasının kesik uzunluğu (07 §5.1).
    static let weekTick: CGFloat = 13
    static let weekDash: CGFloat = 3
    /// Tema günü noktası (07 §5.1: "7 nokta").
    static let themeDot: CGFloat = 8
    /// Ritüel kartındaki ilerleme çizgisi yüksekliği.
    static let progressLine: CGFloat = 4
    /// Haftalık tema gün noktaları arası.
    static let themeDotGap: CGFloat = 6
    /// Yazı sütunu (~65 karakter; iPad'de ortalı, 07 §5.3).
    static let readingColumn: CGFloat = 640
    /// Yatay sayfalı kartlarda bir sonraki kartın görünen payı.
    static let pagePeek: CGFloat = 16
    /// EmotionChip aile noktası.
    static let emotionDot: CGFloat = 10
    /// CheckInCard en küçük yükseklik.
    static let checkInCardMin: CGFloat = 300
    /// ContentCard kemer görseli.
    static let contentArt: CGFloat = 88

    /// İkonlar: varsayılan, hap içi ve büyük (söz kartı çubuğu, + hapı).
    static let icon: CGFloat = 22
    static let iconSmall: CGFloat = 18
    static let iconLarge: CGFloat = 26

    /// Hap yatay dolgusu (`.o-pill` 18px) ve mood hapı (`.o-moodpill`).
    static let pillPadding: CGFloat = 18
    static let moodPillGap: CGFloat = 10
    /// CauseTag görünür yüksekliği ve yatay dolgusu (`.o-tag`); dokunma
    /// alanı yine `minTouch`.
    static let tagHeight: CGFloat = 36
    static let tagPadding: CGFloat = 14
    /// İskelet çubuğu yüksekliği (`.o-skel`).
    static let skeletonLine: CGFloat = 14

    /// Dock (`.o-dock`, `.o-tabbar`): tab bar'ın + hapının tepesinden
    /// uzaklığı; tab bar iç dolgusu 6pt. CSS 34px'te + hapı ortadaki sekme
    /// ikonunun üstünü 6pt örtüyordu; 44 ile hap ikonun 4pt üstünde biter.
    static let dockTop: CGFloat = 44
    static let tabBarPadding: CGFloat = 6
    /// Sekme öğesinin üst dolgusu (`.o-tab` 10px; alt `space-2`).
    static let tabItemTop: CGFloat = 10

    /// Referans ekranlardaki en küçük yükseklikler (`.o-week__d`, `.o-tile`,
    /// `.o-featured`, `.o-quote`, `.o-trend` grafiği).
    static let weekCell: CGFloat = 72
    static let practiceTileMin: CGFloat = 200
    static let featuredMin: CGFloat = 280
    static let quoteCardMin: CGFloat = 560
    static let chartHeight: CGFloat = 150
    /// Fotoğraf anısı kartı (`.o-memory`).
    static let memoryMin: CGFloat = 240
    /// İskelet hap genişliği (seri hapı, dönem hapı yer tutucusu).
    static let skeletonPill: CGFloat = 96

    /// Dekoratif kenar (`line`) ve anlamlı kenar (`lineStrong`).
    static let hairline: CGFloat = 1
    /// Odak halkası, seçili PlanCard kenarı.
    static let focusRing: CGFloat = 2
}
