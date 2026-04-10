// GRDBLanguageService.swift
// LangCI

import Foundation
import GRDB

final class GRDBLanguageService: LanguageService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    func getActiveLanguages() async throws -> [Language] {
        try await db.read { database in
            let rows = try Row.fetchAll(database,
                sql: "SELECT * FROM language WHERE is_active = 1 ORDER BY name")
            return try rows.map { try Language(row: $0) }
        }
    }

    func getLanguage(id: Int) async throws -> Language? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM language WHERE id = ?", arguments: [id])
            else { return nil }
            return try Language(row: row)
        }
    }

    func getDialects(for languageId: Int) async throws -> [Dialect] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM dialect WHERE language_id = ? ORDER BY name
            """, arguments: [languageId])
            return try rows.map { try Dialect(row: $0) }
        }
    }

    func getDialect(id: Int) async throws -> Dialect? {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM dialect WHERE id = ?", arguments: [id])
            else { return nil }
            return try Dialect(row: row)
        }
    }

    func getActiveDialects(for languageId: Int) async throws -> [Dialect] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM dialect
                WHERE language_id = ? AND is_active = 1
                ORDER BY name
            """, arguments: [languageId])
            return try rows.map { try Dialect(row: $0) }
        }
    }

    func getCategories(for languageId: Int) async throws -> [WordCategory] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM word_category
                WHERE language_id = ?
                ORDER BY sort_order
            """, arguments: [languageId])
            return try rows.map { try WordCategory(row: $0) }
        }
    }

    func getPhoneticGroups(for languageId: Int) async throws -> [PhoneticGroup] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM phonetic_group
                WHERE language_id = ?
                ORDER BY ci_difficulty_level, group_key
            """, arguments: [languageId])
            return try rows.map { try PhoneticGroup(row: $0) }
        }
    }
}
