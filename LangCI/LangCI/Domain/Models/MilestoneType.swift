//
//  MilestoneType.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

enum MilestoneType: Int, Codable, CaseIterable {
    case activation           = 0
    case firstWord            = 1
    case week1Check           = 2
    case month1Check          = 3
    case month3Check          = 4
    case month6Check          = 5
    case year1Check           = 6
    case firstPhoneCall       = 7
    case firstMusic           = 8
    case custom               = 9

    // v3.1 — firsts across every data source so the user can see
    // every "first time I did X" moment in one timeline, even when
    // the event is already captured in the journal / drill tables.
    case firstTrainingSession = 10
    case firstAVTSession      = 11
    case firstLing6Session    = 12
    case firstMappingSession  = 13
    case firstFatigueLog      = 14
    case firstConfusionLogged = 15
    case firstReadingAloud    = 16
    case firstBadgeEarned     = 17
    case first100Points       = 18

    // True when this type can be auto-detected from data in other
    // tables. Auto-detected types are created at most once (uniqueness
    // is enforced at the service layer).
    var isAutoDetectable: Bool {
        switch self {
        case .activation,
             .firstWord,
             .firstPhoneCall,
             .firstMusic,
             .custom:
            return false
        case .week1Check, .month1Check, .month3Check, .month6Check, .year1Check:
            return true
        case .firstTrainingSession,
             .firstAVTSession,
             .firstLing6Session,
             .firstMappingSession,
             .firstFatigueLog,
             .firstConfusionLogged,
             .firstReadingAloud,
             .firstBadgeEarned,
             .first100Points:
            return true
        }
    }

    /// True when only ONE row of this type may exist (e.g. CI Activation).
    var isSingleton: Bool {
        switch self {
        case .activation,
             .week1Check, .month1Check, .month3Check, .month6Check, .year1Check,
             .firstTrainingSession,
             .firstAVTSession,
             .firstLing6Session,
             .firstMappingSession,
             .firstFatigueLog,
             .firstConfusionLogged,
             .firstReadingAloud,
             .firstBadgeEarned,
             .first100Points:
            return true
        case .firstWord,
             .firstPhoneCall,
             .firstMusic,
             .custom:
            return false
        }
    }

    /// Types the user can pick from the Add Milestone sheet.
    /// Auto-detected scheduled checks (week1Check, etc.) are filtered out.
    static var userPickable: [MilestoneType] {
        [
            .activation,
            .firstWord,
            .firstPhoneCall,
            .firstMusic,
            .firstTrainingSession,
            .firstAVTSession,
            .firstLing6Session,
            .firstMappingSession,
            .firstFatigueLog,
            .firstConfusionLogged,
            .firstReadingAloud,
            .custom
        ]
    }
}
