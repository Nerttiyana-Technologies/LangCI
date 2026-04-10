//
//  MinimalPair.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct MinimalPair: Identifiable, Codable {
    var id: Int
    
    var languageId: Int
    var language: Language?
    
    var wordEntryId1: Int
    var wordEntry1: WordEntry?
    
    var wordEntryId2: Int
    var wordEntry2: WordEntry?
    
    /// Human-readable contrast label, e.g. "voiced/unvoiced", "retroflex/dental".
    var contrastDescription: String = ""
    
    /// 1 (easiest) – 5 (hardest) for CI users.
    var ciDifficultyLevel: Int = 1
    
    // Navigation
    var attempts: [MinimalPairAttempt] = []

}
