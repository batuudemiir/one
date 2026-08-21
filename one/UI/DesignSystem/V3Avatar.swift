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
