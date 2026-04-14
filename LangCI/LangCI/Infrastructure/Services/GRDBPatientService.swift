// GRDBPatientService.swift
// LangCI — GRDB-backed PatientService

import Foundation
import GRDB

final class GRDBPatientService: PatientService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    // MARK: - CRUD

    func getAllPatients() async throws -> [Patient] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM patient ORDER BY name COLLATE NOCASE")
            return rows.map { self.patientFromRow($0) }
        }
    }

    func getPatient(id: Int) async throws -> Patient? {
        try await db.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM patient WHERE id = ?", arguments: [id]) else { return nil }
            return self.patientFromRow(row)
        }
    }

    func searchPatients(query: String) async throws -> [Patient] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return try await recentPatients(limit: 20)
        }
        return try await db.read { db in
            let pattern = "%\(trimmed)%"
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM patient
                WHERE name LIKE ? COLLATE NOCASE
                   OR identifier LIKE ? COLLATE NOCASE
                ORDER BY name COLLATE NOCASE
                LIMIT 30
            """, arguments: [pattern, pattern])
            return rows.map { self.patientFromRow($0) }
        }
    }

    func recentPatients(limit: Int) async throws -> [Patient] {
        try await db.read { db in
            // Patients ordered by most recent session activity; falls back to
            // creation date for brand-new patients with no sessions yet.
            let rows = try Row.fetchAll(db, sql: """
                SELECT p.*,
                       COALESCE(MAX(s.tested_at), p.created_at) AS last_activity
                FROM patient p
                LEFT JOIN detection_test_session s ON s.patient_id = p.id
                GROUP BY p.id
                ORDER BY last_activity DESC
                LIMIT ?
            """, arguments: [limit])
            return rows.map { self.patientFromRow($0) }
        }
    }

    func addPatient(_ patient: Patient) async throws -> Patient {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(
                sql: """
                    INSERT INTO patient (name, identifier, notes, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [patient.name, patient.identifier, patient.notes, now, now])
            var result = patient
            result.id = Int(db.lastInsertedRowID)
            result.createdAt = Date(timeIntervalSince1970: now)
            result.updatedAt = Date(timeIntervalSince1970: now)
            return result
        }
    }

    func updatePatient(_ patient: Patient) async throws {
        try await db.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(
                sql: """
                    UPDATE patient SET name = ?, identifier = ?, notes = ?, updated_at = ?
                    WHERE id = ?
                """,
                arguments: [patient.name, patient.identifier, patient.notes, now, patient.id])

            // Keep denormalised patient_name in sessions in sync
            try db.execute(
                sql: "UPDATE detection_test_session SET patient_name = ? WHERE patient_id = ?",
                arguments: [patient.name, patient.id])
        }
    }

    func deletePatient(id: Int) async throws {
        try await db.write { db in
            // Null-out session FKs so session rows survive (audit trail),
            // but disassociate the patient. If caller wants full erasure,
            // they should call deleteSession for each session first.
            try db.execute(
                sql: "UPDATE detection_test_session SET patient_id = NULL, patient_name = NULL WHERE patient_id = ?",
                arguments: [id])
            try db.execute(sql: "DELETE FROM patient WHERE id = ?", arguments: [id])
        }
    }

    func patientsMatching(name: String) async throws -> [Patient] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM patient
                WHERE name = ? COLLATE NOCASE
                ORDER BY created_at ASC
            """, arguments: [trimmed])
            return rows.map { self.patientFromRow($0) }
        }
    }

    // MARK: - Longitudinal progress

    func sessions(forPatient patientId: Int) async throws -> [DetectionTestSession] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM detection_test_session
                WHERE patient_id = ?
                ORDER BY tested_at DESC
            """, arguments: [patientId])
            return rows.map { self.sessionFromRow($0) }
        }
    }

    func progressOverTime(patientId: Int, soundId: Int) async throws -> [(date: Date, percentage: Int)] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.tested_at,
                       SUM(CASE WHEN t.is_correct = 1 THEN 1 ELSE 0 END) AS correct,
                       COUNT(*) AS total
                FROM detection_trial t
                JOIN detection_test_session s ON s.id = t.session_id
                WHERE s.patient_id = ? AND t.sound_id = ? AND s.is_complete = 1
                GROUP BY s.id
                ORDER BY s.tested_at ASC
            """, arguments: [patientId, soundId])

            return rows.map { row in
                let date = Date(timeIntervalSince1970: row["tested_at"] as Double)
                let correct: Int = row["correct"]
                let total: Int = row["total"]
                let pct = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
                return (date: date, percentage: pct)
            }
        }
    }

    // MARK: - Row mappers

    private func patientFromRow(_ row: Row) -> Patient {
        Patient(
            id: row["id"],
            name: row["name"],
            identifier: row["identifier"],
            notes: row["notes"],
            createdAt: Date(timeIntervalSince1970: row["created_at"] as Double),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"] as Double))
    }

    private func sessionFromRow(_ row: Row) -> DetectionTestSession {
        DetectionTestSession(
            id: row["id"],
            testedAt: Date(timeIntervalSince1970: row["tested_at"] as Double),
            mode: TestMode(rawValue: row["mode"] as Int) ?? .audiologist,
            trialsPerSound: row["trials_per_sound"],
            distanceCm: row["distance_cm"],
            patientId: row["patient_id"],
            patientName: row["patient_name"],
            testerName: row["tester_name"],
            notes: row["notes"],
            isComplete: row["is_complete"] as Int == 1,
            createdAt: Date(timeIntervalSince1970: row["created_at"] as Double))
    }
}
