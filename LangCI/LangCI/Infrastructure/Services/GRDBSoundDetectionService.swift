// GRDBSoundDetectionService.swift
// LangCI — GRDB implementation of SoundDetectionService

import Foundation
import GRDB

final class GRDBSoundDetectionService: SoundDetectionService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    // MARK: - Test Sounds

    func getAllSounds() async throws -> [TestSound] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM test_sound ORDER BY sort_order")
            return rows.map { self.soundFromRow($0) }
        }
    }

    func getActiveSounds() async throws -> [TestSound] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM test_sound WHERE is_active = 1 ORDER BY sort_order")
            return rows.map { self.soundFromRow($0) }
        }
    }

    func addSound(_ sound: TestSound) async throws -> TestSound {
        try await db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO test_sound (symbol, tamil_label, ipa_symbol, tts_hint, audio_file_name, sort_order, is_active, is_default, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [sound.symbol, sound.tamilLabel, sound.ipaSymbol, sound.ttsHint,
                           sound.audioFileName, sound.sortOrder, sound.isActive, sound.isDefault,
                           sound.createdAt.timeIntervalSince1970])
            var result = sound
            result.id = Int(db.lastInsertedRowID)
            return result
        }
    }

    func updateSound(_ sound: TestSound) async throws {
        try await db.write { db in
            try db.execute(
                sql: """
                    UPDATE test_sound SET symbol = ?, tamil_label = ?, ipa_symbol = ?,
                    tts_hint = ?, audio_file_name = ?, sort_order = ?, is_active = ?
                    WHERE id = ?
                """,
                arguments: [sound.symbol, sound.tamilLabel, sound.ipaSymbol, sound.ttsHint,
                           sound.audioFileName, sound.sortOrder, sound.isActive, sound.id])
        }
    }

    func deleteSound(id: Int) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM test_sound WHERE id = ? AND is_default = 0", arguments: [id])
        }
    }

    // MARK: - Sessions

    func createSession(mode: TestMode, trialsPerSound: Int, distanceCm: Int, testerName: String?) async throws -> DetectionTestSession {
        try await db.write { db in
            let now = Date()
            try db.execute(
                sql: """
                    INSERT INTO detection_test_session (tested_at, mode, trials_per_sound, distance_cm, tester_name, is_complete, created_at)
                    VALUES (?, ?, ?, ?, ?, 0, ?)
                """,
                arguments: [now.timeIntervalSince1970, mode.rawValue, trialsPerSound, distanceCm, testerName, now.timeIntervalSince1970])
            return DetectionTestSession(
                id: Int(db.lastInsertedRowID), testedAt: now, mode: mode,
                trialsPerSound: trialsPerSound, distanceCm: distanceCm,
                testerName: testerName, notes: nil, isComplete: false, createdAt: now)
        }
    }

    func getSession(id: Int) async throws -> DetectionTestSession? {
        try await db.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM detection_test_session WHERE id = ?", arguments: [id]) else { return nil }
            return self.sessionFromRow(row)
        }
    }

    func getRecentSessions(count: Int) async throws -> [DetectionTestSession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM detection_test_session ORDER BY tested_at DESC LIMIT ?", arguments: [count])
            return rows.map { self.sessionFromRow($0) }
        }
    }

    func getAllSessions() async throws -> [DetectionTestSession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM detection_test_session ORDER BY tested_at DESC")
            return rows.map { self.sessionFromRow($0) }
        }
    }

    func completeSession(id: Int, notes: String?) async throws {
        try await db.write { db in
            try db.execute(
                sql: "UPDATE detection_test_session SET is_complete = 1, notes = ? WHERE id = ?",
                arguments: [notes, id])
        }
    }

    func deleteSession(id: Int) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM detection_test_session WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Trials

    func recordTrial(_ trial: DetectionTrial) async throws -> DetectionTrial {
        try await db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO detection_trial (session_id, sound_id, trial_number, is_detected, is_correct, user_response, response_time_ms, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [trial.sessionId, trial.soundId, trial.trialNumber,
                           trial.isDetected, trial.isCorrect, trial.userResponse,
                           trial.responseTimeMs, trial.createdAt.timeIntervalSince1970])
            var result = trial
            result.id = Int(db.lastInsertedRowID)
            return result
        }
    }

    func getTrials(forSession sessionId: Int) async throws -> [DetectionTrial] {
        try await db.read { db in
            let rows = try Row.fetchAll(db,
                sql: "SELECT * FROM detection_trial WHERE session_id = ? ORDER BY trial_number, sound_id",
                arguments: [sessionId])
            return rows.map { self.trialFromRow($0) }
        }
    }

    func getTrials(forSession sessionId: Int, soundId: Int) async throws -> [DetectionTrial] {
        try await db.read { db in
            let rows = try Row.fetchAll(db,
                sql: "SELECT * FROM detection_trial WHERE session_id = ? AND sound_id = ? ORDER BY trial_number",
                arguments: [sessionId, soundId])
            return rows.map { self.trialFromRow($0) }
        }
    }

    // MARK: - Analytics

    func getSessionScores(sessionId: Int) async throws -> [SoundScore] {
        let sounds = try await getActiveSounds()
        let trials = try await getTrials(forSession: sessionId)

        return sounds.map { sound in
            let soundTrials = trials.filter { $0.soundId == sound.id }
            let correct = soundTrials.filter { $0.isCorrect }.count
            return SoundScore(sound: sound, correctCount: correct, totalTrials: soundTrials.count)
        }
    }

    func getSoundProgress(soundId: Int, limit: Int) async throws -> [(date: Date, percentage: Int)] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.tested_at,
                       SUM(CASE WHEN t.is_correct = 1 THEN 1 ELSE 0 END) AS correct,
                       COUNT(*) AS total
                FROM detection_trial t
                JOIN detection_test_session s ON s.id = t.session_id
                WHERE t.sound_id = ? AND s.is_complete = 1
                GROUP BY s.id
                ORDER BY s.tested_at DESC
                LIMIT ?
            """, arguments: [soundId, limit])

            return rows.map { row in
                let date = Date(timeIntervalSince1970: row["tested_at"] as Double)
                let correct: Int = row["correct"]
                let total: Int = row["total"]
                let pct = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
                return (date: date, percentage: pct)
            }.reversed()
        }
    }

    // MARK: - Row Mappers

    private func soundFromRow(_ row: Row) -> TestSound {
        TestSound(
            id: row["id"],
            symbol: row["symbol"],
            tamilLabel: row["tamil_label"],
            ipaSymbol: row["ipa_symbol"],
            ttsHint: row["tts_hint"],
            audioFileName: row["audio_file_name"],
            sortOrder: row["sort_order"],
            isActive: row["is_active"] as Int == 1,
            isDefault: row["is_default"] as Int == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"] as Double))
    }

    private func sessionFromRow(_ row: Row) -> DetectionTestSession {
        DetectionTestSession(
            id: row["id"],
            testedAt: Date(timeIntervalSince1970: row["tested_at"] as Double),
            mode: TestMode(rawValue: row["mode"] as Int) ?? .audiologist,
            trialsPerSound: row["trials_per_sound"],
            distanceCm: row["distance_cm"],
            testerName: row["tester_name"],
            notes: row["notes"],
            isComplete: row["is_complete"] as Int == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"] as Double))
    }

    private func trialFromRow(_ row: Row) -> DetectionTrial {
        DetectionTrial(
            id: row["id"],
            sessionId: row["session_id"],
            soundId: row["sound_id"],
            trialNumber: row["trial_number"],
            isDetected: row["is_detected"] as Int == 1,
            isCorrect: row["is_correct"] as Int == 1,
            userResponse: row["user_response"],
            responseTimeMs: row["response_time_ms"],
            createdAt: Date(timeIntervalSince1970: row["created_at"] as Double))
    }
}
