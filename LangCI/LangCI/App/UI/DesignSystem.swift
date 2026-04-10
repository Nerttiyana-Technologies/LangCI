// DesignSystem.swift
// LangCI — shared colours, typography, and layout constants.

import UIKit

// MARK: - Brand colours

extension UIColor {
    // Tab accent colours
    static let lcBlue   = UIColor(red: 0.27, green: 0.51, blue: 0.97, alpha: 1) // Home
    static let lcGreen  = UIColor(red: 0.13, green: 0.75, blue: 0.37, alpha: 1) // Train
    static let lcOrange = UIColor(red: 0.99, green: 0.55, blue: 0.14, alpha: 1) // Library
    static let lcRed    = UIColor(red: 0.96, green: 0.26, blue: 0.26, alpha: 1) // Record
    static let lcPurple = UIColor(red: 0.60, green: 0.30, blue: 0.90, alpha: 1) // Reports
    static let lcTeal   = UIColor(red: 0.12, green: 0.67, blue: 0.71, alpha: 1) // CI Hub
    static let lcAmber  = UIColor(red: 0.99, green: 0.72, blue: 0.10, alpha: 1) // Fatigue
    static let lcGold   = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1) // Mapping

    // Semantic
    static let lcCard        = UIColor.secondarySystemBackground
    static let lcBackground  = UIColor.systemGroupedBackground
}

// MARK: - Typography helpers

extension UIFont {
    static func lcHeroTitle()    -> UIFont { .systemFont(ofSize: 28, weight: .bold) }
    static func lcHeroSubtitle() -> UIFont { .systemFont(ofSize: 14, weight: .medium) }
    static func lcCardValue()    -> UIFont { .systemFont(ofSize: 22, weight: .bold) }
    static func lcCardLabel()    -> UIFont { .systemFont(ofSize: 11, weight: .medium) }
    static func lcSectionTitle() -> UIFont { .systemFont(ofSize: 13, weight: .semibold) }
    static func lcBodyBold()     -> UIFont { .systemFont(ofSize: 15, weight: .semibold) }
    static func lcBody()         -> UIFont { .systemFont(ofSize: 15, weight: .regular) }
    static func lcCaption()      -> UIFont { .systemFont(ofSize: 12, weight: .regular) }
}

// MARK: - Layout constants

enum LC {
    static let cornerRadius:  CGFloat = 16
    static let cardPadding:   CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let shadowRadius:  CGFloat = 8
    static let shadowOpacity: Float   = 0.10
}

// MARK: - Shadow helper

extension UIView {
    func lcApplyShadow(radius: CGFloat = LC.shadowRadius, opacity: Float = LC.shadowOpacity) {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOffset  = CGSize(width: 0, height: 2)
        layer.shadowRadius  = radius
        layer.shadowOpacity = opacity
        layer.masksToBounds = false
    }
}
