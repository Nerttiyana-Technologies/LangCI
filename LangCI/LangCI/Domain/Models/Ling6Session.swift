//
//  Ling6Session.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct Ling6Session: Identifiable, Codable {
    var id: Int
    var testedAt: Date = Date()
    var distanceCm: Int = 100 // 1 metre standard
    
    // Enum (Requires ProcessorProgram to be defined)
    var programUsed: ProcessorProgram = .everyday
    var notes: String?

    // Navigation
    var attempts: [Ling6Attempt] = []

    // Computed Helpers
    var detectedCount: Int {
        attempts.filter { $0.isDetected }.count
    }

    var totalSounds: Int {
        attempts.count
    }

    var allDetected: Bool {
        totalSounds == 6 && detectedCount == 6
    }
}

enum ProcessorProgram: Int, Codable {
    case everyday = 0   // default everyday map
    case noise = 1      // SmartSound iQ noise reduction
    case music = 2      // optimised for music
    case focus = 3      // beam-forming / directionality
    case telecoil = 4    // T-coil / loop system
    case custom1 = 5    // audiologist custom program 1
    case custom2 = 6    // audiologist custom program 2
}
