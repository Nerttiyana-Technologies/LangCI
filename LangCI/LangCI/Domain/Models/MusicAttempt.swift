//
//  MusicAttempt.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct MusicAttempt: Identifiable, Codable {
    var id: Int
    
    // Enums (Ensure MusicTrainingType and ProcessorProgram are Codable)
    var trainingType: MusicTrainingType
    
    // e.g. "piano", "waltz"
    var playedItem: String = ""
    
    var userAnswer: String = ""
    var isCorrect: Bool
    
    var programUsed: ProcessorProgram
    var attemptedAt: Date = Date()

}
