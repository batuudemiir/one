//  MoodAdjacencyMap.swift
//  one

import Foundation

enum MoodAdjacency {
    private static let adjacent: [String: [String]] = [
        "Ateşli":    ["Coşkulu", "Özgür"],
        "Coşkulu":   ["Ateşli", "Mutlu"],
        "Mutlu":     ["Coşkulu", "Doğal"],
        "Doğal":     ["Huzurlu", "Özgür"],
        "Huzurlu":   ["Sessiz", "Doğal"],
        "Özgür":     ["Doğal", "Ateşli"],
        "Derin":     ["Gizemli", "Nostaljik"],
        "Nostaljik": ["Derin", "Hassas"],
        "Gizemli":   ["Derin", "Sessiz"],
        "Hassas":    ["Sessiz", "Nostaljik"],
        "Sessiz":    ["Huzurlu", "Hassas"],
        "Nötr":      ["Huzurlu", "Doğal"]
    ]

    private static let contrast: [String: String] = [
        "Ateşli":    "Huzurlu",
        "Coşkulu":   "Sessiz",
        "Mutlu":     "Derin",
        "Doğal":     "Gizemli",
        "Huzurlu":   "Ateşli",
        "Özgür":     "Hassas",
        "Derin":     "Mutlu",
        "Nostaljik": "Coşkulu",
        "Gizemli":   "Mutlu",
        "Hassas":    "Özgür",
        "Sessiz":    "Coşkulu",
        "Nötr":      "Ateşli"
    ]

    static func neighbors(for mood: String) -> [String] {
        adjacent[canonicalMoodLabel(mood)] ?? []
    }

    static func contrastMood(for mood: String) -> String? {
        contrast[canonicalMoodLabel(mood)]
    }
}
