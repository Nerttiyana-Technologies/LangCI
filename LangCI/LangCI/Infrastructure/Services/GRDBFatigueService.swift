// GRDBFatigueService.swift
// LangCI

import Foundation
import GRDB

final class GRDBFatigueService: FatigueService {

    private let db: DatabaseQueue

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Log entry

    func log(_ entry: FatigueEntry) async throws -> FatigueEntry {
        try await db.write { database -> FatigueEntry in
            var saved = entry

            if entry.id == 0 {
                try database.execute(sql: """
                    INSERT INTO fatigue_entry
                        (logged_at, effort_level, fatigue_level, environment,
                         program_used, hours_worn, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    entry.loggedAt.timeIntervalSince1970,
                    entry.effortLevel,
                    entry.fatigueLevel,
                    entry.environment.rawValue,
                    entry.programUsed.rawValue,
                    entry.hoursWorn,
                    entry.notes
                ])
                saved.id = Int(database.lastInsertedRowID)
            } else {
                try database.execute(sql: """
                    UPDATE fatigue_entry
                    SET logged_at = ?, effort_level = ?, fatigue_level = ?,
                        environment = ?, program_used = ?, hours_worn = ?, notes = ?
                    WHERE id = ?
                """, arguments: [
                    entry.loggedAt.timeIntervalSince1970,
                    entry.effortLevel,
                    entry.fatigueLevel,
                    entry.environment.rawValue,
                    entry.programUsed.rawValue,
                    entry.hoursWorn,
                    entry.notes,
                    entry.id
                ])
            }
            return saved
        }
    }

    // MARK: - Get entries

    func getEntries(days: Int) async throws -> [FatigueEntry] {
        let cutoff = Calendar.current
            .date(byAdding: .day, value: -days, to: Date())!
            .timeIntervalSince1970
        return try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM fatigue_entry
                WHERE logged_at >= ?
                ORDER BY logged_at DESC
            """, arguments: [cutoff])
            return try rows.map { try FatigueEntry(row: $0) }
        }
    }

    // MARK: - Stats

    func getStats(days: Int) async throws -> FatigueStatsDto {
        let cutoff = Calendar.current
            .date(byAdding: .day, value: -days, to: Date())!
            .timeIntervalSince1970

        return try await db.read { database in
            let summaryRows = try Row.fetchAll(database, sql: """
                SELECT
                    AVG(CAST(effort_level  AS REAL)) AS avg_effort,
                    AVG(CAST(fatigue_level AS REAL)) AS avg_fatigue,
                    COUNT(*) AS total
                FROM fatigue_entry
                WHERE logged_at >= ?
            """, arguments: [cutoff])

            let avgEffort:  Double = summaryRows.first?["avg_effort"]  ?? 0
            let avgFatigue: Double = summaryRows.first?["avg_fatigue"] ?? 0
            let total:      Int    = summaryRows.first?["total"]       ?? 0

            // Hardest / easiest environment by average fatigue
            let envRows = try Row.fetchAll(database, sql: """
                SELECT environment, AVG(CAST(fatigue_level AS REAL)) AS avg_f
                FROM fatigue_entry
                WHERE logged_at >= ?
                GROUP BY environment
                ORDER BY avg_f DESC
            """, arguments: [cutoff])

            let hardestEnv  = envLabel(envRows.first?["environment"] as Int? ?? -1)
            let easiestEnv  = envLabel(envRows.last?["environment"]  as Int? ?? -1)

            // Daily trend (last `days` days, grouped by day)
            let trendRows = try Row.fetchAll(database, sql: """
                SELECT
                    date(logged_at, 'unixepoch') AS day,
                    AVG(CAST(effort_level  AS REAL)) AS avg_effort,
                    AVG(CAST(fatigue_level AS REAL)) AS avg_fatigue
                FROM fatigue_entry
                WHERE logged_at >= ?
                GROUP BY day
                ORDER BY day ASC
            """, arguments: [cutoff])

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let trend: [FatigueTrendPoint] = trendRows.compactMap { r in
                guard let dayStr = r["day"] as String?,
                      let date   = fmt.date(from: dayStr) else { return nil }
                return FatigueTrendPoint(
                    date:       date,
                    effortAvg:  r["avg_effort"]  ?? 0,
                    fatigueAvg: r["avg_fatigue"] ?? 0
                )
            }

            return FatigueStatsDto(
                avgEffort:   avgEffort,
                avgFatigue:  avgFatigue,
                totalEntries: total,
                hardestEnv:  hardestEnv,
                easiestEnv:  easiestEnv,
                trend:       trend
            )
        }
    }

    // MARK: - Delete

    func deleteEntry(id: Int) async throws {
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM fatigue_entry WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Has entry today

    func hasEntryToday() async throws -> Bool {
        let startOfDay = Calendar.current
            .startOfDay(for: Date()).timeIntervalSince1970
        return try await db.read { database in
            let count = try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM fatigue_entry WHERE logged_at >= ?
            """, arguments: [startOfDay]) ?? 0
            return count > 0
        }
    }

    // MARK: - Private helpers

    private func envLabel(_ rawValue: Int) -> String {
        switch FatigueEnvironment(rawValue: rawValue) {
        case .quiet:       return "Quiet"
        case .homeTV:      return "Home / TV"
        case .office:      return "Office"
        case .restaurant:  return "Restaurant"
        case .outdoors:    return "Outdoors"
        case .phone:       return "Phone"
        case .shopping:    return "Shopping"
        case .transport:   return "Transport"
        case .none:        return "Unknown"
        }
    }
}
