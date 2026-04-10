// LangCIApp.swift
// LangCI
//
// UIKit application entry point.
// Replaces the default SwiftUI @main struct.
//
// ⚠️  Xcode setup required (one-time):
//   1. Select the LangCI target → General → "iPhone Deployment Info"
//      Make sure "Main Interface" is blank (delete "Main" if present).
//   2. In Info settings (Build Settings → Info.plist values), ensure
//      there is no "UIMainStoryboardFile" key, or set its value to blank.
//   3. Add GRDB via File → Add Package Dependencies:
//      https://github.com/groue/GRDB.swift  Up to Next Major: 7.0.0

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Bootstrap database + services (runs migrations on first launch)
        _ = ServiceLocator.shared

        // Prime the AVTAudioPlayer's noise bed from saved preferences so
        // that drills start with the correct ambient loop queued up.
        AVTAudioPlayer.shared.refreshNoiseBed()

        // Reschedule practice reminders in case the user upgraded from a
        // build without the feature, or iOS lost pending notifications.
        PracticeReminderService.shared.rescheduleFromPreferences()

        // Fire-and-forget scan for any "first X" milestones the user
        // has already achieved (e.g. when upgrading from an older build
        // that had data but no milestone auto-detection). Also picks up
        // week1/month1 style checks once the activation date is known.
        Task.detached(priority: .utility) {
            try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
            try? await ServiceLocator.shared.milestoneService.autoCheck()
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

// MARK: - SceneDelegate

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        // Apply persisted dark/light theme BEFORE the window becomes
        // visible so there's no flash of the wrong palette.
        window.overrideUserInterfaceStyle = ThemeManager.shared.current.uiStyle
        window.makeKeyAndVisible()
        self.window = window
    }
}
