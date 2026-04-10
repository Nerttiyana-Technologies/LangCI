//
//  FatigueService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol FatigueService {
    func log(_ entry: FatigueEntry) async throws -> FatigueEntry
    
    func getEntries(days: Int) async throws -> [FatigueEntry]
    
    func getStats(days: Int) async throws -> FatigueStatsDto
    
    func deleteEntry(id: Int) async throws
    
    func hasEntryToday() async throws -> Bool
}

struct FatigueStatsDto: Codable {
    var avgEffort: Double
    var avgFatigue: Double
    var totalEntries: Int
    
    // Environment with highest/lowest average fatigue
    var hardestEnv: String = ""
    var easiestEnv: String = ""
    
    var trend: [FatigueTrendPoint] = []
}

struct FatigueTrendPoint: Codable {
    var date: Date
    var effortAvg: Double
    var fatigueAvg: Double
}
