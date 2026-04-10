//
//  Recording.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct Recording: Identifiable, Codable {
    var id: Int
    
    var wordEntryId: Int
    var wordEntry: WordEntry?
    
    var dialectId: Int
    var dialect: Dialect?
    
    var familyMemberId: Int
    var familyMember: FamilyMember?
    
    var filePath: String = ""
    var format: String = "wav"
    var durationSeconds: Double
    var peakAmplitude: Double
    var averageFrequencyHz: Double?
    var isApproved: Bool = true
    var recordedAt: Date = Date()

}
