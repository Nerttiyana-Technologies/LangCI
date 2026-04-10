// CochlearExercise.swift
// LangCI — Cochlear "Adult Aural Rehabilitation" exercise bank.
//
// 75 exercises (1213 items) extracted from the Cochlear adult AVT
// (Auditory Verbal Therapy) curriculum PDFs and shipped as
// Resources/cochlear_exercises.json.
//
// Source: Cochlear Adult Aural Rehabilitation programme.
// Used as seed content for the AVT drill engine.

import Foundation

// MARK: - Section

enum CochlearSection: String, Codable {
    case analytic       // Sections 1.x — phoneme / syllable / word level drills
    case synthetic      // Sections 2.x — sentence / context / story level drills
    case sentenceTest   = "sentence_test"
}

// MARK: - Format
//
// 17 distinct exercise formats found in the curriculum. Each exercise's
// `format` determines which optional fields on `CochlearExerciseItem` are
// populated.
enum CochlearExerciseFormat: String, Codable {
    case wordPair             = "word_pair"
    case wordChoice           = "word_choice"
    case sentenceChoice       = "sentence_choice"
    case sentenceCompletion   = "sentence_completion"
    case sentenceWithChoice   = "sentence_with_choice"
    case sentence             = "sentence"
    case cuedSentence         = "cued_sentence"
    case letteredClueSentence = "lettered_clue_sentence"
    case topicClues           = "topic_clues"
    case phrase               = "phrase"
    case passage              = "passage"
    case story                = "story"
    case fillBlank            = "fill_blank"
    case task                 = "task"
    case conversation         = "conversation"
    case roleplay             = "roleplay"
    case closedSet            = "closed_set"
    case stressSentence       = "stress_sentence"
}

// MARK: - Lettered choice (for sentence_choice format)

struct CochlearLetteredChoice: Codable, Hashable {
    var label: String
    var text: String
}

// MARK: - Item
//
// All format variants share this single struct with optional fields.
// `format` on the parent exercise tells you which fields are populated.
struct CochlearExerciseItem: Codable, Identifiable, Hashable {
    var n: Int
    var text: String?
    var carrier: String?
    var template: String?
    var pairA: String?
    var pairB: String?
    var choices: [String]?
    var letteredChoices: [CochlearLetteredChoice]?
    var sentences: [String]?
    var alternatives: [String]?
    var cue: String?
    var letter: String?
    var setName: String?
    var group: String?

    var id: Int { n }

    /// Best human-readable representation of the item, used for fallbacks.
    var displaySummary: String {
        if let t = text, !t.isEmpty { return t }
        if let c = carrier {
            if let chs = choices, !chs.isEmpty {
                return "\(c)  →  \(chs.joined(separator: " / "))"
            }
            return c
        }
        if let a = pairA, let b = pairB { return "\(a) — \(b)" }
        if let chs = choices, !chs.isEmpty { return chs.joined(separator: " / ") }
        if let lc = letteredChoices, !lc.isEmpty {
            return lc.map { "\($0.label). \($0.text)" }.joined(separator: " / ")
        }
        return "Item \(n)"
    }

    /// All distinct words this item exposes (used for phoneme matching).
    var allWords: [String] {
        var words: [String] = []
        if let a = pairA { words.append(a) }
        if let b = pairB { words.append(b) }
        if let chs = choices { words.append(contentsOf: chs) }
        if let s = sentences { words.append(contentsOf: s) }
        if let t = text { words.append(t) }
        if let c = carrier { words.append(c) }
        if let tpl = template { words.append(tpl) }
        if let lc = letteredChoices { words.append(contentsOf: lc.map { $0.text }) }
        return words
    }
}

// MARK: - Exercise

struct CochlearExercise: Codable, Identifiable, Hashable {
    var id: String          // e.g. "ex-1.1"
    var section: CochlearSection
    var number: String      // e.g. "1.1"
    var title: String
    var category: String
    var format: CochlearExerciseFormat
    var level: String       // "detection" | "discrimination" | "identification" | "comprehension"
    var items: [CochlearExerciseItem]

    /// Map the JSON `level` string into the AVT `ListeningHierarchy` enum.
    var listeningLevel: ListeningHierarchy {
        switch level {
        case "detection":      return .detection
        case "discrimination": return .discrimination
        case "identification": return .identification
        case "comprehension":  return .comprehension
        default:               return .identification
        }
    }
}
