// AVTAudioPlayer.swift
// LangCI — Unified audio playback for AVT drills.
//
// Dispatches between two backends:
//   1. Bundled .mp3 / .wav files  (used by the curated detection drills
//      that ship with real recordings)
//   2. AVSpeechSynthesizer TTS    (used by the 1,177 Cochlear library items
//      that have no recorded audio)
//
// The TTS backend respects the user's voice preference
// (Female / Male / Alternate) stored in UserDefaults.

import Foundation
import AVFoundation

final class AVTAudioPlayer: NSObject {

    // MARK: - Voice preference

    enum VoicePreference: String, CaseIterable {
        case female
        case male
        case alternate

        var displayName: String {
            switch self {
            case .female:    return "Female"
            case .male:      return "Male"
            case .alternate: return "Alternate"
            }
        }
    }

    static let voicePreferenceKey = "avtVoicePreference"

    static var voicePreference: VoicePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: voicePreferenceKey) ?? VoicePreference.female.rawValue
            return VoicePreference(rawValue: raw) ?? .female
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: voicePreferenceKey)
        }
    }

    // MARK: - Noise preference (SNR challenge mode)

    enum NoiseProfile: String, CaseIterable {
        case off
        case cafeteria
        case street
        case music

        var displayName: String {
            switch self {
            case .off:       return "Off"
            case .cafeteria: return "Cafeteria"
            case .street:    return "Street"
            case .music:     return "Background Music"
            }
        }

        var resourceName: String? {
            switch self {
            case .off:       return nil
            case .cafeteria: return "noise_cafeteria"
            case .street:    return "noise_street"
            case .music:     return "noise_music"
            }
        }
    }

    /// Signal-to-noise ratio. Higher is easier. `offDB` is used only when
    /// the profile is .off.
    enum NoiseLevel: String, CaseIterable {
        case offDB       // profile off
        case plus10dB    // easy noise
        case plus5dB     // moderate
        case zeroDB      // hard (speech and noise equal loudness)
        case minus5dB    // challenging — expert level

        var displayName: String {
            switch self {
            case .offDB:    return "Clear"
            case .plus10dB: return "+10 dB (Light)"
            case .plus5dB:  return "+5 dB (Moderate)"
            case .zeroDB:   return "0 dB (Hard)"
            case .minus5dB: return "-5 dB (Expert)"
            }
        }

        /// Noise gain relative to speech (1.0 = equal). Computed from SNR.
        var noiseGain: Float {
            switch self {
            case .offDB:    return 0.0
            case .plus10dB: return pow(10.0, -10.0 / 20.0) // ~0.316
            case .plus5dB:  return pow(10.0, -5.0  / 20.0) // ~0.562
            case .zeroDB:   return 1.0
            case .minus5dB: return pow(10.0, 5.0  / 20.0)  // ~1.78
            }
        }
    }

    static let noiseProfileKey = "avtNoiseProfile"
    static let noiseLevelKey = "avtNoiseLevel"

    static var noiseProfile: NoiseProfile {
        get {
            let raw = UserDefaults.standard.string(forKey: noiseProfileKey) ?? NoiseProfile.off.rawValue
            return NoiseProfile(rawValue: raw) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: noiseProfileKey)
            shared.refreshNoiseBed()
        }
    }

    static var noiseLevel: NoiseLevel {
        get {
            let raw = UserDefaults.standard.string(forKey: noiseLevelKey) ?? NoiseLevel.offDB.rawValue
            return NoiseLevel(rawValue: raw) ?? .offDB
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: noiseLevelKey)
            shared.refreshNoiseBed()
        }
    }

    // MARK: - Singleton

    static let shared = AVTAudioPlayer()

    private override init() {
        super.init()
        configureAudioSession()
        synth.delegate = self
    }

    // MARK: - Backends

    private var filePlayer: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private var turnCounter: Int = 0

    /// Background ambient loop used for SNR challenge mode. Loaded lazily
    /// when the user picks a noise profile in Settings.
    private var noisePlayer: AVAudioPlayer?

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .mixWithOthers so our noise bed and TTS can coexist with
            // the speech synth's own audio graph.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("⚠️ AVTAudioPlayer: audio session config failed: \(error)")
            #endif
        }
    }

    // MARK: - Noise bed

    /// (Re)load the noise loop based on the current Settings preferences and
    /// start or stop it accordingly. Called automatically when the user
    /// changes noiseProfile or noiseLevel in Settings.
    func refreshNoiseBed() {
        // Tear down any existing player
        noisePlayer?.stop()
        noisePlayer = nil

        let profile = Self.noiseProfile
        let level = Self.noiseLevel
        guard profile != .off, level != .offDB, let resource = profile.resourceName else {
            return
        }

        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            #if DEBUG
            print("⚠️ AVTAudioPlayer: noise resource \(resource).wav missing from bundle")
            #endif
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1  // loop indefinitely
            player.volume = min(max(level.noiseGain, 0.0), 1.5)
            player.prepareToPlay()
            noisePlayer = player
            // Don't start yet — only start when a speech/file play call fires
        } catch {
            #if DEBUG
            print("⚠️ AVTAudioPlayer: failed to load noise bed: \(error)")
            #endif
        }
    }

    private func startNoiseBedIfNeeded() {
        guard let player = noisePlayer else { return }
        if !player.isPlaying {
            player.currentTime = 0
            player.play()
        }
    }

    private func stopNoiseBed() {
        noisePlayer?.stop()
    }

    // MARK: - Public API

    /// Play the "main" voice for a drill item. Used by the single Play button.
    /// For items with a recorded audio file, plays the file; otherwise
    /// speaks the correct distractor (or the raw `correctAnswer`) via TTS.
    func play(item: AVTDrillItem) {
        stopSpeech()
        startNoiseBedIfNeeded()
        if !item.audioFileName.isEmpty, playBundledFile(named: item.audioFileName) {
            return
        }
        let textToSpeak = speakableText(for: item)
        if !textToSpeak.isEmpty {
            speak(textToSpeak)
        }
    }

    /// Play a specific distractor (used by Play A / Play B buttons in
    /// discrimination mode). Falls back to the main item if the index is
    /// out of bounds.
    func play(item: AVTDrillItem, distractorIndex: Int) {
        guard distractorIndex >= 0, distractorIndex < item.distractors.count else {
            play(item: item)
            return
        }
        stopSpeech()
        startNoiseBedIfNeeded()
        let distractor = item.distractors[distractorIndex]
        if !distractor.audioFileName.isEmpty, playBundledFile(named: distractor.audioFileName) {
            return
        }
        let cleaned = cleanForTTS(distractor.text)
        if !cleaned.isEmpty {
            speak(cleaned)
        }
    }

    /// Stop any currently playing speech or file. Leaves the noise bed
    /// running so the ambient environment stays continuous between turns.
    private func stopSpeech() {
        filePlayer?.stop()
        filePlayer = nil
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }

    /// Public stop: halts everything including the noise bed. Call from
    /// the drill screen when it tears down or pauses.
    func stop() {
        stopSpeech()
        stopNoiseBed()
    }

    // MARK: - File backend

    private func playBundledFile(named fileName: String) -> Bool {
        // fileName may already include an extension — strip it for resource lookup
        let base = (fileName as NSString).deletingPathExtension
        let url = Bundle.main.url(forResource: base, withExtension: "mp3")
            ?? Bundle.main.url(forResource: base, withExtension: "wav")
            ?? Bundle.main.url(forResource: fileName, withExtension: "mp3")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav")

        guard let url else { return false }
        do {
            filePlayer = try AVAudioPlayer(contentsOf: url)
            filePlayer?.prepareToPlay()
            filePlayer?.play()
            return true
        } catch {
            return false
        }
    }

    // MARK: - TTS backend

    private func speak(_ text: String) {
        let cleaned = cleanForTTS(text)
        guard !cleaned.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = resolveVoice()
        // Slow down slightly for CI users — halfway between default and minimum.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05
        synth.speak(utterance)
        turnCounter += 1
    }

    /// Choose the best system voice for the current preference.
    ///
    /// Strategy:
    ///   1. Enumerate all installed voices
    ///   2. Filter to the current locale (English) matching the desired gender
    ///   3. Prefer enhanced/premium quality if available
    ///   4. Fall back to any English voice, then to the system default
    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        let desired: AVSpeechSynthesisVoiceGender
        switch Self.voicePreference {
        case .female:    desired = .female
        case .male:      desired = .male
        case .alternate: desired = (turnCounter % 2 == 0) ? .female : .male
        }

        let all = AVSpeechSynthesisVoice.speechVoices()
        let englishMatching = all.filter {
            $0.language.hasPrefix("en") && $0.gender == desired
        }

        // Sort: premium > enhanced > default, then prefer en-US
        let sorted = englishMatching.sorted { a, b in
            if a.quality != b.quality {
                return a.quality.rawValue > b.quality.rawValue
            }
            return a.language == "en-US" && b.language != "en-US"
        }

        return sorted.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first
    }

    // MARK: - Text helpers

    /// Pick the best text to speak for a given drill item.
    private func speakableText(for item: AVTDrillItem) -> String {
        if let correct = item.distractors.first(where: { $0.isCorrect }) {
            let t = cleanForTTS(correct.text)
            if !t.isEmpty { return t }
        }
        if let first = item.distractors.first {
            let t = cleanForTTS(first.text)
            if !t.isEmpty { return t }
        }
        let fallback = cleanForTTS(item.correctAnswer.isEmpty ? item.displayText : item.correctAnswer)
        return fallback
    }

    /// Strip formatting artifacts that shouldn't be spoken: IPA brackets,
    /// dotted blanks used by the Cochlear PDFs, multiple spaces, etc.
    private func cleanForTTS(_ text: String) -> String {
        var s = text
        // Remove IPA slashes around phonemes (e.g. "/ʃ/" → "ʃ") — though the
        // synth can't pronounce bare IPA either, so drop bracketed phonemes.
        s = s.replacingOccurrences(of: #"/[^\s/]+/"#, with: "", options: .regularExpression)
        // Drop the Cochlear dotted-blank placeholders.
        s = s.replacingOccurrences(of: "........", with: "")
        s = s.replacingOccurrences(of: ".......", with: "")
        s = s.replacingOccurrences(of: "......", with: "")
        s = s.replacingOccurrences(of: "…", with: "")
        // Collapse whitespace
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AVTAudioPlayer: AVSpeechSynthesizerDelegate {
    // Currently unused — reserved for progress callbacks and haptics hook-ups.
}
