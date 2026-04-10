//
//  Ling6Service.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol Ling6Service {
    func startSession(distanceCm: Int, program: ProcessorProgram) async throws -> Ling6Session
    
    func recordAttempt(sessionId: Int, sound: String, isDetected: Bool, isRecognised: Bool) async throws
    
    func getRecentSessions(count: Int) async throws -> [Ling6Session]
    
    func getStats() async throws -> Ling6StatsDto
    
    func isDoneToday() async throws -> Bool
}

struct Ling6StatsDto: Codable {
    var totalSessions: Int
    var avgDetectionRate: Double   // 0-100
    var avgRecognitionRate: Double // 0-100
    var currentStreak: Int         // consecutive days tested
    var testedToday: Bool
    var perSoundAccuracy: [Ling6SoundAccuracy] = []

}

struct Ling6SoundAccuracy: Codable {
    var sound: String = ""       // ah, ee, oo, sh, s, m
    var ipaSymbol: String = ""
    var freqHz: Int              // representative frequency
    var detectionPct: Double
    var recognitionPct: Double
    var attempts: Int

}
