// VoiceRecordingService.swift
// LangCI — Voice Library service protocol

import Foundation

protocol VoiceRecordingService {

    // MARK: - People
    func getAllPeople() async throws -> [RecordedPerson]
    func addPerson(_ person: RecordedPerson) async throws -> RecordedPerson
    func updatePerson(_ person: RecordedPerson) async throws
    func deletePerson(id: Int) async throws   // cascades recordings

    // MARK: - Recordings
    func getRecordings(forPerson personId: Int) async throws -> [VoiceRecording]
    func getRecordings(forSound soundId: String) async throws -> [VoiceRecording]
    func getAllRecordings() async throws -> [VoiceRecording]
    func addRecording(_ recording: VoiceRecording) async throws -> VoiceRecording
    func deleteRecording(id: Int) async throws

    // MARK: - Stats
    func totalRecordingCount() async throws -> Int
    func recordingCount(forPerson personId: Int) async throws -> Int
}
