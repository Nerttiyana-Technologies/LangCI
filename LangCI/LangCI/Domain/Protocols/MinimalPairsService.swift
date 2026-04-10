//
//  MinimalPairsService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol MinimalPairsService {
    /// Build a session queue of minimal pairs for the given language/dialect.
    func getPairsForSession(languageId: Int, dialectId: Int?, count: Int) async throws -> [MinimalPairDto]

    /// Record the user's choice and persist it.
    func recordAttempt(minimalPairId: Int, playedWordEntryId: Int, selectedWordEntryId: Int, familyMemberId: Int?) async throws -> MinimalPairAttemptResult

    /// The pairs where the user scores lowest (for targeted practice).
    func getWeakestPairs(languageId: Int, limit: Int) async throws -> [MinimalPairDto]

    /// Per-contrast accuracy summary (e.g. voiced/unvoiced = 62%).
    func getContrastAccuracy(languageId: Int) async throws -> [ContrastAccuracy]
}

struct MinimalPairDto: Identifiable, Codable {
    var id: Int
    var ciDifficultyLevel: Int
    var contrastDescription: String = ""
    var word1: MinimalPairWordDto
    var word2: MinimalPairWordDto

}

struct MinimalPairWordDto: Codable {
    var wordEntryId: Int
    var nativeScript: String = ""
    var translation: String = ""
    var transliteration: String = ""
    var recordingPath: String?

}

struct MinimalPairAttemptResult: Codable {
    var isCorrect: Bool
    var pointsEarned: Int
    var badgeEarned: String?
}

struct ContrastAccuracy: Codable {
    var contrastDescription: String = ""
    var totalAttempts: Int
    var accuracyPct: Double
    
    // Computed property
    var accuracyNorm: Double {
        accuracyPct / 100.0
    }
}
