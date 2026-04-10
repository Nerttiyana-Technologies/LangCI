//
//  Language.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct Language: Identifiable, Codable {
    var id: Int
    
    // e.g. "ta" (Tamil), "te" (Telugu), "si" (Sinhala)
    var code: String = ""
    
    // English name: "Tamil"
    var name: String = ""
    
    // Native name: "தமிழ்"
    var nativeName: String = ""
    
    // Script system: "Tamil", "Telugu", "Sinhala", "Latin"
    var scriptCode: String = ""
    
    // Font to load for rendering this script correctly
    var fontFamily: String = ""
    
    // RTL support for Arabic, Urdu etc.
    var isRightToLeft: Bool = false
    
    var isActive: Bool = true
    
    // Navigation collections
    var dialects: [Dialect] = []
    var words: [WordEntry] = []
    var categories: [WordCategory] = []
    var phoneticGroups: [PhoneticGroup] = []
    var publisherPacks: [PublisherPack] = []

}
