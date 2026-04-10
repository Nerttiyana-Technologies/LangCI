//
//  WordEntry.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct WordEntry: Identifiable, Codable {
    var id: Int
    var globalId: UUID // Swift's equivalent to C# Guid
    
    var languageId: Int
    var language: Language?
    
    var nativeScript: String = ""
    var ipaPhoneme: String = ""
    var phoneticKey: String?
    var isSlang: Bool = false
    var categoryCode: String?

    // Enums (Ensure these are defined as Codable)
    var source: WordSource = .publisher
    var status: WordStatus = .active
    
    var publisherPackId: Int?
    var publisherPack: PublisherPack?
    
    var syncStatus: SyncStatus = .local
    var lastSyncedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Navigation collections
    var translations: [WordTranslation] = []
    var categoryMaps: [WordCategoryMap] = []
    var dialectMaps: [WordDialectMap] = []
    var phoneticGroupMembers: [PhoneticGroupMember] = []
    var recordings: [Recording] = []
    var sessionWords: [SessionWord] = []

}

enum WordSource: Int, Codable {
    case publisher = 0 // pushed by you via API
    case user = 1      // added by the user locally
}

enum WordStatus: Int, Codable {
    case draft = 0    // user added, not yet reviewed
    case active = 1   // visible in library and training
    case archived = 2 // hidden but kept for history
}

enum SyncStatus: Int, Codable {
    case local = 0           // never synced
    case synced = 1          // matches cloud
    case pendingUpload = 2   // user word waiting to push
    case pendingDownload = 3 // newer version available
}
