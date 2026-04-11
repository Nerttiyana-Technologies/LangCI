// VoiceRecordingModels.swift
// LangCI — Voice Library for Environmental Sound Training
//
// Record real voices (wife, audiologist, family, friends) speaking
// sound descriptions, words, and sentences. Using familiar voices
// accelerates CI neural adaptation far more than synthetic TTS —
// the brain is motivated to decode voices it already "knows."

import Foundation

// MARK: - Recorded Person

/// A person whose voice has been recorded (wife, audiologist, friend, etc.)
struct RecordedPerson: Identifiable, Codable {
    var id: Int
    var name: String                 // "Priya", "Dr. Kumar"
    var relationship: String         // "Wife", "Audiologist", "Mother"
    var color: String                // Color key for UI chip: "lcPurple"
    var icon: String                 // SF Symbol: "heart.fill", "stethoscope"
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    /// Number of recordings this person has (set transiently, not in DB)
    var recordingCount: Int = 0
}

// MARK: - Voice Recording

/// A single audio recording of a person saying a sound description,
/// word, or sentence.
struct VoiceRecording: Identifiable, Codable {
    var id: Int
    var personId: Int                // FK → RecordedPerson.id
    var soundId: String?             // FK → EnvironmentalSoundItem.id (nil for free sentences)
    var label: String                // What they said: "Pressure cooker whistling"
    var fileName: String             // "voice_1_pressure_cooker_1234.m4a"
    var durationSeconds: Double      // Length of clip
    var createdAt: Date

    /// Full file path in the app's documents directory
    var filePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("VoiceRecordings/\(fileName)").path
    }

    /// URL for playback
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

// MARK: - Relationship presets for quick setup

enum PersonRelationship: String, CaseIterable {
    case wife        = "Wife"
    case husband     = "Husband"
    case mother      = "Mother"
    case father      = "Father"
    case audiologist = "Audiologist"
    case therapist   = "Therapist"
    case friend      = "Friend"
    case sibling     = "Sibling"
    case child       = "Child"
    case other       = "Other"

    var icon: String {
        switch self {
        case .wife, .husband:   return "heart.fill"
        case .mother, .father:  return "figure.and.child.holdinghands"
        case .audiologist:      return "stethoscope"
        case .therapist:        return "brain.head.profile"
        case .friend:           return "person.2.fill"
        case .sibling:          return "figure.2"
        case .child:            return "figure.child"
        case .other:            return "person.fill"
        }
    }

    var color: String {
        switch self {
        case .wife, .husband:   return "lcPurple"
        case .mother, .father:  return "lcAmber"
        case .audiologist:      return "lcTeal"
        case .therapist:        return "lcGreen"
        case .friend:           return "lcBlue"
        case .sibling:          return "lcOrange"
        case .child:            return "lcGold"
        case .other:            return "lcRed"
        }
    }
}
