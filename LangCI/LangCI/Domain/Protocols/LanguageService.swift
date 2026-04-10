// LanguageService.swift
// LangCI

import Foundation

protocol LanguageService {
    // ── Languages ────────────────────────────────────────────────────────────────
    func getActiveLanguages() async throws -> [Language]
    func getLanguage(id: Int) async throws -> Language?

    // ── Dialects ─────────────────────────────────────────────────────────────────
    func getDialects(for languageId: Int) async throws -> [Dialect]
    func getDialect(id: Int) async throws -> Dialect?
    func getActiveDialects(for languageId: Int) async throws -> [Dialect]

    // ── Categories ──────────────────────────────────────────────────────────────
    func getCategories(for languageId: Int) async throws -> [WordCategory]

    // ── Phonetic groups ──────────────────────────────────────────────────────────
    func getPhoneticGroups(for languageId: Int) async throws -> [PhoneticGroup]
}
