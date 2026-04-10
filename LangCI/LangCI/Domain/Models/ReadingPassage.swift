// ReadingPassage.swift
// LangCI
//
// A passage the user reads aloud. May be bundled (shipped with the app)
// or user-pasted (custom).

import Foundation

enum ReadingCategory: Int, Codable, CaseIterable {
    case news       = 0
    case story      = 1
    case technical  = 2
    case everyday   = 3
    case childrens  = 4

    var label: String {
        switch self {
        case .news:      return "News"
        case .story:     return "Story"
        case .technical: return "Technical"
        case .everyday:  return "Everyday"
        case .childrens: return "Children's"
        }
    }

    var emoji: String {
        switch self {
        case .news:      return "📰"
        case .story:     return "📖"
        case .technical: return "🔬"
        case .everyday:  return "☕️"
        case .childrens: return "🧸"
        }
    }
}

struct ReadingPassage: Identifiable, Codable {
    var id: Int
    var title: String
    var category: ReadingCategory
    /// 1 = easy, 2 = medium, 3 = hard
    var difficulty: Int
    var body: String
    var wordCount: Int
    var isBundled: Bool
    var createdAt: Date

    init(id: Int = 0,
         title: String,
         category: ReadingCategory = .everyday,
         difficulty: Int = 1,
         body: String,
         wordCount: Int = 0,
         isBundled: Bool = false,
         createdAt: Date = Date())
    {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.body = body
        self.wordCount = wordCount == 0
            ? body.split { $0.isWhitespace || $0.isNewline }.count
            : wordCount
        self.isBundled = isBundled
        self.createdAt = createdAt
    }

    var difficultyLabel: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        default: return "Hard"
        }
    }
}
