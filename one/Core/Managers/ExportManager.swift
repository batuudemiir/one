//
//  ExportManager.swift
//  one
//
//  Exports all DailySong records to CSV or JSON for the user.
//

import Foundation
import CoreData
import UIKit

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv  = "CSV"
    case json = "JSON"
    var id: String { rawValue }

    var mimeType: String {
        switch self {
        case .csv:  return "text/csv"
        case .json: return "application/json"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv:  return "csv"
        case .json: return "json"
        }
    }
}

// MARK: - ExportManager

final class ExportManager {
    static let shared = ExportManager()
    private init() {}

    // MARK: - Public

    /// Fetch all DailySong records, serialise to the requested format, write a temp file, and return its URL.
    func exportAll(format: ExportFormat, context: NSManagedObjectContext) throws -> URL {
        let songs = try fetchAllSongs(context: context)

        let data: Data
        switch format {
        case .csv:  data = try buildCSV(songs: songs)
        case .json: data = try buildJSON(songs: songs)
        }

        return try writeTempFile(data: data, name: filename(format: format), ext: format.fileExtension)
    }

    // MARK: - Fetch

    private func fetchAllSongs(context: NSManagedObjectContext) throws -> [DailySong] {
        let request: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailySong.date, ascending: true)]
        return try context.fetch(request)
    }

    // MARK: - CSV

    private func buildCSV(songs: [DailySong]) throws -> Data {
        var lines: [String] = []

        // Header
        lines.append("date,songName,artistName,moodWord,moodColorHex,feeling,note,platform")

        // Rows
        let df = ISO8601DateFormatter()
        for song in songs {
            let row: [String] = [
                song.date.map { df.string(from: $0) } ?? "",
                csvEscape(song.songName ?? ""),
                csvEscape(song.artistName ?? ""),
                csvEscape(song.moodWord ?? ""),
                csvEscape(song.moodColorHex ?? ""),
                csvEscape(song.feeling ?? ""),
                csvEscape(song.dailyNote ?? ""),
                csvEscape(song.platform ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - JSON

    private func buildJSON(songs: [DailySong]) throws -> Data {
        let df = ISO8601DateFormatter()
        let entries: [[String: Any]] = songs.map { song in
            var dict: [String: Any] = [:]
            dict["date"]         = song.date.map { df.string(from: $0) } ?? NSNull()
            dict["songName"]     = song.songName     ?? NSNull()
            dict["artistName"]   = song.artistName   ?? NSNull()
            dict["moodWord"]     = song.moodWord     ?? NSNull()
            dict["moodColorHex"] = song.moodColorHex ?? NSNull()
            dict["feeling"]      = song.feeling      ?? NSNull()
            dict["note"]         = song.dailyNote    ?? NSNull()
            dict["platform"]     = song.platform     ?? NSNull()
            return dict
        }

        let wrapper: [String: Any] = [
            "app":        "ONE",
            "exportedAt": df.string(from: Date()),
            "count":      entries.count,
            "entries":    entries
        ]

        return try JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - File I/O

    private func filename(format: ExportFormat) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "one-export-\(df.string(from: Date()))"
    }

    private func writeTempFile(data: Data, name: String, ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(name).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Error

enum ExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Dışa aktarma sırasında bir kodlama hatası oluştu."
        }
    }
}
