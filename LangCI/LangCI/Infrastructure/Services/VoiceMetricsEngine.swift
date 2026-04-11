// VoiceMetricsEngine.swift
// LangCI
//
// Real-time voice analysis engine that reports live pitch (Hz), loudness (dB),
// and word count (via on-device speech recognition). Designed for the
// Reading Aloud drill's live gauges.
//
// Architecture:
//   • AVAudioEngine taps the microphone input node for raw PCM buffers
//   • Pitch is estimated via autocorrelation (60–500 Hz range covers all voices)
//   • Loudness is RMS → dBFS conversion
//   • Word count uses SFSpeechRecognizer with on-device recognition (iOS 17+)
//   • Audio is simultaneously written to a file via AVAudioFile so we still
//     have a recording when the drill ends

import AVFoundation
import Speech

// MARK: - Delegate protocol

protocol VoiceMetricsDelegate: AnyObject {
    /// Called ~10× per second on the main thread with the latest metrics.
    func voiceMetrics(
        didUpdate pitch: Double,   // Hz (0 when no voice detected)
        loudness: Double,          // dBFS (typically -60 … 0)
        wordCount: Int,            // cumulative words recognised so far
        wpm: Double                // words per minute based on elapsed time
    )

    /// Called when speech recognition is unavailable and the engine falls back
    /// to syllable-rate estimation. WPM will still be reported but is approximate.
    func voiceMetricsUsingSyllableEstimation()

    /// Called when speech recognition encounters an error or is unavailable
    /// and no fallback is possible. WPM will stay at 0.
    func voiceMetricsRecognitionUnavailable(reason: String)
}

// Default implementations so existing adopters don't break
extension VoiceMetricsDelegate {
    func voiceMetricsUsingSyllableEstimation() {}
    func voiceMetricsRecognitionUnavailable(reason: String) {}
}

// MARK: - Engine

final class VoiceMetricsEngine: NSObject, SFSpeechRecognizerDelegate {

    weak var delegate: VoiceMetricsDelegate?

    // MARK: - Audio engine

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?

    // MARK: - Speech recognition

    private let inputLocale: Locale
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Tracks whether we've already notified the delegate about recognition failure
    private var hasNotifiedRecognitionFailure = false

    /// When true, speech recognition is unavailable and we use syllable-rate
    /// estimation instead to approximate WPM (language-independent).
    private var useSyllableEstimation = false

    // MARK: - Syllable-rate estimator state
    // Counts syllables via energy-envelope peak detection.
    // Each syllable creates a local peak in the RMS envelope.
    // Average syllables-per-word varies by language: English ~1.5, Tamil ~3.2.
    private var syllableCount: Int = 0
    private var syllablesPerWord: Double = 1.5
    private var prevRMS: Float = 0
    private var prevPrevRMS: Float = 0
    private var inVoicedSegment = false       // kept but unused after refactor
    /// Minimum gap between syllable peaks (in audio buffers) to avoid double-counting.
    /// At 16 kHz / 4096 frames ≈ 256 ms per buffer → 2 buffers ≈ 512 ms min gap.
    /// At 48 kHz / 4096 frames ≈ 85 ms per buffer → 3 buffers ≈ 255 ms min gap.
    private var buffersSinceLastOnset: Int = 0
    private let minOnsetGapBuffers = 2

    // MARK: - State

    private var startTime: Date?
    private(set) var wordCount: Int = 0
    private(set) var currentPitch: Double = 0
    private(set) var currentLoudness: Double = -160
    private(set) var currentWPM: Double = 0
    private(set) var recordingURL: URL?

    // Smoothing buffers
    private var pitchBuffer: [Double] = []
    private let pitchBufferSize = 5  // ~0.5 s at 10 Hz update rate

    // MARK: - Init

    init(locale: Locale = .current) {
        // Try the exact locale first, then fall back to language-only,
        // then search Apple's supported locales for a match.
        inputLocale = locale
        let resolved = VoiceMetricsEngine.resolveRecognizer(for: locale)
        speechRecognizer = resolved
        super.init()
        speechRecognizer?.delegate = self
        print("[VoiceMetrics] init requested=\(locale.identifier) resolved=\(resolved?.locale.identifier ?? "nil") available=\(resolved?.isAvailable ?? false)")
        if let r = resolved {
            if #available(iOS 17, *) {
                print("[VoiceMetrics] supportsOnDevice=\(r.supportsOnDeviceRecognition)")
            }
        }
    }

    /// Tries several strategies to find a working SFSpeechRecognizer for the
    /// requested locale. Returns nil only if no match is found at all.
    private static func resolveRecognizer(for locale: Locale) -> SFSpeechRecognizer? {
        // 1. Try exact locale (e.g. "ta-IN")
        if let r = SFSpeechRecognizer(locale: locale) {
            print("[VoiceMetrics] Exact match for \(locale.identifier)")
            return r
        }

        // 2. Try language-only (e.g. "ta")
        let lang = locale.language.languageCode?.identifier ?? locale.identifier.components(separatedBy: "-").first ?? locale.identifier
        let langOnly = Locale(identifier: lang)
        if let r = SFSpeechRecognizer(locale: langOnly) {
            print("[VoiceMetrics] Language-only match for \(lang)")
            return r
        }

        // 3. Search Apple's supported locales for one that shares the language
        let supported = SFSpeechRecognizer.supportedLocales()
        print("[VoiceMetrics] Supported locales containing '\(lang)': \(supported.filter { $0.identifier.hasPrefix(lang) }.map { $0.identifier })")
        for candidate in supported where candidate.identifier.hasPrefix(lang) {
            if let r = SFSpeechRecognizer(locale: candidate) {
                print("[VoiceMetrics] Found supported match: \(candidate.identifier)")
                return r
            }
        }

        // 4. Log all supported locales for debugging
        print("[VoiceMetrics] No recognizer found for \(locale.identifier). All supported: \(supported.map { $0.identifier }.sorted())")
        return nil
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("[VoiceMetrics] availabilityDidChange: \(available)")
    }

    // MARK: - Public API

    /// Starts the audio engine, installs the input tap, begins speech
    /// recognition, and writes the audio to a file at the returned URL.
    /// Call from a non-main thread — this may block briefly on permission
    /// requests.
    func start() async throws -> URL {
        // ---- Microphone permission ----
        let micGranted = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                cont.resume(returning: ok)
            }
        }
        guard micGranted else {
            throw engineError("Microphone access is required. Enable it in Settings → Privacy & Security → Microphone.")
        }

        // ---- Speech recognition permission ----
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw engineError("Speech recognition permission is needed for real-time word counting. Enable it in Settings → Privacy & Security → Speech Recognition.")
        }

        // ---- Audio session ----
        // Use .spokenAudio mode for better speech clarity (AGC, noise reduction).
        // .measurement mode disables all processing which hurts transcription quality.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
        // Prefer 16 kHz — this is Whisper's native sample rate and reduces file
        // size by 3× vs 48 kHz.  iOS may choose a nearby rate it supports.
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true)
        print("[VoiceMetrics] Audio session active — sampleRate=\(session.sampleRate)Hz")

        // ---- Prepare output file ----
        let dir = try recordingsDirectory()
        let url = dir.appendingPathComponent("reading_\(UUID().uuidString).m4a")
        recordingURL = url

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Write raw audio to WAV. Use the EXACT tap format (Float32) to avoid
        // any conversion issues between the tap's float buffers and the file.
        let wavURL = url.deletingPathExtension().appendingPathExtension("wav")
        print("[VoiceMetrics] Recording format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch, \(recordingFormat.commonFormat.rawValue) commonFormat, settings=\(recordingFormat.settings)")
        audioFile = try AVAudioFile(
            forWriting: wavURL,
            settings: recordingFormat.settings)
        recordingURL = wavURL
        print("[VoiceMetrics] Audio file created at \(wavURL.lastPathComponent)")

        // ---- Speech recognition request ----
        wordCount = 0
        startTime = Date()
        currentPitch = 0
        currentLoudness = -160
        currentWPM = 0
        pitchBuffer.removeAll()

        hasNotifiedRecognitionFailure = false
        useSyllableEstimation = false
        syllableCount = 0
        prevRMS = 0
        prevPrevRMS = 0
        inVoicedSegment = false
        buffersSinceLastOnset = 0

        // Check if speech recognizer is available for the chosen locale
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let lang = speechRecognizer?.locale.identifier ?? inputLocale.identifier
            print("[VoiceMetrics] No speech recognition for \(lang) — falling back to syllable-rate estimation")

            // Enable syllable-rate estimation as fallback
            useSyllableEstimation = true
            // Tamil words average ~3.2 syllables; English ~1.5; Hindi ~2.8
            let langPrefix = lang.components(separatedBy: "-").first ?? lang
            switch langPrefix {
            case "ta": syllablesPerWord = 3.2
            case "hi": syllablesPerWord = 2.8
            case "ml", "te", "kn": syllablesPerWord = 3.0  // other Dravidian/Indian
            default: syllablesPerWord = 1.5
            }
            print("[VoiceMetrics] syllablesPerWord=\(syllablesPerWord) for lang=\(langPrefix)")

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.voiceMetricsUsingSyllableEstimation()
            }

            recognitionRequest = nil
            recognitionTask = nil
            return try startAudioEngineOnly(inputNode: inputNode, recordingFormat: recordingFormat, wavURL: wavURL)
        }

        print("[VoiceMetrics] Recognizer OK — locale=\(recognizer.locale.identifier) available=\(recognizer.isAvailable)")

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        // Use on-device recognition when available (faster, private).
        // Fall back to server for languages without on-device support (e.g. Tamil).
        if #available(iOS 17, *), recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            print("[VoiceMetrics] Using ON-DEVICE recognition")
        } else {
            print("[VoiceMetrics] Using SERVER-BASED recognition (needs internet)")
        }
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                let count = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                print("[VoiceMetrics] Partial result: \(count) words, isFinal=\(result.isFinal), text=\"\(text.prefix(80))\"")
                DispatchQueue.main.async {
                    self.wordCount = count
                    self.recalcWPM()
                }
            }

            if let error {
                let nsErr = error as NSError
                print("[VoiceMetrics] Recognition error: domain=\(nsErr.domain) code=\(nsErr.code) desc=\(error.localizedDescription)")
                // Code 1101 = "Retry" (transient); Code 203 = cancelled by us; Code 216 = rate limited
                // Only notify user for non-cancellation errors
                if nsErr.code != 203 && nsErr.code != 216 {
                    DispatchQueue.main.async {
                        if !self.hasNotifiedRecognitionFailure {
                            self.hasNotifiedRecognitionFailure = true
                            self.delegate?.voiceMetricsRecognitionUnavailable(
                                reason: "Speech recognition error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        print("[VoiceMetrics] Recognition task created, state=\(recognitionTask?.state.rawValue ?? -1)")

        // ---- Install tap and start engine ----
        return try installTapAndStart(inputNode: inputNode, recordingFormat: recordingFormat, wavURL: wavURL)
    }

    /// Installs the audio tap and starts the engine. Shared by both the full
    /// path (with speech recognition) and the fallback path (pitch/loudness only).
    private var tapBufferCount = 0

    private func installTapAndStart(inputNode: AVAudioInputNode,
                                     recordingFormat: AVAudioFormat,
                                     wavURL: URL) throws -> URL {
        tapBufferCount = 0
        print("[VoiceMetrics] Installing tap — format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch")

        inputNode.installTap(onBus: 0,
                             bufferSize: 4096,
                             format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }

            self.tapBufferCount += 1
            // Log every 50th buffer (~every 2.3s at 48kHz/4096) to avoid spam
            if self.tapBufferCount % 50 == 1 {
                print("[VoiceMetrics] tap buffer #\(self.tapBufferCount), feeding to recogniser=\(self.recognitionRequest != nil), taskState=\(self.recognitionTask?.state.rawValue ?? -1)")
            }

            // Feed speech recogniser (nil-safe — skipped when unavailable)
            self.recognitionRequest?.append(buffer)

            // Write to file — DO NOT use try? so we catch failures
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                if self.tapBufferCount <= 3 {
                    print("[VoiceMetrics] ⚠️ audioFile.write FAILED: \(error)")
                }
            }

            // Log RMS every 50 buffers to diagnose audio levels
            if self.tapBufferCount % 50 == 1, let cd = buffer.floatChannelData?[0] {
                let len = Int(buffer.frameLength)
                var s: Float = 0
                for i in 0..<len { s += cd[i] * cd[i] }
                let rms = sqrt(s / Float(max(len, 1)))
                print("[VoiceMetrics] buf#\(self.tapBufferCount) RMS=\(String(format: "%.5f", rms)) (threshold=0.012)")
            }

            // Analyse buffer for pitch + loudness
            let pitch = self.detectPitch(buffer: buffer)
            let loudness = self.calculateLoudness(buffer: buffer)

            // ---- Syllable-rate estimation (fallback when no speech recognition) ----
            if self.useSyllableEstimation {
                self.detectSyllableOnset(buffer: buffer)
            }

            DispatchQueue.main.async {
                // Smooth pitch with a rolling average
                if let p = pitch {
                    self.pitchBuffer.append(p)
                    if self.pitchBuffer.count > self.pitchBufferSize {
                        self.pitchBuffer.removeFirst()
                    }
                    self.currentPitch = self.pitchBuffer.reduce(0, +) / Double(self.pitchBuffer.count)
                } else if self.pitchBuffer.isEmpty {
                    self.currentPitch = 0
                }
                // Loudness doesn't need smoothing — the bar already animates
                self.currentLoudness = loudness

                // Update word count from syllable estimation if active
                if self.useSyllableEstimation {
                    self.wordCount = max(1, Int(Double(self.syllableCount) / self.syllablesPerWord))
                }

                self.recalcWPM()

                self.delegate?.voiceMetrics(
                    didUpdate: self.currentPitch,
                    loudness: self.currentLoudness,
                    wordCount: self.wordCount,
                    wpm: self.currentWPM)
            }
        }

        // ---- Start engine ----
        audioEngine.prepare()
        try audioEngine.start()

        return wavURL
    }

    /// Fallback: starts audio engine for pitch/loudness only (no speech recognition).
    private func startAudioEngineOnly(inputNode: AVAudioInputNode,
                                       recordingFormat: AVAudioFormat,
                                       wavURL: URL) throws -> URL {
        return try installTapAndStart(inputNode: inputNode, recordingFormat: recordingFormat, wavURL: wavURL)
    }

    /// Stops the audio engine, speech recognition, and closes the audio file.
    func stop() {
        print("[VoiceMetrics] stop() called — wordCount=\(wordCount)")
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Signal end of audio — let the recogniser finish processing
        // any buffered audio before we tear it down.
        recognitionRequest?.endAudio()

        // For server-based recognition (e.g. Tamil) results may still be
        // in-flight. Give a short window before cancelling so the final
        // partial result can arrive. If recognition already delivered
        // results, finish() will complete synchronously.
        if let task = recognitionTask {
            // Only cancel if the task is still running after a short grace period
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if task.state == .running || task.state == .starting {
                    task.finish()
                }
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
            }
        } else {
            recognitionRequest = nil
            recognitionTask = nil
        }

        // Log file size before closing
        if let url = recordingURL {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("[VoiceMetrics] Audio file size: \(fileSize) bytes (\(fileSize / 1024) KB) at \(url.lastPathComponent)")
            print("[VoiceMetrics] Total tap buffers written: \(tapBufferCount)")
        }
        audioFile = nil  // flushes and closes
    }

    // MARK: - Syllable onset detection (energy-based)

    /// Detects syllables by finding **local peaks** in the RMS energy envelope.
    /// A peak is where prevRMS > prevPrevRMS AND prevRMS > currentRMS (i.e. the
    /// middle value is a local maximum).  This works for continuous speech where
    /// the energy never drops below an absolute silence threshold.
    private func detectSyllableOnset(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Calculate RMS for this buffer
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))

        buffersSinceLastOnset += 1

        // Peak detection: prevRMS is a local maximum if it was higher than
        // both its neighbours AND above the noise floor.
        let noiseFloor: Float = 0.008
        if prevRMS > prevPrevRMS && prevRMS > rms
            && prevRMS > noiseFloor
            && buffersSinceLastOnset >= minOnsetGapBuffers {
            syllableCount += 1
            buffersSinceLastOnset = 0
        }

        prevPrevRMS = prevRMS
        prevRMS = rms
    }

    // MARK: - Pitch detection (autocorrelation)

    private func detectPitch(buffer: AVAudioPCMBuffer) -> Double? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        // Pitch range: 60 Hz (deep male) to 500 Hz (high child voice)
        let minLag = Int(sampleRate / 500)
        let maxLag = Int(sampleRate / 60)

        guard maxLag < frameLength else { return nil }

        // Check energy — skip if silence
        var energy: Float = 0
        for i in 0..<frameLength {
            energy += channelData[i] * channelData[i]
        }
        let rms = sqrt(energy / Float(frameLength))
        guard rms > 0.01 else { return nil }  // silence threshold

        // Normalised autocorrelation
        var bestCorrelation: Float = 0
        var bestLag = 0

        for lag in minLag...maxLag {
            var correlation: Float = 0
            var norm1: Float = 0
            var norm2: Float = 0
            let count = frameLength - lag
            for i in 0..<count {
                correlation += channelData[i] * channelData[i + lag]
                norm1 += channelData[i] * channelData[i]
                norm2 += channelData[i + lag] * channelData[i + lag]
            }
            let denominator = sqrt(norm1 * norm2)
            guard denominator > 0 else { continue }
            let normalized = correlation / denominator

            if normalized > bestCorrelation {
                bestCorrelation = normalized
                bestLag = lag
            }
        }

        // Only accept if correlation is strong enough
        guard bestCorrelation > 0.3, bestLag > 0 else { return nil }
        return sampleRate / Double(bestLag)
    }

    // MARK: - Loudness (RMS → dBFS)

    private func calculateLoudness(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return -160 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return -160 }

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 1e-6))
        return Double(db)
    }

    // MARK: - Helpers

    private func recalcWPM() {
        guard let start = startTime else { currentWPM = 0; return }
        let elapsed = Date().timeIntervalSince(start)
        currentWPM = elapsed > 2 ? (Double(wordCount) / elapsed) * 60.0 : 0
    }

    private func recordingsDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .documentDirectory,
                              in: .userDomainMask,
                              appropriateFor: nil,
                              create: true)
        let dir = base.appendingPathComponent("reading")
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func engineError(_ message: String) -> NSError {
        NSError(domain: "com.sapthagiri.langci.voicemetrics",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
