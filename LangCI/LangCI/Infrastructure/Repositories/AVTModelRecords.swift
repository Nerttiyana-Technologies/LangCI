// AVTModelRecords.swift
// LangCI
//
// GRDB FetchableRecord + MutablePersistableRecord conformances for AVT
// domain models. Models are plain structs — navigation collections are
// always empty after a row-level fetch and must be loaded explicitly in
// the service layer. The encode side mirrors the init(row:) column
// mapping exactly so save/load round-trips correctly.

import Foundation
import GRDB

// MARK: - Helpers

private extension Row {
    /// Decode a Unix-epoch Double column as Date. Returns nil if column is NULL.
    func date(_ col: String) -> Date? {
        guard let ts: Double = self[col] else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
    /// Decode a non-null Unix-epoch Double column as Date, fallback to now.
    func dateOrNow(_ col: String) -> Date {
        date(col) ?? Date()
    }
}

// MARK: - AVTTarget

extension AVTTarget: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "avt_target" }

    init(row: Row) throws {
        id                = row["id"]
        sound             = row["sound"] ?? ""
        phonemeIpa        = row["phoneme_ipa"] ?? ""
        frequencyRange    = row["frequency_range"] ?? ""
        soundDescription  = row["sound_description"] ?? ""
        currentLevel      = ListeningHierarchy(rawValue: row["current_level"] ?? 0) ?? .detection
        isActive          = (row["is_active"] as Int?) == 1
        assignedAt        = row.dateOrNow("assigned_at")
        audiologistNote   = row["audiologist_note"]
    }

    func encode(to container: inout PersistenceContainer) throws {
        // Skip `id` when 0 so SQLite can autoincrement on insert; the
        // generated rowid is captured in `didInsert(_:)` below.
        if id != 0 { container["id"] = id }
        container["sound"]             = sound
        container["phoneme_ipa"]       = phonemeIpa
        container["frequency_range"]   = frequencyRange
        container["sound_description"] = soundDescription
        container["current_level"]     = currentLevel.rawValue
        container["is_active"]         = isActive ? 1 : 0
        container["assigned_at"]       = assignedAt.timeIntervalSince1970
        container["audiologist_note"]  = audiologistNote
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = Int(inserted.rowID)
    }
}

// MARK: - AVTSession

extension AVTSession: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "avt_session" }

    init(row: Row) throws {
        id                = row["id"]
        targetSound       = row["target_sound"] ?? ""
        hierarchyLevel    = ListeningHierarchy(rawValue: row["hierarchy_level"] ?? 0) ?? .detection
        startedAt         = row.dateOrNow("started_at")
        completedAt       = row.date("completed_at")
        totalAttempts     = row["total_attempts"] ?? 0
        correctAttempts   = row["correct_attempts"] ?? 0
        attempts          = []
    }

    func encode(to container: inout PersistenceContainer) throws {
        if id != 0 { container["id"] = id }
        container["target_sound"]     = targetSound
        container["hierarchy_level"]  = hierarchyLevel.rawValue
        container["started_at"]       = startedAt.timeIntervalSince1970
        container["completed_at"]     = completedAt?.timeIntervalSince1970
        container["total_attempts"]   = totalAttempts
        container["correct_attempts"] = correctAttempts
        // `attempts` has no column — it's hydrated separately by the service layer.
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = Int(inserted.rowID)
    }
}

// MARK: - AVTAttempt

extension AVTAttempt: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "avt_attempt" }

    init(row: Row) throws {
        id                = row["id"]
        sessionId         = row["session_id"]
        targetSound       = row["target_sound"] ?? ""
        presentedSound    = row["presented_sound"] ?? ""
        userResponse      = row["user_response"] ?? ""
        isCorrect         = (row["is_correct"] as Int?) == 1
        hierarchyLevel    = ListeningHierarchy(rawValue: row["hierarchy_level"] ?? 0) ?? .detection
        attemptedAt       = row.dateOrNow("attempted_at")
    }

    func encode(to container: inout PersistenceContainer) throws {
        if id != 0 { container["id"] = id }
        container["session_id"]      = sessionId
        container["target_sound"]    = targetSound
        container["presented_sound"] = presentedSound
        container["user_response"]   = userResponse
        container["is_correct"]      = isCorrect ? 1 : 0
        container["hierarchy_level"] = hierarchyLevel.rawValue
        container["attempted_at"]    = attemptedAt.timeIntervalSince1970
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = Int(inserted.rowID)
    }
}

// MARK: - AVTAudiologistNote

extension AVTAudiologistNote: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName: String { "avt_audiologist_note" }

    init(row: Row) throws {
        id                = row["id"]
        notedAt           = row.dateOrNow("noted_at")
        targetSounds      = row["target_sounds"] ?? ""
        notes             = row["notes"] ?? ""
        nextAppointment   = row.date("next_appointment")
    }

    func encode(to container: inout PersistenceContainer) throws {
        if id != 0 { container["id"] = id }
        container["noted_at"]         = notedAt.timeIntervalSince1970
        container["target_sounds"]    = targetSounds
        container["notes"]            = notes
        container["next_appointment"] = nextAppointment?.timeIntervalSince1970
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = Int(inserted.rowID)
    }
}
