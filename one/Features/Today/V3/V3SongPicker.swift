import SwiftUI
import CoreData

/// Adım 2'deki "Şarkı" toggle'ı bir şarkı arama sheet'i açar. Mevcut
/// `TodayViewModel.search(...)` altyapısını yeniden kullanır; sonuç seçilince
/// callback ile döner.
///
/// Query boşken `SongRecommendationEngine` üzerinden mood + trend katmanlı
/// öneriler gösteriyoruz — kullanıcı arama yapmadan da hemen bir şey seçebilsin.
struct V3SongPicker: View {
    let mood: V3Mood
    let onSelect: (SongResult) -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: TodayViewModel
    @StateObject private var engine = SongRecommendationEngine()
    @State private var query: String = ""

    init(mood: V3Mood, onSelect: @escaping (SongResult) -> Void) {
        self.mood = mood
        self.onSelect = onSelect
        _vm = StateObject(wrappedValue: TodayViewModel(context: PersistenceController.shared.container.viewContext))
    }

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 24)

            searchField
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if isQueryEmpty {
                recommendationsContent
            } else {
                searchContent
            }
        }
        .background(V3Tokens.paper.ignoresSafeArea())
        .task {
            engine.load(mood: mood, context: viewContext)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("Şarkı seç")
                .font(V3Typography.display(24, weight: .semibold))
                .tracking(-0.6)
                .foregroundColor(V3Tokens.ink)
            Spacer()
            if isQueryEmpty {
                Button {
                    ONEHaptics.nudge()
                    engine.refresh(mood: mood, context: viewContext)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Yenile")
                            .font(V3Typography.sans(13, weight: .semibold))
                    }
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(V3Tokens.hairline, lineWidth: 1)
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(engine.isLoading)
                .opacity(engine.isLoading ? 0.5 : 1)
            }
            Button {
                dismiss()
            } label: {
                Text("Kapat")
                    .font(V3Typography.sans(15, weight: .medium))
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Search (query dolu)

    private var searchContent: some View {
        Group {
            if vm.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
            List {
                ForEach(vm.searchResults) { song in
                    songRowButton(song)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Recommendations (query boş)

    @ViewBuilder
    private var recommendationsContent: some View {
        if engine.sections.isEmpty {
            if engine.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Sana özel öneriler hazırlanıyor")
                        .font(V3Typography.sans(13))
                        .foregroundColor(V3Tokens.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = engine.errorMessage {
                emptyState(text: msg)
            } else {
                emptyState(text: "Öneri bulunamadı.")
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(engine.sections) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 40)
            }
            .refreshable {
                engine.refresh(mood: mood, context: viewContext)
                // refreshable pull-hold jesti bittikten sonra loading göstergesini
                // görebilmek için minik gecikme — engine.isLoading await'lenmiyor.
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func sectionBlock(_ section: SongRecommendationEngine.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.6)
                .foregroundColor(V3Tokens.faintText)

            VStack(spacing: 0) {
                ForEach(section.songs) { song in
                    songRowButton(song)
                        .padding(.vertical, 6)
                    if song.id != section.songs.last?.id {
                        Divider()
                            .background(V3Tokens.hairline)
                    }
                }
            }
        }
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(V3Tokens.faintText)
            Text(text)
                .font(V3Typography.sans(14))
                .foregroundColor(V3Tokens.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Row

    private func songRowButton(_ song: SongResult) -> some View {
        Button {
            ONEHaptics.moodSelected()
            onSelect(song)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(mood.color.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Group {
                            if let url = song.artworkURLString.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.clear
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(V3Typography.sans(15, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(V3Typography.sans(13))
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(V3Tokens.faintText)
            TextField("Şarkı, sanatçı…", text: $query)
                .font(V3Typography.sans(15))
                .foregroundColor(V3Tokens.ink)
                .autocorrectionDisabled(true)
                .onChange(of: query) { _, newValue in
                    vm.search(newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    vm.search("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(V3Tokens.faintText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }
}
