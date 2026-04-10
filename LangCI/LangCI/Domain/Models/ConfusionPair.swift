// ConfusionPair.swift
// LangCI
//
// Tracks "trainer said X, I heard Y" moments noticed by the user.
// Used to build a personalised confusion matrix and suggest targeted drills.

import Foundation

/// Where the confusion pair was captured.
enum ConfusionSource: Int, Codable, CaseIterable {
    case manual         = 0   // Standalone quick-log, not tied to any drill
    case avtDrill       = 1   // Captured inline inside an AVT drill
    case minimalPairs   = 2   // Captured during minimal pairs drill
    case therapySession = 3   // External: noted during a speech therapy session

    var label: String {
        switch self {
        case .manual:         return "Quick Log"
        case .avtDrill:       return "AVT Drill"
        case .minimalPairs:   return "Minimal Pairs"
        case .therapySession: return "Therapy Session"
        }
    }

    var emoji: String {
        switch self {
        case .manual:         return "✏️"
        case .avtDrill:       return "🎯"
        case .minimalPairs:   return "🔀"
        case .therapySession: return "🗣️"
        }
    }
}

struct ConfusionPair: Identifiable, Codable {
    var id: Int
    /// What the trainer / audio actually said.
    var saidWord: String
    /// What the user perceived / answered.
    var heardWord: String
    /// Optional phoneme tag, e.g. "sh", "mm", "p" — free text.
    var targetSound: String
    var source: ConfusionSource
    /// Optional link to the AVT session this was captured in.
    var avtSessionId: Int?
    var contextNote: String?
    var loggedAt: Date

    init(id: Int = 0,
         saidWord: String,
         heardWord: String,
         targetSound: String = "",
         source: ConfusionSource = .manual,
         avtSessionId: Int? = nil,
         contextNote: String? = nil,
         loggedAt: Date = Date())
    {
        self.id = id
        self.saidWord = saidWord
        self.heardWord = heardWord
        self.targetSound = targetSound
        self.source = source
        self.avtSessionId = avtSessionId
        self.contextNote = contextNote
        self.loggedAt = loggedAt
    }

    /// "Amma → Appa"
    var displayPair: String { "\(saidWord) → \(heardWord)" }
}

/// Aggregated "most-confused pairs" for reporting.
struct ConfusionStatDto {
    var saidWord: String
    var heardWord: String
    var count: Int
    var mostRecent: Date
}
