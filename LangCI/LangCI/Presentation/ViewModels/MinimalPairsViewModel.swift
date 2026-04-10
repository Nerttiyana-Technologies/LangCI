//
//  MinimalPairsViewModel.swift
//  LangCI
//
//  Extracted from MinimalPairsViewController.swift on 09/04/26 so the
//  view controller stays focused on UIKit wiring while data calls live
//  here.
//

import Foundation

final class MinimalPairsViewModel {

    private let minimalPairsService: MinimalPairsService = ServiceLocator.shared.minimalPairsService

    /// The currently selected learning language. Pulled from `UserDefaults`
    /// the same way `SettingsViewModel` does, with a fallback to `1`.
    var selectedLanguageId: Int {
        let stored = UserDefaults.standard.integer(forKey: "selectedLanguageId")
        return stored != 0 ? stored : 1
    }

    /// Optional dialect filter. `nil` means "any dialect".
    var selectedDialectId: Int? {
        let stored = UserDefaults.standard.integer(forKey: "selectedDialectId")
        return stored != 0 ? stored : nil
    }

    /// Build a session queue of minimal pairs for the current language and
    /// dialect. Returns at most `count` pairs.
    func loadPairs(count: Int) async throws -> [MinimalPairDto] {
        try await minimalPairsService.getPairsForSession(
            languageId: selectedLanguageId,
            dialectId: selectedDialectId,
            count: count
        )
    }

    /// Persist the user's choice for a single round.
    func recordAttempt(
        minimalPairId: Int,
        playedWordEntryId: Int,
        selectedWordEntryId: Int,
        familyMemberId: Int? = nil
    ) async throws -> MinimalPairAttemptResult {
        try await minimalPairsService.recordAttempt(
            minimalPairId: minimalPairId,
            playedWordEntryId: playedWordEntryId,
            selectedWordEntryId: selectedWordEntryId,
            familyMemberId: familyMemberId
        )
    }
}
