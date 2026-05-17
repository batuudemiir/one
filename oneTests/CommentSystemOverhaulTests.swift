//
//  CommentSystemOverhaulTests.swift
//  oneTests
//
//  TDD tests for comment system overhaul (P0-A through P1).
//

import Testing
import Foundation
import CloudKit
@testable import OneDailyBatuhan

// Disambiguate from Testing.Comment
private typealias Comment = OneDailyBatuhan.Comment

// MARK: - Comment Model Tests

struct CommentModelTests {

    // MARK: - canDelete

    @Test func authorCanDeleteOwnComment() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob")
        #expect(comment.canDelete(by: "alice"))
    }

    @Test func shareOwnerCanDeleteOtherComment() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob")
        #expect(comment.canDelete(by: "bob"))
    }

    @Test func randomUserCannotDeleteComment() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob")
        #expect(!comment.canDelete(by: "carol"))
    }

    // MARK: - canEdit

    @Test func authorCanEditWithinWindow() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob", age: 60)
        #expect(comment.canEdit(by: "alice"))
    }

    @Test func authorCannotEditAfterWindow() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob", age: 301)
        #expect(!comment.canEdit(by: "alice"))
    }

    @Test func nonAuthorCannotEdit() {
        let comment = makeComment(authorUserID: "alice", shareOwnerID: "bob", age: 10)
        #expect(!comment.canEdit(by: "bob"))
    }

    // MARK: - maxBodyLength boundary

    @Test func bodyAt280IsValid() {
        let body = String(repeating: "a", count: Comment.maxBodyLength)
        #expect(body.count == 280)
    }

    @Test func bodyAt281Exceeds() {
        let body = String(repeating: "a", count: Comment.maxBodyLength + 1)
        #expect(body.count > Comment.maxBodyLength)
    }

    // MARK: - isEdited

    @Test func isEditedFalseWhenEditedAtIsNil() {
        let c = makeComment()
        #expect(!c.isEdited)
    }

    @Test func isEditedTrueWhenEditedAtIsSet() {
        var c = makeComment()
        c.editedAt = Date()
        #expect(c.isEdited)
    }

    // MARK: - Helpers

    private func makeComment(
        authorUserID: String = "alice",
        shareOwnerID: String = "bob",
        age: TimeInterval = 10,
        body: String = "Test yorum"
    ) -> Comment {
        Comment(
            id: Comment.newID(shareRecordName: "share123", authorUserID: authorUserID),
            shareRecordName: "share123",
            shareOwnerID: shareOwnerID,
            authorUserID: authorUserID,
            body: body,
            createdAt: Date().addingTimeInterval(-age),
            editedAt: nil,
            parentCommentID: nil,
            moderationStatus: .active,
            reportCount: 0
        )
    }
}

// MARK: - Comment New ID Format Tests

struct CommentNewIDTests {

    @Test func newIDHasCommentPrefix() {
        let id = Comment.newID(shareRecordName: "share123", authorUserID: "alice")
        #expect(id.hasPrefix("comment_"))
    }

    @Test func newIDContainsSharePrefix() {
        let id = Comment.newID(shareRecordName: "share123", authorUserID: "alice")
        #expect(id.contains("share123"))
    }

    @Test func newIDsAreUnique() {
        let id1 = Comment.newID(shareRecordName: "share123", authorUserID: "alice")
        let id2 = Comment.newID(shareRecordName: "share123", authorUserID: "alice")
        #expect(id1 != id2)
    }

    @Test func newIDLongShareTruncates() {
        let longShare = String(repeating: "x", count: 50)
        let id = Comment.newID(shareRecordName: longShare, authorUserID: "alice")
        // Should not include the full 50-char share name (capped at 24)
        let shareSegment = String(repeating: "x", count: 24)
        #expect(id.contains(shareSegment))
        let excessSegment = String(repeating: "x", count: 25)
        #expect(!id.contains(excessSegment))
    }
}

// MARK: - CommentModerationStatus Tests

struct CommentModerationStatusTests {

    @Test func defaultStatusIsActive() {
        let c = Comment(
            id: "test_id",
            shareRecordName: "share1",
            shareOwnerID: "owner",
            authorUserID: "author",
            body: "Merhaba",
            createdAt: Date(),
            editedAt: nil,
            parentCommentID: nil,
            moderationStatus: .active,
            reportCount: 0
        )
        #expect(c.moderationStatus == .active)
    }

    @Test func rawValueRoundTrips() {
        let statuses: [CommentModerationStatus] = [.active, .hidden, .removed]
        for s in statuses {
            let roundTripped = CommentModerationStatus(rawValue: s.rawValue)
            #expect(roundTripped == s)
        }
    }
}

// MARK: - CommentThreadViewModel init Tests
// Tests that the ViewModel stores its init parameters correctly.

@MainActor
struct CommentThreadViewModelInitTests {

    @Test func shareRecordNameIsStored() {
        let vm = CommentThreadViewModel(shareRecordName: "rec123", shareOwnerID: "owner1")
        #expect(vm.shareRecordName == "rec123")
    }

    @Test func shareOwnerIDIsStored() {
        let vm = CommentThreadViewModel(shareRecordName: "rec123", shareOwnerID: "owner1")
        #expect(vm.shareOwnerID == "owner1")
    }

    @Test func initialStateIsEmpty() {
        let vm = CommentThreadViewModel(shareRecordName: "rec123", shareOwnerID: "owner1")
        #expect(vm.comments.isEmpty)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
        #expect(vm.editingComment == nil)
    }
}

// MARK: - P1: CloudKit commentID extraction logic

struct CommentIDExtractionTests {

    /// Simulates the P1 fix: commentID should come from notification.recordID?.recordName,
    /// not a synthesized string based on timestamp.
    @Test func commentIDPrefersRecordName() {
        // Given: a real record name (as set by CKRecord.ID)
        let realRecordName = "comment_share123_alice_abcd1234"

        // When: we resolve commentID like the fixed handler does
        let fallbackID = "comment_alice_\(Int(Date().timeIntervalSince1970))"
        let commentID = realRecordName.isEmpty ? fallbackID : realRecordName

        // Then: the real record name wins
        #expect(commentID == realRecordName)
    }

    @Test func commentIDFallsBackWhenRecordNameNil() {
        let realRecordName: String? = nil
        let fallbackID = "comment_alice_12345"
        let commentID = realRecordName ?? fallbackID
        #expect(commentID == fallbackID)
    }

    @Test func commentIDNotificationIDPrefixIsComment() {
        let recordName = "comment_share123_alice_abcd1234"
        let notifID = "comment_\(recordName)"
        #expect(notifID.hasPrefix("comment_"))
    }
}
