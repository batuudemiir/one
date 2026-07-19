import SwiftUI

struct CommentSongSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    let onSelect: (Song) -> Void

    @State private var recentSongs: [RecentSongItem] = []
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [RecentSongItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return recentSongs }
        let q = query.lowercased()
        return recentSongs.filter {
            $0.name.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Divider().opacity(0.12)

                if filtered.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
            .background(ONETokens.oneCream.ignoresSafeArea())
            .navigationTitle("Bir şarkı seç")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(ONETokens.oneInk)
                }
            }
        }
        .task { loadRecentSongs() }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ONETokens.oneAsh)
            TextField("Şarkı veya sanatçı ara…", text: $query)
                .font(ONETypography.bodySM)
                .focused($searchFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ONETokens.oneCreamMid, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Song list

    private var songList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { item in
                    Button {
                        let song = Song(
                            name: item.name,
                            artist: item.artist,
                            genre: "",
                            emoji: "",
                            grad: [.gray],
                            shadow: .gray,
                            artworkURL: item.artworkURL
                        )
                        onSelect(song)
                        dismiss()
                    } label: {
                        songRow(item)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 76)
                        .opacity(0.1)
                }
            }
            .padding(.top, 4)
        }
    }

    private func songRow(_ item: RecentSongItem) -> some View {
        HStack(spacing: 12) {
            artworkView(item)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(ONETypography.bodySMMedium)
                    .foregroundStyle(ONETokens.oneInk)
                    .lineLimit(1)
                Text(item.artist)
                    .font(ONETypography.bodyXS)
                    .foregroundStyle(ONETokens.oneAsh)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func artworkView(_ item: RecentSongItem) -> some View {
        if let url = item.artworkURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                artworkPlaceholder(hex: item.moodColorHex)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            artworkPlaceholder(hex: item.moodColorHex)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func artworkPlaceholder(hex: String?) -> some View {
        let color = Color(hex: hex ?? "#C8C8C8")
        return ZStack {
            color
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(ONETokens.oneAsh)
            Text(query.isEmpty ? "Henüz entry yok" : "Sonuç bulunamadı")
                .font(ONETypography.bodySM)
                .foregroundStyle(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Data

    private func loadRecentSongs() {
        let all = PersistenceController.shared.fetchAllDailySongs(context: context)
        var seen = Set<String>()
        var unique: [RecentSongItem] = []
        for song in all.reversed() {
            guard let name = song.songName, !name.isEmpty,
                  let artist = song.artistName else { continue }
            let key = "\(name)|\(artist)"
            guard seen.insert(key).inserted else { continue }
            let artworkURL = song.artworkURL.flatMap { URL(string: $0) }
            unique.append(RecentSongItem(
                name: name,
                artist: artist,
                artworkURL: artworkURL,
                moodColorHex: song.moodColorHex
            ))
            if unique.count == 20 { break }
        }
        recentSongs = unique
    }
}

// MARK: - Model

private struct RecentSongItem: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
    let artworkURL: URL?
    let moodColorHex: String?
}
