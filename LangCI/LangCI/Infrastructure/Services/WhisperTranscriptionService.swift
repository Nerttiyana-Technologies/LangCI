// WhisperTranscriptionService.swift
// LangCI
//
// Post-session speech-to-text using OpenAI's Whisper API.
// Used as a fallback when Apple's SFSpeechRecognizer doesn't support
// the user's language (e.g. Tamil). After a reading session ends,
// the recorded audio file is sent to Whisper for transcription,
// and the accurate word count / WPM is computed from the result.
//
// API docs: https://platform.openai.com/docs/api-reference/audio/createTranscription

import Foundation

// MARK: - Result

struct WhisperResult {
    let text: String
    let wordCount: Int
    let language: String?
}

// MARK: - Service

final class WhisperTranscriptionService {

    static let shared = WhisperTranscriptionService()

    // MARK: - API key management

    private static let apiKeyKey = "whisper_api_key"

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: Self.apiKeyKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.apiKeyKey) }
    }

    var hasAPIKey: Bool { !(apiKey ?? "").isEmpty }

    // MARK: - Transcription

    /// Transcribes an audio file using OpenAI Whisper.
    /// - Parameters:
    ///   - fileURL: Local URL to the WAV/M4A audio file.
    ///   - language: ISO-639-1 code (e.g. "ta" for Tamil, "en" for English).
    ///              If nil, Whisper auto-detects.
    ///   - prompt: Optional context hint for Whisper to improve accuracy.
    /// - Returns: A `WhisperResult` with the transcribed text and word count.
    func transcribe(fileURL: URL, language: String? = nil, prompt: String? = nil) async throws -> WhisperResult {
        guard let key = apiKey, !key.isEmpty else {
            throw WhisperError.noAPIKey
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw WhisperError.fileNotFound(fileURL.path)
        }

        // Build multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // "model" field
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")

        // "language" field (optional — helps accuracy)
        if let lang = language {
            body.appendMultipart(boundary: boundary, name: "language", value: lang)
        }

        // "response_format" — use verbose_json so we get word-level info
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")

        // "prompt" — context hint to improve accuracy
        if let prompt = prompt, !prompt.isEmpty {
            body.appendMultipart(boundary: boundary, name: "prompt", value: prompt)
        }

        // "temperature" — 0 for most deterministic/accurate transcription
        body.appendMultipart(boundary: boundary, name: "temperature", value: "0")

        // Audio file
        let audioData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mime = filename.hasSuffix(".wav") ? "audio/wav" : "audio/mp4"
        body.appendMultipartFile(boundary: boundary, name: "file",
                                  filename: filename, mimeType: mime, data: audioData)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let fileSizeKB = audioData.count / 1024
        let fileSizeMB = Double(audioData.count) / (1024 * 1024)
        print("[Whisper] Sending \(fileSizeKB)KB (\(String(format: "%.1f", fileSizeMB))MB) audio, lang=\(language ?? "auto"), file=\(filename)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("[Whisper] API error \(http.statusCode): \(body)")
            if http.statusCode == 401 {
                throw WhisperError.invalidAPIKey
            }
            if http.statusCode == 429 {
                throw WhisperError.rateLimited
            }
            throw WhisperError.apiError(statusCode: http.statusCode, message: body)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = json?["text"] as? String ?? ""
        let detectedLang = json?["language"] as? String

        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let wordCount = words.count

        print("[Whisper] Transcribed \(wordCount) words, lang=\(detectedLang ?? "?"), text=\"\(text.prefix(100))\"")

        return WhisperResult(text: text, wordCount: wordCount, language: detectedLang)
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case fileNotFound(String)
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No OpenAI API key configured. Add one in Settings to enable Tamil word counting."
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your key in Settings."
        case .rateLimited:
            return "OpenAI usage limit reached. Increase your spending cap at platform.openai.com → Settings → Limits."
        case .fileNotFound(let path):
            return "Audio file not found at \(path)."
        case .invalidResponse:
            return "Invalid response from Whisper API."
        case .apiError(let code, let msg):
            return "Whisper API error (\(code)): \(msg)"
        }
    }
}

// MARK: - Data helpers for multipart form

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(boundary: String, name: String,
                                       filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
