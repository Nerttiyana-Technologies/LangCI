// SoundTherapyService.swift
// LangCI — Sound Therapy service protocol

import Foundation

protocol SoundTherapyService {

    // MARK: - Sound Progress
    func getAllProgress() async throws -> [SoundProgress]
    func getProgress(for sound: String) async throws -> SoundProgress?
    func unlockSound(_ sound: String, category: String) async throws -> SoundProgress
    func updateProgress(sound: String, level: SoundExerciseLevel,
                        voiceGender: VoiceGender,
                        correct: Int, total: Int) async throws -> SoundProgress

    // MARK: - Sessions
    func saveSession(_ session: SoundTherapySession) async throws -> SoundTherapySession
    func getRecentSessions(count: Int) async throws -> [SoundTherapySession]
    func getSessionsForSound(_ sound: String) async throws -> [SoundTherapySession]

    // MARK: - Stats
    func getHomeStats() async throws -> SoundTherapyHomeStats

    // MARK: - Adaptive progression
    /// Check if a sound should advance to the next level based on accuracy thresholds.
    /// Returns the new level if advancement is recommended, nil otherwise.
    func checkAdvancement(sound: String) async throws -> SoundExerciseLevel?

    /// Auto-unlock next sounds based on mastery of current ones
    func autoUnlockSounds() async throws -> [String]
}
