// DatabaseManager.swift
// LangCI
//
// Central SQLite access point backed by GRDB.
// One DatabaseQueue = serialised, crash-safe I/O.
//
// ── SPM dependency (add once in Xcode) ──────────────────────────────────────
// File ▸ Add Package Dependencies ▸
//   https://github.com/groue/GRDB.swift   "Up to Next Major"  7.0.0
// ────────────────────────────────────────────────────────────────────────────

import Foundation
import GRDB

final class DatabaseManager {

    // MARK: - Singleton
    static let shared = DatabaseManager()

    // MARK: - Public access
    let dbQueue: DatabaseQueue

    // MARK: - Init
    private init() {
        let appSupport = try! FileManager.default.url(
            for:           .applicationSupportDirectory,
            in:            .userDomainMask,
            appropriateFor: nil,
            create:         true
        )
        let dbURL = appSupport.appendingPathComponent("langci.sqlite")

        var config = Configuration()
        config.foreignKeysEnabled = true

        #if DEBUG
        config.prepareDatabase { db in
            db.trace { event in
                // Uncomment to log every SQL statement:
                // print("[SQL]", event)
            }
        }
        #endif

        dbQueue = try! DatabaseQueue(path: dbURL.path, configuration: config)
        try! Migrations.migrate(dbQueue)
    }
}
