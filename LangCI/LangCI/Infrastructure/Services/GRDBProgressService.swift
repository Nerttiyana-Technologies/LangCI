// GRDBProgressService.swift
// LangCI

import Foundation
import GRDB

final class GRDBProgressService: ProgressService {

    private let db: DatabaseQueue

    // Points per level (index = level - 1)
    private static let levelThresholds = [
        0, 100, 250, 500, 1000, 1750, 2750, 4000, 5500, 7500, 10000
    ]

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Get progress

    func getProgress() async throws -> UserProgress {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM user_progress WHERE id = 1")
            else { return UserProgress(id: 1, totalPoints: 0, currentLevel: 1,
                                       currentStreak: 0, longestStreak: 0,
                                       totalSessions: 0, totalCorrect: 0, totalAttempts: 0) }
            return try UserProgress(row: row)
        }
    }

    // MARK: - Badges

    func getAllBadges() async throws -> [BadgeDto] {
        try await db.read { database in
            let badgeRows = try Row.fetchAll(database,
                sql: "SELECT * FROM badge ORDER BY sort_order")
            let earnedRows = try Row.fetchAll(database,
                sql: "SELECT badge_id FROM user_badge")
            let earnedIds = Set(earnedRows.map { $0["badge_id"] as Int })

            return try badgeRows.map { row in
                let b = try AppBadge(row: row)
                let earnedRow = try Row.fetchOne(database, sql: """
                    SELECT earned_at FROM user_badge WHERE badge_id = ?
                """, arguments: [b.id])
                return BadgeDto(
                    id: b.id, code: b.code, title: b.title,
                    description: b.description, emoji: b.emoji,
                    isEarned: earnedIds.contains(b.id),
                    earnedAt: earnedRow.flatMap { r in
                        (r["earned_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
                    }
                )
            }
        }
    }

    func getEarnedBadges() async throws -> [BadgeDto] {
        try await getAllBadges().filter(\.isEarned)
    }

    // MARK: - Add points

    func addPoints(_ points: Int, wasCorrect: Bool, wordEntryId: Int) async throws -> AwardResult {
        try await db.write { database -> AwardResult in
            // Load current progress
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM user_progress WHERE id = 1") else {
                return AwardResult(totalPoints: 0, currentLevel: 1, leveledUp: false)
            }
            var progress = try UserProgress(row: row)

            let oldLevel    = progress.currentLevel
            progress.totalPoints   += points
            progress.totalAttempts += 1
            if wasCorrect { progress.totalCorrect += 1 }

            let newLevel = Self.levelForPoints(progress.totalPoints)
            progress.currentLevel = newLevel
            progress.lastTrainedAt = Date()

            try database.execute(sql: """
                UPDATE user_progress
                SET total_points = ?, current_level = ?,
                    total_attempts = ?, total_correct = ?, last_trained_at = ?
                WHERE id = 1
            """, arguments: [
                progress.totalPoints,
                progress.currentLevel,
                progress.totalAttempts,
                progress.totalCorrect,
                progress.lastTrainedAt?.timeIntervalSince1970
            ])

            // Check for new badges
            let (badgeCode, badgeTitle, badgeEmoji) = try self.checkBadges(
                database, progress: progress, wordEntryId: wordEntryId)

            return AwardResult(
                totalPoints:    progress.totalPoints,
                currentLevel:   progress.currentLevel,
                leveledUp:      newLevel > oldLevel,
                newBadgeCode:   badgeCode,
                newBadgeTitle:  badgeTitle,
                newBadgeEmoji:  badgeEmoji
            )
        }
    }

    // MARK: - Refresh streak

    // MARK: - Activation date

    func setActivationDate(_ date: Date?) async throws {
        try await db.write { database in
            try database.execute(sql: """
                UPDATE user_progress SET activated_at = ? WHERE id = 1
            """, arguments: [date?.timeIntervalSince1970])
        }
    }

    func refreshStreak() async throws {
        try await db.write { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM user_progress WHERE id = 1") else { return }
            var progress = try UserProgress(row: row)

            let today     = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

            guard let lastTrained = progress.lastTrainedAt else {
                progress.currentStreak = 0
                try database.execute(sql:
                    "UPDATE user_progress SET current_streak = 0 WHERE id = 1")
                return
            }

            let lastDay = Calendar.current.startOfDay(for: lastTrained)
            if lastDay == today {
                return // already trained today — streak unchanged
            } else if lastDay == yesterday {
                // Trained yesterday — streak continues
            } else {
                // Gap — reset streak
                progress.currentStreak = 0
                try database.execute(sql:
                    "UPDATE user_progress SET current_streak = 0 WHERE id = 1")
            }
        }
    }

    // MARK: - Home stats

    func getHomeStats() async throws -> HomeStats {
        try await db.read { database in
            guard let row = try Row.fetchOne(database,
                sql: "SELECT * FROM user_progress WHERE id = 1") else {
                return HomeStats(
                    totalPoints: 0, currentLevel: 1, currentStreak: 0,
                    longestStreak: 0,
                    totalSessions: 0, totalCorrect: 0, totalAttempts: 0,
                    badgesEarned: 0, totalBadges: 0, familyMembers: 0,
                    totalRecordings: 0, wordsLearned: 0, overallAccuracy: 0,
                    pointsToNextLevel: 100, pointsForCurrentLevel: 0, pointsForNextLevel: 100)
            }
            let progress = try UserProgress(row: row)

            let badgesEarned = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM user_badge") ?? 0
            let totalBadges  = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM badge") ?? 0
            let familyMembers = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM family_member") ?? 0
            let totalRecordings = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM recording WHERE is_approved = 1") ?? 0
            let wordsLearned = try Int.fetchOne(database, sql: """
                SELECT COUNT(DISTINCT word_entry_id) FROM session_word WHERE rating >= 2
            """) ?? 0
            let totalSessions = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM training_session WHERE completed_at IS NOT NULL") ?? 0

            let accuracy = progress.totalAttempts > 0
                ? Double(progress.totalCorrect) / Double(progress.totalAttempts) * 100 : 0

            let level      = progress.currentLevel
            let thresholds = Self.levelThresholds
            let curThresh  = thresholds[safe: level - 1] ?? 0
            let nxtThresh  = thresholds[safe: level]     ?? curThresh + 100

            return HomeStats(
                totalPoints:          progress.totalPoints,
                currentLevel:         progress.currentLevel,
                currentStreak:        progress.currentStreak,
                longestStreak:        progress.longestStreak,
                totalSessions:        totalSessions,
                totalCorrect:         progress.totalCorrect,
                totalAttempts:        progress.totalAttempts,
                badgesEarned:         badgesEarned,
                totalBadges:          totalBadges,
                familyMembers:        familyMembers,
                totalRecordings:      totalRecordings,
                wordsLearned:         wordsLearned,
                overallAccuracy:      accuracy,
                pointsToNextLevel:    max(0, nxtThresh - progress.totalPoints),
                pointsForCurrentLevel: curThresh,
                pointsForNextLevel:   nxtThresh
            )
        }
    }

    // MARK: - Private helpers

    private static func levelForPoints(_ points: Int) -> Int {
        var level = 1
        for (i, threshold) in levelThresholds.enumerated() where points >= threshold {
            level = i + 1
        }
        return min(level, levelThresholds.count)
    }

    /// Returns (code, title, emoji) of a newly earned badge, or (nil, nil, nil).
    private func checkBadges(
        _ database: Database,
        progress: UserProgress,
        wordEntryId: Int
    ) throws -> (String?, String?, String?) {

        let existing = Set(
            (try Row.fetchAll(database, sql: "SELECT badge_id FROM user_badge"))
                .map { $0["badge_id"] as Int }
        )
        let allBadges = try Row.fetchAll(database,
            sql: "SELECT * FROM badge ORDER BY sort_order")

        for row in allBadges {
            let badge = try AppBadge(row: row)
            guard !existing.contains(badge.id) else { continue }

            let earn = try shouldEarn(badge: badge, database: database, progress: progress)
            if earn {
                try database.execute(sql: """
                    INSERT INTO user_badge (badge_id, earned_at) VALUES (?, ?)
                """, arguments: [badge.id, Date().timeIntervalSince1970])
                return (badge.code, badge.title, badge.emoji)
            }
        }
        return (nil, nil, nil)
    }

    private func shouldEarn(
        badge: AppBadge, database: Database, progress: UserProgress
    ) throws -> Bool {
        switch badge.code {
        case "first_session":
            return progress.totalSessions >= 1
        case "streak_3":
            return progress.currentStreak >= 3
        case "streak_7":
            return progress.currentStreak >= 7
        case "streak_30":
            return progress.currentStreak >= 30
        case "ling6_first":
            let c = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM ling6_session") ?? 0
            return c >= 1
        case "ling6_perfect":
            let c = try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM ling6_session s
                WHERE (SELECT COUNT(*) FROM ling6_attempt a
                       WHERE a.session_id = s.id AND a.is_detected = 1) = 6
            """) ?? 0
            return c >= 1
        case "words_10":  return progress.totalCorrect >= 10
        case "words_50":  return progress.totalCorrect >= 50
        case "words_100": return progress.totalCorrect >= 100
        case "family_1":
            let c = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM family_member") ?? 0
            return c >= 1
        case "recordings_10":
            let c = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM recording") ?? 0
            return c >= 10
        case "milestone_first":
            let c = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM milestone_entry") ?? 0
            return c >= 1
        default:
            return false
        }
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
