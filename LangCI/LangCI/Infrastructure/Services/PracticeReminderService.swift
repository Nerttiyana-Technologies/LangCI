// PracticeReminderService.swift
// LangCI — Local notification reminders for daily listening practice.
//
// Two independently-toggleable slots:
//   • Morning  (default 09:00)
//   • Evening  (default 19:30)
//
// Each slot stores its enabled state and an hour/minute in UserDefaults.
// Reminders are delivered via UNCalendarNotificationTrigger with
// `repeats: true` so they fire every day at the user's chosen time.
//
// Call `rescheduleFromPreferences()` at app launch (and whenever the user
// toggles a slot or changes a time in Settings) to sync pending requests
// with the current preferences.

import Foundation
import UserNotifications

final class PracticeReminderService {

    // MARK: - Singleton

    static let shared = PracticeReminderService()
    private init() {}

    // MARK: - Identifiers

    private let morningID = "langci.reminder.morning"
    private let eveningID = "langci.reminder.evening"

    // MARK: - UserDefaults keys

    private enum Keys {
        static let morningEnabled = "reminderMorningEnabled"
        static let morningHour    = "reminderMorningHour"
        static let morningMinute  = "reminderMorningMinute"
        static let eveningEnabled = "reminderEveningEnabled"
        static let eveningHour    = "reminderEveningHour"
        static let eveningMinute  = "reminderEveningMinute"
    }

    // MARK: - Defaults

    private static let defaultMorningHour = 9
    private static let defaultMorningMinute = 0
    private static let defaultEveningHour = 19
    private static let defaultEveningMinute = 30

    // MARK: - Slot model

    struct Slot {
        var enabled: Bool
        var hour: Int
        var minute: Int

        var displayTime: String {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let date = Calendar.current.date(from: comps) ?? Date()
            return fmt.string(from: date)
        }
    }

    // MARK: - Preference accessors

    var morning: Slot {
        get {
            let defaults = UserDefaults.standard
            // First-run defaults
            if defaults.object(forKey: Keys.morningHour) == nil {
                defaults.set(Self.defaultMorningHour, forKey: Keys.morningHour)
                defaults.set(Self.defaultMorningMinute, forKey: Keys.morningMinute)
            }
            return Slot(
                enabled: defaults.bool(forKey: Keys.morningEnabled),
                hour:    defaults.integer(forKey: Keys.morningHour),
                minute:  defaults.integer(forKey: Keys.morningMinute)
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.enabled, forKey: Keys.morningEnabled)
            defaults.set(newValue.hour,    forKey: Keys.morningHour)
            defaults.set(newValue.minute,  forKey: Keys.morningMinute)
        }
    }

    var evening: Slot {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: Keys.eveningHour) == nil {
                defaults.set(Self.defaultEveningHour, forKey: Keys.eveningHour)
                defaults.set(Self.defaultEveningMinute, forKey: Keys.eveningMinute)
            }
            return Slot(
                enabled: defaults.bool(forKey: Keys.eveningEnabled),
                hour:    defaults.integer(forKey: Keys.eveningHour),
                minute:  defaults.integer(forKey: Keys.eveningMinute)
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.enabled, forKey: Keys.eveningEnabled)
            defaults.set(newValue.hour,    forKey: Keys.eveningHour)
            defaults.set(newValue.minute,  forKey: Keys.eveningMinute)
        }
    }

    // MARK: - Authorization

    /// Request notification permission. Call this the first time the user
    /// flips a reminder toggle to ON. Completion is on the main queue.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            #if DEBUG
            if let error { print("⚠️ Reminder auth error: \(error)") }
            #endif
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Check current authorization status (for Settings UI to reflect).
    func checkAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Scheduling

    /// Cancel existing LangCI reminder requests and re-add them based on
    /// the current enabled/time preferences. Safe to call repeatedly.
    func rescheduleFromPreferences() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: [morningID, eveningID]
        )

        // Only schedule if we have authorization. Don't request here —
        // that should come from Settings when the user flips the toggle.
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .authorized
               || settings.authorizationStatus == .provisional else {
                return
            }

            let morning = self.morning
            if morning.enabled {
                self.schedule(
                    id: self.morningID,
                    title: "LangCI practice time",
                    body:  "Ready for your morning listening practice?",
                    hour:  morning.hour,
                    minute: morning.minute
                )
            }

            let evening = self.evening
            if evening.enabled {
                self.schedule(
                    id: self.eveningID,
                    title: "Evening drill",
                    body:  "10 minutes of practice keeps your streak alive.",
                    hour:  evening.hour,
                    minute: evening.minute
                )
            }
        }
    }

    private func schedule(id: String,
                          title: String,
                          body: String,
                          hour: Int,
                          minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.threadIdentifier = "langci.practice"

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: comps, repeats: true
        )

        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error { print("⚠️ Reminder schedule error (\(id)): \(error)") }
            #endif
        }
    }
}
