// GRDBConfusionPairService.swift
// LangCI

import Foundation
import GRDB

final class GRDBConfusionPairService: ConfusionPairService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - CRUD

    func logPair(_ pair: ConfusionPair) async throws -> ConfusionPair {
        try await db.write { database -> ConfusionPair in
            var saved = pair
            if pair.id == 0 {
                try database.execute(sql: """
                    INSERT INTO confusion_pair
                        (said_word, heard_word, target_sound, source,
                         avt_session_id, context_note, logged_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    pair.saidWord,
                    pair.heardWord,
                    pair.targetSound,
                    pair.source.rawValue,
                    pair.avtSessionId,
                    pair.contextNote,
                    pair.loggedAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE confusion_pair
                    SET said_word = ?, heard_word = ?, target_sound = ?,
                        source = ?, avt_session_id = ?, context_note = ?,
                        logged_at = ?
                    WHERE id = ?
                """, arguments: [
                    pair.saidWord,
                    pair.heardWord,
                    pair.targetSound,
                    pair.source.rawValue,
                    pair.avtSessionId,
                    pair.contextNote,
                    pair.loggedAt.timeIntervalSince1970,
                    pair.id
                ])
            }
            return saved
        }
    }

    func deletePair(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM confusion_pair WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Queries

    func getRecentPairs(limit: Int) async throws -> [ConfusionPair] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM confusion_pair
                ORDER BY logged_at DESC
                LIMIT ?
            """, arguments: [limit])
            return try rows.map { try ConfusionPair(row: $0) }
        }
    }

    func getPairsForSession(_ sessionId: Int) async throws -> [ConfusionPair] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM confusion_pair
                WHERE avt_session_id = ?
                ORDER BY logged_at DESC
            """, arguments: [sessionId])
            return try rows.map { try ConfusionPair(row: $0) }
        }
    }

    func getPairsForSound(_ sound: String) async throws -> [ConfusionPair] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM confusion_pair
                WHERE target_sound = ?
                ORDER BY logged_at DESC
            """, arguments: [sound])
            return try rows.map { try ConfusionPair(row: $0) }
        }
    }

    // MARK: - Aggregations

    func getTopConfusions(limit: Int, days: Int?) async throws -> [ConfusionStatDto] {
        let cutoff: Double? = days.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())!
                .timeIntervalSince1970
        }

        return try await db.read { database in
            let sql: String
            let args: StatementArguments
            if let cutoff = cutoff {
                sql = """
                    SELECT
                        LOWER(TRIM(said_word))  AS said,
                        LOWER(TRIM(heard_word)) AS heard,
                        COUNT(*)                AS cnt,
                        MAX(logged_at)          AS most_recent
                    FROM confusion_pair
                    WHERE logged_at >= ? AND said_word != '' AND heard_word != ''
                    GROUP BY said, heard
                    ORDER BY cnt DESC, most_recent DESC
                    LIMIT ?
                """
                args = [cutoff, limit]
            } else {
                sql = """
                    SELECT
                        LOWER(TRIM(said_word))  AS said,
                        LOWER(TRIM(heard_word)) AS heard,
                        COUNT(*)                AS cnt,
                        MAX(logged_at)          AS most_recent
                    FROM confusion_pair
                    WHERE said_word != '' AND heard_word != ''
                    GROUP BY said, heard
                    ORDER BY cnt DESC, most_recent DESC
                    LIMIT ?
                """
                args = [limit]
            }
            let rows = try Row.fetchAll(database, sql: sql, arguments: args)
            return rows.map { r in
                ConfusionStatDto(
                    saidWord:   r["said"]  ?? "",
                    heardWord:  r["heard"] ?? "",
                    count:      r["cnt"]   ?? 0,
                    mostRecent: Date(timeIntervalSince1970: r["most_recent"] ?? 0)
                )
            }
        }
    }

    func getCount(days: Int?) async throws -> Int {
        let cutoff: Double? = days.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())!
                .timeIntervalSince1970
        }
        return try await db.read { database in
            if let cutoff = cutoff {
                return try Int.fetchOne(database, sql: """
                    SELECT COUNT(*) FROM confusion_pair WHERE logged_at >= ?
                """, arguments: [cutoff]) ?? 0
            }
            return try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM confusion_pair
            """) ?? 0
        }
    }
}
