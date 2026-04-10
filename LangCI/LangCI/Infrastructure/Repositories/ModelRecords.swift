// ModelRecords.swift
// LangCI
//
// GRDB FetchableRecord conformances for every domain model.
// Models are plain structs — navigation collections are always empty after a
// row-level fetch and must be loaded explicitly in the service layer.

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

// MARK: - Language

extension Language: FetchableRecord {
    static var databaseTableName: String { "language" }

    init(row: Row) throws {
        id             = row["id"]
        code           = row["code"] ?? ""
        name           = row["name"] ?? ""
        nativeName     = row["native_name"] ?? ""
        scriptCode     = row["script_code"] ?? ""
        fontFamily     = row["font_family"] ?? ""
        isRightToLeft  = (row["is_right_to_left"] as Int?) == 1
        isActive       = (row["is_active"] as Int?) != 0
    }
}

// MARK: - Dialect

extension Dialect: FetchableRecord {
    static var databaseTableName: String { "dialect" }

    init(row: Row) throws {
        id         = row["id"]
        languageId = row["language_id"]
        name       = row["name"] ?? ""
        nativeName = row["native_name"] ?? ""
        regionCode = row["region_code"] ?? ""
        colorHex   = row["color_hex"] ?? ""
        isActive   = (row["is_active"] as Int?) != 0
    }
}

// MARK: - WordCategory

extension WordCategory: FetchableRecord {
    static var databaseTableName: String { "word_category" }

    init(row: Row) throws {
        id                  = row["id"]
        languageId          = row["language_id"]
        code                = row["code"] ?? ""
        nativeDisplayName   = row["native_display_name"] ?? ""
        englishDisplayName  = row["english_display_name"] ?? ""
        sortOrder           = row["sort_order"] ?? 0
    }
}

// MARK: - PhoneticGroup

extension PhoneticGroup: FetchableRecord {
    static var databaseTableName: String { "phonetic_group" }

    init(row: Row) throws {
        id                = row["id"]
        languageId        = row["language_id"]
        groupKey          = row["group_key"] ?? ""
        description       = row["description"] ?? ""
        sharedIpaPattern  = row["shared_ipa_pattern"] ?? ""
        ciDifficultyLevel = row["ci_difficulty_level"] ?? 3
    }
}

// MARK: - PublisherPack

extension PublisherPack: FetchableRecord {
    static var databaseTableName: String { "publisher_pack" }

    init(row: Row) throws {
        id               = row["id"]
        globalId         = UUID(uuidString: row["global_id"] ?? "") ?? UUID()
        languageId       = row["language_id"]
        name             = row["name"] ?? ""
        description      = row["description"] ?? ""
        difficultyLevel  = row["difficulty_level"] ?? 1
        version          = row["version"] ?? 1
        publishedAt      = row.dateOrNow("published_at")
        syncedAt         = row.date("synced_at")
        isInstalled      = (row["is_installed"] as Int?) == 1
        isPremium        = (row["is_premium"] as Int?) == 1
    }
}

// MARK: - WordEntry

extension WordEntry: FetchableRecord {
    static var databaseTableName: String { "word_entry" }

    init(row: Row) throws {
        id              = row["id"]
        globalId        = UUID(uuidString: row["global_id"] ?? "") ?? UUID()
        languageId      = row["language_id"]
        nativeScript    = row["native_script"] ?? ""
        ipaPhoneme      = row["ipa_phoneme"] ?? ""
        phoneticKey     = row["phonetic_key"]
        isSlang         = (row["is_slang"] as Int?) == 1
        source          = WordSource(rawValue: row["source"] ?? 0) ?? .publisher
        status          = WordStatus(rawValue: row["status"] ?? 1) ?? .active
        publisherPackId = row["publisher_pack_id"]
        syncStatus      = SyncStatus(rawValue: row["sync_status"] ?? 0) ?? .local
        lastSyncedAt    = row.date("last_synced_at")
        createdAt       = row.dateOrNow("created_at")
        updatedAt       = row.dateOrNow("updated_at")
    }
}

// MARK: - WordTranslation

extension WordTranslation: FetchableRecord {
    static var databaseTableName: String { "word_translation" }

    init(row: Row) throws {
        id                  = row["id"]
        wordEntryId         = row["word_entry_id"]
        targetLanguageCode  = row["target_language_code"] ?? ""
        translation         = row["translation"] ?? ""
        transliteration     = row["transliteration"] ?? ""
        exampleNative       = row["example_native"]
        exampleTranslation  = row["example_translation"]
    }
}

// MARK: - FamilyMember

extension FamilyMember: FetchableRecord {
    static var databaseTableName: String { "family_member" }

    init(row: Row) throws {
        id                   = row["id"]
        name                 = row["name"] ?? ""
        relationship         = row["relationship"] ?? ""
        avatarInitials       = row["avatar_initials"] ?? ""
        avatarColorHex       = row["avatar_color_hex"] ?? "#1D9E75"
        preferredDialectId   = row["preferred_dialect_id"]
        baselineFrequencyHz  = row["baseline_frequency_hz"]
        createdAt            = row.dateOrNow("created_at")
    }
}

// MARK: - Recording

extension Recording: FetchableRecord {
    static var databaseTableName: String { "recording" }

    init(row: Row) throws {
        id                   = row["id"]
        wordEntryId          = row["word_entry_id"]
        dialectId            = row["dialect_id"]
        familyMemberId       = row["family_member_id"]
        filePath             = row["file_path"] ?? ""
        format               = row["format"] ?? "wav"
        durationSeconds      = row["duration_seconds"] ?? 0
        peakAmplitude        = row["peak_amplitude"] ?? 0
        averageFrequencyHz   = row["average_frequency_hz"]
        isApproved           = (row["is_approved"] as Int?) != 0
        recordedAt           = row.dateOrNow("recorded_at")
    }
}

// MARK: - RecordingRequest

extension RecordingRequest: FetchableRecord {
    static var databaseTableName: String { "recording_request" }

    init(row: Row) throws {
        id                = row["id"]
        token             = row["token"] ?? ""
        familyMemberId    = row["family_member_id"]
        requestedWordIds  = row["requested_word_ids"] ?? ""
        message           = row["message"]
        status            = RecordingRequestStatus(rawValue: row["status"] ?? 0) ?? .pending
        totalWords        = row["total_words"] ?? 0
        completedCount    = row["completed_count"] ?? 0
        createdAt         = row.dateOrNow("created_at")
        expiresAt         = row.dateOrNow("expires_at")
    }
}

// MARK: - TrainingSession

extension TrainingSession: FetchableRecord {
    static var databaseTableName: String { "training_session" }

    init(row: Row) throws {
        id               = row["id"]
        dialectId        = row["dialect_id"]
        categoryCode     = row["category_code"] ?? ""
        startedAt        = row.dateOrNow("started_at")
        completedAt      = row.date("completed_at")
        totalWords       = row["total_words"] ?? 0
        completedWords   = row["completed_words"] ?? 0
        publisherPackId  = row["publisher_pack_id"]
        trainingMode     = TrainingMode(rawValue: row["training_mode"] ?? 0) ?? .standard
        noiseEnvironment = NoiseEnvironmentType(rawValue: row["noise_environment"] ?? 0) ?? .none
        noiseLevel       = row["noise_level"] ?? 0.3
        processorProgram = ProcessorProgram(rawValue: row["processor_program"] ?? 0) ?? .everyday
    }
}

// MARK: - SessionWord

extension SessionWord: FetchableRecord {
    static var databaseTableName: String { "session_word" }

    init(row: Row) throws {
        id                = row["id"]
        trainingSessionId = row["training_session_id"]
        wordEntryId       = row["word_entry_id"]
        rating            = row["rating"] ?? 0
        easeFactor        = row["ease_factor"] ?? 2.5
        intervalDays      = row["interval_days"] ?? 1
        repetitionCount   = row["repetition_count"] ?? 0
        nextReviewDate    = row.dateOrNow("next_review_date")
        reviewedAt        = row.dateOrNow("reviewed_at")
    }
}

// MARK: - Ling6Session

extension Ling6Session: FetchableRecord {
    static var databaseTableName: String { "ling6_session" }

    init(row: Row) throws {
        id          = row["id"]
        testedAt    = row.dateOrNow("tested_at")
        distanceCm  = row["distance_cm"] ?? 100
        programUsed = ProcessorProgram(rawValue: row["program_used"] ?? 0) ?? .everyday
        notes       = row["notes"]
    }
}

// MARK: - Ling6Attempt

extension Ling6Attempt: FetchableRecord {
    static var databaseTableName: String { "ling6_attempt" }

    init(row: Row) throws {
        id            = row["id"]
        sessionId     = row["session_id"]
        sound         = row["sound"] ?? ""
        isDetected    = (row["is_detected"] as Int?) == 1
        isRecognised  = (row["is_recognised"] as Int?) == 1
        sortOrder     = row["sort_order"] ?? 0
    }
}

// MARK: - MappingSession

extension MappingSession: FetchableRecord {
    static var databaseTableName: String { "mapping_session" }

    init(row: Row) throws {
        id                  = row["id"]
        sessionDate         = row.dateOrNow("session_date")
        audiologistName     = row["audiologist_name"] ?? ""
        clinicName          = row["clinic_name"] ?? ""
        notes               = row["notes"]
        nextAppointmentDate = row.date("next_appointment_date")
    }
}

// MARK: - ElectrodeLevel

extension ElectrodeLevel: FetchableRecord {
    static var databaseTableName: String { "electrode_level" }

    init(row: Row) throws {
        id               = row["id"]
        mappingSessionId = row["mapping_session_id"]
        electrodeNumber  = row["electrode_number"]
        tLevel           = row["t_level"] ?? 0
        cLevel           = row["c_level"] ?? 0
        isActive         = (row["is_active"] as Int?) != 0
        notes            = row["notes"]
    }
}

// MARK: - FatigueEntry

extension FatigueEntry: FetchableRecord {
    static var databaseTableName: String { "fatigue_entry" }

    init(row: Row) throws {
        id           = row["id"]
        loggedAt     = row.dateOrNow("logged_at")
        effortLevel  = row["effort_level"] ?? 3
        fatigueLevel = row["fatigue_level"] ?? 3
        environment  = FatigueEnvironment(rawValue: row["environment"] ?? 0) ?? .quiet
        programUsed  = ProcessorProgram(rawValue: row["program_used"] ?? 0) ?? .everyday
        hoursWorn    = row["hours_worn"] ?? 8
        notes        = row["notes"]
    }
}

// MARK: - MilestoneEntry

extension MilestoneEntry: FetchableRecord {
    static var databaseTableName: String { "milestone_entry" }

    init(row: Row) throws {
        id                  = row["id"]
        type                = MilestoneType(rawValue: row["type"] ?? 0) ?? .custom
        achievedAt          = row.dateOrNow("achieved_at")
        accuracyAtMilestone = row["accuracy_at_milestone"]
        description         = row["description"] ?? ""
        notes               = row["notes"]
        emoji               = row["emoji"] ?? "🎉"
    }
}

// MARK: - MinimalPair

extension MinimalPair: FetchableRecord {
    static var databaseTableName: String { "minimal_pair" }

    init(row: Row) throws {
        id                  = row["id"]
        languageId          = row["language_id"]
        wordEntryId1        = row["word_entry_id_1"]
        wordEntryId2        = row["word_entry_id_2"]
        contrastDescription = row["contrast_description"] ?? ""
        ciDifficultyLevel   = row["ci_difficulty_level"] ?? 1
    }
}

// MARK: - MinimalPairAttempt

extension MinimalPairAttempt: FetchableRecord {
    static var databaseTableName: String { "minimal_pair_attempt" }

    init(row: Row) throws {
        id                   = row["id"]
        minimalPairId        = row["minimal_pair_id"]
        playedWordEntryId    = row["played_word_entry_id"]
        selectedWordEntryId  = row["selected_word_entry_id"]
        isCorrect            = (row["is_correct"] as Int?) == 1
        familyMemberId       = row["family_member_id"]
        attemptedAt          = row.dateOrNow("attempted_at")
    }
}

// MARK: - MusicAttempt

extension MusicAttempt: FetchableRecord {
    static var databaseTableName: String { "music_attempt" }

    init(row: Row) throws {
        id           = row["id"]
        trainingType = MusicTrainingType(rawValue: row["training_type"] ?? 0) ?? .rhythm
        playedItem   = row["played_item"] ?? ""
        userAnswer   = row["user_answer"] ?? ""
        isCorrect    = (row["is_correct"] as Int?) == 1
        programUsed  = ProcessorProgram(rawValue: row["program_used"] ?? 0) ?? .everyday
        attemptedAt  = row.dateOrNow("attempted_at")
    }
}

// MARK: - AppBadge

extension AppBadge: FetchableRecord {
    static var databaseTableName: String { "badge" }

    init(row: Row) throws {
        id          = row["id"]
        code        = row["code"] ?? ""
        title       = row["title"] ?? ""
        description = row["description"] ?? ""
        emoji       = row["emoji"] ?? "🏅"
        sortOrder   = row["sort_order"] ?? 0
    }
}

// MARK: - UserBadge

extension UserBadge: FetchableRecord {
    static var databaseTableName: String { "user_badge" }

    init(row: Row) throws {
        id       = row["id"]
        BadgeId  = row["badge_id"]
        Badge    = AppBadge(id: 0, code: "", title: "", description: "", emoji: "🏅", sortOrder: 0)
        EarnedAt = row.dateOrNow("earned_at")
    }
}

// MARK: - UserProgress

extension UserProgress: FetchableRecord {
    static var databaseTableName: String { "user_progress" }

    init(row: Row) throws {
        id             = row["id"]
        totalPoints    = row["total_points"] ?? 0
        currentLevel   = row["current_level"] ?? 1
        currentStreak  = row["current_streak"] ?? 0
        longestStreak  = row["longest_streak"] ?? 0
        totalSessions  = row["total_sessions"] ?? 0
        totalCorrect   = row["total_correct"] ?? 0
        totalAttempts  = row["total_attempts"] ?? 0
        lastTrainedAt  = row.date("last_trained_at")
        activatedAt    = row.date("activated_at")
    }
}

// MARK: - ConfusionPair

extension ConfusionPair: FetchableRecord {
    static var databaseTableName: String { "confusion_pair" }

    init(row: Row) throws {
        id           = row["id"]
        saidWord     = row["said_word"] ?? ""
        heardWord    = row["heard_word"] ?? ""
        targetSound  = row["target_sound"] ?? ""
        source       = ConfusionSource(rawValue: row["source"] ?? 0) ?? .manual
        avtSessionId = row["avt_session_id"]
        contextNote  = row["context_note"]
        loggedAt     = row.dateOrNow("logged_at")
    }
}

// MARK: - ReadingPassage

extension ReadingPassage: FetchableRecord {
    static var databaseTableName: String { "reading_passage" }

    init(row: Row) throws {
        id         = row["id"]
        title      = row["title"] ?? ""
        category   = ReadingCategory(rawValue: row["category"] ?? 0) ?? .news
        difficulty = row["difficulty"] ?? 1
        body       = row["body"] ?? ""
        wordCount  = row["word_count"] ?? 0
        isBundled  = (row["is_bundled"] as Int?) == 1
        createdAt  = row.dateOrNow("created_at")
    }
}

// MARK: - ReadingSession

extension ReadingSession: FetchableRecord {
    static var databaseTableName: String { "reading_session" }

    init(row: Row) throws {
        id              = row["id"]
        passageId       = row["passage_id"]
        passageTitle    = row["passage_title"] ?? ""
        passageBody     = row["passage_body"] ?? ""
        wordCount       = row["word_count"] ?? 0
        durationSeconds = row["duration_seconds"] ?? 0
        wordsPerMinute  = row["words_per_minute"] ?? 0
        avgLoudnessDb   = row["avg_loudness_db"] ?? 0
        peakLoudnessDb  = row["peak_loudness_db"] ?? 0
        audioFilePath   = row["audio_file_path"]
        notes           = row["notes"]
        recordedAt      = row.dateOrNow("recorded_at")
    }
}
