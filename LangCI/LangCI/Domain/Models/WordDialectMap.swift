//
//  WordDialectMap.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct WordDialectMap: Codable {
    var wordEntryId: Int
    var wordEntry: WordEntry?
    
    var dialectId: Int
    var dialect: Dialect?
    
    // Dialect-specific pronunciation variation if different from base IPA
    var dialectIpaVariant: String?
    
    // Is this word more common in this dialect vs others?
    var isPrimary: Bool = true
}
