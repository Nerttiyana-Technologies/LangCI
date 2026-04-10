// RecordingService.swift
// LangCI

import Foundation

protocol RecordingService {
    // ── Playback ────────────────────────────────────────────────────────────────
    func playRecording(path: String) async throws

    // ── Recording ───────────────────────────────────────────────────────────────
    /// Begin recording audio. Call stopRecording() to finalise.
    func startRecording() async throws

    /// Stop and persist. Returns the saved Recording (id assigned by DB).
    func stopRecording(wordEntryId: Int, dialectId: Int, familyMemberId: Int) async throws -> Recording

    // ── Fetch ────────────────────────────────────────────────────────────────────
    func getRecordings(for wordEntryId: Int) async throws -> [Recording]
    func getRecentRecordings(count: Int) async throws -> [Recording]
    func getRecordingCount(for familyMemberId: Int) async throws -> Int

    // ── Manage ──────────────────────────────────────────────────────────────────
    func deleteRecording(id: Int) async throws

    // ── Audio analysis ──────────────────────────────────────────────────────────
    /// Zero-Crossing-Rate estimate of fundamental frequency for a WAV file.
    func estimateFrequency(filePath: String) -> Double?
}
