// StreakService.swift
// LangCI — Lightweight cache and UX helper around the streak values that
// already live in the GRDB `user_progress` table.
//
// Responsibilities:
//   • Cache the latest (current, longest) streak in UserDefaults so the
//     Home screen can render a badge instantly without an async DB hit
//   • Provide a motivational message for a given streak value
//   • Expose milestone detection for 3 / 7 / 14 / 30 / 60 / 100 day marks
//
// The authoritative source of streak data is still GRDBProgressService;
// this class just mirrors it for instant reads.

import Foundation

final class StreakService {

    // MARK: - Singleton

    static let shared = StreakService()
    private init() {}

    // MARK: - Keys

    private enum Keys {
        static let current = "streak.current"
        static let longest = "streak.longest"
        static let lastMilestone = "streak.lastMilestone"
    }

    // MARK: - Cached state

    var cachedCurrent: Int {
        UserDefaults.standard.integer(forKey: Keys.current)
    }

    var cachedLongest: Int {
        UserDefaults.standard.integer(forKey: Keys.longest)
    }

    /// Update the cached streak values. Called by HomeViewController after
    /// it refreshes HomeStats from GRDBProgressService.
    func updateCache(current: Int, longest: Int) {
        let defaults = UserDefaults.standard
        defaults.set(current, forKey: Keys.current)
        defaults.set(longest, forKey: Keys.longest)
    }

    // MARK: - Milestones

    static let milestones: [Int] = [3, 7, 14, 30, 60, 100, 365]

    /// Returns the highest milestone the user has reached at or below the
    /// given streak (or nil if below 3).
    func currentMilestone(for streak: Int) -> Int? {
        Self.milestones.last(where: { streak >= $0 })
    }

    /// Returns the next milestone above the given streak (or nil if the
    /// user has hit the top one).
    func nextMilestone(above streak: Int) -> Int? {
        Self.milestones.first(where: { $0 > streak })
    }

    /// Has the user just crossed a new milestone since the last time we
    /// checked? Call this after refreshing streak. Returns the milestone
    /// value if this is the first time we've seen it, else nil.
    func consumeNewMilestone(for streak: Int) -> Int? {
        guard let current = currentMilestone(for: streak) else { return nil }
        let last = UserDefaults.standard.integer(forKey: Keys.lastMilestone)
        if current > last {
            UserDefaults.standard.set(current, forKey: Keys.lastMilestone)
            return current
        }
        return nil
    }

    // MARK: - Copy

    /// Short motivational label shown under the streak badge on Home.
    func motivationalLabel(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start a streak today"
        case 1:
            return "Great start — keep going!"
        case 2:
            return "Don't break the chain"
        case 3..<7:
            return "You're on a roll"
        case 7..<14:
            return "One week strong"
        case 14..<30:
            return "Two weeks — building habits"
        case 30..<60:
            return "One month — impressive!"
        case 60..<100:
            return "Two months of dedication"
        case 100..<365:
            return "Triple digits — legendary"
        default:
            return "A full year — remarkable"
        }
    }

    /// Celebratory message shown in a toast/alert when a new milestone
    /// is crossed.
    func milestoneMessage(for milestone: Int) -> String {
        switch milestone {
        case 3:   return "3-day streak! The habit is forming."
        case 7:   return "One full week. That's commitment."
        case 14:  return "Two weeks straight — your brain is rewiring."
        case 30:  return "30 days! You're officially a practice regular."
        case 60:  return "60 days — two months of steady work."
        case 100: return "100 days! Triple digits — incredible."
        case 365: return "365 days. A full year of listening practice."
        default:  return "\(milestone)-day streak!"
        }
    }

    /// SF Symbol name to use for a flame badge intensity at a given streak.
    func flameSymbol(for streak: Int) -> String {
        if streak >= 30 { return "flame.fill" }
        if streak >= 3  { return "flame" }
        return "flame"
    }
}
