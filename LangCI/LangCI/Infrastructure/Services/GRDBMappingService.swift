// GRDBMappingService.swift
// LangCI

import Foundation
import GRDB

final class GRDBMappingService: MappingService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Save session

    func saveSession(_ session: MappingSession) async throws -> MappingSession {
        try await db.write { database -> MappingSession in
            var saved = session

            if session.id == 0 {
                // INSERT
                try database.execute(sql: """
                    INSERT INTO mapping_session
                        (session_date, audiologist_name, clinic_name, notes, next_appointment_date)
                    VALUES (?, ?, ?, ?, ?)
                """, arguments: [
                    session.sessionDate.timeIntervalSince1970,
                    session.audiologistName,
                    session.clinicName,
                    session.notes,
                    session.nextAppointmentDate?.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                // UPDATE
                try database.execute(sql: """
                    UPDATE mapping_session
                    SET session_date = ?, audiologist_name = ?, clinic_name = ?,
                        notes = ?, next_appointment_date = ?
                    WHERE id = ?
                """, arguments: [
                    session.sessionDate.timeIntervalSince1970,
                    session.audiologistName,
                    session.clinicName,
                    session.notes,
                    session.nextAppointmentDate?.timeIntervalSince1970,
                    session.id
                ])
                // Delete old electrode levels before re-inserting
                try database.execute(sql:
                    "DELETE FROM electrode_level WHERE mapping_session_id = ?",
                    arguments: [session.id])
            }

            // Persist electrode levels
            for level in session.electrodeLevels {
                try database.execute(sql: """
                    INSERT INTO electrode_level
                        (mapping_session_id, electrode_number, t_level, c_level, is_active, notes)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    saved.id,
                    level.electrodeNumber,
                    level.tLevel,
                    level.cLevel,
                    level.isActive ? 1 : 0,
                    level.notes
                ])
            }

            return saved
        }
    }

    // MARK: - Fetch all

    func getAllSessions() async throws -> [MappingSession] {
        try await db.read { database in
            let rows = try Row.fetchAll(database,
                sql: "SELECT * FROM mapping_session ORDER BY session_date DESC")
            return try rows.map { row in
                var s = try MappingSession(row: row)
                s.electrodeLevels = try self.loadElectrodes(database, sessionId: s.id)
                return s
            }
        }
    }

    // MARK: - Latest session

    func getLatestSession() async throws -> MappingSession? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM mapping_session ORDER BY session_date DESC LIMIT 1")
            else { return nil }
            var s = try MappingSession(row: row)
            s.electrodeLevels = try self.loadElectrodes(database, sessionId: s.id)
            return s
        }
    }

    // MARK: - Delete session

    func deleteSession(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM mapping_session WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Default electrode levels

    func createDefaultElectrodeLevels() -> [ElectrodeLevel] {
        (1...22).map { n in
            ElectrodeLevel(
                id: 0,
                mappingSessionId: 0,
                electrodeNumber: n,
                tLevel: 100,
                cLevel: 200,
                isActive: true
            )
        }
    }

    // MARK: - Private helpers

    private func loadElectrodes(_ db: Database, sessionId: Int) throws -> [ElectrodeLevel] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT * FROM electrode_level
            WHERE mapping_session_id = ?
            ORDER BY electrode_number
        """, arguments: [sessionId])
        return try rows.map { try ElectrodeLevel(row: $0) }
    }
}
