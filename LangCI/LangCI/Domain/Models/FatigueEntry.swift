//
//  FatigueEntry.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct FatigueEntry: Identifiable, Codable {
    var id: Int
    var loggedAt: Date = Date()

    /// 1 = effortless, 5 = exhausting
    var effortLevel: Int = 3

    /// 1 = fresh, 5 = completely fatigued
    var fatigueLevel: Int = 3

    // Enums (Ensure FatigueEnvironment is defined as Codable)
    var environment: FatigueEnvironment
    var programUsed: ProcessorProgram

    /// Hours the processor was worn today
    var hoursWorn: Int = 8

    var notes: String?

}

enum FatigueEnvironment: Int, Codable {
    case quiet = 0
    case homeTV = 1
    case office = 2
    case restaurant = 3
    case outdoors = 4
    case phone = 5
    case shopping = 6
    case transport = 7
}
