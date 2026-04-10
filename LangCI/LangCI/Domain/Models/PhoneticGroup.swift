//
//  PhoneticGroup.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct PhoneticGroup: Identifiable, Codable {
    var id: Int
    var languageId: Int
    var language: Language?
    
    // Stable key: "ai_end"
    var groupKey: String = ""
    
    // "Words ending in the 'ai' sound"
    var description: String = ""
    
    // Shared phonetic pattern: "aɪ"
    var sharedIpaPattern: String = ""
    
    // Training difficulty (1=easiest, 5=hardest)
    var ciDifficultyLevel: Int = 3
    
    // Navigation
    var members: [PhoneticGroupMember] = []

}
