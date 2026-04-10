//
//  ElectrodeLevel.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct ElectrodeLevel: Identifiable, Codable {
    var id: Int
    var mappingSessionId: Int
    var mapingSession: MappingSession?
    var electrodeNumber: Int
    var tLevel: Double
    var cLevel: Double
    var isActive: Bool
    var notes: String?
    
    var frequencyLabel: String {
        switch electrodeNumber {
        case ...3:
            return "250–500 Hz"
        case ...7:
            return "500–1k Hz"
        case ...12:
            return "1–2 kHz"
        case ...17:
            return "2–4 kHz"
        default:
            return "4–8 kHz"
        }
    }
    
}
