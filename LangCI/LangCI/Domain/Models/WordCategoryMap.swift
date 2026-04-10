//
//  WordCategoryMap.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct WordCategoryMap: Codable {
    var wordEntryId: Int
    var wordEntry: WordEntry?
    
    var wordCategoryId: Int
    var wordCategory: WordCategory?

}
