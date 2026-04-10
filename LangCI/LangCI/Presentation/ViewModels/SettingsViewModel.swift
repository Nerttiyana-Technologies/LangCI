//
//  SettingsViewModel.swift
//  LangCI
//
//  Extracted from SettingsViewController.swift on 09/04/26 so the view
//  controller stays focused on UIKit wiring while data/state lives here.
//

import Foundation

final class SettingsViewModel {

    // MARK: - Services

    /// Exposed so the view controller can call language/dialect lookups
    /// without reaching into ServiceLocator itself.
    let languageService: LanguageService = ServiceLocator.shared.languageService

    private let familyMemberService: FamilyMemberService = ServiceLocator.shared.familyMemberService
    private let milestoneService: MilestoneService = ServiceLocator.shared.milestoneService

    // MARK: - State

    var selectedLanguageId: Int = UserDefaults.standard.integer(forKey: "selectedLanguageId") != 0
        ? UserDefaults.standard.integer(forKey: "selectedLanguageId")
        : 1
    var selectedLanguageName: String = "English"

    var selectedDialectId: Int = UserDefaults.standard.integer(forKey: "selectedDialectId") != 0
        ? UserDefaults.standard.integer(forKey: "selectedDialectId")
        : 1
    var selectedDialectName: String = "Standard"

    var defaultProgramRawValue: Int = UserDefaults.standard.integer(forKey: "defaultProcessorProgram") != 0
        ? UserDefaults.standard.integer(forKey: "defaultProcessorProgram")
        : 0
    var defaultProgramName: String = "Everyday"

    var hearingAgeLabel: String = "Not set"
    var activationDateLabel: String = "Not set"
    var currentActivationDate: Date?

    var familyMembers: [FamilyMember] = []
    var milestones: [MilestoneEntry] = []

    /// Convenience for the Settings list — total number of saved milestones
    /// (auto-detected + manual). Updated by `loadData()`.
    var milestoneCount: Int { milestones.count }

    // MARK: - Data Loading

    func loadData() async throws {
        // Cheap idempotent scan so newly-eligible firsts get a milestone
        // entry before we render the Settings count / Milestones screen.
        try? await milestoneService.autoDetectFirsts()
        try? await milestoneService.autoCheck()

        async let familiesResult   = familyMemberService.getAllMembers()
        async let milestonesResult = milestoneService.getAll()
        async let activationResult = milestoneService.getActivation()

        self.familyMembers   = try await familiesResult
        self.milestones      = try await milestonesResult
        let activation       = try await activationResult
        self.hearingAgeLabel = milestoneService.getHearingAgeLabel(activation)
        self.currentActivationDate = activation?.achievedAt
        if let date = activation?.achievedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            self.activationDateLabel = formatter.string(from: date)
        } else {
            self.activationDateLabel = "Not set"
        }
    }

    // MARK: - Activation date

    func setActivationDate(_ date: Date) async throws {
        let existing = try await milestoneService.getActivation()
        var entry = existing ?? MilestoneEntry(
            id: 0,
            type: .activation,
            achievedAt: date,
            accuracyAtMilestone: nil,
            description: "CI Activation",
            notes: nil,
            emoji: "👂"
        )
        entry.achievedAt = date
        _ = try await milestoneService.save(entry)
        // Keep ProgressService mirror (used by cached activation lookups) in sync
        try? await ServiceLocator.shared.progressService.setActivationDate(date)
        try await loadData()
    }

    func clearActivationDate() async throws {
        if let existing = try await milestoneService.getActivation() {
            try await milestoneService.delete(id: existing.id)
        }
        try? await ServiceLocator.shared.progressService.setActivationDate(nil)
        try await loadData()
    }
}
