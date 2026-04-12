// EnvironmentalSoundService.swift
// LangCI — Environmental Sound Training service protocol

import Foundation

protocol EnvironmentalSoundService {

    // MARK: - Sound Progress
    func getAllProgress() async throws -> [EnvironmentalSoundProgress]
    func getProgress(for soundId: String) async throws -> EnvironmentalSoundProgress?
    func updateProgress(soundId: String, environment: String,
                        level: EnvironmentalListeningLevel,
                        correct: Int, total: Int) async throws -> EnvironmentalSoundProgress

    // MARK: - Sessions
    func saveSession(_ session: EnvironmentalSoundSession) async throws -> EnvironmentalSoundSession
    func getRecentSessions(count: Int) async throws -> [EnvironmentalSoundSession]

    // MARK: - Stats
    func getOverallAccuracy() async throws -> Double
    func getTotalSessions() async throws -> Int

    // MARK: - Adaptive progression
    func checkAdvancement(soundId: String) async throws -> EnvironmentalListeningLevel?

    // MARK: - Custom Sounds
    func getAllCustomSounds() async throws -> [CustomEnvironmentalSound]
    func addCustomSound(_ sound: CustomEnvironmentalSound) async throws -> CustomEnvironmentalSound
    func updateCustomSound(_ sound: CustomEnvironmentalSound) async throws
    func deleteCustomSound(soundId: String) async throws

    // MARK: - Sound Edit Overrides (edits to built-in sounds)
    func getAllOverrides() async throws -> [SoundEditOverride]
    func getOverride(for soundId: String) async throws -> SoundEditOverride?
    func saveOverride(_ override: SoundEditOverride) async throws
    func deleteOverride(soundId: String) async throws

    // MARK: - Weekly Packs
    func getPackProgress() async throws -> [WeeklyPackProgress]
    func getPackProgress(for packId: String) async throws -> WeeklyPackProgress?
    func unlockPack(_ packId: String) async throws
    func markPackCompleted(_ packId: String) async throws
    func updatePracticedSounds(packId: String, soundIds: [String]) async throws
    func resetPackProgress(_ packId: String) async throws
}
