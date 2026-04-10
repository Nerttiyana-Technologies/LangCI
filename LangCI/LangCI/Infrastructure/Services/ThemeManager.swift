// ThemeManager.swift
// LangCI — persistent dark/light/system theme preference.
//
// Previously the dark-mode segmented control in Settings called
// `overrideUserInterfaceStyle` directly on the active window but never
// saved the choice, so restarting the app flipped back to system. This
// tiny manager:
//   • Stores the user's preference in UserDefaults (key: "appThemeMode")
//   • Exposes a `current` getter so the settings UI and the scene
//     delegate can read it
//   • Applies the preference to every active window at startup and on
//     every change
//
// Values:
//   0 = system (follow device), 1 = light, 2 = dark

import UIKit

enum AppThemeMode: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2

    /// Index in the Settings UISegmentedControl. The control has only
    /// Light/Dark, so "system" maps to whichever the device is currently
    /// rendering.
    var segmentIndex: Int {
        switch self {
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark ? 1 : 0
        case .light:
            return 0
        case .dark:
            return 1
        }
    }

    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

final class ThemeManager {

    // MARK: Singleton

    static let shared = ThemeManager()
    private init() {}

    // MARK: Storage

    private let key = "appThemeMode"

    /// Current user preference. Writing applies to all active windows
    /// immediately.
    var current: AppThemeMode {
        get {
            let raw = UserDefaults.standard.integer(forKey: key)
            return AppThemeMode(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            applyToAllWindows()
        }
    }

    // MARK: Application

    /// Call from SceneDelegate.scene(_:willConnectTo:options:) so the
    /// saved preference is in effect the moment the first window is
    /// presented.
    func applyToAllWindows() {
        let style = current.uiStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                UIView.transition(
                    with: window, duration: 0.25,
                    options: [.transitionCrossDissolve]
                ) {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}
