// TrainingService.swift
// LangCI

import Foundation

protocol TrainingService {
    // ── Session lifecycle ────────────────────────────────────────────────────────
    func startSession(
        dialectId: Int,
        categoryCode: String,
        mode: TrainingMode,
        wordLimit: Int
    ) async throws -> TrainingSession

    /// Record the user's rating for a word in the current session.
    /// Returns the updated point/badge award result.
    func recordAnswer(
        sessionId: Int,
        wordEntryId: Int,
        rating: Int                 // 0=couldn't hear, 1=partial, 2=clear
    ) async throws -> AwardResult

    func completeSession(id: Int) async throws -> TrainingSession

    // ── Fetch ────────────────────────────────────────────────────────────────────
    func getRecentSessions(count: Int) async throws -> [TrainingSession]

    /// Words whose nextReviewDate <= today, ordered by priority (SM-2 algorithm).
    func getDueWords(dialectId: Int, limit: Int) async throws -> [SessionWord]
}
