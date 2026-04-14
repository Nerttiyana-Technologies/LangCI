// SoundDetectionService.swift
// LangCI — Sound Detection Test service protocol

import Foundation

protocol SoundDetectionService {

    // MARK: - Test Sounds (customizable)
    func getAllSounds() async throws -> [TestSound]
    func getActiveSounds() async throws -> [TestSound]
    func addSound(_ sound: TestSound) async throws -> TestSound
    func updateSound(_ sound: TestSound) async throws
    func deleteSound(id: Int) async throws

    // MARK: - Sessions
    func createSession(mode: TestMode, trialsPerSound: Int, distanceCm: Int, testerName: String?) async throws -> DetectionTestSession
    func getSession(id: Int) async throws -> DetectionTestSession?
    func getRecentSessions(count: Int) async throws -> [DetectionTestSession]
    func getAllSessions() async throws -> [DetectionTestSession]
    func completeSession(id: Int, notes: String?) async throws
    func deleteSession(id: Int) async throws

    // MARK: - Trials
    func recordTrial(_ trial: DetectionTrial) async throws -> DetectionTrial
    func getTrials(forSession sessionId: Int) async throws -> [DetectionTrial]
    func getTrials(forSession sessionId: Int, soundId: Int) async throws -> [DetectionTrial]

    // MARK: - Analytics
    /// Get per-sound scores for a session (for the grid display)
    func getSessionScores(sessionId: Int) async throws -> [SoundScore]
    /// Get per-sound scores across all sessions (progress over time)
    func getSoundProgress(soundId: Int, limit: Int) async throws -> [(date: Date, percentage: Int)]
}
