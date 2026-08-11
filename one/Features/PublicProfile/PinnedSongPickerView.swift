//
//  PinnedSongPickerView.swift
//  one
//
//  CoreData DailySong'dan son 60 gün şarkı listesi. Tap → onSelect, dismiss.
//

import SwiftUI
import CoreData

struct PinnedSongPickerView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onSelect: (PinnedSong) -> Void

    @State private var entries: [DailySong] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Şarkı Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .background(ONEBrand.bone.ignoresSafeArea())
            .onAppear { loadEntries() }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    Button(action: { pick(entry) }) {
                        songRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func songRow(entry: DailySong) -> some View {
        let moodHex = entry.moodColorHex ?? "#9B7FD4"
        let moodColor = Color(hex: moodHex)
        let dateStr = entry.date.map {
            let f = DateFormatter()
            f.locale = Locale(identifier: "tr_TR")
            f.dateStyle = .medium
            return f.string(from: $0)
        } ?? ""

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(moodColor.opacity(0.80))
                .frame(width: 8, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.songName ?? "Bilinmeyen")
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(1)
                Text(entry.artistName ?? "")
                    .monoLabel(tracking: 0)
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Text(dateStr)
                .monoLabel(tracking: 0.3)
                .foregroundColor(V3Tokens.faintText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .stroke(ONETokens.oneSilver, lineWidth: 1)
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(V3Tokens.faintText)
            Text("Henüz hiç şarkı paylaşmadın")
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Data

    private func loadEntries() {
        let request = NSFetchRequest<DailySong>(entityName: "DailySong")
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date.distantPast
        request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        entries = (try? context.fetch(request)) ?? []
    }

    private func pick(_ entry: DailySong) {
        let song = PinnedSong(
            songName: entry.songName ?? "Bilinmeyen",
            artistName: entry.artistName ?? "",
            artworkURLString: entry.artworkURL,
            moodColorHex: entry.moodColorHex,
            pinnedAt: Date()
        )
        onSelect(song)
        dismiss()
    }
}
