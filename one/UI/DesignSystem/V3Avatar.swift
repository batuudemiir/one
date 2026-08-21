//
//  V3Avatar.swift
//  one
//
//  v3 avatar sistemi — 5 tip. Talimat: mosaic, photo, mark-kor, mark-ink, band.
//  (README ayrıca `mark-kor-invert` ve `mark-paper` sayıyor; 7'ye kadar uzayabilir.)
//
//  Animasyonlar:
//   - avbreathe: 3.5s ease-in-out sonsuz, scale 1→1.02 (marka işaretleri için).
//   - avpop: 0.42s cubic-bezier(.2,.9,.25,1) — seçim anında.
//

import SwiftUI

// MARK: - Kind

enum V3AvatarKind: String, CaseIterable, Identifiable, Codable {
    case mosaic        = "mosaic"         // 3×3 mood ızgarası (default)
    case photo         = "photo"          // Kullanıcı fotoğrafı
    case markKor       = "mark-kor"       // Kor square + bone ONE
    case markKorInvert = "mark-kor-invert"// Bone square + kor ONE
    case markInk       = "mark-ink"       // Ink square + bone ONE
    case markPaper     = "mark-paper"     // Bone square + ink ONE
    case band          = "band"           // 9 mood renk şeridi

    var id: String { rawValue }

    // MARK: Persistence

    private static let storageKey = "v3.avatar.kind"

    static var current: V3AvatarKind {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            return V3AvatarKind(rawValue: raw) ?? .mosaic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

// MARK: - Avatar view

struct V3AvatarView: View {
    let kind: V3AvatarKind
    /// Kenar uzunluğu (kare avatar). Nefes animasyonu bunun üstünden çalışır.
    var side: CGFloat = 76
    /// Kullanıcının fotoğrafı — `kind == .photo` için gerekli.
    var photo: UIImage? = nil
    /// `true` → sürekli nefes al (avbreathe). Mark tipleri için önerilir.
    var breathes: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breatheOn = false

    var body: some View {
        content
            .frame(width: side, height: side)
            .scaleEffect(shouldBreathe ? (breatheOn ? 1.02 : 1.0) : 1.0)
            .animation(
                shouldBreathe ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true) : .default,
                value: breatheOn
            )
            .onAppear {
                if shouldBreathe { breatheOn = true }
            }
            .accessibilityLabel("Avatar")
    }

    private var shouldBreathe: Bool {
        guard !reduceMotion, breathes else { return false }
        // Sadece mark tipleri nefes alır; mosaic/photo/band durağandır.
        switch kind {
        case .markKor, .markKorInvert, .markInk, .markPaper: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .mosaic:
            mosaicAvatar
        case .photo:
            photoAvatar
        case .markKor:
            markAvatar(ground: ONEBrand.kor,  letters: ONEBrand.bone)
        case .markKorInvert:
            markAvatar(ground: ONEBrand.bone, letters: ONEBrand.kor)
        case .markInk:
            markAvatar(ground: ONEBrand.ink,  letters: ONEBrand.bone)
        case .markPaper:
            markAvatar(ground: ONEBrand.bone, letters: ONEBrand.ink)
        case .band:
            bandAvatar
        }
    }

    // MARK: Variants

    /// 3×3 mozaik — 9 v3 mood renginin karesi.
    private var mosaicAvatar: some View {
        let cell = side / 3
        return VStack(spacing: 0) {
            ForEach(0..<3) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3) { col in
                        let idx = row * 3 + col
                        Rectangle()
                            .fill(V3Mood.allCases[idx].color)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
    }

    /// Kullanıcı fotoğrafı; yoksa nötr placeholder.
    @ViewBuilder
    private var photoAvatar: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                .fill(V3Tokens.wash)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: side * 0.42))
                        .foregroundColor(V3Tokens.faintText)
                )
        }
    }

    /// Mark varyantları — kor/ink/bone kombinasyonları. ONEAppMark ile aynı geometri.
    private func markAvatar(ground: Color, letters: Color) -> some View {
        let fontSize = side * ONEBrand.wordmarkFontRatio
        return Text("ONE")
            .font(ONEBrand.display(fontSize))
            .tracking(fontSize * ONEBrand.tracking)
            .foregroundColor(letters)
            .lineLimit(1)
            .fixedSize()
            .frame(width: side, height: side)
            .background(ground)
            .clipShape(RoundedRectangle(cornerRadius: side * ONEBrand.cornerRadiusRatio, style: .continuous))
    }

    /// 9 mood renginin dikey şeridi.
    private var bandAvatar: some View {
        VStack(spacing: 0) {
            ForEach(V3Mood.allCases) { mood in
                Rectangle()
                    .fill(mood.color)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
    }
}

// MARK: - Picker

/// Avatar seç — 3 sütunlu grid. Seçili olan `avpop` + çift halka + scale 1.1.
struct V3AvatarPicker: View {
    @Binding var selection: V3AvatarKind
    /// Kullanıcının fotoğrafı — `.photo` seçeneği için gerekli.
    var userPhoto: UIImage? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popKind: V3AvatarKind? = nil
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 14) {
            ForEach(V3AvatarKind.allCases) { kind in
                cell(kind)
            }
        }
    }

    private func cell(_ kind: V3AvatarKind) -> some View {
        let isSelected = kind == selection
        let popping = popKind == kind

        return Button {
            ONEHaptics.feelingSelected()
            selection = kind
            if !reduceMotion {
                popKind = kind
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    if popKind == kind { popKind = nil }
                }
            }
        } label: {
            V3AvatarView(kind: kind, side: 84, photo: userPhoto, breathes: false)
                .scaleEffect(popping ? 1.1 : (isSelected ? 1.06 : 1.0))
                .padding(6)
                .background(
                    Group {
                        if isSelected {
                            // Çift halka — outer ink, inner paper spacer.
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(V3Tokens.paper, lineWidth: 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(V3Tokens.ink, lineWidth: 2)
                                        .padding(3)
                                )
                        }
                    }
                )
                .animation(.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.42), value: popping)
                .animation(.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.22), value: isSelected)
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(a11y(kind))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func a11y(_ kind: V3AvatarKind) -> String {
        switch kind {
        case .mosaic:        return "Mozaik avatar"
        case .photo:         return "Fotoğraf avatar"
        case .markKor:       return "Kor işaret"
        case .markKorInvert: return "Ters kor işaret"
        case .markInk:       return "Mürekkep işaret"
        case .markPaper:     return "Kağıt işaret"
        case .band:          return "Renk bandı"
        }
    }
}

// MARK: - Kişi avatarı (baş harf)

/// Bir **başkasının** avatarı — ad + renk. `V3AvatarView` kullanıcının kendi
/// avatarı için (mozaik / fotoğraf / işaret); bu, arkadaş listelerinde,
/// isteklerde, tepkilerde ve paylaşım detaylarında görünen baş harf kabuğu.
///
/// Neden var: bu kalıp on üç dosyada elle yazılmıştı — 32, 40, 44, 50, 56 ve
/// 64pt; kimi `Circle`, kimi `RoundedRectangle`; yazı kimi yerde
/// `V3Typography.sans(15, .bold)`, kimi yerde `ONEBrand.display(16)`, bir
/// yerde de **serif** (ONE'ın dört yüzünün hiçbiri değil). Aynı arkadaş iki
/// ekranda iki farklı nesne olarak çiziliyordu.
///
/// **Biçim rounded-square**, daire değil: kullanıcının kendi avatarı
/// (`V3AvatarView`) ve logomark zaten bu köşede. Çevre listesinde "sen"
/// kartı kare, arkadaş kartları daireydi — yan yana duran iki avatar iki
/// ayrı dile aitti.
///
/// **Metin rengi renkten türetilir, `.white` değil.** Renk bir mood'a
/// oturuyorsa o mood'un `ink` eşi; oturmuyorsa (kullanıcı seçimi eski bir
/// palet olabilir) parlaklıktan hesaplanır. `.white` rastgele bir hex'in
/// üstünde kontrast garantisi vermiyordu.
struct V3PersonAvatar: View {

    /// Üç ölçü. Ara boyut gerekiyorsa önce buraya kademe ekle — çağrı
    /// yerinde ham sayı yazmak ölçeği yeniden dağıtır.
    enum Size {
        /// 32pt — yoğun liste satırı, tepki gönderen.
        case small
        /// 44pt — standart liste satırı. Dokunma hedefiyle aynı.
        case medium
        /// 56pt — istek kartı, paylaşım detayı başlığı.
        case large

        var side: CGFloat {
            switch self {
            case .small:  return 32
            case .medium: return 44
            case .large:  return 56
            }
        }

        /// Baş harf puntosu — kenarın %38'i. Üç kademede de aynı optik ağırlık.
        var glyph: CGFloat { side * 0.38 }
    }

    let name: String
    /// Kişinin rengi. `nil` ya da çözülemeyen hex → nötr `wash` zemin.
    var colorHex: String? = nil
    var size: Size = .medium

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    /// Zemin ve üstündeki mürekkep birlikte seçilir — biri diğerinden
    /// bağımsız değişemez.
    private var palette: (ground: Color, ink: Color) {
        guard let colorHex, !colorHex.isEmpty else {
            return (V3Tokens.wash, V3Tokens.mutedText)
        }
        if let mood = V3Mood.closest(toHex: colorHex) {
            return (mood.color, mood.ink)
        }
        let ground = Color(hex: colorHex)
        return (ground, Self.readableInk(onHex: colorHex))
    }

    var body: some View {
        Text(initial)
            .font(V3Typography.display(size.glyph))
            .foregroundColor(palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size.side, height: size.side)
            .background(
                RoundedRectangle(cornerRadius: size.side * 0.28, style: .continuous)
                    .fill(palette.ground)
            )
            // Ad zaten satırın kendisinde yazılı; avatar onu tekrar
            // okutmasın diye VoiceOver'dan gizli.
            .accessibilityHidden(true)
    }

    /// Zemin parlaklığından okunur mürekkep. WCAG'ın relative luminance
    /// formülü (sRGB → lineer), eşik 0.45: bunun üstü koyu metin ister.
    ///
    /// Yalnız mood paletine oturmayan hex'ler için — mood'u olan renkte
    /// tasarımın verdiği `ink` eşi kullanılır, hesap değil.
    static func readableInk(onHex hex: String) -> Color {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard clean.count >= 6, let value = UInt64(clean.prefix(6), radix: 16) else {
            return V3Tokens.darkText
        }
        func channel(_ raw: UInt64) -> Double {
            let c = Double(raw) / 255.0
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((value >> 16) & 0xFF)
        let g = channel((value >> 8) & 0xFF)
        let b = channel(value & 0xFF)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.45 ? V3Tokens.darkGround : V3Tokens.darkText
    }
}

#Preview("Kişi avatarı") {
    VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
        ForEach([V3PersonAvatar.Size.small, .medium, .large], id: \.side) { size in
            HStack(spacing: V3Tokens.spacingMD) {
                V3PersonAvatar(name: "Batu", colorHex: V3Mood.huzurlu.hex, size: size)
                V3PersonAvatar(name: "elif", colorHex: V3Mood.mutlu.hex, size: size)
                V3PersonAvatar(name: "Deniz", colorHex: "#7A3FF2", size: size)
                V3PersonAvatar(name: "", colorHex: nil, size: size)
            }
        }
    }
    .padding()
    .background(V3Tokens.paper)
}
