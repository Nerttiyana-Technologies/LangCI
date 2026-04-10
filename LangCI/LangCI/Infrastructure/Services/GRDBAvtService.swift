// GRDBAvtService.swift
// LangCI — GRDB-backed AVT service implementation

import Foundation
import GRDB

final class GRDBAvtService: AVTService {
    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    // MARK: - Targets

    func getActiveTargets() async throws -> [AVTTarget] {
        try await db.read { db in
            try AVTTarget
                .filter(Column("is_active") == true)
                .order(Column("assigned_at").desc)
                .fetchAll(db)
        }
    }

    func getAllTargets() async throws -> [AVTTarget] {
        try await db.read { db in
            try AVTTarget
                .order(Column("assigned_at").desc)
                .fetchAll(db)
        }
    }

    func saveTarget(_ target: AVTTarget) async throws -> AVTTarget {
        return try await db.write { db in
            var mutableTarget = target
            if mutableTarget.id == 0 {
                // INSERT
                try mutableTarget.insert(db)
            } else {
                // UPDATE
                try mutableTarget.update(db)
            }
            return mutableTarget
        }
    }

    func deleteTarget(id: Int) async throws {
        try await db.write { db in
            _ = try AVTTarget.deleteOne(db, key: id)
        }
    }

    func setTargetLevel(_ level: ListeningHierarchy, targetId: Int) async throws {
        try await db.write { db in
            try db.execute(
                sql: "UPDATE avt_target SET current_level = ? WHERE id = ?",
                arguments: [level.rawValue, targetId]
            )
        }
    }

    // MARK: - Sessions

    func startSession(targetSound: String, level: ListeningHierarchy) async throws -> AVTSession {
        let now = Date()
        let session = AVTSession(
            id: 0,
            targetSound: targetSound,
            hierarchyLevel: level,
            startedAt: now,
            completedAt: nil,
            totalAttempts: 0,
            correctAttempts: 0,
            attempts: []
        )
        return try await db.write { db in
            var mutableSession = session
            try mutableSession.insert(db)
            return mutableSession
        }
    }

    func recordAttempt(
        sessionId: Int,
        targetSound: String,
        presentedSound: String,
        userResponse: String,
        isCorrect: Bool,
        level: ListeningHierarchy
    ) async throws -> AVTAttempt {
        let now = Date()
        let attempt = AVTAttempt(
            id: 0,
            sessionId: sessionId,
            targetSound: targetSound,
            presentedSound: presentedSound,
            userResponse: userResponse,
            isCorrect: isCorrect,
            hierarchyLevel: level,
            attemptedAt: now
        )

        return try await db.write { db in
            var mutableAttempt = attempt
            try mutableAttempt.insert(db)

            // Update session counters
            let increment = isCorrect ? 1 : 0
            try db.execute(
                sql: """
                UPDATE avt_session
                SET total_attempts = total_attempts + 1,
                    correct_attempts = correct_attempts + ?
                WHERE id = ?
                """,
                arguments: [increment, sessionId]
            )

            return mutableAttempt
        }
    }

    func completeSession(id: Int) async throws -> AVTSession {
        let now = Date()
        return try await db.write { db in
            try db.execute(
                sql: "UPDATE avt_session SET completed_at = ? WHERE id = ?",
                arguments: [now.timeIntervalSince1970, id]
            )
            guard let session = try AVTSession.fetchOne(db, key: id) else {
                throw GRDBAvtServiceError.sessionNotFound
            }
            return session
        }
    }

    func getRecentSessions(count: Int) async throws -> [AVTSession] {
        try await db.read { db in
            try AVTSession
                .order(Column("started_at").desc)
                .limit(count)
                .fetchAll(db)
        }
    }

    func getSessionsForSound(_ sound: String) async throws -> [AVTSession] {
        try await db.read { db in
            try AVTSession
                .filter(Column("target_sound") == sound)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Audiologist Notes

    func saveNote(_ note: AVTAudiologistNote) async throws -> AVTAudiologistNote {
        return try await db.write { db in
            var mutableNote = note
            if mutableNote.id == 0 {
                try mutableNote.insert(db)
            } else {
                try mutableNote.update(db)
            }
            return mutableNote
        }
    }

    func getNotes() async throws -> [AVTAudiologistNote] {
        try await db.read { db in
            try AVTAudiologistNote
                .order(Column("noted_at").desc)
                .fetchAll(db)
        }
    }

    func getLatestNote() async throws -> AVTAudiologistNote? {
        try await db.read { db in
            try AVTAudiologistNote
                .order(Column("noted_at").desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    func deleteNote(noteId: Int) async throws {
        try await db.write { db in
            _ = try AVTAudiologistNote.deleteOne(db, key: noteId)
        }
    }

    // MARK: - Progress & Stats

    func getProgress() async throws -> [AVTProgressDto] {
        return try await db.read { db in
            let targets = try AVTTarget.fetchAll(db)

            return try targets.map { target in
                let sessions = try AVTSession
                    .filter(Column("target_sound") == target.sound)
                    .order(Column("started_at").desc)
                    .limit(5)
                    .fetchAll(db)

                let totalSessions = try AVTSession
                    .filter(Column("target_sound") == target.sound)
                    .fetchCount(db)

                let recentAccuracy: Double
                if sessions.isEmpty {
                    recentAccuracy = 0
                } else {
                    let totalCorrect = sessions.reduce(0) { $0 + $1.correctAttempts }
                    let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
                    recentAccuracy = totalAttempts > 0
                        ? (Double(totalCorrect) / Double(totalAttempts) * 100)
                        : 0
                }

                let trend: AVTTrend
                if sessions.count >= 3 {
                    let last3 = Array(sessions.prefix(3))
                    let prev3 = Array(sessions.dropFirst(3).prefix(3))

                    let last3Accuracy = calculateAccuracy(sessions: last3)
                    let prev3Accuracy = calculateAccuracy(sessions: prev3)

                    if last3Accuracy > prev3Accuracy {
                        trend = .improving
                    } else if recentAccuracy < 60 {
                        trend = .needsWork
                    } else {
                        trend = .stable
                    }
                } else if recentAccuracy < 60 {
                    trend = .needsWork
                } else {
                    trend = .stable
                }

                return AVTProgressDto(
                    sound: target.sound,
                    phonemeIpa: target.phonemeIpa,
                    currentLevel: target.currentLevel,
                    totalSessions: totalSessions,
                    recentAccuracy: recentAccuracy,
                    isActive: target.isActive,
                    trend: trend
                )
            }
        }
    }

    func getHomeStats() async throws -> AVTHomeStats {
        return try await db.read { db in
            let activeTargets = try AVTTarget
                .filter(Column("is_active") == true)
                .fetchCount(db)

            let now = Date()
            let startOfToday = Calendar.current.startOfDay(for: now)

            let sessionsToday = try AVTSession
                .filter(Column("started_at") >= startOfToday.timeIntervalSince1970)
                .fetchCount(db)

            let allSessions = try AVTSession.fetchAll(db)
            let overallAccuracy: Double
            if allSessions.isEmpty {
                overallAccuracy = 0
            } else {
                let totalCorrect = allSessions.reduce(0) { $0 + $1.correctAttempts }
                let totalAttempts = allSessions.reduce(0) { $0 + $1.totalAttempts }
                overallAccuracy = totalAttempts > 0
                    ? (Double(totalCorrect) / Double(totalAttempts) * 100)
                    : 0
            }

            let currentFocusSound: String
            if let latestTarget = try AVTTarget
                .filter(Column("is_active") == true)
                .order(Column("assigned_at").desc)
                .limit(1)
                .fetchOne(db) {
                currentFocusSound = latestTarget.sound
            } else {
                currentFocusSound = ""
            }

            let streakDays = try calculateStreak(db: db)

            return AVTHomeStats(
                activeTargets: activeTargets,
                sessionsToday: sessionsToday,
                overallAccuracy: overallAccuracy,
                currentFocusSound: currentFocusSound,
                streakDays: streakDays
            )
        }
    }

    // MARK: - Drill Content

    /// Public entry point. Combines the curated audio-backed drills (for the
    /// audiologist's primary targets) with content mined from the Cochlear
    /// adult AVT exercise library (text-based, no recorded audio).
    ///
    /// • Detection level always uses curated content because it requires
    ///   real audio recordings (silence vs. phoneme).
    /// • Higher levels (discrimination/identification/comprehension) start
    ///   with curated items and then append matching items from the
    ///   Cochlear library so the user gets a much larger pool.
    func getDrillItems(sound: String, level: ListeningHierarchy) -> [AVTDrillItem] {
        let curated = legacyCuratedDrillItems(sound: sound, level: level)
        if level == .detection {
            return curated
        }
        let library = CochlearExerciseLibrary.shared.drillItems(forSound: sound, level: level)

        // Mix in a few items from the user's personal confusion log so that
        // normal drills naturally include the sounds they're struggling with.
        // These come from an in-memory cache primed asynchronously by the
        // drill screen's viewWillAppear — if the cache is cold (first app
        // launch / no confusions logged), we just skip injection.
        let personal = ConfusionDrillService.shared.cachedInjectionItems(
            forSound: sound,
            level: level,
            count: 3
        )

        return personal + curated + library
    }

    /// Hard-coded curated drills (with audio file names) — kept exactly as
    /// the original implementation. New sounds and levels fall through to
    /// the Cochlear library via `getDrillItems(sound:level:)`.
    private func legacyCuratedDrillItems(sound: String, level: ListeningHierarchy) -> [AVTDrillItem] {
        switch (sound.lowercased(), level) {
        // MARK: Detection Level (0)
        case ("sh", .detection):
            return [
                AVTDrillItem(
                    sound: "sh",
                    displayText: "/ʃ/ or silence?",
                    audioFileName: "avt_sh_detection_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʃ/", audioFileName: "avt_sh_detection_1.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "/ʃ/ or silence?",
                    audioFileName: "avt_sh_detection_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʃ/", audioFileName: "avt_sh_detection_2.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "/ʃ/ or silence?",
                    audioFileName: "avt_sh_detection_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʃ/", audioFileName: "avt_sh_detection_3.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                )
            ]

        case ("mm", .detection):
            return [
                AVTDrillItem(
                    sound: "mm",
                    displayText: "/m/ or silence?",
                    audioFileName: "avt_mm_detection_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/m/", audioFileName: "avt_mm_detection_1.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "/m/ or silence?",
                    audioFileName: "avt_mm_detection_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/m/", audioFileName: "avt_mm_detection_2.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "/m/ or silence?",
                    audioFileName: "avt_mm_detection_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/m/", audioFileName: "avt_mm_detection_3.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                )
            ]

        case ("ush", .detection):
            return [
                AVTDrillItem(
                    sound: "ush",
                    displayText: "/ʌʃ/ or silence?",
                    audioFileName: "avt_ush_detection_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʌʃ/", audioFileName: "avt_ush_detection_1.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "/ʌʃ/ or silence?",
                    audioFileName: "avt_ush_detection_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʌʃ/", audioFileName: "avt_ush_detection_2.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "/ʌʃ/ or silence?",
                    audioFileName: "avt_ush_detection_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Silence", audioFileName: "avt_silence.mp3", isCorrect: false),
                        AVTDistractor(text: "/ʌʃ/", audioFileName: "avt_ush_detection_3.mp3", isCorrect: true)
                    ],
                    level: .detection,
                    correctAnswer: "yes"
                )
            ]

        // MARK: Discrimination Level (1)
        case ("sh", .discrimination):
            return [
                AVTDrillItem(
                    sound: "sh",
                    displayText: "sh vs s",
                    audioFileName: "avt_sh_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_sh_1.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_s_1.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "sh vs sh",
                    audioFileName: "avt_sh_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_sh_2.mp3", isCorrect: true),
                        AVTDistractor(text: "Different", audioFileName: "avt_s_2.mp3", isCorrect: false)
                    ],
                    level: .discrimination,
                    correctAnswer: "same"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "sh vs s",
                    audioFileName: "avt_sh_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_sh_3.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_s_3.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                )
            ]

        case ("mm", .discrimination):
            return [
                AVTDrillItem(
                    sound: "mm",
                    displayText: "mm vs n",
                    audioFileName: "avt_mm_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_mm_1.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_n_1.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "mm vs mm",
                    audioFileName: "avt_mm_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_mm_2.mp3", isCorrect: true),
                        AVTDistractor(text: "Different", audioFileName: "avt_n_2.mp3", isCorrect: false)
                    ],
                    level: .discrimination,
                    correctAnswer: "same"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "mm vs n",
                    audioFileName: "avt_mm_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_mm_3.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_n_3.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                )
            ]

        case ("ush", .discrimination):
            return [
                AVTDrillItem(
                    sound: "ush",
                    displayText: "ush vs ash",
                    audioFileName: "avt_ush_1.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_ush_1.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_ash_1.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "ush vs ush",
                    audioFileName: "avt_ush_2.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_ush_2.mp3", isCorrect: true),
                        AVTDistractor(text: "Different", audioFileName: "avt_ash_2.mp3", isCorrect: false)
                    ],
                    level: .discrimination,
                    correctAnswer: "same"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "ush vs ash",
                    audioFileName: "avt_ush_3.mp3",
                    distractors: [
                        AVTDistractor(text: "Same", audioFileName: "avt_ush_3.mp3", isCorrect: false),
                        AVTDistractor(text: "Different", audioFileName: "avt_ash_3.mp3", isCorrect: true)
                    ],
                    level: .discrimination,
                    correctAnswer: "different"
                )
            ]

        // MARK: Identification Level (2)
        case ("sh", .identification):
            return [
                AVTDrillItem(
                    sound: "sh",
                    displayText: "shoe",
                    audioFileName: "avt_word_shoe.mp3",
                    distractors: [
                        AVTDistractor(text: "shoe", audioFileName: "avt_word_shoe.mp3", isCorrect: true),
                        AVTDistractor(text: "zoo", audioFileName: "avt_word_zoo.mp3", isCorrect: false),
                        AVTDistractor(text: "sue", audioFileName: "avt_word_sue.mp3", isCorrect: false),
                        AVTDistractor(text: "blue", audioFileName: "avt_word_blue.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "shoe"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "ship",
                    audioFileName: "avt_word_ship.mp3",
                    distractors: [
                        AVTDistractor(text: "ship", audioFileName: "avt_word_ship.mp3", isCorrect: true),
                        AVTDistractor(text: "chip", audioFileName: "avt_word_chip.mp3", isCorrect: false),
                        AVTDistractor(text: "zip", audioFileName: "avt_word_zip.mp3", isCorrect: false),
                        AVTDistractor(text: "tip", audioFileName: "avt_word_tip.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "ship"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "sheep",
                    audioFileName: "avt_word_sheep.mp3",
                    distractors: [
                        AVTDistractor(text: "sheep", audioFileName: "avt_word_sheep.mp3", isCorrect: true),
                        AVTDistractor(text: "sleep", audioFileName: "avt_word_sleep.mp3", isCorrect: false),
                        AVTDistractor(text: "seep", audioFileName: "avt_word_seep.mp3", isCorrect: false),
                        AVTDistractor(text: "jeep", audioFileName: "avt_word_jeep.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "sheep"
                )
            ]

        case ("mm", .identification):
            return [
                AVTDrillItem(
                    sound: "mm",
                    displayText: "moon",
                    audioFileName: "avt_word_moon.mp3",
                    distractors: [
                        AVTDistractor(text: "moon", audioFileName: "avt_word_moon.mp3", isCorrect: true),
                        AVTDistractor(text: "soon", audioFileName: "avt_word_soon.mp3", isCorrect: false),
                        AVTDistractor(text: "noon", audioFileName: "avt_word_noon.mp3", isCorrect: false),
                        AVTDistractor(text: "boon", audioFileName: "avt_word_boon.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "moon"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "man",
                    audioFileName: "avt_word_man.mp3",
                    distractors: [
                        AVTDistractor(text: "man", audioFileName: "avt_word_man.mp3", isCorrect: true),
                        AVTDistractor(text: "pan", audioFileName: "avt_word_pan.mp3", isCorrect: false),
                        AVTDistractor(text: "tan", audioFileName: "avt_word_tan.mp3", isCorrect: false),
                        AVTDistractor(text: "can", audioFileName: "avt_word_can.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "man"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "milk",
                    audioFileName: "avt_word_milk.mp3",
                    distractors: [
                        AVTDistractor(text: "milk", audioFileName: "avt_word_milk.mp3", isCorrect: true),
                        AVTDistractor(text: "silk", audioFileName: "avt_word_silk.mp3", isCorrect: false),
                        AVTDistractor(text: "kill", audioFileName: "avt_word_kill.mp3", isCorrect: false),
                        AVTDistractor(text: "bill", audioFileName: "avt_word_bill.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "milk"
                )
            ]

        case ("ush", .identification):
            return [
                AVTDrillItem(
                    sound: "ush",
                    displayText: "rush",
                    audioFileName: "avt_word_rush.mp3",
                    distractors: [
                        AVTDistractor(text: "rush", audioFileName: "avt_word_rush.mp3", isCorrect: true),
                        AVTDistractor(text: "push", audioFileName: "avt_word_push.mp3", isCorrect: false),
                        AVTDistractor(text: "bush", audioFileName: "avt_word_bush.mp3", isCorrect: false),
                        AVTDistractor(text: "gush", audioFileName: "avt_word_gush.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "rush"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "bush",
                    audioFileName: "avt_word_bush.mp3",
                    distractors: [
                        AVTDistractor(text: "bush", audioFileName: "avt_word_bush.mp3", isCorrect: true),
                        AVTDistractor(text: "push", audioFileName: "avt_word_push.mp3", isCorrect: false),
                        AVTDistractor(text: "rush", audioFileName: "avt_word_rush.mp3", isCorrect: false),
                        AVTDistractor(text: "cash", audioFileName: "avt_word_cash.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "bush"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "push",
                    audioFileName: "avt_word_push.mp3",
                    distractors: [
                        AVTDistractor(text: "push", audioFileName: "avt_word_push.mp3", isCorrect: true),
                        AVTDistractor(text: "bush", audioFileName: "avt_word_bush.mp3", isCorrect: false),
                        AVTDistractor(text: "rush", audioFileName: "avt_word_rush.mp3", isCorrect: false),
                        AVTDistractor(text: "plush", audioFileName: "avt_word_plush.mp3", isCorrect: false)
                    ],
                    level: .identification,
                    correctAnswer: "push"
                )
            ]

        // MARK: Comprehension Level (3)
        case ("sh", .comprehension):
            return [
                AVTDrillItem(
                    sound: "sh",
                    displayText: "shoe",
                    audioFileName: "avt_word_shoe.mp3",
                    distractors: [
                        AVTDistractor(text: "A piece of clothing you wear on your foot", audioFileName: "avt_word_shoe.mp3", isCorrect: true),
                        AVTDistractor(text: "A vehicle", audioFileName: "avt_word_car.mp3", isCorrect: false),
                        AVTDistractor(text: "An animal", audioFileName: "avt_word_cat.mp3", isCorrect: false),
                        AVTDistractor(text: "Food you eat", audioFileName: "avt_word_bread.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "A piece of clothing you wear on your foot"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "ship",
                    audioFileName: "avt_word_ship.mp3",
                    distractors: [
                        AVTDistractor(text: "A large boat", audioFileName: "avt_word_ship.mp3", isCorrect: true),
                        AVTDistractor(text: "Flying in the sky", audioFileName: "avt_word_plane.mp3", isCorrect: false),
                        AVTDistractor(text: "Something you wear", audioFileName: "avt_word_hat.mp3", isCorrect: false),
                        AVTDistractor(text: "A building", audioFileName: "avt_word_house.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "A large boat"
                ),
                AVTDrillItem(
                    sound: "sh",
                    displayText: "sheep",
                    audioFileName: "avt_word_sheep.mp3",
                    distractors: [
                        AVTDistractor(text: "An animal with wool", audioFileName: "avt_word_sheep.mp3", isCorrect: true),
                        AVTDistractor(text: "A color", audioFileName: "avt_word_blue.mp3", isCorrect: false),
                        AVTDistractor(text: "A number", audioFileName: "avt_word_ten.mp3", isCorrect: false),
                        AVTDistractor(text: "A type of food", audioFileName: "avt_word_apple.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "An animal with wool"
                )
            ]

        case ("mm", .comprehension):
            return [
                AVTDrillItem(
                    sound: "mm",
                    displayText: "moon",
                    audioFileName: "avt_word_moon.mp3",
                    distractors: [
                        AVTDistractor(text: "Bright light in the night sky", audioFileName: "avt_word_moon.mp3", isCorrect: true),
                        AVTDistractor(text: "Bright light in the day sky", audioFileName: "avt_word_sun.mp3", isCorrect: false),
                        AVTDistractor(text: "Wet and cold", audioFileName: "avt_word_snow.mp3", isCorrect: false),
                        AVTDistractor(text: "Green and growing", audioFileName: "avt_word_tree.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "Bright light in the night sky"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "man",
                    audioFileName: "avt_word_man.mp3",
                    distractors: [
                        AVTDistractor(text: "Adult male human", audioFileName: "avt_word_man.mp3", isCorrect: true),
                        AVTDistractor(text: "Adult female human", audioFileName: "avt_word_woman.mp3", isCorrect: false),
                        AVTDistractor(text: "A city", audioFileName: "avt_word_town.mp3", isCorrect: false),
                        AVTDistractor(text: "A tool", audioFileName: "avt_word_hammer.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "Adult male human"
                ),
                AVTDrillItem(
                    sound: "mm",
                    displayText: "milk",
                    audioFileName: "avt_word_milk.mp3",
                    distractors: [
                        AVTDistractor(text: "White liquid from animals", audioFileName: "avt_word_milk.mp3", isCorrect: true),
                        AVTDistractor(text: "Red liquid in your body", audioFileName: "avt_word_blood.mp3", isCorrect: false),
                        AVTDistractor(text: "Sweet treat", audioFileName: "avt_word_candy.mp3", isCorrect: false),
                        AVTDistractor(text: "Hot drink", audioFileName: "avt_word_coffee.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "White liquid from animals"
                )
            ]

        case ("ush", .comprehension):
            return [
                AVTDrillItem(
                    sound: "ush",
                    displayText: "rush",
                    audioFileName: "avt_word_rush.mp3",
                    distractors: [
                        AVTDistractor(text: "To move quickly", audioFileName: "avt_word_rush.mp3", isCorrect: true),
                        AVTDistractor(text: "To move slowly", audioFileName: "avt_word_walk.mp3", isCorrect: false),
                        AVTDistractor(text: "To stop", audioFileName: "avt_word_stop.mp3", isCorrect: false),
                        AVTDistractor(text: "To rest", audioFileName: "avt_word_sit.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "To move quickly"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "bush",
                    audioFileName: "avt_word_bush.mp3",
                    distractors: [
                        AVTDistractor(text: "A thick plant with leaves", audioFileName: "avt_word_bush.mp3", isCorrect: true),
                        AVTDistractor(text: "A tall plant with trunk", audioFileName: "avt_word_tree.mp3", isCorrect: false),
                        AVTDistractor(text: "A small building", audioFileName: "avt_word_house.mp3", isCorrect: false),
                        AVTDistractor(text: "A large stone", audioFileName: "avt_word_rock.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "A thick plant with leaves"
                ),
                AVTDrillItem(
                    sound: "ush",
                    displayText: "push",
                    audioFileName: "avt_word_push.mp3",
                    distractors: [
                        AVTDistractor(text: "To apply force to move something", audioFileName: "avt_word_push.mp3", isCorrect: true),
                        AVTDistractor(text: "To take something toward you", audioFileName: "avt_word_pull.mp3", isCorrect: false),
                        AVTDistractor(text: "To lift something up", audioFileName: "avt_word_lift.mp3", isCorrect: false),
                        AVTDistractor(text: "To carry something", audioFileName: "avt_word_carry.mp3", isCorrect: false)
                    ],
                    level: .comprehension,
                    correctAnswer: "To apply force to move something"
                )
            ]

        default:
            return []
        }
    }

    // MARK: - Private Helpers

    private func calculateAccuracy(sessions: [AVTSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let totalCorrect = sessions.reduce(0) { $0 + $1.correctAttempts }
        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        return totalAttempts > 0
            ? (Double(totalCorrect) / Double(totalAttempts) * 100)
            : 0
    }

    private func calculateStreak(db: Database) throws -> Int {
        let sessions = try AVTSession
            .order(Column("started_at").desc)
            .fetchAll(db)

        guard !sessions.isEmpty else { return 0 }

        var streak = 0
        var currentDate = Calendar.current.startOfDay(for: Date())

        for session in sessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startedAt)

            if Calendar.current.dateComponents([.day], from: sessionDate, to: currentDate).day == 0 {
                // Same day, increment streak
                if streak == 0 {
                    streak = 1
                }
            } else if Calendar.current.dateComponents([.day], from: sessionDate, to: currentDate).day == 1 {
                // Previous day, continue streak
                streak += 1
                currentDate = sessionDate
            } else {
                // Gap detected, break streak
                break
            }
        }

        return streak
    }
}

// MARK: - Error

enum GRDBAvtServiceError: Error {
    case sessionNotFound
}
