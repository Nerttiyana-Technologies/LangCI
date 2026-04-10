// ReadingAloudService.swift
// LangCI — protocol for the read-aloud drill (speed & loudness tracking).

import Foundation

protocol ReadingAloudService {

    // MARK: - Passages
    func getAllPassages() async throws -> [ReadingPassage]
    func getBundledPassages() async throws -> [ReadingPassage]
    func savePassage(_ passage: ReadingPassage) async throws -> ReadingPassage
    func deletePassage(id: Int) async throws

    // MARK: - Sessions
    func saveSession(_ session: ReadingSession) async throws -> ReadingSession
    func deleteSession(id: Int) async throws
    func getRecentSessions(limit: Int) async throws -> [ReadingSession]
    func getSessionsForPassage(_ passageId: Int) async throws -> [ReadingSession]

    // MARK: - Stats
    func getStats(days: Int?) async throws -> ReadingStatsDto
}
