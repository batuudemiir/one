//
//  PinnedSong.swift
//  one
//
//  Bir kullanıcının profilinde sabitlenmiş şarkı.
//  CloudKit AppUser record'unda "pinnedSongData" alanında JSON olarak saklanır.
//

import Foundation

struct PinnedSong: Codable, Equatable {
    var schemaVersion: Int = 1
    let songName: String
    let artistName: String
    let artworkURLString: String?
    let moodColorHex: String?
    let pinnedAt: Date

    // MARK: - JSON Helpers

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSONString(_ s: String) -> PinnedSong? {
        guard !s.isEmpty, let data = s.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PinnedSong.self, from: data)
    }
}
