//
//  SessionWord.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct SessionWord: Identifiable, Codable {
    var id: Int
    
    var trainingSessionId: Int
    var trainingSession: TrainingSession?
    
    var wordEntryId: Int
    var wordEntry: WordEntry?
    
    // SM-2 Spaced Repetition fields
    // 0 = couldn't hear, 1 = partially, 2 = clear
    var rating: Int
    
    // SM-2 ease factor — starts at 2.5
    var easeFactor: Double = 2.5
    
    // Days until next review
    var intervalDays: Int = 1
    
    // How many times reviewed total
    var repetitionCount: Int
    
    var nextReviewDate: Date = Date()
    var reviewedAt: Date = Date()

}
