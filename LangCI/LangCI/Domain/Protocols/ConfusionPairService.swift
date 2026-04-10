// ConfusionPairService.swift
// LangCI — protocol for the personal "said X, heard Y" log.

import Foundation

protocol ConfusionPairService {

    // MARK: - CRUD
    func logPair(_ pair: ConfusionPair) async throws -> ConfusionPair
    func deletePair(id: Int) async throws

    // MARK: - Queries
    /// Most recent pairs first.
    func getRecentPairs(limit: Int) async throws -> [ConfusionPair]
    /// All pairs tied to a specific AVT session.
    func getPairsForSession(_ sessionId: Int) async throws -> [ConfusionPair]
    /// All pairs tagged with a specific target sound.
    func getPairsForSound(_ sound: String) async throws -> [ConfusionPair]

    // MARK: - Aggregations
    /// Top (saidWord, heardWord) combos ordered by frequency, across the last
    /// `days` days (or all-time if `days == nil`).
    func getTopConfusions(limit: Int, days: Int?) async throws -> [ConfusionStatDto]
    /// Total count for the given window.
    func getCount(days: Int?) async throws -> Int
}
