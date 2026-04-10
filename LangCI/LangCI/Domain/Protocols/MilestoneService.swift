//
//  MilestoneService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol MilestoneService {
    // MARK: - CRUD

    func getAll() async throws -> [MilestoneEntry]

    func getActivation() async throws -> MilestoneEntry?

    /// Returns the most recent milestone of a given type, if any.
    func getLatest(of type: MilestoneType) async throws -> MilestoneEntry?

    func save(_ entry: MilestoneEntry) async throws -> MilestoneEntry

    func delete(id: Int) async throws

    // MARK: - Auto-detection

    /// Checks app progress data and automatically adds standard
    /// milestone entries (Week 1, Month 1, etc.) if they are due
    /// and don't already exist.
    func autoCheck() async throws

    /// Scans every data source in the app (AVT, reading, confusion,
    /// fatigue, Ling 6, mapping, training) and inserts a matching
    /// "first X" milestone if none has been logged yet. Idempotent —
    /// safe to call after every save. Should be called from the
    /// save paths of the relevant services and on app startup.
    func autoDetectFirsts() async throws

    /// Inserts a singleton milestone of the given type if none
    /// exists. No-op if one is already present. Returns the saved
    /// milestone (either the existing one or the new one).
    @discardableResult
    func markFirstIfMissing(
        _ type: MilestoneType,
        at date: Date,
        accuracy: Double?
    ) async throws -> MilestoneEntry

    // MARK: - Helpers

    func getDaysSinceActivation(_ activation: MilestoneEntry?) -> Int

    func getHearingAgeLabel(_ activation: MilestoneEntry?) -> String
}
