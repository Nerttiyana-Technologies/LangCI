//
//  TrainingSession.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct TrainingSession: Identifiable, Codable {
    var id: Int
    var dialectId: Int
    var dialect: Dialect?
    
    // Category code: "body", "food", "slang", "phonetic", or "mixed"
    var categoryCode: String = ""
    
    var startedAt: Date = Date()
    var completedAt: Date?
    
    var totalWords: Int
    var completedWords: Int
    
    var publisherPackId: Int?
    var publisherPack: PublisherPack?
    
    // Enums (Need to be defined as Codable)
    var trainingMode: TrainingMode = .standard
    var noiseEnvironment: NoiseEnvironmentType = .none
    var noiseLevel: Double = 0.3
    var processorProgram: ProcessorProgram = .everyday
    
    // Computed Property
    var isCompleted: Bool {
        completedAt != nil
    }
    
    // Navigation
    var sessionWords: [SessionWord] = []

}

enum TrainingMode: Int, Codable {
    case standard = 0         // normal family voice playback
    case noisyEnvironment = 1 // family voice + background noise
    case minimalPairs = 2     // two-word forced-choice discrimination
}

enum NoiseEnvironmentType: Int, Codable {
    case none = 0
    case cafe = 1   // coffee-shop chatter
    case street = 2 // outdoor traffic & crowd
    case tv = 3     // television speech-in-speech
    case rain = 4   // rain / white noise
    case office = 5 // office hum & keyboard
}
