// Badge.swift
// LangCI

import Foundation

/// Renamed from Badge → AppBadge to avoid collision with UIKit's Badge type (iOS 26+).
struct AppBadge: Identifiable, Codable {
    var id: Int
    var code: String = ""
    var title: String = ""
    var description: String = ""
    var emoji: String = "🏅"
    var sortOrder: Int

    // Navigation equivalent
    var userBadges: [UserBadge] = []
}
