//
//  MusicPerceptionService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol MusicPerceptionService {
    /// Record the user's attempt and return the result.
    func recordAttempt(_ attempt: MusicAttempt) async throws -> MusicAttempt
    
    /// Get accuracy statistics grouped by training type.
    func getStatsByType() async throws -> [MusicStatsDto]
    
    /// Get the combined accuracy across all music modes.
    func getOverallAccuracy() async throws -> Double
    
    /// Returns the built-in item list for a training type.
    func getItems(for mode: MusicTrainingType) -> [MusicItem]
}

// MARK: - DTOs
struct MusicStatsDto: Codable {
    var trainingType: MusicTrainingType
    var typeLabel: String = ""
    var attempts: Int
    var accuracyPct: Double
    
    /// Accuracy as a 0.0 - 1.0 fraction.
    var accuracyNorm: Double {
        accuracyPct / 100.0
    }
}

/// One playable item in a music training session.
struct MusicItem: Codable {
    var name: String = ""
    var audioFile: String = "" // Resources/Raw/ filename
    var description: String = ""
    var emoji: String = "🎵"
    var type: MusicTrainingType
    var distractors: [String] = []
}
