// GRDBFamilyMemberService.swift
// LangCI

import Foundation
import GRDB

final class GRDBFamilyMemberService: FamilyMemberService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    func getAllMembers() async throws -> [FamilyMember] {
        try await db.read { database in
            let rows = try Row.fetchAll(database,
                sql: "SELECT * FROM family_member ORDER BY name")
            return try rows.map { try FamilyMember(row: $0) }
        }
    }

    func getMember(id: Int) async throws -> FamilyMember? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM family_member WHERE id = ?", arguments: [id])
            else { return nil }
            return try FamilyMember(row: row)
        }
    }

    func saveMember(_ member: FamilyMember) async throws -> FamilyMember {
        try await db.write { database -> FamilyMember in
            var saved = member

            // Guard against FK violations: if the caller didn't pick a dialect
            // (or picked one that isn't in the dialect table), fall back to the
            // first active dialect. The v4 migration seeds English + Tamil
            // dialects, so there should always be at least one available.
            let resolvedDialectId = try Self.resolvePreferredDialectId(
                member.preferredDialectId, db: database)
            saved.preferredDialectId = resolvedDialectId

            if saved.id == 0 {
                try database.execute(sql: """
                    INSERT INTO family_member
                        (name, relationship, avatar_initials, avatar_color_hex,
                         preferred_dialect_id, baseline_frequency_hz, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    saved.name,
                    saved.relationship,
                    saved.avatarInitials,
                    saved.avatarColorHex,
                    saved.preferredDialectId,
                    saved.baselineFrequencyHz,
                    saved.createdAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE family_member
                    SET name = ?, relationship = ?, avatar_initials = ?,
                        avatar_color_hex = ?, preferred_dialect_id = ?,
                        baseline_frequency_hz = ?
                    WHERE id = ?
                """, arguments: [
                    saved.name,
                    saved.relationship,
                    saved.avatarInitials,
                    saved.avatarColorHex,
                    saved.preferredDialectId,
                    saved.baselineFrequencyHz,
                    saved.id
                ])
            }
            return saved
        }
    }

    /// Returns a dialect id that is guaranteed to exist in the `dialect`
    /// table. If `requestedId` is valid it is returned unchanged; otherwise
    /// this falls back to the first active dialect (preferring English for
    /// consistency with the default UI language). Throws if the dialect
    /// table is completely empty, which should never happen in practice
    /// because the v4 migration seeds the baseline set.
    private static func resolvePreferredDialectId(
        _ requestedId: Int, db database: Database
    ) throws -> Int {
        if requestedId > 0 {
            let exists = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM dialect WHERE id = ?",
                arguments: [requestedId]) ?? 0
            if exists > 0 { return requestedId }
        }
        // Prefer an English dialect, fall back to any active dialect.
        if let enDialectId = try Int.fetchOne(database, sql: """
            SELECT d.id FROM dialect d
            JOIN language l ON l.id = d.language_id
            WHERE l.code = 'en' AND d.is_active = 1
            ORDER BY d.id
            LIMIT 1
        """) {
            return enDialectId
        }
        if let anyDialectId = try Int.fetchOne(database, sql: """
            SELECT id FROM dialect WHERE is_active = 1
            ORDER BY id LIMIT 1
        """) {
            return anyDialectId
        }
        throw NSError(
            domain: "LangCI.FamilyMemberService",
            code: 19,
            userInfo: [NSLocalizedDescriptionKey:
                "No dialects available to assign to this family member."]
        )
    }

    func deleteMember(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM family_member WHERE id = ?", arguments: [id])
        }
    }

    func getMemberCount() async throws -> Int {
        try await db.read { database in
            try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM family_member") ?? 0
        }
    }

    func getTotalRecordingCount() async throws -> Int {
        try await db.read { database in
            try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM recording WHERE is_approved = 1") ?? 0
        }
    }
}
