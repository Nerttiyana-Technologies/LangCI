// GRDBEnvironmentalSoundService.swift
// LangCI — GRDB-backed environmental sound training service

import Foundation
import GRDB

final class GRDBEnvironmentalSoundService: EnvironmentalSoundService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    // MARK: - Sound Progress

    func getAllProgress() async throws -> [EnvironmentalSoundProgress] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM environmental_sound_progress ORDER BY sound_id")
            return rows.map { self.progressFromRow($0) }
        }
    }

    func getProgress(for soundId: String) async throws -> EnvironmentalSoundProgress? {
        try await db.read { db in
            guard let row = try Row.fetchOne(db,
                sql: "SELECT * FROM environmental_sound_progress WHERE sound_id = ?",
                arguments: [soundId]) else { return nil }
            return self.progressFromRow(row)
        }
    }

    func updateProgress(soundId: String, environment: String,
                        level: EnvironmentalListeningLevel,
                        correct: Int, total: Int) async throws -> EnvironmentalSoundProgress {
        try await db.write { db in
            let now = Date().timeIntervalSince1970

            let existing = try Row.fetchOne(db,
                sql: "SELECT * FROM environmental_sound_progress WHERE sound_id = ?",
                arguments: [soundId])

            if let row = existing {
                let oldCorrect: Int = row["correct_attempts"]
                let oldTotal: Int = row["total_attempts"]
                let newCorrect = oldCorrect + correct
                let newTotal = oldTotal + total

                try db.execute(sql: """
                    UPDATE environmental_sound_progress
                    SET correct_attempts = ?,
                        total_attempts = ?,
                        current_level = ?,
                        last_practiced_at = ?
                    WHERE sound_id = ?
                """, arguments: [newCorrect, newTotal, level.rawValue, now, soundId])
            } else {
                try db.execute(sql: """
                    INSERT INTO environmental_sound_progress
                        (sound_id, environment, current_level, total_attempts,
                         correct_attempts, is_unlocked, last_practiced_at)
                    VALUES (?, ?, ?, ?, ?, 1, ?)
                """, arguments: [soundId, environment, level.rawValue, total, correct, now])
            }

            guard let updated = try Row.fetchOne(db,
                sql: "SELECT * FROM environmental_sound_progress WHERE sound_id = ?",
                arguments: [soundId]) else {
                return EnvironmentalSoundProgress(
                    id: 0, soundId: soundId, environment: environment,
                    currentLevel: level, totalAttempts: total,
                    correctAttempts: correct, isUnlocked: true,
                    lastPracticedAt: Date())
            }
            return self.progressFromRow(updated)
        }
    }

    // MARK: - Sessions

    func saveSession(_ session: EnvironmentalSoundSession) async throws -> EnvironmentalSoundSession {
        try await db.write { db in
            let completedAt = session.completedAt?.timeIntervalSince1970
            try db.execute(sql: """
                INSERT INTO environmental_sound_session
                    (environment, listening_level, started_at, completed_at,
                     total_items, correct_items, days_post_activation)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                session.environment,
                session.listeningLevel.rawValue,
                session.startedAt.timeIntervalSince1970,
                completedAt,
                session.totalItems,
                session.correctItems,
                session.daysPostActivation
            ])

            let newId = Int(db.lastInsertedRowID)
            var saved = session
            saved.id = newId
            return saved
        }
    }

    func getRecentSessions(count: Int) async throws -> [EnvironmentalSoundSession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM environmental_sound_session
                ORDER BY started_at DESC LIMIT ?
            """, arguments: [count])
            return rows.map { self.sessionFromRow($0) }
        }
    }

    // MARK: - Stats

    func getOverallAccuracy() async throws -> Double {
        try await db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(correct_items), 0) AS correct,
                       COALESCE(SUM(total_items), 0) AS total
                FROM environmental_sound_session
            """)
            guard let r = row else { return 0 }
            let correct: Int = r["correct"]
            let total: Int = r["total"]
            guard total > 0 else { return 0 }
            return Double(correct) / Double(total) * 100
        }
    }

    func getTotalSessions() async throws -> Int {
        try await db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM environmental_sound_session") ?? 0
        }
    }

    // MARK: - Adaptive Progression

    func checkAdvancement(soundId: String) async throws -> EnvironmentalListeningLevel? {
        try await db.read { db in
            guard let progress = try Row.fetchOne(db,
                sql: "SELECT * FROM environmental_sound_progress WHERE sound_id = ?",
                arguments: [soundId]) else { return nil }

            let currentLevel: Int = progress["current_level"]
            let totalAttempts: Int = progress["total_attempts"]
            let correctAttempts: Int = progress["correct_attempts"]

            guard totalAttempts >= 5 else { return nil }

            let accuracy = Double(correctAttempts) / Double(totalAttempts) * 100
            guard accuracy >= 80 else { return nil }

            let nextRaw = currentLevel + 1
            guard let next = EnvironmentalListeningLevel(rawValue: nextRaw) else { return nil }
            return next
        }
    }

    // MARK: - Custom Sounds

    func getAllCustomSounds() async throws -> [CustomEnvironmentalSound] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM custom_environmental_sound
                WHERE is_active = 1 ORDER BY name
            """)
            return rows.map { self.customSoundFromRow($0) }
        }
    }

    func addCustomSound(_ sound: CustomEnvironmentalSound) async throws -> CustomEnvironmentalSound {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                INSERT INTO custom_environmental_sound
                    (sound_id, name, environment, description, speech_description,
                     ci_difficulty, is_active, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
            """, arguments: [
                sound.soundId, sound.name, sound.environment,
                sound.description, sound.speechDescription,
                sound.ciDifficulty, now, now
            ])
            let newId = Int(db.lastInsertedRowID)
            var saved = sound
            saved.id = newId
            saved.createdAt = Date(timeIntervalSince1970: now)
            saved.updatedAt = Date(timeIntervalSince1970: now)
            return saved
        }
    }

    func updateCustomSound(_ sound: CustomEnvironmentalSound) async throws {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                UPDATE custom_environmental_sound
                SET name = ?, environment = ?, description = ?,
                    speech_description = ?, ci_difficulty = ?, updated_at = ?
                WHERE sound_id = ?
            """, arguments: [
                sound.name, sound.environment, sound.description,
                sound.speechDescription, sound.ciDifficulty, now,
                sound.soundId
            ])
        }
    }

    func deleteCustomSound(soundId: String) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM custom_environmental_sound WHERE sound_id = ?",
                           arguments: [soundId])
        }
    }

    // MARK: - Sound Edit Overrides

    func getAllOverrides() async throws -> [SoundEditOverride] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM sound_edit_override ORDER BY sound_id")
            return rows.map { self.overrideFromRow($0) }
        }
    }

    func getOverride(for soundId: String) async throws -> SoundEditOverride? {
        try await db.read { db in
            guard let row = try Row.fetchOne(db,
                sql: "SELECT * FROM sound_edit_override WHERE sound_id = ?",
                arguments: [soundId]) else { return nil }
            return self.overrideFromRow(row)
        }
    }

    func saveOverride(_ override: SoundEditOverride) async throws {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            // Upsert
            let exists = try Row.fetchOne(db,
                sql: "SELECT id FROM sound_edit_override WHERE sound_id = ?",
                arguments: [override.soundId])

            if exists != nil {
                try db.execute(sql: """
                    UPDATE sound_edit_override
                    SET name = ?, description = ?, speech_description = ?,
                        ci_difficulty = ?, updated_at = ?
                    WHERE sound_id = ?
                """, arguments: [
                    override.name, override.description,
                    override.speechDescription, override.ciDifficulty,
                    now, override.soundId
                ])
            } else {
                try db.execute(sql: """
                    INSERT INTO sound_edit_override
                        (sound_id, name, description, speech_description,
                         ci_difficulty, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    override.soundId, override.name, override.description,
                    override.speechDescription, override.ciDifficulty, now
                ])
            }
        }
    }

    func deleteOverride(soundId: String) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM sound_edit_override WHERE sound_id = ?",
                           arguments: [soundId])
        }
    }

    // MARK: - Weekly Packs

    func getPackProgress() async throws -> [WeeklyPackProgress] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM weekly_pack_progress ORDER BY id")
            return rows.map { self.packProgressFromRow($0) }
        }
    }

    func unlockPack(_ packId: String) async throws {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                UPDATE weekly_pack_progress
                SET is_unlocked = 1, unlocked_at = ?
                WHERE pack_id = ?
            """, arguments: [now, packId])
        }
    }

    func markPackCompleted(_ packId: String) async throws {
        try await db.write { db in
            try db.execute(sql: """
                UPDATE weekly_pack_progress SET completed = 1 WHERE pack_id = ?
            """, arguments: [packId])

            // Auto-unlock next pack
            let allPacks = ["week1", "week2", "week3", "week4"]
            if let idx = allPacks.firstIndex(of: packId), idx + 1 < allPacks.count {
                let nextPack = allPacks[idx + 1]
                let now = Date().timeIntervalSince1970
                try db.execute(sql: """
                    UPDATE weekly_pack_progress
                    SET is_unlocked = 1, unlocked_at = ?
                    WHERE pack_id = ? AND is_unlocked = 0
                """, arguments: [now, nextPack])
            }
        }
    }

    // MARK: - Row Mappers

    private func progressFromRow(_ row: Row) -> EnvironmentalSoundProgress {
        let lastPracticedEpoch: Double? = row["last_practiced_at"]
        return EnvironmentalSoundProgress(
            id: row["id"],
            soundId: row["sound_id"],
            environment: row["environment"],
            currentLevel: EnvironmentalListeningLevel(rawValue: row["current_level"]) ?? .detection,
            totalAttempts: row["total_attempts"],
            correctAttempts: row["correct_attempts"],
            isUnlocked: row["is_unlocked"] == 1,
            lastPracticedAt: lastPracticedEpoch.map { Date(timeIntervalSince1970: $0) }
        )
    }

    private func sessionFromRow(_ row: Row) -> EnvironmentalSoundSession {
        let completedEpoch: Double? = row["completed_at"]
        return EnvironmentalSoundSession(
            id: row["id"],
            environment: row["environment"],
            listeningLevel: EnvironmentalListeningLevel(rawValue: row["listening_level"]) ?? .detection,
            startedAt: Date(timeIntervalSince1970: row["started_at"]),
            completedAt: completedEpoch.map { Date(timeIntervalSince1970: $0) },
            totalItems: row["total_items"],
            correctItems: row["correct_items"],
            daysPostActivation: row["days_post_activation"]
        )
    }

    private func customSoundFromRow(_ row: Row) -> CustomEnvironmentalSound {
        CustomEnvironmentalSound(
            id: row["id"],
            soundId: row["sound_id"],
            name: row["name"],
            environment: row["environment"],
            description: row["description"],
            speechDescription: row["speech_description"],
            ciDifficulty: row["ci_difficulty"],
            isActive: row["is_active"] == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
    }

    private func overrideFromRow(_ row: Row) -> SoundEditOverride {
        SoundEditOverride(
            id: row["id"],
            soundId: row["sound_id"],
            name: row["name"],
            description: row["description"],
            speechDescription: row["speech_description"],
            ciDifficulty: row["ci_difficulty"],
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
    }

    private func packProgressFromRow(_ row: Row) -> WeeklyPackProgress {
        let unlockedEpoch: Double? = row["unlocked_at"]
        return WeeklyPackProgress(
            id: row["id"],
            packId: row["pack_id"],
            isUnlocked: row["is_unlocked"] == 1,
            unlockedAt: unlockedEpoch.map { Date(timeIntervalSince1970: $0) },
            completed: row["completed"] == 1
        )
    }
}
