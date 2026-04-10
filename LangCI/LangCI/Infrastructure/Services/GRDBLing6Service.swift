// GRDBLing6Service.swift
// LangCI

import Foundation
import GRDB

final class GRDBLing6Service: Ling6Service {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Start session

    func startSession(distanceCm: Int, program: ProcessorProgram) async throws -> Ling6Session {
        let sounds = ["ah", "ee", "oo", "sh", "s", "m"]
        let now    = Date().timeIntervalSince1970

        return try await db.write { database -> Ling6Session in
            try database.execute(sql: """
                INSERT INTO ling6_session (tested_at, distance_cm, program_used)
                VALUES (?, ?, ?)
            """, arguments: [now, distanceCm, program.rawValue])

            let sessionId = Int(database.lastInsertedRowID)

            for (i, sound) in sounds.enumerated() {
                try database.execute(sql: """
                    INSERT INTO ling6_attempt (session_id, sound, is_detected, is_recognised, sort_order)
                    VALUES (?, ?, 0, 0, ?)
                """, arguments: [sessionId, sound, i])
            }

            var session           = Ling6Session(id: sessionId)
            session.testedAt      = Date(timeIntervalSince1970: now)
            session.distanceCm    = distanceCm
            session.programUsed   = program
            return session
        }
    }

    // MARK: - Record attempt

    func recordAttempt(sessionId: Int, sound: String, isDetected: Bool, isRecognised: Bool) async throws {
        try await db.write { database in
            try database.execute(sql: """
                UPDATE ling6_attempt
                SET is_detected = ?, is_recognised = ?
                WHERE session_id = ? AND sound = ?
            """, arguments: [isDetected ? 1 : 0, isRecognised ? 1 : 0, sessionId, sound])
        }
    }

    // MARK: - Recent sessions

    func getRecentSessions(count: Int) async throws -> [Ling6Session] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM ling6_session ORDER BY tested_at DESC LIMIT ?
            """, arguments: [count])

            return try rows.map { row in
                var session = try Ling6Session(row: row)
                let attempts = try Row.fetchAll(database, sql: """
                    SELECT * FROM ling6_attempt WHERE session_id = ? ORDER BY sort_order
                """, arguments: [session.id])
                session.attempts = try attempts.map { try Ling6Attempt(row: $0) }
                return session
            }
        }
    }

    // MARK: - Stats

    func getStats() async throws -> Ling6StatsDto {
        try await db.read { database in
            let total = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM ling6_session") ?? 0

            // Detection / recognition averages over all sessions
            let avgDetection = try Double.fetchOne(database, sql: """
                SELECT AVG(CAST(is_detected AS REAL)) * 100
                FROM ling6_attempt
            """) ?? 0

            let avgRecognition = try Double.fetchOne(database, sql: """
                SELECT AVG(CAST(is_recognised AS REAL)) * 100
                FROM ling6_attempt
            """) ?? 0

            // Streak — consecutive days with at least one session
            let streak = try self.calculateStreak(database)

            // Tested today
            let startOfDay = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            let testedToday = (try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM ling6_session WHERE tested_at >= ?
            """, arguments: [startOfDay]) ?? 0) > 0

            // Per-sound accuracy
            let sounds = ["ah", "ee", "oo", "sh", "s", "m"]
            let soundFreqs = [500, 1000, 2000, 3000, 4000, 8000]
            let soundIpa   = ["/ɑː/", "/iː/", "/uː/", "/ʃ/", "/s/", "/m/"]

            var perSound: [Ling6SoundAccuracy] = []
            for (i, sound) in sounds.enumerated() {
                let rows = try Row.fetchAll(database, sql: """
                    SELECT
                        COUNT(*) AS attempts,
                        AVG(CAST(is_detected AS REAL)) * 100 AS detection_pct,
                        AVG(CAST(is_recognised AS REAL)) * 100 AS recognition_pct
                    FROM ling6_attempt WHERE sound = ?
                """, arguments: [sound])

                if let r = rows.first {
                    perSound.append(Ling6SoundAccuracy(
                        sound:           sound,
                        ipaSymbol:       soundIpa[i],
                        freqHz:          soundFreqs[i],
                        detectionPct:    r["detection_pct"] ?? 0,
                        recognitionPct:  r["recognition_pct"] ?? 0,
                        attempts:        r["attempts"] ?? 0
                    ))
                }
            }

            return Ling6StatsDto(
                totalSessions:      total,
                avgDetectionRate:   avgDetection,
                avgRecognitionRate: avgRecognition,
                currentStreak:      streak,
                testedToday:        testedToday,
                perSoundAccuracy:   perSound
            )
        }
    }

    // MARK: - Is done today

    func isDoneToday() async throws -> Bool {
        try await db.read { database in
            let start = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            let count = try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM ling6_session WHERE tested_at >= ?
            """, arguments: [start]) ?? 0
            return count > 0
        }
    }

    // MARK: - Private helpers

    private func calculateStreak(_ db: Database) throws -> Int {
        let rows = try Row.fetchAll(db, sql: """
            SELECT DISTINCT date(tested_at, 'unixepoch') AS day
            FROM ling6_session
            ORDER BY day DESC
        """)
        var streak = 0
        var expected = Calendar.current.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        for row in rows {
            guard let dayStr = row["day"] as String?,
                  let day = fmt.date(from: dayStr) else { break }
            if day == expected {
                streak += 1
                expected = Calendar.current.date(byAdding: .day, value: -1, to: expected)!
            } else {
                break
            }
        }
        return streak
    }
}
