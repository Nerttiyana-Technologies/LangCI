// GRDBMilestoneService.swift
// LangCI

import Foundation
import GRDB

final class GRDBMilestoneService: MilestoneService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Get all

    func getAll() async throws -> [MilestoneEntry] {
        try await db.read { database in
            let rows = try Row.fetchAll(database,
                sql: "SELECT * FROM milestone_entry ORDER BY achieved_at ASC")
            return try rows.map { try MilestoneEntry(row: $0) }
        }
    }

    // MARK: - Get activation

    func getActivation() async throws -> MilestoneEntry? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database, sql: """
                SELECT * FROM milestone_entry WHERE type = ? LIMIT 1
            """, arguments: [MilestoneType.activation.rawValue])
            else { return nil }
            return try MilestoneEntry(row: row)
        }
    }

    // MARK: - Get latest of type

    func getLatest(of type: MilestoneType) async throws -> MilestoneEntry? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database, sql: """
                SELECT * FROM milestone_entry
                WHERE type = ?
                ORDER BY achieved_at DESC
                LIMIT 1
            """, arguments: [type.rawValue])
            else { return nil }
            return try MilestoneEntry(row: row)
        }
    }

    // MARK: - Save

    func save(_ entry: MilestoneEntry) async throws -> MilestoneEntry {
        try await db.write { database -> MilestoneEntry in
            var saved = entry

            if entry.id == 0 {
                try database.execute(sql: """
                    INSERT INTO milestone_entry
                        (type, achieved_at, accuracy_at_milestone, description, notes, emoji)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    entry.type.rawValue,
                    entry.achievedAt.timeIntervalSince1970,
                    entry.accuracyAtMilestone,
                    entry.description,
                    entry.notes,
                    entry.emoji
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE milestone_entry
                    SET type = ?, achieved_at = ?, accuracy_at_milestone = ?,
                        description = ?, notes = ?, emoji = ?
                    WHERE id = ?
                """, arguments: [
                    entry.type.rawValue,
                    entry.achievedAt.timeIntervalSince1970,
                    entry.accuracyAtMilestone,
                    entry.description,
                    entry.notes,
                    entry.emoji,
                    entry.id
                ])
            }
            return saved
        }
    }

    // MARK: - Delete

    func delete(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM milestone_entry WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Auto check (hearing-age milestones)

    func autoCheck() async throws {
        let all = try await getAll()
        let existingTypes = Set(all.map { $0.type })

        let activation = all.first(where: { $0.type == .activation })
        guard let activation else { return }

        let days  = getDaysSinceActivation(activation)
        let today = Date()

        let checksToAdd: [(type: MilestoneType, threshold: Int)] = [
            (.week1Check,  7),
            (.month1Check, 30),
            (.month3Check, 90),
            (.month6Check, 180),
            (.year1Check,  365),
        ]

        for check in checksToAdd where !existingTypes.contains(check.type) {
            if days >= check.threshold {
                var entry   = MilestoneEntry(id: 0, type: check.type, achievedAt: today)
                entry.emoji = entry.defaultEmoji
                _ = try await save(entry)
            }
        }
    }

    // MARK: - Auto detect firsts (v3.1)

    /// Scans every feature table for the earliest row and inserts a
    /// matching "first X" milestone if one doesn't already exist.
    /// Idempotent and cheap — each query is a simple MIN() lookup.
    func autoDetectFirsts() async throws {
        // Build a snapshot of which singleton types already exist
        // so we don't re-query the database for each one.
        let existing = try await db.read { database -> Set<Int> in
            let rows = try Row.fetchAll(database,
                sql: "SELECT DISTINCT type FROM milestone_entry")
            return Set(rows.compactMap { $0["type"] as Int? })
        }

        // Also pre-load the single-row user_progress so we can decide
        // on firstBadgeEarned / first100Points without extra reads.
        let (totalPoints, firstBadgeAt) = try await db.read { database -> (Int, Date?) in
            let points = try Int.fetchOne(database,
                sql: "SELECT total_points FROM user_progress WHERE id = 1") ?? 0
            let badgeTs = try Double.fetchOne(database,
                sql: "SELECT MIN(earned_at) FROM user_badge")
            let badgeDate = badgeTs.map { Date(timeIntervalSince1970: $0) }
            return (points, badgeDate)
        }

        // Mapping of milestone type → SQL that returns the earliest
        // timestamp (as Double) for that data source, or nil.
        let probes: [(type: MilestoneType, sql: String)] = [
            (.firstTrainingSession, "SELECT MIN(started_at)   FROM training_session"),
            (.firstAVTSession,      "SELECT MIN(started_at)   FROM avt_session"),
            (.firstLing6Session,    "SELECT MIN(tested_at)    FROM ling6_session"),
            (.firstMappingSession,  "SELECT MIN(session_date) FROM mapping_session"),
            (.firstFatigueLog,      "SELECT MIN(logged_at)    FROM fatigue_entry"),
            (.firstConfusionLogged, "SELECT MIN(logged_at)    FROM confusion_pair"),
            (.firstReadingAloud,    "SELECT MIN(recorded_at)  FROM reading_session"),
        ]

        for probe in probes where !existing.contains(probe.type.rawValue) {
            let ts: Double? = try await db.read { database in
                try Double.fetchOne(database, sql: probe.sql)
            }
            guard let ts else { continue }
            let date = Date(timeIntervalSince1970: ts)
            try await insertFirstMilestone(type: probe.type, at: date, accuracy: nil)
        }

        // Badge & points milestones — these don't come from a time
        // column directly, so we key off user_progress + user_badge.
        if !existing.contains(MilestoneType.firstBadgeEarned.rawValue),
           let badgeDate = firstBadgeAt {
            try await insertFirstMilestone(
                type: .firstBadgeEarned,
                at: badgeDate,
                accuracy: nil
            )
        }

        if !existing.contains(MilestoneType.first100Points.rawValue),
           totalPoints >= 100 {
            try await insertFirstMilestone(
                type: .first100Points,
                at: Date(),
                accuracy: nil
            )
        }
    }

    @discardableResult
    func markFirstIfMissing(
        _ type: MilestoneType,
        at date: Date,
        accuracy: Double?
    ) async throws -> MilestoneEntry {
        if let existing = try await getLatest(of: type), type.isSingleton {
            return existing
        }
        return try await insertFirstMilestone(type: type, at: date, accuracy: accuracy)
    }

    @discardableResult
    private func insertFirstMilestone(
        type: MilestoneType,
        at date: Date,
        accuracy: Double?
    ) async throws -> MilestoneEntry {
        var entry = MilestoneEntry(
            id: 0,
            type: type,
            achievedAt: date,
            accuracyAtMilestone: accuracy,
            description: "",
            notes: nil,
            emoji: "🎉"
        )
        entry.emoji = entry.defaultEmoji
        return try await save(entry)
    }

    // MARK: - Helpers

    func getDaysSinceActivation(_ activation: MilestoneEntry?) -> Int {
        guard let activation else { return 0 }
        return Int(Date().timeIntervalSince(activation.achievedAt) / 86_400)
    }

    func getHearingAgeLabel(_ activation: MilestoneEntry?) -> String {
        let days = getDaysSinceActivation(activation)
        guard days > 0 else { return "Activation date not set" }
        let months = days / 30
        let rem    = days % 30
        if months == 0 { return "\(days) days" }
        if months == 1 { return "1 month \(rem) days" }
        return "\(months) months \(rem) days"
    }
}
