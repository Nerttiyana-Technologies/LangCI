// GRDBSoundTherapyService.swift
// LangCI — GRDB-backed sound therapy service

import Foundation
import GRDB

final class GRDBSoundTherapyService: SoundTherapyService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    // MARK: - Sound Progress

    func getAllProgress() async throws -> [SoundProgress] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM sound_progress ORDER BY sound")
            return rows.map { self.progressFromRow($0) }
        }
    }

    func getProgress(for sound: String) async throws -> SoundProgress? {
        try await db.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM sound_progress WHERE sound = ?", arguments: [sound]) else {
                return nil
            }
            return self.progressFromRow(row)
        }
    }

    func unlockSound(_ sound: String, category: String) async throws -> SoundProgress {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                INSERT OR IGNORE INTO sound_progress
                    (sound, category, current_level, total_sessions, total_correct,
                     total_attempts, best_accuracy, last_practiced_at, is_unlocked,
                     female_voice_accuracy, male_voice_accuracy)
                VALUES (?, ?, 0, 0, 0, 0, 0, ?, 1, 0, 0)
            """, arguments: [sound, category, now])
            let row = try Row.fetchOne(db, sql: "SELECT * FROM sound_progress WHERE sound = ?", arguments: [sound])!
            return self.progressFromRow(row)
        }
    }

    func updateProgress(sound: String, level: SoundExerciseLevel,
                        voiceGender: VoiceGender,
                        correct: Int, total: Int) async throws -> SoundProgress {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            let accuracy = total > 0 ? Double(correct) / Double(total) * 100 : 0

            // Update cumulative stats
            try db.execute(sql: """
                UPDATE sound_progress SET
                    current_level = MAX(current_level, ?),
                    total_sessions = total_sessions + 1,
                    total_correct = total_correct + ?,
                    total_attempts = total_attempts + ?,
                    best_accuracy = MAX(best_accuracy, ?),
                    last_practiced_at = ?
                WHERE sound = ?
            """, arguments: [level.rawValue, correct, total, accuracy, now, sound])

            // Update voice-specific accuracy (weighted running average)
            let genderCol = voiceGender == .female ? "female_voice_accuracy" : "male_voice_accuracy"
            // Running average: new = old * 0.7 + latest * 0.3
            try db.execute(sql: """
                UPDATE sound_progress SET
                    \(genderCol) = \(genderCol) * 0.7 + ? * 0.3
                WHERE sound = ?
            """, arguments: [accuracy, sound])

            let row = try Row.fetchOne(db, sql: "SELECT * FROM sound_progress WHERE sound = ?", arguments: [sound])!
            return self.progressFromRow(row)
        }
    }

    // MARK: - Sessions

    func saveSession(_ session: SoundTherapySession) async throws -> SoundTherapySession {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                INSERT INTO sound_therapy_session
                    (exercise_type, target_sound, voice_gender, exercise_level,
                     started_at, completed_at, total_items, correct_items, is_adaptive)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                session.exerciseType, session.targetSound,
                session.voiceGender.rawValue, session.exerciseLevel.rawValue,
                session.startedAt.timeIntervalSince1970,
                (session.completedAt ?? Date()).timeIntervalSince1970,
                session.totalItems, session.correctItems,
                session.isAdaptive ? 1 : 0
            ])

            var saved = session
            saved.id = Int(db.lastInsertedRowID)
            return saved
        }
    }

    func getRecentSessions(count: Int) async throws -> [SoundTherapySession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM sound_therapy_session
                ORDER BY started_at DESC LIMIT ?
            """, arguments: [count])
            return rows.map { self.sessionFromRow($0) }
        }
    }

    func getSessionsForSound(_ sound: String) async throws -> [SoundTherapySession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM sound_therapy_session
                WHERE target_sound = ?
                ORDER BY started_at DESC
            """, arguments: [sound])
            return rows.map { self.sessionFromRow($0) }
        }
    }

    // MARK: - Stats

    func getHomeStats() async throws -> SoundTherapyHomeStats {
        try await db.read { db in
            let unlocked = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sound_progress WHERE is_unlocked = 1") ?? 0
            let mastered = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sound_progress
                WHERE female_voice_accuracy >= 80 AND male_voice_accuracy >= 80
            """) ?? 0

            let weekAgo = Date().addingTimeInterval(-7 * 86400).timeIntervalSince1970
            let weekSessions = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sound_therapy_session
                WHERE started_at >= ?
            """, arguments: [weekAgo]) ?? 0

            let totalCorrect = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(total_correct), 0) FROM sound_progress") ?? 0
            let totalAttempts = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(total_attempts), 0) FROM sound_progress") ?? 0
            let accuracy = totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) * 100 : 0

            let weakest = try String.fetchOne(db, sql: """
                SELECT sound FROM sound_progress
                WHERE is_unlocked = 1 AND total_attempts > 0
                ORDER BY (CAST(total_correct AS REAL) / total_attempts) ASC LIMIT 1
            """)

            let strongest = try String.fetchOne(db, sql: """
                SELECT sound FROM sound_progress
                WHERE is_unlocked = 1 AND total_attempts > 0
                ORDER BY (CAST(total_correct AS REAL) / total_attempts) DESC LIMIT 1
            """)

            // Streak: count consecutive days with at least one session
            var streak = 0
            let today = Calendar.current.startOfDay(for: Date())
            for dayOffset in 0..<365 {
                let dayStart = today.addingTimeInterval(Double(-dayOffset) * 86400).timeIntervalSince1970
                let dayEnd = dayStart + 86400
                let count = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM sound_therapy_session
                    WHERE started_at >= ? AND started_at < ?
                """, arguments: [dayStart, dayEnd]) ?? 0
                if count > 0 { streak += 1 } else if dayOffset > 0 { break }
            }

            return SoundTherapyHomeStats(
                totalSoundsUnlocked: unlocked,
                soundsMastered: mastered,
                sessionsThisWeek: weekSessions,
                overallAccuracy: accuracy,
                weakestSound: weakest,
                strongestSound: strongest,
                currentStreak: streak
            )
        }
    }

    // MARK: - Adaptive Progression

    func checkAdvancement(sound: String) async throws -> SoundExerciseLevel? {
        guard let progress = try await getProgress(for: sound) else { return nil }
        guard progress.canAdvance else { return nil }

        // Need at least 3 sessions at current level with >80% accuracy
        let sessions = try await getSessionsForSound(sound)
        let currentLevelSessions = sessions.filter {
            SoundExerciseLevel(rawValue: $0.exerciseLevel.rawValue) == progress.currentLevel
        }
        guard currentLevelSessions.count >= 3 else { return nil }

        let recentAccuracy = currentLevelSessions.prefix(3).map(\.accuracy)
        let avgAccuracy = recentAccuracy.reduce(0, +) / Double(recentAccuracy.count)

        if avgAccuracy >= 80 {
            if let nextLevel = SoundExerciseLevel(rawValue: progress.currentLevel.rawValue + 1) {
                // Advance the level
                try await db.write { db in
                    try db.execute(sql: "UPDATE sound_progress SET current_level = ? WHERE sound = ?",
                                 arguments: [nextLevel.rawValue, sound])
                }
                return nextLevel
            }
        }

        return nil
    }

    func autoUnlockSounds() async throws -> [String] {
        let allProgress = try await getAllProgress()
        let unlockedSounds = Set(allProgress.filter(\.isUnlocked).map(\.sound))

        // Unlock sounds from easiest categories first
        var newlyUnlocked: [String] = []
        for soundDef in SoundTherapyContent.allSounds {
            if !unlockedSounds.contains(soundDef.sound) {
                // Check if any confusion partner is mastered
                let partnerMastered = soundDef.confusionPartners.contains { partner in
                    allProgress.first(where: { $0.sound == partner })?.isMastered == true
                }
                // Or if no sounds are unlocked yet (first time)
                if unlockedSounds.isEmpty || partnerMastered {
                    _ = try await unlockSound(soundDef.sound, category: soundDef.category.rawValue)
                    newlyUnlocked.append(soundDef.sound)
                    if newlyUnlocked.count >= 2 { break } // Unlock max 2 at a time
                }
            }
        }

        return newlyUnlocked
    }

    // MARK: - Row Mapping

    private func progressFromRow(_ row: Row) -> SoundProgress {
        SoundProgress(
            id: row["id"],
            sound: row["sound"],
            category: row["category"],
            currentLevel: SoundExerciseLevel(rawValue: row["current_level"]) ?? .isolation,
            totalSessions: row["total_sessions"],
            totalCorrect: row["total_correct"],
            totalAttempts: row["total_attempts"],
            bestAccuracy: row["best_accuracy"],
            lastPracticedAt: (row["last_practiced_at"] as Double?).map { Date(timeIntervalSince1970: $0) },
            isUnlocked: row["is_unlocked"] == 1,
            femaleVoiceAccuracy: row["female_voice_accuracy"],
            maleVoiceAccuracy: row["male_voice_accuracy"]
        )
    }

    private func sessionFromRow(_ row: Row) -> SoundTherapySession {
        SoundTherapySession(
            id: row["id"],
            exerciseType: row["exercise_type"],
            targetSound: row["target_sound"],
            voiceGender: VoiceGender(rawValue: row["voice_gender"]) ?? .female,
            exerciseLevel: SoundExerciseLevel(rawValue: row["exercise_level"]) ?? .isolation,
            startedAt: Date(timeIntervalSince1970: row["started_at"]),
            completedAt: (row["completed_at"] as Double?).map { Date(timeIntervalSince1970: $0) },
            totalItems: row["total_items"],
            correctItems: row["correct_items"],
            isAdaptive: row["is_adaptive"] == 1
        )
    }
}
