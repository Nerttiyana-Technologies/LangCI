//
//  UserProgress.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct UserProgress: Identifiable, Codable {
    var id: Int
    var totalPoints: Int
    var currentLevel: Int = 1
    var currentStreak: Int // days in a row
    var longestStreak: Int
    var totalSessions: Int
    var totalCorrect: Int
    var totalAttempts: Int
    var lastTrainedAt: Date?

    /// Date the cochlear implant was activated ("switch-on" day).
    /// Used as Day 0 for per-sound progress timelines.
    var activatedAt: Date?

    /// Convenience: whole days elapsed since activation (nil if not set).
    var daysSinceActivation: Int? {
        guard let activatedAt else { return nil }
        return Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: activatedAt),
            to: Calendar.current.startOfDay(for: Date())).day
    }
}
