//
//  FamilyMember.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct FamilyMember: Identifiable, Codable {
    var id: Int
    var name: String = ""
    var relationship: String = ""
    var avatarInitials: String = ""
    var avatarColorHex: String = "#1D9E75"
    var preferredDialectId: Int
    var preferredDialect: Dialect?
    var baselineFrequencyHz: Double?
    var createdAt: Date = Date()
    
    // Navigation
    var recordings: [Recording] = []

}
