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
        // Everything here runs before the first frame is drawn.
        // The splash screen covers the window so the user sees a
        // branded gradient instead of a blank/frozen screen.

        // Bootstrap database + services (runs migrations on first launch)
        _ = ServiceLocator.shared

        // Prime the AVTAudioPlayer's noise bed from saved preferences
        AVTAudioPlayer.shared.refreshNoiseBed()

        // Reschedule practice reminders
        PracticeReminderService.shared.rescheduleFromPreferences()

        // Fire-and-forget milestone checks (truly background, not needed at launch)
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
        window.overrideUserInterfaceStyle = ThemeManager.shared.current.uiStyle

        // Build the full tab bar (all 8 tabs). By this point ServiceLocator
        // is already initialized, so data loading in viewWillAppear won't block.
        let tabBar = MainTabBarController()
        window.rootViewController = tabBar
        window.makeKeyAndVisible()
        self.window = window

        // Splash covers everything until the app is fully ready.
        let splash = SplashView(frame: window.bounds)
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(splash)

        // Fade out after layout settles — app is fully interactive underneath.
        splash.dismissAnimated(delay: 1.0, duration: 0.5)
    }
}
