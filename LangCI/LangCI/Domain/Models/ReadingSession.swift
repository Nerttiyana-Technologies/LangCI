// ReadingSession.swift
// LangCI
//
// One recorded reading-aloud attempt. Stores the duration, computed
// words-per-minute, and loudness stats captured from the audio meter.

import Foundation

struct ReadingSession: Identifiable, Codable {
    var id: Int
    /// Optional link back to a bundled / saved passage. May be nil for pasted text.
    var passageId: Int?
    var passageTitle: String
    /// Snapshot of the text that was read (copied at read time so edits to the
    /// underlying passage don't break historical sessions).
    var passageBody: String
    var wordCount: Int
    var durationSeconds: Double
    var wordsPerMinute: Double
    /// Average loudness in dBFS (0 = clipping, negative = quieter).
    var avgLoudnessDb: Double
    var peakLoudnessDb: Double
    var audioFilePath: String?
    var notes: String?
    var recordedAt: Date

    init(id: Int = 0,
         passageId: Int? = nil,
         passageTitle: String,
         passageBody: String,
         wordCount: Int,
         durationSeconds: Double,
         wordsPerMinute: Double,
         avgLoudnessDb: Double,
         peakLoudnessDb: Double,
         audioFilePath: String? = nil,
         notes: String? = nil,
         recordedAt: Date = Date())
    {
        self.id = id
        self.passageId = passageId
        self.passageTitle = passageTitle
        self.passageBody = passageBody
        self.wordCount = wordCount
        self.durationSeconds = durationSeconds
        self.wordsPerMinute = wordsPerMinute
        self.avgLoudnessDb = avgLoudnessDb
        self.peakLoudnessDb = peakLoudnessDb
        self.audioFilePath = audioFilePath
        self.notes = notes
        self.recordedAt = recordedAt
    }

    /// Normal adult reading aloud is ~150–180 wpm. Below 90 suggests very slow;
    /// above 200 suggests rushed. Used for coaching hints.
    var wpmBand: WPMBand {
        switch wordsPerMinute {
        case ..<90:   return .slow
        case 90..<140: return .developing
        case 140..<200: return .natural
        default: return .fast
        }
    }

    /// dBFS-style loudness band.
    /// Voice captured on iPhone mic is normally in the −35…−15 dBFS range.
    var loudnessBand: LoudnessBand {
        switch avgLoudnessDb {
        case ..<(-40): return .quiet
        case (-40)..<(-25): return .soft
        case (-25)..<(-12): return .comfortable
        default: return .loud
        }
    }
}

enum WPMBand {
    case slow, developing, natural, fast

    var label: String {
        switch self {
        case .slow:       return "Slow"
        case .developing: return "Developing"
        case .natural:    return "Natural"
        case .fast:       return "Fast"
        }
    }
}

enum LoudnessBand {
    case quiet, soft, comfortable, loud

    var label: String {
        switch self {
        case .quiet:       return "Quiet"
        case .soft:        return "Soft"
        case .comfortable: return "Comfortable"
        case .loud:        return "Loud"
        }
    }
}

/// Aggregated reading stats across a date range.
struct ReadingStatsDto {
    var sessionCount: Int
    var avgWordsPerMinute: Double
    var avgLoudnessDb: Double
    var bestWpm: Double
    var lastRecordedAt: Date?
}
