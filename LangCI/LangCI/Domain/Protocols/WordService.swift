// WordService.swift
// LangCI

import Foundation

protocol WordService {
    // ── Fetch ────────────────────────────────────────────────────────────────────
    func getWords(languageId: Int, dialectId: Int?) async throws -> [WordEntry]
    func getWord(id: Int) async throws -> WordEntry?
    func getWordsForReview(dialectId: Int, limit: Int) async throws -> [WordEntry]
    func searchWords(query: String, languageId: Int) async throws -> [WordEntry]
    func getWordsByCategory(categoryCode: String, languageId: Int) async throws -> [WordEntry]
    func getWordCount(languageId: Int) async throws -> Int

    // ── Manage ──────────────────────────────────────────────────────────────────
    func saveWord(_ word: WordEntry) async throws -> WordEntry
    func deleteWord(id: Int) async throws

    // ── Translations ─────────────────────────────────────────────────────────────
    func getTranslations(for wordEntryId: Int) async throws -> [WordTranslation]
    func saveTranslation(_ translation: WordTranslation) async throws -> WordTranslation
}
