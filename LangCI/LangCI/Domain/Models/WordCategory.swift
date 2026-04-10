//
//  WordCategory.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct WordCategory: Identifiable, Codable {
    var id: Int
    var languageId: Int
    var language: Language?
    
    // Machine key — stable: "body", "food", "slang"
    var code: String = ""
    
    // Display in native script: "உடல் உறுப்புகள்"
    var nativeDisplayName: String = ""
    
    // Display in English: "Body parts"
    var englishDisplayName: String = ""
    
    // Display order in UI
    var sortOrder: Int
    
    // Navigation
    var wordCategoryMaps: [WordCategoryMap] = []
    
}
