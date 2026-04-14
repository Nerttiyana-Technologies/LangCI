// SoundDetectionModels.swift
// LangCI — Sound Detection & Discrimination Test
//
// Replicates the audiologist's paper tracking sheet digitally.
// Supports both clinic mode (audiologist marks ✓/✗) and self-test
// mode (app plays sound, user picks from choices).
//
// The sound list is fully customizable — audiologist can add/remove
// any sounds they want to track. Defaults to Ling 6 + common extras.

import Foundation

// MARK: - Test Sound

/// A single sound that can be tested (e.g. "a", "sh", "ush", "mm")
struct TestSound: Identifiable, Codable {
    var id: Int
    var symbol: String          // Display symbol: "a", "sh", "ush", "mm"
    var tamilLabel: String?     // Optional Tamil label: "ஷ்"
    var ipaSymbol: String?      // IPA notation: "/ʃ/"
    var ttsHint: String?        // How TTS should pronounce this (e.g. "church" for "ch")
    var audioFileName: String?  // Pre-recorded audio file (nil = use TTS)
    var sortOrder: Int          // Position in the grid
    var isActive: Bool          // Can be hidden without deleting
    var isDefault: Bool         // Part of the default set
    var createdAt: Date

    /// For TTS playback — the text to speak.
    ///
    /// iOS TTS CANNOT produce isolated phonetic sounds reliably.
    /// Short strings like "eee", "ooo", "mmmm" get spelled out as
    /// individual letters or produce garbage across en-IN / en-AU voices.
    ///
    /// The ONLY reliable approach: use real English words that every
    /// TTS voice knows how to say, chosen so the TARGET sound is
    /// the dominant audible component. The audiologist can override
    /// any of these via the ttsHint field.
    var speakableText: String {
        // If the audiologist provided a pronunciation hint, always use it
        if let hint = ttsHint, !hint.isEmpty { return hint }

        // Real words that emphasise the target sound
        switch symbol.lowercased() {
        case "a", "ah":     return "father"       // clear /ɑː/ vowel
        case "ee":          return "see"           // clear /iː/ vowel
        case "oo":          return "blue"          // clear /uː/ vowel
        case "mm":          return "hum"           // clear /m/ ending
        case "sh":          return "shoe"          // clear /ʃ/ onset
        case "ss", "s":     return "sun"           // clear /s/ onset
        case "ush":         return "push"          // clear /ʊʃ/ ending
        case "e":           return "bed"           // clear /ɛ/ vowel
        case "o":           return "go"            // clear /oː/ vowel
        default:            return symbol
        }
    }
}

// MARK: - Detection Test Session

/// One complete test session (e.g. "07/07/2026 — audiologist visit")
struct DetectionTestSession: Identifiable, Codable {
    var id: Int
    var testedAt: Date
    var mode: TestMode              // audiologist or self-test
    var trialsPerSound: Int         // typically 9 (like the paper)
    var distanceCm: Int             // distance from speaker (100cm standard)
    var testerName: String?         // "Dr. Priya" or nil for self
    var notes: String?
    var isComplete: Bool
    var createdAt: Date
}

enum TestMode: Int, Codable {
    case audiologist = 0    // someone else plays & marks
    case selfTest = 1       // app plays, user picks
}

// MARK: - Detection Trial

/// A single trial result: one sound played, one response recorded
struct DetectionTrial: Identifiable, Codable {
    var id: Int
    var sessionId: Int              // FK → DetectionTestSession
    var soundId: Int                // FK → TestSound
    var trialNumber: Int            // 1–9 (or however many trials)
    var isDetected: Bool            // Could user hear ANY sound?
    var isCorrect: Bool             // Did user correctly identify the sound?
    var userResponse: String?       // What they thought they heard (for confusion tracking)
    var responseTimeMs: Int?        // How long to respond (ms) — useful metric
    var createdAt: Date
}

// MARK: - Grid Cell (computed, not stored)

/// Represents one cell in the tracking grid (for display)
struct GridCell {
    let trialNumber: Int
    let sound: TestSound
    let result: TrialResult
}

enum TrialResult {
    case correct        // ✓
    case wrong          // ✗
    case detected       // Heard something but wrong identification
    case notTested      // Empty cell
}

// MARK: - Session Summary (computed)

struct SoundScore {
    let sound: TestSound
    let correctCount: Int
    let totalTrials: Int
    var percentage: Int {
        totalTrials > 0 ? Int(Double(correctCount) / Double(totalTrials) * 100) : 0
    }
}

// MARK: - Default Sounds

extension TestSound {

    /// Ling 6 standard + common extras that audiologists test
    static let defaultSounds: [TestSound] = [
        TestSound(id: 0, symbol: "a",   tamilLabel: nil,    ipaSymbol: "/ɑː/", ttsHint: nil, audioFileName: nil, sortOrder: 0, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "e",   tamilLabel: nil,    ipaSymbol: "/ɛ/",  ttsHint: nil, audioFileName: nil, sortOrder: 1, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "mm",  tamilLabel: nil,    ipaSymbol: "/m/",  ttsHint: nil, audioFileName: nil, sortOrder: 2, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "o",   tamilLabel: nil,    ipaSymbol: "/oː/", ttsHint: nil, audioFileName: nil, sortOrder: 3, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "sh",  tamilLabel: "ஷ்",   ipaSymbol: "/ʃ/",  ttsHint: nil, audioFileName: nil, sortOrder: 4, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "ush", tamilLabel: nil,    ipaSymbol: "/ʊʃ/", ttsHint: nil, audioFileName: nil, sortOrder: 5, isActive: true, isDefault: true, createdAt: Date()),
        // Ling 6 additions
        TestSound(id: 0, symbol: "ee",  tamilLabel: nil,    ipaSymbol: "/iː/", ttsHint: nil, audioFileName: nil, sortOrder: 6, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "oo",  tamilLabel: nil,    ipaSymbol: "/uː/", ttsHint: nil, audioFileName: nil, sortOrder: 7, isActive: true, isDefault: true, createdAt: Date()),
        TestSound(id: 0, symbol: "ss",  tamilLabel: "ஸ்",   ipaSymbol: "/s/",  ttsHint: nil, audioFileName: nil, sortOrder: 8, isActive: true, isDefault: true, createdAt: Date()),
    ]
}
