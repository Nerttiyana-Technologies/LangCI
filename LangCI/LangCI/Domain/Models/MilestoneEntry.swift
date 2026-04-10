//
//  MilestoneEntry.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct MilestoneEntry: Identifiable, Codable {
    var id: Int
    var type: MilestoneType
    var achievedAt: Date = Date()
    var accuracyAtMilestone: Double?
    var description: String = ""
    var notes: String?
    var emoji: String = "🎉"

    // Computed Property for Labels
    var typeLabel: String {
        switch type {
        case .activation:           return "CI Activation"
        case .firstWord:            return "First Word Heard"
        case .week1Check:           return "1 Week Check"
        case .month1Check:          return "1 Month Check"
        case .month3Check:          return "3 Month Check"
        case .month6Check:          return "6 Month Check"
        case .year1Check:           return "1 Year Check"
        case .firstPhoneCall:       return "First Phone Call"
        case .firstMusic:           return "First Music Recognised"
        case .firstTrainingSession: return "First Training Session"
        case .firstAVTSession:      return "First AVT Drill"
        case .firstLing6Session:    return "First Ling 6 Check"
        case .firstMappingSession:  return "First Mapping Visit"
        case .firstFatigueLog:      return "First Fatigue Log"
        case .firstConfusionLogged: return "First Confusion Logged"
        case .firstReadingAloud:    return "First Reading Aloud"
        case .firstBadgeEarned:     return "First Badge Earned"
        case .first100Points:       return "100 Points Reached"
        case .custom:               return description.isEmpty ? "Custom Milestone" : description
        }
    }

    // Computed Property for Default Emojis
    var defaultEmoji: String {
        switch type {
        case .activation:           return "👂"
        case .firstWord:            return "💬"
        case .week1Check:           return "📅"
        case .month1Check:          return "🗓️"
        case .month3Check:          return "📊"
        case .month6Check:          return "⭐"
        case .year1Check:           return "🏆"
        case .firstPhoneCall:       return "📞"
        case .firstMusic:           return "🎵"
        case .firstTrainingSession: return "👣"
        case .firstAVTSession:      return "🎯"
        case .firstLing6Session:    return "🔔"
        case .firstMappingSession:  return "🏥"
        case .firstFatigueLog:      return "📓"
        case .firstConfusionLogged: return "🔄"
        case .firstReadingAloud:    return "📖"
        case .firstBadgeEarned:     return "🏅"
        case .first100Points:       return "💯"
        case .custom:               return "🎉"
        }
    }
}
