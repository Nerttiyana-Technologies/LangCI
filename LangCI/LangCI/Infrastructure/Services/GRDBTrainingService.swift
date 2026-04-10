// GRDBTrainingService.swift
// LangCI

import Foundation
import GRDB

final class GRDBTrainingService: TrainingService {

    private let db: DatabaseQueue
    private let progressService: ProgressService

    init(db: DatabaseQueue, progressService: ProgressService) {
        self.db              = db
        self.progressService = progressService
    }

    // MARK: - Start session

    func startSession(
        dialectId: Int,
        categoryCode: String,
        mode: TrainingMode,
        wordLimit: Int
    ) async throws -> TrainingSession {
        let now = Date()

        // Pick words: due for review first, then new words
        let dueWords = try await getDueWords(dialectId: dialectId, limit: wordLimit)
        let wordIds  = Array(dueWords.prefix(wordLimit).map { $0.wordEntryId })

        return try await db.write { database -> TrainingSession in
            try database.execute(sql: """
                INSERT INTO training_session
                    (dialect_id, category_code, started_at, total_words,
                     completed_words, training_mode)
                VALUES (?, ?, ?, ?, 0, ?)
            """, arguments: [
                dialectId,
                categoryCode,
                now.timeIntervalSince1970,
                wordIds.count,
                mode.rawValue
            ])
            let sessionId = Int(database.lastInsertedRowID)

            for wordId in wordIds {
                try database.execute(sql: """
                    INSERT INTO session_word
                        (training_session_id, word_entry_id, rating, ease_factor,
                         interval_days, repetition_count, next_review_date, reviewed_at)
                    VALUES (?, ?, 0, 2.5, 1, 0, ?, ?)
                """, arguments: [
                    sessionId, wordId,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970
                ])
            }

            return TrainingSession(
                id: sessionId,
                dialectId: dialectId,
                categoryCode: categoryCode,
                startedAt: now,
                completedAt: nil,
                totalWords: wordIds.count,
                completedWords: 0,
                trainingMode: mode
            )
        }
    }

    // MARK: - Record answer

    func recordAnswer(
        sessionId: Int,
        wordEntryId: Int,
        rating: Int
    ) async throws -> AwardResult {
        try await db.write { database -> AwardResult in
            // Load current SM-2 values
            guard let row = try Row.fetchOne(database, sql: """
                SELECT * FROM session_word
                WHERE training_session_id = ? AND word_entry_id = ?
            """, arguments: [sessionId, wordEntryId]) else {
                return AwardResult(totalPoints: 0, currentLevel: 1, leveledUp: false)
            }
            var sw = try SessionWord(row: row)

            // SM-2 algorithm
            let (newInterval, newEF, newRep) = sm2(
                rating: rating,
                repetitions: sw.repetitionCount,
                easeFactor:  sw.easeFactor,
                interval:    sw.intervalDays
            )
            sw.intervalDays     = newInterval
            sw.easeFactor       = newEF
            sw.repetitionCount  = newRep
            sw.rating           = rating
            sw.reviewedAt       = Date()
            sw.nextReviewDate   = Calendar.current.date(
                byAdding: .day, value: newInterval, to: Date())!

            try database.execute(sql: """
                UPDATE session_word
                SET rating = ?, ease_factor = ?, interval_days = ?,
                    repetition_count = ?, next_review_date = ?, reviewed_at = ?
                WHERE id = ?
            """, arguments: [
                sw.rating,
                sw.easeFactor,
                sw.intervalDays,
                sw.repetitionCount,
                sw.nextReviewDate.timeIntervalSince1970,
                sw.reviewedAt.timeIntervalSince1970,
                sw.id
            ])

            // Increment completed_words
            try database.execute(sql: """
                UPDATE training_session
                SET completed_words = completed_words + 1
                WHERE id = ?
            """, arguments: [sessionId])

            return AwardResult(
                totalPoints: 0, currentLevel: 1, leveledUp: false)
        }
        // Award points via progress service
        // (10 pts for clear, 5 for partial, 0 for missed)
        .applying { result in
            let points = rating == 2 ? 10 : rating == 1 ? 5 : 0
            return (try? await progressService.addPoints(
                points,
                wasCorrect: rating >= 1,
                wordEntryId: wordEntryId
            )) ?? result
        }
    }

    // MARK: - Complete session

    func completeSession(id: Int) async throws -> TrainingSession {
        let now = Date()
        return try await db.write { database -> TrainingSession in
            try database.execute(sql: """
                UPDATE training_session SET completed_at = ? WHERE id = ?
            """, arguments: [now.timeIntervalSince1970, id])

            try database.execute(sql: """
                UPDATE user_progress
                SET total_sessions = total_sessions + 1,
                    current_streak = current_streak + 1,
                    last_trained_at = ?
                WHERE id = 1
            """, arguments: [now.timeIntervalSince1970])

            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM training_session WHERE id = ?", arguments: [id])
            else { throw LangCIError.notFound }
            return try TrainingSession(row: row)
        }
    }

    // MARK: - Recent sessions

    func getRecentSessions(count: Int) async throws -> [TrainingSession] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM training_session ORDER BY started_at DESC LIMIT ?
            """, arguments: [count])
            return try rows.map { try TrainingSession(row: $0) }
        }
    }

    // MARK: - Due words (SM-2)

    func getDueWords(dialectId: Int, limit: Int) async throws -> [SessionWord] {
        let now = Date().timeIntervalSince1970
        return try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT sw.* FROM session_word sw
                JOIN word_entry w ON w.id = sw.word_entry_id
                JOIN word_dialect_map m ON m.word_entry_id = w.id
                WHERE m.dialect_id = ? AND sw.next_review_date <= ?
                ORDER BY sw.next_review_date ASC
                LIMIT ?
            """, arguments: [dialectId, now, limit])
            return try rows.map { try SessionWord(row: $0) }
        }
    }

    // MARK: - SM-2 algorithm

    private func sm2(
        rating: Int,
        repetitions: Int,
        easeFactor: Double,
        interval: Int
    ) -> (interval: Int, easeFactor: Double, repetitions: Int) {
        // SM-2: q is 0–5 (we map our 0–2 scale → 0–5)
        let q = Double(rating) * 2.5
        var ef = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        ef = max(1.3, ef)

        if rating < 1 {
            // Failed — reset
            return (1, ef, 0)
        }

        let newRep = repetitions + 1
        let newInterval: Int
        switch newRep {
        case 1:  newInterval = 1
        case 2:  newInterval = 6
        default: newInterval = Int(Double(interval) * ef)
        }
        return (newInterval, ef, newRep)
    }
}

// MARK: - AwardResult apply helper

private extension AwardResult {
    func applying(_ transform: (AwardResult) async throws -> AwardResult) async rethrows -> AwardResult {
        try await transform(self)
    }
}

// MARK: - Error

enum LangCIError: Error {
    case notFound
    case invalidData
}
