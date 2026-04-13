// GRDBVoiceRecordingService.swift
// LangCI — GRDB implementation for voice library

import Foundation
import GRDB

final class GRDBVoiceRecordingService: VoiceRecordingService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - People

    func getAllPeople() async throws -> [RecordedPerson] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT p.*,
                       (SELECT COUNT(*) FROM voice_recording WHERE person_id = p.id) AS recording_count
                FROM recorded_person p
                WHERE p.is_active = 1
                ORDER BY p.name ASC
            """)
            return rows.map { personFromRow($0) }
        }
    }

    func addPerson(_ person: RecordedPerson) async throws -> RecordedPerson {
        let now = Date().timeIntervalSince1970
        let id = try await db.write { db -> Int64 in
            try db.execute(sql: """
                INSERT INTO recorded_person
                    (name, relationship, color, icon, is_active, created_at, updated_at)
                VALUES (?, ?, ?, ?, 1, ?, ?)
            """, arguments: [person.name, person.relationship,
                             person.color, person.icon, now, now])
            return db.lastInsertedRowID
        }
        var result = person
        result.id = Int(id)
        result.createdAt = Date(timeIntervalSince1970: now)
        result.updatedAt = Date(timeIntervalSince1970: now)
        return result
    }

    func updatePerson(_ person: RecordedPerson) async throws {
        let now = Date().timeIntervalSince1970
        try await db.write { db in
            try db.execute(sql: """
                UPDATE recorded_person
                SET name = ?, relationship = ?, color = ?, icon = ?,
                    is_active = ?, updated_at = ?
                WHERE id = ?
            """, arguments: [person.name, person.relationship,
                             person.color, person.icon,
                             person.isActive ? 1 : 0, now, person.id])
        }
    }

    func deletePerson(id: Int) async throws {
        // First delete audio files for this person
        let recordings = try await getRecordings(forPerson: id)
        for rec in recordings {
            try? FileManager.default.removeItem(atPath: rec.filePath)
        }
        // DB cascade handles voice_recording rows
        try await db.write { db in
            try db.execute(sql: "DELETE FROM recorded_person WHERE id = ?",
                           arguments: [id])
        }
    }

    // MARK: - Recordings

    func getRecordings(forPerson personId: Int) async throws -> [VoiceRecording] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM voice_recording
                WHERE person_id = ?
                ORDER BY created_at DESC
            """, arguments: [personId])
            return rows.map { recordingFromRow($0) }
        }
    }

    func getRecordings(forSound soundId: String) async throws -> [VoiceRecording] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM voice_recording
                WHERE sound_id = ?
                ORDER BY person_id, created_at DESC
            """, arguments: [soundId])
            return rows.map { recordingFromRow($0) }
        }
    }

    func getAllRecordings() async throws -> [VoiceRecording] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM voice_recording
                ORDER BY created_at DESC
            """)
            return rows.map { recordingFromRow($0) }
        }
    }

    func addRecording(_ recording: VoiceRecording) async throws -> VoiceRecording {
        let now = Date().timeIntervalSince1970
        let id = try await db.write { db -> Int64 in
            try db.execute(sql: """
                INSERT INTO voice_recording
                    (person_id, sound_id, label, file_name, duration_seconds, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [recording.personId, recording.soundId,
                             recording.label, recording.fileName,
                             recording.durationSeconds, now])
            return db.lastInsertedRowID
        }
        var result = recording
        result.id = Int(id)
        result.createdAt = Date(timeIntervalSince1970: now)
        return result
    }

    func deleteRecording(id: Int) async throws {
        // Get the file path first
        let rec: VoiceRecording? = try await db.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT * FROM voice_recording WHERE id = ?
            """, arguments: [id]) else { return nil }
            return self.recordingFromRow(row)
        }
        // Delete audio file
        if let rec = rec {
            try? FileManager.default.removeItem(atPath: rec.filePath)
        }
        try await db.write { db in
            try db.execute(sql: "DELETE FROM voice_recording WHERE id = ?",
                           arguments: [id])
        }
    }

    // MARK: - Stats

    func totalRecordingCount() async throws -> Int {
        try await db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM voice_recording") ?? 0
        }
    }

    func recordingCount(forPerson personId: Int) async throws -> Int {
        try await db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM voice_recording WHERE person_id = ?
            """, arguments: [personId]) ?? 0
        }
    }

    // MARK: - Custom Prompts

    func getAllCustomPrompts() async throws -> [CustomVoicePrompt] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM custom_voice_prompt
                ORDER BY category, created_at DESC
            """)
            return rows.map { self.customPromptFromRow($0) }
        }
    }

    func getCustomPrompts(category: String) async throws -> [CustomVoicePrompt] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM custom_voice_prompt
                WHERE category = ?
                ORDER BY created_at DESC
            """, arguments: [category])
            return rows.map { self.customPromptFromRow($0) }
        }
    }

    func addCustomPrompt(_ prompt: CustomVoicePrompt) async throws -> CustomVoicePrompt {
        let now = Date().timeIntervalSince1970
        let id = try await db.write { db -> Int64 in
            try db.execute(sql: """
                INSERT INTO custom_voice_prompt
                    (text, transliteration, meaning, category, created_by, is_built_in, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [prompt.text, prompt.transliteration,
                             prompt.meaning, prompt.category,
                             prompt.createdBy, prompt.isBuiltIn ? 1 : 0, now])
            return db.lastInsertedRowID
        }
        var result = prompt
        result.id = Int(id)
        result.createdAt = Date(timeIntervalSince1970: now)
        return result
    }

    func deleteCustomPrompt(id: Int) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM custom_voice_prompt WHERE id = ?",
                           arguments: [id])
        }
    }

    // MARK: - Row mappers

    private func personFromRow(_ row: Row) -> RecordedPerson {
        var p = RecordedPerson(
            id: row["id"],
            name: row["name"],
            relationship: row["relationship"] ?? "",
            color: row["color"] ?? "lcPurple",
            icon: row["icon"] ?? "person.fill",
            isActive: (row["is_active"] as Int?) == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"] ?? 0),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"] ?? 0))
        p.recordingCount = row["recording_count"] ?? 0
        return p
    }

    private func recordingFromRow(_ row: Row) -> VoiceRecording {
        VoiceRecording(
            id: row["id"],
            personId: row["person_id"],
            soundId: row["sound_id"],
            label: row["label"] ?? "",
            fileName: row["file_name"] ?? "",
            durationSeconds: row["duration_seconds"] ?? 0,
            createdAt: Date(timeIntervalSince1970: row["created_at"] ?? 0))
    }

    private func customPromptFromRow(_ row: Row) -> CustomVoicePrompt {
        CustomVoicePrompt(
            id: row["id"],
            text: row["text"] ?? "",
            transliteration: row["transliteration"] ?? "",
            meaning: row["meaning"] ?? "",
            category: row["category"] ?? "custom",
            createdBy: row["created_by"],
            isBuiltIn: (row["is_built_in"] as Int?) == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"] ?? 0))
    }
}
