//
//  MinimalPairAttempt.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct MinimalPairAttempt: Identifiable, Codable {
    var id: Int
    
    var minimalPairId: Int
    var minimalPair: MinimalPair?
    
    /// Id of the word that was actually played.
    var playedWordEntryId: Int
    
    /// Id of the word the user tapped — nil if they gave up.
    var selectedWordEntryId: Int?
    
    var isCorrect: Bool
    
    var familyMemberId: Int?
    var familyMember: FamilyMember?
    
    var attemptedAt: Date = Date()

}
