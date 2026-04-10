//
//  Dialect.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct Dialect: Identifiable, Codable {
    var id: Int
    var languageId: Int?
    var name: String = ""
    var nativeName: String = ""
    var regionCode: String = ""
    var colorHex: String = ""
    var isActive: Bool = true
    
    var wordDialectMaps: [WordDialectMap] = []
    var familyMembers: [FamilyMember] = []
    var recordings: [Recording] = []
}
