//
//  WordTranslation.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct WordTranslation: Identifiable, Codable {
    var id: Int
    var wordEntryId: Int
    var wordEntry: WordEntry?
    
    // ISO 639-1 code: "en", "fr", "de"
    var targetLanguageCode: String = ""
    
    // "Hand"
    var translation: String = ""
    
    // Latin-script pronunciation: "kai"
    var transliteration: String = ""
    
    // Optional example sentences
    var exampleNative: String?
    var exampleTranslation: String?

}
