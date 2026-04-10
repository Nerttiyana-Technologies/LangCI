//
//  RecordingRequest.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct RecordingRequest: Identifiable, Codable {
    var id: Int
    
    // Generates a short 8-char hex token similar to the C# logic
    var token: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).uppercased()
    
    var familyMemberId: Int
    var familyMember: FamilyMember?
    
    // Comma-separated WordEntry IDs
    var requestedWordIds: String = ""
    
    // Optional personal note
    var message: String?
    
    // Enum (Requires RecordingRequestStatus to be defined)
    var status: RecordingRequestStatus = .pending
    
    var totalWords: Int
    var completedCount: Int
    
    var createdAt: Date = Date()
    var expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    // Computed Property
    var isExpired: Bool {
        status == .pending && Date() > expiresAt
    }

}
