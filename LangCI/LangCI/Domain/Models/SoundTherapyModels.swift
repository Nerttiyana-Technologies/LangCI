// SoundTherapyModels.swift
// LangCI — Sound Therapy domain models
//
// Comprehensive sound training for cochlear implant users.
// Covers minimal pair drills, sound isolation exercises,
// and adaptive difficulty progression with voice gender control.

import Foundation

// MARK: - Sound Category

/// Groups of sounds that share acoustic characteristics.
/// CI users typically struggle most with high-frequency fricatives.
enum SoundCategory: String, Codable, CaseIterable {
    case fricatives   = "fricatives"    // sh, s, f, th, z, v
    case nasals       = "nasals"        // m, n, ng
    case plosives     = "plosives"      // p, b, t, d, k, g
    case affricates   = "affricates"    // ch, j
    case vowels       = "vowels"        // a, e, i, o, u
    case blends       = "blends"        // sh+vowel, ush, ash

    var label: String {
        switch self {
        case .fricatives: return "Fricatives"
        case .nasals:     return "Nasals"
        case .plosives:   return "Plosives"
        case .affricates: return "Affricates"
        case .vowels:     return "Vowels"
        case .blends:     return "Blends"
        }
    }

    var icon: String {
        switch self {
        case .fricatives: return "wind"
        case .nasals:     return "waveform"
        case .plosives:   return "burst"
        case .affricates: return "waveform.path.ecg"
        case .vowels:     return "mouth"
        case .blends:     return "arrow.triangle.merge"
        }
    }

    var color: String {
        switch self {
        case .fricatives: return "lcTeal"
        case .nasals:     return "lcPurple"
        case .plosives:   return "lcOrange"
        case .affricates: return "lcAmber"
        case .vowels:     return "lcBlue"
        case .blends:     return "lcGreen"
        }
    }
}

// MARK: - Voice Gender

/// Female voices have higher formant frequencies making sounds more distinct
/// for CI users. Male voices are harder to discriminate — used as advanced
/// difficulty.
enum VoiceGender: Int, Codable, CaseIterable {
    case female = 0
    case male   = 1

    var label: String {
        switch self {
        case .female: return "Female"
        case .male:   return "Male"
        }
    }

    /// AVSpeechSynthesizer voice identifier hints
    var voiceLanguageHint: String {
        switch self {
        case .female: return "en-US"   // Samantha (female) is default
        case .male:   return "en-GB"   // Daniel (male)
        }
    }
}

// MARK: - Exercise Difficulty

/// Progressive difficulty for sound isolation exercises.
enum SoundExerciseLevel: Int, Codable, CaseIterable, Comparable {
    case isolation  = 0   // Hear the sound alone: "sh"
    case syllable   = 1   // Hear it in syllables: "sha", "she", "shi"
    case word       = 2   // Hear it in words: "ship", "shop", "fish"
    case sentence   = 3   // Hear it in sentences: "She sells seashells"

    var label: String {
        switch self {
        case .isolation: return "Isolation"
        case .syllable:  return "Syllable"
        case .word:      return "Word"
        case .sentence:  return "Sentence"
        }
    }

    var emoji: String {
        switch self {
        case .isolation: return "1"
        case .syllable:  return "2"
        case .word:      return "3"
        case .sentence:  return "4"
        }
    }

    var description: String {
        switch self {
        case .isolation: return "Hear the sound alone"
        case .syllable:  return "Hear it in syllables"
        case .word:      return "Hear it in words"
        case .sentence:  return "Hear it in sentences"
        }
    }

    static func < (lhs: SoundExerciseLevel, rhs: SoundExerciseLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Target Sound Definition

/// A single phoneme/sound with its practice content at each level.
struct TargetSoundDefinition {
    let sound: String           // e.g. "sh"
    let ipa: String             // e.g. "/ʃ/"
    let category: SoundCategory
    let frequencyRange: String  // e.g. "3500-8000 Hz"

    // Content for each exercise level
    let isolationForms: [String]     // ["sh"]
    let syllableForms: [String]      // ["sha", "she", "shi", "sho", "shu"]
    let wordForms: [String]          // ["ship", "shop", "push", "fish", "shell"]
    let sentenceForms: [String]      // ["She sells seashells by the seashore"]

    // Minimal pair partners (sounds commonly confused with this one)
    let confusionPartners: [String]  // ["s", "ch", "th"]
}

// MARK: - Minimal Pair Item

/// A pair of words/sounds that differ by exactly one phoneme.
struct SoundMinimalPairItem {
    let sound1: String        // e.g. "ship"
    let sound2: String        // e.g. "sip"
    let phoneme1: String      // e.g. "sh"
    let phoneme2: String      // e.g. "s"
    let contrastLabel: String // e.g. "sh vs s"
    let difficulty: Int       // 1-5
}

// MARK: - Sound Therapy Session

/// Records one practice session of sound therapy exercises.
struct SoundTherapySession: Identifiable, Codable {
    var id: Int
    var exerciseType: String        // "minimal_pair", "isolation", "identification"
    var targetSound: String
    var voiceGender: VoiceGender
    var exerciseLevel: SoundExerciseLevel
    var startedAt: Date
    var completedAt: Date?
    var totalItems: Int
    var correctItems: Int
    var isAdaptive: Bool            // auto-progression vs therapist-set

    var accuracy: Double {
        guard totalItems > 0 else { return 0 }
        return Double(correctItems) / Double(totalItems) * 100
    }
}

// MARK: - Sound Progress

/// Tracks cumulative progress for a specific sound.
struct SoundProgress: Identifiable, Codable {
    var id: Int
    var sound: String
    var category: String
    var currentLevel: SoundExerciseLevel
    var totalSessions: Int
    var totalCorrect: Int
    var totalAttempts: Int
    var bestAccuracy: Double
    var lastPracticedAt: Date?
    var isUnlocked: Bool

    // Adaptive progression thresholds
    var femaleVoiceAccuracy: Double  // avg accuracy with female voice
    var maleVoiceAccuracy: Double    // avg accuracy with male voice

    var overallAccuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts) * 100
    }

    /// Whether the user has "mastered" this sound at current level
    /// (>80% accuracy on both voice genders)
    var isMastered: Bool {
        femaleVoiceAccuracy >= 80 && maleVoiceAccuracy >= 80
    }

    /// Whether ready to advance to next level
    var canAdvance: Bool {
        isMastered && currentLevel != .sentence
    }
}

// MARK: - Sound Therapy Home Stats

struct SoundTherapyHomeStats {
    var totalSoundsUnlocked: Int
    var soundsMastered: Int
    var sessionsThisWeek: Int
    var overallAccuracy: Double
    var weakestSound: String?
    var strongestSound: String?
    var currentStreak: Int
}

// MARK: - Exercise Result (used in drill screens)

struct SoundExerciseResult {
    var sound: String
    var level: SoundExerciseLevel
    var voiceGender: VoiceGender
    var totalItems: Int
    var correctItems: Int
    var accuracy: Double
    var duration: TimeInterval
    var itemResults: [SoundItemResult]
}

struct SoundItemResult {
    var presented: String       // what was spoken
    var target: String          // correct answer
    var userChoice: String      // what user picked
    var isCorrect: Bool
    var reactionTimeMs: Int     // time to respond
}
