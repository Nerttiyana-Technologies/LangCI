//
//  PublisherPack.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct PublisherPack: Identifiable, Codable {
    var id: Int
    var globalId: UUID // Swift equivalent to Guid
    
    var languageId: Int
    var language: Language?
    
    // "Madurai Slang Pack 1"
    var name: String = ""
    
    // "Advanced slang and expressions from Madurai"
    var description: String = ""
    
    // 1=Beginner, 2=Intermediate, 3=Advanced
    var difficultyLevel: Int = 1
    
    // Version number
    var version: Int = 1
    
    var publishedAt: Date
    var syncedAt: Date?
    
    var isInstalled: Bool = false
    var isPremium: Bool = false
    
    // Navigation
    var words: [WordEntry] = []
}
