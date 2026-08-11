//
//  GenreChipsView.swift
//  one
//
//  Keşfet sekmesi — Kullanıcının dinleme geçmişinden tür chip'leri
//  Tıklanabilir genre chip'leri o türe göre yeniden öneri çeker.
//

import SwiftUI

struct GenreChipsView: View {
    let genres: [String]
    let artists: [String]
    /// Seçili genre filtresi — nil ise tüm türler
    @Binding var selectedGenre: String?
    /// Genre seçilince çağrılır (nil = filtre kaldır)
    var onGenreSelected: ((String?) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("discover.yourProfile", comment: ""))
                    .monoBase(tracking: 2)
                    .foregroundColor(V3Tokens.mutedText)

                if selectedGenre != nil {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedGenre = nil }
                        onGenreSelected?(nil)
                    } label: {
                        Text(NSLocalizedString("general.clearFilter", comment: ""))
                            .monoLabel(tracking: 0.4)
                            .foregroundColor(ONEBrand.kor)
                    }
                }
            }

            // Genre chips — tıklanabilir
            if !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            let isSelected = selectedGenre == genre
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    selectedGenre = isSelected ? nil : genre
                                }
                                onGenreSelected?(isSelected ? nil : genre)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isSelected ? "checkmark" : "music.note")
                                        .font(.system(size: 9, weight: .medium))
                                    Text(genre)
                                        .monoSM(tracking: 0.4)
                                }
                                .foregroundColor(isSelected ? .white : V3Tokens.mutedText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .liquidGlass((isSelected ? LiquidGlassVariant.regular.tint(ONEBrand.kor) : .regular).interactive(), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Top artists
            if !artists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(artists, id: \.self) { artist in
                            HStack(spacing: 5) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text(artist)
                                    .monoSM(tracking: 0.4)
                            }
                            .foregroundColor(V3Tokens.mutedText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .stroke(V3Tokens.hairline, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
}
