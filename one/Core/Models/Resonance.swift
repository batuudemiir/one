//
//  Resonance.swift
//  one
//
//  v2.6 — Mood-based social interaction (Resonance)
//

import Foundation
import CloudKit

struct Resonance: Identifiable, Equatable {
    let id: String
    let recordID: CKRecord.ID
    let senderID: String
    let receiverID: String
    let shareRecordID: CKRecord.Reference
    let moodColor: String
    let moodWord: String
    let songSuggestionID: String?
    let songSuggestionName: String?
    let songSuggestionArtist: String?
    let createdAt: Date
    var senderDisplayName: String?
    
    init?(record: CKRecord) {
        guard record.recordType == "Resonance",
              let senderID = record["senderID"] as? String,
              let receiverID = record["receiverID"] as? String,
              let shareRef = record["shareID"] as? CKRecord.Reference,
              let moodColor = record["moodColor"] as? String,
              let moodWord = record["moodWord"] as? String,
              let createdAt = record.creationDate else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.recordID = record.recordID
        self.senderID = senderID
        self.receiverID = receiverID
        self.shareRecordID = shareRef
        self.moodColor = moodColor
        self.moodWord = moodWord
        self.songSuggestionID = record["songSuggestionID"] as? String
        self.songSuggestionName = record["songSuggestionName"] as? String
        self.songSuggestionArtist = record["songSuggestionArtist"] as? String
        self.createdAt = createdAt
    }
}
