// AVTModels.swift
// LangCI — Auditory Verbal Therapy domain models

import Foundation

// MARK: - Listening Hierarchy

/// The four progressive levels of AVT listening skill.
enum ListeningHierarchy: Int, Codable, CaseIterable {
    case detection      = 0   // Did you hear *a* sound? yes/no
    case discrimination = 1   // Are these two sounds the same or different?
    case identification = 2   // Which word/sound is it? (multiple choice)
    case comprehension  = 3   // What does it mean? (context/meaning)

    var label: String {
        switch self {
        case .detection:      return "Detection"
        case .discrimination: return "Discrimination"
        case .identification: return "Identification"
        case .comprehension:  return "Comprehension"
        }
    }

    var emoji: String {
        switch self {
        case .detection:      return "👂"
        case .discrimination: return "🔀"
        case .identification: return "🎯"
        case .comprehension:  return "💡"
        }
    }

    var description: String {
        switch self {
        case .detection:      return "Can you hear the sound?"
        case .discrimination: return "Same or different?"
        case .identification: return "Which sound is it?"
        case .comprehension:  return "What does it mean?"
        }
    }
}

// MARK: - AVT Target

/// A phoneme/sound assigned by an audiologist for focused practice.
struct AVTTarget: Identifiable, Codable {
    var id: Int
    var sound: String           // e.g. "sh", "mm", "ush"
    var phonemeIpa: String      // e.g. "/ʃ/", "/m/", "/ʌʃ/"
    var frequencyRange: String  // e.g. "3500–8000 Hz"
    var soundDescription: String // e.g. "Voiceless palato-alveolar fricative"
    var currentLevel: ListeningHierarchy
    var isActive: Bool
    var assignedAt: Date
    var audiologistNote: String?

    // Computed
    var displayName: String { "\(sound)  \(phonemeIpa)" }
}

// MARK: - AVT Session

struct AVTSession: Identifiable, Codable {
    var id: Int
    var targetSound: String
    var hierarchyLevel: ListeningHierarchy
    var startedAt: Date
    var completedAt: Date?
    var totalAttempts: Int
    var correctAttempts: Int
    var attempts: [AVTAttempt] = []

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts) * 100
    }
}

// MARK: - AVT Attempt

struct AVTAttempt: Identifiable, Codable {
    var id: Int
    var sessionId: Int
    var targetSound: String         // the sound being practised
    var presentedSound: String      // what was actually presented
    var userResponse: String        // the user's answer
    var isCorrect: Bool
    var hierarchyLevel: ListeningHierarchy
    var attemptedAt: Date
}

// MARK: - AVT Audiologist Note

struct AVTAudiologistNote: Identifiable, Codable {
    var id: Int
    var notedAt: Date
    var targetSounds: String        // comma-separated, e.g. "sh,mm,ush"
    var notes: String
    var nextAppointment: Date?

    var targetSoundList: [String] {
        targetSounds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - DTOs

struct AVTProgressDto {
    var sound: String
    var phonemeIpa: String
    var currentLevel: ListeningHierarchy
    var totalSessions: Int
    var recentAccuracy: Double      // last 5 sessions avg
    var isActive: Bool
    var trend: AVTTrend
}

enum AVTTrend { case improving, stable, needsWork }

struct AVTHomeStats {
    var activeTargets: Int
    var sessionsToday: Int
    var overallAccuracy: Double
    var currentFocusSound: String   // most recently assigned active target
    var streakDays: Int
}
