// PatientService.swift
// LangCI — Patient CRUD + search + longitudinal progress

import Foundation

protocol PatientService {

    // MARK: - CRUD
    func getAllPatients() async throws -> [Patient]
    func getPatient(id: Int) async throws -> Patient?
    func searchPatients(query: String) async throws -> [Patient]
    func recentPatients(limit: Int) async throws -> [Patient]

    /// Create a patient. Caller should have already checked for duplicates.
    func addPatient(_ patient: Patient) async throws -> Patient
    func updatePatient(_ patient: Patient) async throws
    func deletePatient(id: Int) async throws

    /// Find existing patients with the same (case-insensitive) name,
    /// so the UI can ask "did you mean one of these?" before creating a duplicate.
    func patientsMatching(name: String) async throws -> [Patient]

    // MARK: - Longitudinal progress

    /// All sessions for a patient, most recent first
    func sessions(forPatient patientId: Int) async throws -> [DetectionTestSession]

    /// Per-sound accuracy over time for a single patient
    /// Returns (date, percentage) pairs chronologically
    func progressOverTime(patientId: Int, soundId: Int) async throws -> [(date: Date, percentage: Int)]
}
