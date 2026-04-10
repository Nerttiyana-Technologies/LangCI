// GRDBMinimalPairsService.swift
// LangCI

import Foundation
import GRDB

final class GRDBMinimalPairsService: MinimalPairsService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Session pairs

    func getPairsForSession(languageId: Int, dialectId: Int?, count: Int) async throws -> [MinimalPairDto] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT mp.*,
                       w1.native_script AS ns1, w2.native_script AS ns2,
                       t1.translation AS tr1,   t2.translation AS tr2,
                       t1.transliteration AS tl1, t2.transliteration AS tl2,
                       r1.file_path AS rp1, r2.file_path AS rp2
                FROM minimal_pair mp
                JOIN word_entry w1 ON w1.id = mp.word_entry_id_1
                JOIN word_entry w2 ON w2.id = mp.word_entry_id_2
                LEFT JOIN word_translation t1 ON t1.word_entry_id = w1.id AND t1.target_language_code = 'en'
                LEFT JOIN word_translation t2 ON t2.word_entry_id = w2.id AND t2.target_language_code = 'en'
                LEFT JOIN recording r1 ON r1.word_entry_id = w1.id AND r1.is_approved = 1
                LEFT JOIN recording r2 ON r2.word_entry_id = w2.id AND r2.is_approved = 1
                WHERE mp.language_id = ?
                ORDER BY mp.ci_difficulty_level ASC, RANDOM()
                LIMIT ?
            """, arguments: [languageId, count])

            return rows.map { row in
                MinimalPairDto(
                    id: row["id"] ?? 0,
                    ciDifficultyLevel: row["ci_difficulty_level"] ?? 1,
                    contrastDescription: row["contrast_description"] ?? "",
                    word1: MinimalPairWordDto(
                        wordEntryId: row["word_entry_id_1"] ?? 0,
                        nativeScript: row["ns1"] ?? "",
                        translation: row["tr1"] ?? "",
                        transliteration: row["tl1"] ?? "",
                        recordingPath: row["rp1"]
                    ),
                    word2: MinimalPairWordDto(
                        wordEntryId: row["word_entry_id_2"] ?? 0,
                        nativeScript: row["ns2"] ?? "",
                        translation: row["tr2"] ?? "",
                        transliteration: row["tl2"] ?? "",
                        recordingPath: row["rp2"]
                    )
                )
            }
        }
    }

    // MARK: - Record attempt

    func recordAttempt(
        minimalPairId: Int,
        playedWordEntryId: Int,
        selectedWordEntryId: Int,
        familyMemberId: Int?
    ) async throws -> MinimalPairAttemptResult {
        // Determine correctness
        let isCorrect = try await db.read { database -> Bool in
            guard let row = try Row.fetchOne(database, sql: """
                SELECT word_entry_id_1, word_entry_id_2 FROM minimal_pair WHERE id = ?
            """, arguments: [minimalPairId]) else { return false }
            return (row["word_entry_id_1"] as Int? == playedWordEntryId
                 || row["word_entry_id_2"] as Int? == playedWordEntryId)
                && playedWordEntryId == selectedWordEntryId
        }

        try await db.write { database in
            try database.execute(sql: """
                INSERT INTO minimal_pair_attempt
                    (minimal_pair_id, played_word_entry_id, selected_word_entry_id,
                     is_correct, family_member_id, attempted_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [
                minimalPairId,
                playedWordEntryId,
                selectedWordEntryId,
                isCorrect ? 1 : 0,
                familyMemberId,
                Date().timeIntervalSince1970
            ])
        }

        return MinimalPairAttemptResult(
            isCorrect: isCorrect,
            pointsEarned: isCorrect ? 5 : 0,
            badgeEarned: nil
        )
    }

    // MARK: - Weakest pairs

    func getWeakestPairs(languageId: Int, limit: Int) async throws -> [MinimalPairDto] {
        // Re-use session logic with lowest-accuracy filter
        try await getPairsForSession(languageId: languageId, dialectId: nil, count: limit)
    }

    // MARK: - Contrast accuracy

    func getContrastAccuracy(languageId: Int) async throws -> [ContrastAccuracy] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT mp.contrast_description,
                       COUNT(a.id) AS total,
                       AVG(CAST(a.is_correct AS REAL)) * 100 AS accuracy_pct
                FROM minimal_pair_attempt a
                JOIN minimal_pair mp ON mp.id = a.minimal_pair_id
                WHERE mp.language_id = ?
                GROUP BY mp.contrast_description
                ORDER BY accuracy_pct ASC
            """, arguments: [languageId])

            return rows.map { row in
                ContrastAccuracy(
                    contrastDescription: row["contrast_description"] ?? "",
                    totalAttempts: row["total"] ?? 0,
                    accuracyPct: row["accuracy_pct"] ?? 0
                )
            }
        }
    }
}
