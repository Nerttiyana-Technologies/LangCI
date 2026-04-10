// AVTService.swift
// LangCI — Auditory Verbal Therapy service protocol

import Foundation

protocol AVTService {

    // MARK: - Targets (assigned by audiologist)
    func getActiveTargets() async throws -> [AVTTarget]
    func getAllTargets() async throws -> [AVTTarget]
    func saveTarget(_ target: AVTTarget) async throws -> AVTTarget
    func deleteTarget(id: Int) async throws
    func setTargetLevel(_ level: ListeningHierarchy, targetId: Int) async throws

    // MARK: - Sessions
    func startSession(targetSound: String, level: ListeningHierarchy) async throws -> AVTSession
    func recordAttempt(sessionId: Int, targetSound: String, presentedSound: String,
                       userResponse: String, isCorrect: Bool,
                       level: ListeningHierarchy) async throws -> AVTAttempt
    func completeSession(id: Int) async throws -> AVTSession
    func getRecentSessions(count: Int) async throws -> [AVTSession]
    func getSessionsForSound(_ sound: String) async throws -> [AVTSession]

    // MARK: - Audiologist Notes
    func saveNote(_ note: AVTAudiologistNote) async throws -> AVTAudiologistNote
    func getNotes() async throws -> [AVTAudiologistNote]
    func getLatestNote() async throws -> AVTAudiologistNote?
    func deleteNote(noteId: Int) async throws

    // MARK: - Progress & Stats
    func getProgress() async throws -> [AVTProgressDto]
    func getHomeStats() async throws -> AVTHomeStats

    // MARK: - Built-in drill content
    func getDrillItems(sound: String, level: ListeningHierarchy) -> [AVTDrillItem]
}

// MARK: - Drill content model

/// One item presented during an AVT drill.
struct AVTDrillItem {
    var sound: String
    var displayText: String         // native script or phoneme to show
    var audioFileName: String       // file in Resources/AVT/
    var distractors: [AVTDistractor]
    var level: ListeningHierarchy
    var correctAnswer: String
}

struct AVTDistractor {
    var text: String
    var audioFileName: String
    var isCorrect: Bool
}
