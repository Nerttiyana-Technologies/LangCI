// GRDBMusicPerceptionService.swift
// LangCI

import Foundation
import GRDB

final class GRDBMusicPerceptionService: MusicPerceptionService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Record attempt

    func recordAttempt(_ attempt: MusicAttempt) async throws -> MusicAttempt {
        try await db.write { database -> MusicAttempt in
            var saved = attempt
            if attempt.id == 0 {
                try database.execute(sql: """
                    INSERT INTO music_attempt
                        (training_type, played_item, user_answer,
                         is_correct, program_used, attempted_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    attempt.trainingType.rawValue,
                    attempt.playedItem,
                    attempt.userAnswer,
                    attempt.isCorrect ? 1 : 0,
                    attempt.programUsed.rawValue,
                    attempt.attemptedAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE music_attempt
                    SET training_type = ?, played_item = ?, user_answer = ?,
                        is_correct = ?, program_used = ?, attempted_at = ?
                    WHERE id = ?
                """, arguments: [
                    attempt.trainingType.rawValue,
                    attempt.playedItem,
                    attempt.userAnswer,
                    attempt.isCorrect ? 1 : 0,
                    attempt.programUsed.rawValue,
                    attempt.attemptedAt.timeIntervalSince1970,
                    attempt.id
                ])
            }
            return saved
        }
    }

    // MARK: - Stats by type

    func getStatsByType() async throws -> [MusicStatsDto] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT training_type,
                       COUNT(*) AS attempts,
                       AVG(CAST(is_correct AS REAL)) * 100 AS accuracy_pct
                FROM music_attempt
                GROUP BY training_type
                ORDER BY training_type ASC
            """)

            return rows.compactMap { row -> MusicStatsDto? in
                guard let typeRaw: Int = row["training_type"],
                      let type = MusicTrainingType(rawValue: typeRaw) else { return nil }

                return MusicStatsDto(
                    trainingType: type,
                    typeLabel: type.label,
                    attempts: row["attempts"] ?? 0,
                    accuracyPct: row["accuracy_pct"] ?? 0.0
                )
            }
        }
    }

    // MARK: - Overall accuracy

    func getOverallAccuracy() async throws -> Double {
        try await db.read { database in
            let row = try Row.fetchOne(database, sql: """
                SELECT AVG(CAST(is_correct AS REAL)) * 100 AS accuracy_pct
                FROM music_attempt
            """)
            return row?["accuracy_pct"] ?? 0.0
        }
    }

    // MARK: - Built-in item catalogue

    func getItems(for mode: MusicTrainingType) -> [MusicItem] {
        switch mode {
        case .rhythm:
            return [
                MusicItem(
                    name: "Slow Waltz",
                    audioFile: "rhythm_waltz_slow.mp3",
                    description: "3/4 time, 60 BPM — steady, swaying beat",
                    emoji: "🎼",
                    type: .rhythm,
                    distractors: ["Fast March", "Bossa Nova", "Tango"]
                ),
                MusicItem(
                    name: "Fast March",
                    audioFile: "rhythm_march_fast.mp3",
                    description: "4/4 time, 120 BPM — strong, regular downbeats",
                    emoji: "🥁",
                    type: .rhythm,
                    distractors: ["Slow Waltz", "Bossa Nova", "Tango"]
                ),
                MusicItem(
                    name: "Bossa Nova",
                    audioFile: "rhythm_bossa_nova.mp3",
                    description: "Syncopated 4/4, 100 BPM — subtle cross-rhythm",
                    emoji: "🎹",
                    type: .rhythm,
                    distractors: ["Slow Waltz", "Fast March", "Tango"]
                ),
                MusicItem(
                    name: "Tango",
                    audioFile: "rhythm_tango.mp3",
                    description: "2/4 time, 65 BPM — sharp staccato beats",
                    emoji: "💃",
                    type: .rhythm,
                    distractors: ["Slow Waltz", "Fast March", "Bossa Nova"]
                )
            ]

        case .instrument:
            return [
                MusicItem(
                    name: "Piano",
                    audioFile: "instrument_piano.mp3",
                    description: "Percussive keyboard — bright, sustaining tone",
                    emoji: "🎹",
                    type: .instrument,
                    distractors: ["Violin", "Trumpet", "Guitar"]
                ),
                MusicItem(
                    name: "Violin",
                    audioFile: "instrument_violin.mp3",
                    description: "Bowed string — warm, expressive vibrato",
                    emoji: "🎻",
                    type: .instrument,
                    distractors: ["Piano", "Trumpet", "Guitar"]
                ),
                MusicItem(
                    name: "Trumpet",
                    audioFile: "instrument_trumpet.mp3",
                    description: "Brass — bright, piercing, clear attack",
                    emoji: "🎺",
                    type: .instrument,
                    distractors: ["Piano", "Violin", "Guitar"]
                ),
                MusicItem(
                    name: "Guitar",
                    audioFile: "instrument_guitar.mp3",
                    description: "Plucked string — warm, resonant body",
                    emoji: "🎸",
                    type: .instrument,
                    distractors: ["Piano", "Violin", "Trumpet"]
                ),
                MusicItem(
                    name: "Flute",
                    audioFile: "instrument_flute.mp3",
                    description: "Woodwind — airy, high-frequency breath tone",
                    emoji: "🪈",
                    type: .instrument,
                    distractors: ["Piano", "Violin", "Trumpet"]
                )
            ]

        case .melody:
            return [
                MusicItem(
                    name: "Twinkle Twinkle",
                    audioFile: "melody_twinkle.mp3",
                    description: "Simple stepwise melody — easy to follow",
                    emoji: "⭐",
                    type: .melody,
                    distractors: ["Happy Birthday", "Jingle Bells", "Ode to Joy"]
                ),
                MusicItem(
                    name: "Happy Birthday",
                    audioFile: "melody_happy_birthday.mp3",
                    description: "Familiar 3/4 melody with a rising opening leap",
                    emoji: "🎂",
                    type: .melody,
                    distractors: ["Twinkle Twinkle", "Jingle Bells", "Ode to Joy"]
                ),
                MusicItem(
                    name: "Jingle Bells",
                    audioFile: "melody_jingle_bells.mp3",
                    description: "Energetic stepwise descents — very recognisable",
                    emoji: "🔔",
                    type: .melody,
                    distractors: ["Twinkle Twinkle", "Happy Birthday", "Ode to Joy"]
                ),
                MusicItem(
                    name: "Ode to Joy",
                    audioFile: "melody_ode_to_joy.mp3",
                    description: "Beethoven — repeated-note figure then scale ascent",
                    emoji: "🎶",
                    type: .melody,
                    distractors: ["Twinkle Twinkle", "Happy Birthday", "Jingle Bells"]
                )
            ]
        }
    }
}

// MARK: - MusicTrainingType display label

private extension MusicTrainingType {
    var label: String {
        switch self {
        case .rhythm:     return "Rhythm"
        case .instrument: return "Instrument"
        case .melody:     return "Melody"
        }
    }
}
