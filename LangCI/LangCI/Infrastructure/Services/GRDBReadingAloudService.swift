// GRDBReadingAloudService.swift
// LangCI

import Foundation
import GRDB

final class GRDBReadingAloudService: ReadingAloudService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Passages

    func getAllPassages() async throws -> [ReadingPassage] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM reading_passage
                ORDER BY is_bundled DESC, difficulty ASC, title ASC
            """)
            return try rows.map { try ReadingPassage(row: $0) }
        }
    }

    func getBundledPassages() async throws -> [ReadingPassage] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM reading_passage
                WHERE is_bundled = 1
                ORDER BY difficulty ASC, title ASC
            """)
            return try rows.map { try ReadingPassage(row: $0) }
        }
    }

    func savePassage(_ passage: ReadingPassage) async throws -> ReadingPassage {
        try await db.write { database -> ReadingPassage in
            var saved = passage
            if passage.id == 0 {
                try database.execute(sql: """
                    INSERT INTO reading_passage
                        (title, category, difficulty, body, word_count,
                         is_bundled, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    passage.title,
                    passage.category.rawValue,
                    passage.difficulty,
                    passage.body,
                    passage.wordCount,
                    passage.isBundled ? 1 : 0,
                    passage.createdAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE reading_passage
                    SET title = ?, category = ?, difficulty = ?, body = ?,
                        word_count = ?, is_bundled = ?
                    WHERE id = ?
                """, arguments: [
                    passage.title,
                    passage.category.rawValue,
                    passage.difficulty,
                    passage.body,
                    passage.wordCount,
                    passage.isBundled ? 1 : 0,
                    passage.id
                ])
            }
            return saved
        }
    }

    func deletePassage(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM reading_passage WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Sessions

    func saveSession(_ session: ReadingSession) async throws -> ReadingSession {
        try await db.write { database -> ReadingSession in
            var saved = session
            if session.id == 0 {
                try database.execute(sql: """
                    INSERT INTO reading_session
                        (passage_id, passage_title, passage_body, word_count,
                         duration_seconds, words_per_minute, avg_loudness_db,
                         peak_loudness_db, audio_file_path, notes, recorded_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    session.passageId,
                    session.passageTitle,
                    session.passageBody,
                    session.wordCount,
                    session.durationSeconds,
                    session.wordsPerMinute,
                    session.avgLoudnessDb,
                    session.peakLoudnessDb,
                    session.audioFilePath,
                    session.notes,
                    session.recordedAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE reading_session
                    SET passage_id = ?, passage_title = ?, passage_body = ?,
                        word_count = ?, duration_seconds = ?, words_per_minute = ?,
                        avg_loudness_db = ?, peak_loudness_db = ?,
                        audio_file_path = ?, notes = ?, recorded_at = ?
                    WHERE id = ?
                """, arguments: [
                    session.passageId,
                    session.passageTitle,
                    session.passageBody,
                    session.wordCount,
                    session.durationSeconds,
                    session.wordsPerMinute,
                    session.avgLoudnessDb,
                    session.peakLoudnessDb,
                    session.audioFilePath,
                    session.notes,
                    session.recordedAt.timeIntervalSince1970,
                    session.id
                ])
            }
            return saved
        }
    }

    func deleteSession(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM reading_session WHERE id = ?", arguments: [id])
        }
    }

    func getRecentSessions(limit: Int) async throws -> [ReadingSession] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM reading_session
                ORDER BY recorded_at DESC
                LIMIT ?
            """, arguments: [limit])
            return try rows.map { try ReadingSession(row: $0) }
        }
    }

    func getSessionsForPassage(_ passageId: Int) async throws -> [ReadingSession] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM reading_session
                WHERE passage_id = ?
                ORDER BY recorded_at DESC
            """, arguments: [passageId])
            return try rows.map { try ReadingSession(row: $0) }
        }
    }

    // MARK: - Stats

    func getStats(days: Int?) async throws -> ReadingStatsDto {
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
                        COUNT(*) AS cnt,
                        AVG(words_per_minute) AS avg_wpm,
                        AVG(avg_loudness_db) AS avg_db,
                        MAX(words_per_minute) AS best_wpm,
                        MAX(recorded_at) AS last_at
                    FROM reading_session
                    WHERE recorded_at >= ?
                """
                args = [cutoff]
            } else {
                sql = """
                    SELECT
                        COUNT(*) AS cnt,
                        AVG(words_per_minute) AS avg_wpm,
                        AVG(avg_loudness_db) AS avg_db,
                        MAX(words_per_minute) AS best_wpm,
                        MAX(recorded_at) AS last_at
                    FROM reading_session
                """
                args = []
            }
            guard let row = try Row.fetchOne(database, sql: sql, arguments: args) else {
                return ReadingStatsDto(sessionCount: 0, avgWordsPerMinute: 0,
                                       avgLoudnessDb: 0, bestWpm: 0, lastRecordedAt: nil)
            }
            let lastAt: Double? = row["last_at"]
            return ReadingStatsDto(
                sessionCount:      row["cnt"] ?? 0,
                avgWordsPerMinute: row["avg_wpm"] ?? 0,
                avgLoudnessDb:     row["avg_db"] ?? 0,
                bestWpm:           row["best_wpm"] ?? 0,
                lastRecordedAt:    lastAt.map { Date(timeIntervalSince1970: $0) }
            )
        }
    }
}
