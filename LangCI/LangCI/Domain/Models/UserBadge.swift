// UserBadge.swift
// LangCI

import Foundation

struct UserBadge: Identifiable, Codable {
    var id: Int
    var BadgeId: Int
    var Badge: AppBadge          // property name kept as-is (ported from C# model)
    var EarnedAt: Date
}
