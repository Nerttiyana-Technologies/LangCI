// EnvironmentalSoundModels.swift
// LangCI — Environmental Sound Training for early CI activation
//
// In the first weeks after CI activation, the brain perceives
// electrical stimulation as static/beeping. Environmental sound
// training teaches the brain to map electrical patterns to real
// sounds, progressing through the listening hierarchy:
//   Detection → Discrimination → Identification → Comprehension
//
// This module provides structured exercises using everyday sounds
// that CI users encounter in daily life.

import UIKit

// MARK: - Sound Environment Category

/// Groups of environmental sounds by where they occur.
enum SoundEnvironment: String, Codable, CaseIterable {
    case home        = "home"
    case kitchen     = "kitchen"
    case indianHome  = "indian_home"
    case outdoors    = "outdoors"
    case people      = "people"
    case speech      = "speech"
    case animals     = "animals"
    case transport   = "transport"
    case alerts      = "alerts"
    case music       = "music"
    case tones       = "tones"

    var label: String {
        switch self {
        case .home:       return "Home"
        case .kitchen:    return "Kitchen"
        case .indianHome: return "Indian Home"
        case .outdoors:   return "Outdoors"
        case .people:     return "People"
        case .speech:     return "Speech"
        case .animals:    return "Animals"
        case .transport:  return "Transport"
        case .alerts:     return "Alerts"
        case .music:      return "Music"
        case .tones:      return "Tones"
        }
    }

    var icon: String {
        switch self {
        case .home:       return "house.fill"
        case .kitchen:    return "fork.knife"
        case .indianHome: return "sparkles"
        case .outdoors:   return "leaf.fill"
        case .people:     return "person.2.fill"
        case .speech:     return "mouth.fill"
        case .animals:    return "pawprint.fill"
        case .transport:  return "car.fill"
        case .alerts:     return "bell.fill"
        case .music:      return "music.note"
        case .tones:      return "tuningfork"
        }
    }

    var color: String {
        switch self {
        case .home:       return "lcBlue"
        case .kitchen:    return "lcOrange"
        case .indianHome: return "lcAmber"
        case .outdoors:   return "lcGreen"
        case .people:     return "lcPurple"
        case .speech:     return "lcPurple"
        case .animals:    return "lcAmber"
        case .transport:  return "lcRed"
        case .alerts:     return "lcTeal"
        case .music:      return "lcGold"
        case .tones:      return "lcBlue"
        }
    }
}

// MARK: - Listening Level (reuses AVT hierarchy concept)

/// Progressive listening levels for environmental sounds.
enum EnvironmentalListeningLevel: Int, Codable, CaseIterable, Comparable {
    case detection       = 0  // "Did you hear a sound?" (yes/no)
    case discrimination  = 1  // "Are these two sounds the same or different?"
    case identification  = 2  // "Which sound was it?" (pick from 3-4 choices)
    case categorisation  = 3  // "What category does this sound belong to?"

    var label: String {
        switch self {
        case .detection:      return "Detection"
        case .discrimination: return "Discrimination"
        case .identification: return "Identification"
        case .categorisation: return "Categorisation"
        }
    }

    var instruction: String {
        switch self {
        case .detection:      return "Did you hear a sound?"
        case .discrimination: return "Are these sounds the same or different?"
        case .identification: return "Which sound did you hear?"
        case .categorisation: return "What type of sound was that?"
        }
    }

    var emoji: String {
        switch self {
        case .detection:      return "👂"
        case .discrimination: return "🔀"
        case .identification: return "🎯"
        case .categorisation: return "🗂️"
        }
    }

    static func < (lhs: EnvironmentalListeningLevel, rhs: EnvironmentalListeningLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Environmental Sound Item

/// A single environmental sound with metadata for training.
struct EnvironmentalSoundItem: Identifiable {
    let id: String               // unique key, e.g. "doorbell"
    let name: String             // display name: "Doorbell"
    let environment: SoundEnvironment
    let description: String      // "A doorbell ringing"
    let systemSoundName: String? // iOS system sound ID (if available)
    let speechDescription: String // TTS fallback: describe the sound verbally

    /// Difficulty 1-5 for CI users.
    /// Low-frequency, simple sounds (knock, clap) = 1
    /// High-frequency, complex sounds (birds, music) = 5
    let ciDifficulty: Int
}

// MARK: - Training Session

struct EnvironmentalSoundSession: Identifiable, Codable {
    var id: Int
    var environment: String
    var listeningLevel: EnvironmentalListeningLevel
    var startedAt: Date
    var completedAt: Date?
    var totalItems: Int
    var correctItems: Int
    var daysPostActivation: Int   // track which day post-CI this session was

    var accuracy: Double {
        guard totalItems > 0 else { return 0 }
        return Double(correctItems) / Double(totalItems) * 100
    }
}

// MARK: - Custom Environmental Sound (user-created)

struct CustomEnvironmentalSound: Identifiable, Codable {
    var id: Int
    var soundId: String
    var name: String
    var environment: String
    var description: String
    var speechDescription: String
    var ciDifficulty: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    /// Convert to an EnvironmentalSoundItem for use in drills
    func toItem() -> EnvironmentalSoundItem {
        EnvironmentalSoundItem(
            id: soundId, name: name,
            environment: SoundEnvironment(rawValue: environment) ?? .home,
            description: description,
            systemSoundName: nil,
            speechDescription: speechDescription,
            ciDifficulty: ciDifficulty)
    }
}

// MARK: - Sound Edit Override (edits to built-in sounds)

struct SoundEditOverride: Identifiable, Codable {
    var id: Int
    var soundId: String
    var name: String?
    var description: String?
    var speechDescription: String?
    var ciDifficulty: Int?
    var updatedAt: Date
}

// MARK: - Weekly Sound Pack

struct WeeklySoundPack: Identifiable {
    let id: String              // "week1", "week2", etc.
    let title: String
    let subtitle: String
    let icon: String            // SF Symbol
    let color: UIColor
    let soundIds: [String]      // IDs of sounds in this pack
    var isUnlocked: Bool
    var isCompleted: Bool

    var soundCount: Int { soundIds.count }
}

// MARK: - Weekly Pack Progress (database record)

struct WeeklyPackProgress: Identifiable, Codable {
    var id: Int
    var packId: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var completed: Bool
}

// MARK: - Environmental Sound Progress

struct EnvironmentalSoundProgress: Identifiable, Codable {
    var id: Int
    var soundId: String
    var environment: String
    var currentLevel: EnvironmentalListeningLevel
    var totalAttempts: Int
    var correctAttempts: Int
    var isUnlocked: Bool
    var lastPracticedAt: Date?

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts) * 100
    }
}
