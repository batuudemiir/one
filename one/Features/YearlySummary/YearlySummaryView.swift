//
//  YearlySummaryView.swift
//  one
//
//  12 ay özet ekranı.
//

import SwiftUI
import CoreData

struct YearlySummaryView: View {
    @StateObject private var viewModel: YearlySummaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var exportedURL: URL?

    private let year: Int
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext, year: Int = Calendar.current.component(.year, from: Date())) {
        self.context = context
        self.year = year
        _viewModel = StateObject(wrappedValue: YearlySummaryViewModel(context: context, year: year))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView().padding(80)
                } else if let data = viewModel.data {
                    content(data: data)
                }
            }
            .background(ONEBrand.bone.ignoresSafeArea())
            .navigationTitle(String(year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .font(.custom("GeistMono-Regular", size: 13))
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.data != nil {
                        Button(action: exportJSON) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .light))
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    @ViewBuilder
    private func content(data: YearlySummaryData) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("yearly.title", comment: ""))
                    .monoBase(tracking: 2.0)
                    .foregroundColor(V3Tokens.mutedText)
                Text("\(data.year)")
                    .font(.custom("GeistMono-Regular", size: 48))
                    .foregroundColor(V3Tokens.ink)
                Text(data.dominantMood.uppercased())
                    .font(.custom("GeistMono-Regular", size: 13))
                    .tracking(2.0)
                    .foregroundColor(data.dominantMoodColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Stat grid
            statGrid(data: data)
                .padding(.horizontal, 20)

            // Monthly mood strip
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("yearly.monthlyMoods", comment: ""))
                    .font(.custom("GeistMono-Regular", size: 11))
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.mutedText)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(0..<12, id: \.self) { m in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(data.monthlyMoodColors[m])
                                .frame(height: 44)
                                .overlay(
                                    Text("\(data.monthlyEntryCounts[m])")
                                        .font(.custom("GeistMono-Regular", size: 10))
                                        .foregroundColor(.white.opacity(0.9))
                                )
                            Text(monthShort(m + 1))
                                .font(.custom("GeistMono-Regular", size: 9))
                                .foregroundColor(V3Tokens.mutedText)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Top tracks
            if !data.topTracks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("yearly.topTracks", comment: ""))
                        .font(.custom("GeistMono-Regular", size: 11))
                        .tracking(1.4)
                        .foregroundColor(V3Tokens.mutedText)

                    VStack(spacing: 0) {
                        ForEach(data.topTracks) { track in
                            trackRow(track)
                            if track.id != data.topTracks.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .background(V3Tokens.surface.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .padding(.horizontal, 20)
            }

            // Top artists
            if !data.topArtists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("yearly.topArtists", comment: ""))
                        .font(.custom("GeistMono-Regular", size: 11))
                        .tracking(1.4)
                        .foregroundColor(V3Tokens.mutedText)

                    VStack(spacing: 8) {
                        ForEach(Array(data.topArtists.enumerated()), id: \.offset) { idx, a in
                            HStack {
                                Text("\(idx + 1).")
                                    .font(.custom("GeistMono-Regular", size: 11))
                                    .foregroundColor(V3Tokens.faintText)
                                    .frame(width: 24, alignment: .leading)
                                Text(a.name)
                                    .font(.custom("GeistMono-Regular", size: 13))
                                    .foregroundColor(V3Tokens.ink)
                                Spacer()
                                Text("\(a.days)")
                                    .font(.custom("GeistMono-Regular", size: 11))
                                    .foregroundColor(V3Tokens.mutedText)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 60)
        }
    }

    private func statGrid(data: YearlySummaryData) -> some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            statCell(value: "\(data.daysLogged)", label: NSLocalizedString("yearly.daysLogged", comment: ""))
            statCell(value: "\(data.totalEntries)", label: NSLocalizedString("yearly.totalEntries", comment: ""))
            statCell(value: "\(data.uniqueArtists)", label: NSLocalizedString("yearly.uniqueArtists", comment: ""))
            statCell(value: "\(data.uniqueSongs)", label: NSLocalizedString("yearly.uniqueSongs", comment: ""))
            statCell(value: "\(data.longestStreak)", label: NSLocalizedString("yearly.longestStreak", comment: ""))
            statCell(value: data.dominantMood, label: NSLocalizedString("yearly.dominantMood", comment: ""))
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.custom("GeistMono-Regular", size: 22))
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.custom("GeistMono-Regular", size: 9))
                .tracking(1.0)
                .foregroundColor(V3Tokens.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(V3Tokens.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private func trackRow(_ t: TrackEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(t.rank).")
                .font(.custom("GeistMono-Regular", size: 11))
                .foregroundColor(V3Tokens.faintText)
                .frame(width: 24, alignment: .leading)
            Text(t.emoji)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.name)
                    .font(.custom("GeistMono-Regular", size: 13))
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(1)
                Text(t.artist)
                    .font(.custom("GeistMono-Regular", size: 10))
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(t.days)×")
                .font(.custom("GeistMono-Regular", size: 11))
                .foregroundColor(V3Tokens.mutedText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func monthShort(_ m: Int) -> String {
        let df = DateFormatter()
        df.locale = LanguageManager.shared.currentLocale
        df.dateFormat = "MMM"
        var c = DateComponents(); c.year = 2000; c.month = m; c.day = 1
        guard let d = Calendar.current.date(from: c) else { return "" }
        return df.string(from: d).uppercased()
    }

    // MARK: - JSON Export

    private func exportJSON() {
        guard let data = viewModel.data else { return }
        guard let url = TasteProfileExporter.exportJSON(data: data) else { return }
        exportedURL = url
        showShareSheet = true
    }
}
