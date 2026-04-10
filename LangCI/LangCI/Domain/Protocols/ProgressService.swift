//
//  ProgressService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol ProgressService {
    func getProgress() async throws -> UserProgress
    func getAllBadges() async throws -> [BadgeDto]
    func getEarnedBadges() async throws -> [BadgeDto]

    /// Called by TrainingService after each answer
    func addPoints(_ points: Int, wasCorrect: Bool, wordEntryId: Int) async throws -> AwardResult

    /// Called once on startup to maintain day-streak
    func refreshStreak() async throws

    /// Home page stats
    func getHomeStats() async throws -> HomeStats

    /// Persist / clear the cochlear implant activation date (Day 0 marker).
    func setActivationDate(_ date: Date?) async throws
}


struct BadgeDto: Identifiable, Codable {
    var id: Int
    var code: String = ""
    var title: String = ""
    var description: String = ""
    var emoji: String = "🏅"
    var isEarned: Bool
    var earnedAt: Date?

}

struct AwardResult: Codable {
    var totalPoints: Int
    var currentLevel: Int
    var leveledUp: Bool
    var newBadgeCode: String?
    var newBadgeTitle: String?
    var newBadgeEmoji: String?

    enum CodingKeys: String, CodingKey {
        case totalPoints = "TotalPoints"
        case currentLevel = "CurrentLevel"
        case leveledUp = "LeveledUp"
        case newBadgeCode = "NewBadgeCode"
        case newBadgeTitle = "NewBadgeTitle"
        case newBadgeEmoji = "NewBadgeEmoji"
    }
}

struct HomeStats: Codable {
    var totalPoints: Int
    var currentLevel: Int
    var currentStreak: Int
    var longestStreak: Int = 0
    var totalSessions: Int
    var totalCorrect: Int
    var totalAttempts: Int
    var badgesEarned: Int
    var totalBadges: Int
    var familyMembers: Int
    var totalRecordings: Int
    var wordsLearned: Int
    var overallAccuracy: Double
    var pointsToNextLevel: Int
    var pointsForCurrentLevel: Int
    var pointsForNextLevel: Int

    enum CodingKeys: String, CodingKey {
        case totalPoints = "TotalPoints"
        case currentLevel = "CurrentLevel"
        case currentStreak = "CurrentStreak"
        case longestStreak = "LongestStreak"
        case totalSessions = "TotalSessions"
        case totalCorrect = "TotalCorrect"
        case totalAttempts = "TotalAttempts"
        case badgesEarned = "BadgesEarned"
        case totalBadges = "TotalBadges"
        case familyMembers = "FamilyMembers"
        case totalRecordings = "TotalRecordings"
        case wordsLearned = "WordsLearned"
        case overallAccuracy = "OverallAccuracy"
        case pointsToNextLevel = "PointsToNextLevel"
        case pointsForCurrentLevel = "PointsForCurrentLevel"
        case pointsForNextLevel = "PointsForNextLevel"
    }
}
