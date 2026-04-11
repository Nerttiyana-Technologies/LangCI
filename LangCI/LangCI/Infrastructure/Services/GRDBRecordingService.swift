// GRDBRecordingService.swift
// LangCI

import Foundation
import AVFoundation
import GRDB

final class GRDBRecordingService: NSObject, RecordingService {

    private let db: DatabaseQueue
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var activeRecordingURL: URL?

    init(db: DatabaseQueue) { self.db = db }

    // MARK: - Playback

    func playRecording(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw LangCIError.notFound
        }
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    // MARK: - Recording

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()

        // Request microphone permission before configuring the audio session.
        // Without this, AVAudioRecorder initialisation crashes on first launch
        // because the user has not yet granted microphone access.
        let granted = await withCheckedContinuation { continuation in
            session.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard granted else {
            throw NSError(
                domain: "com.sapthagiri.langci",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Microphone access is required to record. Please enable it in Settings → Privacy & Security → Microphone."])
        }

        try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try session.setActive(true)

        let dir = try recordingsDirectory()
        let url = dir.appendingPathComponent("\(UUID().uuidString).wav")
        activeRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey:             Int(kAudioFormatLinearPCM),
            AVSampleRateKey:           44_100,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false
        ]
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
    }

    func stopRecording(wordEntryId: Int, dialectId: Int, familyMemberId: Int) async throws -> Recording {
        guard let recorder = audioRecorder,
              let url = activeRecordingURL else {
            throw LangCIError.invalidData
        }
        recorder.stop()
        let duration = recorder.currentTime
        audioRecorder = nil

        let freq = estimateFrequency(filePath: url.path)

        return try await db.write { database -> Recording in
            // Guard against FK violations on recording.dialect_id. If the
            // caller didn't pick a dialect (callers currently pass 0), fall
            // back to the family member's own preferred_dialect_id, which
            // is guaranteed valid because GRDBFamilyMemberService.saveMember
            // validates it on insert. As a last resort, fall back to any
            // active dialect.
            let resolvedDialectId = try Self.resolveRecordingDialectId(
                requestedId: dialectId,
                familyMemberId: familyMemberId,
                db: database)

            try database.execute(sql: """
                INSERT INTO recording
                    (word_entry_id, dialect_id, family_member_id, file_path, format,
                     duration_seconds, peak_amplitude, average_frequency_hz,
                     is_approved, recorded_at)
                VALUES (?, ?, ?, ?, 'wav', ?, 0.0, ?, 1, ?)
            """, arguments: [
                wordEntryId,
                resolvedDialectId,
                familyMemberId,
                url.path,
                duration,
                freq,
                Date().timeIntervalSince1970
            ])
            let rowId = Int(database.lastInsertedRowID)
            return Recording(
                id:                  rowId,
                wordEntryId:         wordEntryId,
                dialectId:           resolvedDialectId,
                familyMemberId:      familyMemberId,
                filePath:            url.path,
                format:              "wav",
                durationSeconds:     duration,
                peakAmplitude:       0.0,
                averageFrequencyHz:  freq,
                isApproved:          true,
                recordedAt:          Date()
            )
        }
    }

    /// Returns a dialect id that is guaranteed to satisfy the FK into
    /// `dialect(id)`. Resolution order: (1) the requested id, if it points
    /// at a real row; (2) the family member's own preferred dialect; (3)
    /// the first active English dialect; (4) any active dialect. Throws
    /// only if the dialect table is completely empty, which should never
    /// happen post-v4 migration.
    private static func resolveRecordingDialectId(
        requestedId: Int, familyMemberId: Int, db database: Database
    ) throws -> Int {
        if requestedId > 0 {
            let exists = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM dialect WHERE id = ?",
                arguments: [requestedId]) ?? 0
            if exists > 0 { return requestedId }
        }
        if let memberDialectId = try Int.fetchOne(database, sql: """
            SELECT preferred_dialect_id FROM family_member WHERE id = ?
        """, arguments: [familyMemberId]) {
            let exists = try Int.fetchOne(database,
                sql: "SELECT COUNT(*) FROM dialect WHERE id = ?",
                arguments: [memberDialectId]) ?? 0
            if exists > 0 { return memberDialectId }
        }
        if let enDialectId = try Int.fetchOne(database, sql: """
            SELECT d.id FROM dialect d
            JOIN language l ON l.id = d.language_id
            WHERE l.code = 'en' AND d.is_active = 1
            ORDER BY d.id LIMIT 1
        """) {
            return enDialectId
        }
        if let anyDialectId = try Int.fetchOne(database, sql: """
            SELECT id FROM dialect WHERE is_active = 1
            ORDER BY id LIMIT 1
        """) {
            return anyDialectId
        }
        throw NSError(
            domain: "LangCI.RecordingService",
            code: 19,
            userInfo: [NSLocalizedDescriptionKey:
                "No dialects available to assign to this recording."]
        )
    }

    // MARK: - Fetch

    func getRecordings(for wordEntryId: Int) async throws -> [Recording] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM recording WHERE word_entry_id = ? ORDER BY recorded_at DESC
            """, arguments: [wordEntryId])
            return try rows.map { try Recording(row: $0) }
        }
    }

    func getRecentRecordings(count: Int) async throws -> [Recording] {
        try await db.read { database in
            let rows = try Row.fetchAll(database, sql: """
                SELECT * FROM recording ORDER BY recorded_at DESC LIMIT ?
            """, arguments: [count])
            return try rows.map { try Recording(row: $0) }
        }
    }

    func getRecordingCount(for familyMemberId: Int) async throws -> Int {
        try await db.read { database in
            try Int.fetchOne(database, sql: """
                SELECT COUNT(*) FROM recording WHERE family_member_id = ?
            """, arguments: [familyMemberId]) ?? 0
        }
    }

    func deleteRecording(id: Int) async throws {
        // Remove file first
        let filePath: String? = try? await db.read { database in
            let row = try Row.fetchOne(database,
                sql: "SELECT file_path FROM recording WHERE id = ?",
                arguments: [id])
            return row?["file_path"] as String?
        }
        if let path = filePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try await db.write { database in
            try database.execute(sql:
                "DELETE FROM recording WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Frequency estimation (ZCR)

    func estimateFrequency(filePath: String) -> Double? {
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: filePath)),
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: file.fileFormat.sampleRate,
                channels: 1,
                interleaved: false),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }

        try? file.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        let frameCount = Int(buffer.frameLength)
        let sampleRate = file.fileFormat.sampleRate

        // Zero-Crossing Rate
        var crossings = 0
        for i in 1 ..< frameCount {
            if (channelData[i - 1] >= 0) != (channelData[i] >= 0) {
                crossings += 1
            }
        }
        guard frameCount > 0 else { return nil }
        let duration  = Double(frameCount) / sampleRate
        return Double(crossings) / (2.0 * duration)
    }

    // MARK: - Private helpers

    private func recordingsDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let dir = docs.appendingPathComponent("Recordings")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }
}
