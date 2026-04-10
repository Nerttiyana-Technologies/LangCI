//
//  MappingSession.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation
struct MappingSession: Identifiable, Codable {
    var id: Int
    var sessionDate: Date = Date()
    var audiologistName: String = ""
    var clinicName: String = ""
    var notes: String?
    var nextAppointmentDate: Date?

    // Navigation
    var electrodeLevels: [ElectrodeLevel] = []

    // Computed Properties
    var activeElectrodes: Int {
        electrodeLevels.filter { $0.isActive }.count
    }

    var inactiveElectrodes: Int {
        electrodeLevels.filter { !$0.isActive }.count
    }

    var hasNextAppointment: Bool {
        if let nextDate = nextAppointmentDate {
            return nextDate > Date()
        }
        return false
    }

    var daysUntilNext: Int {
        guard let nextDate = nextAppointmentDate else { return -1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: nextDate))
        return components.day ?? -1
    }
}
