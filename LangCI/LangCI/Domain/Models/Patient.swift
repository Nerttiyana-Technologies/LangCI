// Patient.swift
// LangCI — Patient entity for clinical sound detection tests
//
// Audiologists see multiple patients. Each patient can have many sessions
// over time, enabling longitudinal progress tracking ("how is Suresh's
// /sh/ detection improving over the last 6 months?").
//
// Two patients may share a first name, so `identifier` disambiguates them.
// It's free-text — the audiologist can put DOB, phone last-4, CI brand,
// or any note that makes this patient unique in their clinic.

import Foundation

struct Patient: Identifiable, Codable, Equatable {
    var id: Int
    var name: String                // Primary display name: "Suresh S"
    var identifier: String?         // Disambiguator: DOB, phone, "Age 42", etc.
    var notes: String?              // Free-form clinical notes
    var createdAt: Date
    var updatedAt: Date

    /// Combined display for UI — shows both fields when identifier is present
    /// Example: "Suresh S  •  12-Mar-1990" or just "Suresh S"
    var displayName: String {
        if let id = identifier, !id.isEmpty {
            return "\(name)  •  \(id)"
        }
        return name
    }

    /// Short display for compact rows
    var shortDisplay: String {
        if let id = identifier, !id.isEmpty {
            return "\(name) (\(id))"
        }
        return name
    }
}
