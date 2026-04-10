// GRDBWordService.swift
// LangCI

import Foundation
import GRDB

final class GRDBWordService: WordService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Fetch

    func getWords(languageId: Int, dialectId: Int?) async throws -> [WordEntry] {
        try await db.read { database in
            if let dialectId {
                let rows = try Row.fetchAll(database, sql: """
                    SELECT w.* FROM word_entry w
                    JOIN word_dialect_map m ON m.word_entry_id = w.id
                    WHERE w.language_id = ? AND m.dialect_id = ? AND w.status = 1
                    ORDER BY w.native_script
                """, arguments: [languageId, dialectId])
                return try rows.map { try WordEntry(row: $0) }
            } else {
                let rows = try Row.fetchAll(database, sql: """
                    SELECT * FROM word_entry
                    WHERE language_id = ? AND status = 1
                    ORDER BY native_script
                """, arguments: [languageId])
                return try rows.map { try WordEntry(row: $0) }
            }
        }
    }

    func getWord(id: Int) async throws -> WordEntry? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM word_entry WHERE id = ?", arguments: [id])
            else { return nil }
            var word = try WordEntry(row: row)
            word.translations = try self.loadTranslations(database, wordId: id)
            return word
        }
    }

    func getWordsForReview(dialectId: Int, limit: Int) async throws -> [WordEntry] {
        let cutoff = Date().timeIntervalSince1970
        return try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT DISTINCT w.* FROM word_entry w
                JOIN session_word sw ON sw.word_entry_id = w.id
                WHERE sw.next_review_date <= ?
                ORDER BY sw.next_review_date ASC
                LIMIT ?
            """, arguments: [cutoff, limit])
            return try rows.map { try WordEntry(row: $0) }
        }
    }

    func searchWords(query: String, languageId: Int) async throws -> [WordEntry] {
        let pattern = "%\(query)%"
        return try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT w.* FROM word_entry w
                LEFT JOIN word_translation t ON t.word_entry_id = w.id
                WHERE w.language_id = ? AND w.status = 1
                  AND (w.native_script LIKE ? OR w.ipa_phoneme LIKE ?
                       OR t.translation LIKE ? OR t.transliteration LIKE ?)
                GROUP BY w.id
                ORDER BY w.native_script
                LIMIT 50
            """, arguments: [languageId, pattern, pattern, pattern, pattern])
            return try rows.map { try WordEntry(row: $0) }
        }
    }

    func getWordsByCategory(categoryCode: String, languageId: Int) async throws -> [WordEntry] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT w.* FROM word_entry w
                JOIN word_category_map wm ON wm.word_entry_id = w.id
                JOIN word_category c ON c.id = wm.word_category_id
                WHERE c.code = ? AND w.language_id = ? AND w.status = 1
                ORDER BY w.native_script
            """, arguments: [categoryCode, languageId])
            return try rows.map { try WordEntry(row: $0) }
        }
    }

    func getWordCount(languageId: Int) async throws -> Int {
        try await db.read { database in
            try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM word_entry
                WHERE language_id = ? AND status = 1
            """, arguments: [languageId]) ?? 0
        }
    }

    // MARK: - Manage

    func saveWord(_ word: WordEntry) async throws -> WordEntry {
        try await db.write { database -> WordEntry in
            var saved = word
            if word.id == 0 {
                try database.execute(sql: """
                    INSERT INTO word_entry
                        (global_id, language_id, native_script, ipa_phoneme, phonetic_key,
                         is_slang, source, status, publisher_pack_id,
                         sync_status, last_synced_at, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    word.globalId.uuidString,
                    word.languageId,
                    word.nativeScript,
                    word.ipaPhoneme,
                    word.phoneticKey,
                    word.isSlang ? 1 : 0,
                    word.source.rawValue,
                    word.status.rawValue,
                    word.publisherPackId,
                    word.syncStatus.rawValue,
                    word.lastSyncedAt?.timeIntervalSince1970,
                    word.createdAt.timeIntervalSince1970,
                    word.updatedAt.timeIntervalSince1970
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE word_entry
                    SET native_script = ?, ipa_phoneme = ?, phonetic_key = ?,
                        is_slang = ?, status = ?, sync_status = ?, updated_at = ?
                    WHERE id = ?
                """, arguments: [
                    word.nativeScript,
                    word.ipaPhoneme,
                    word.phoneticKey,
                    word.isSlang ? 1 : 0,
                    word.status.rawValue,
                    word.syncStatus.rawValue,
                    Date().timeIntervalSince1970,
                    word.id
                ])
            }
            return saved
        }
    }

    func deleteWord(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM word_entry WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Translations

    func getTranslations(for wordEntryId: Int) async throws -> [WordTranslation] {
        try await db.read { database in
            try loadTranslations(database, wordId: wordEntryId)
        }
    }

    func saveTranslation(_ translation: WordTranslation) async throws -> WordTranslation {
        try await db.write { database -> WordTranslation in
            var saved = translation
            if translation.id == 0 {
                try database.execute(sql: """
                    INSERT INTO word_translation
                        (word_entry_id, target_language_code, translation,
                         transliteration, example_native, example_translation)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    translation.wordEntryId,
                    translation.targetLanguageCode,
                    translation.translation,
                    translation.transliteration,
                    translation.exampleNative,
                    translation.exampleTranslation
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE word_translation
                    SET translation = ?, transliteration = ?,
                        example_native = ?, example_translation = ?
                    WHERE id = ?
                """, arguments: [
                    translation.translation,
                    translation.transliteration,
                    translation.exampleNative,
                    translation.exampleTranslation,
                    translation.id
                ])
            }
            return saved
        }
    }

    // MARK: - Private helpers

    private func loadTranslations(_ db: Database, wordId: Int) throws -> [WordTranslation] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT * FROM word_translation WHERE word_entry_id = ?
        """, arguments: [wordId])
        return try rows.map { try WordTranslation(row: $0) }
    }
}
