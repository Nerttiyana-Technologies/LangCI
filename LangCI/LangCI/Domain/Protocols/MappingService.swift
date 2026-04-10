//
//  MappingService.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

protocol MappingService {
    func saveSession(_ session: MappingSession) async throws -> MappingSession
    
    func getAllSessions() async throws -> [MappingSession]
    
    func getLatestSession() async throws -> MappingSession?
    
    func deleteSession(id: Int) async throws
    
    /// Returns 22 ElectrodeLevel objects pre-populated with defaults.
    /// Call this when starting a new mapping session.
    func createDefaultElectrodeLevels() -> [ElectrodeLevel]
}
