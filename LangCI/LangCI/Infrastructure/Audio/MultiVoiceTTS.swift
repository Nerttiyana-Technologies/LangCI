// MultiVoiceTTS.swift
// LangCI — Multi-voice Text-to-Speech for CI training
//
// CI users need to hear the SAME word in DIFFERENT voices (male, female,
// different pitches, different speeds) to train their brain to recognise
// sounds across speakers. A single voice is not real-world training.
//
// Each VoiceProfile specifies a preferred iOS voice by name (e.g. "Karen",
// "Daniel") so the displayed label always matches the actual voice playing.

import AVFoundation

final class MultiVoiceTTS: NSObject, AVSpeechSynthesizerDelegate {

    static let shared = MultiVoiceTTS()

    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    /// Cache of available voices on this device, keyed by name (lowercased)
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    // MARK: - Voice Profiles

    /// A named voice configuration combining a specific iOS voice + pitch + rate tweaks
    struct VoiceProfile: Equatable {
        let name: String          // Display name: "Rishi (India)", "Karen (AU)", etc.
        let voiceName: String     // iOS voice name to search for: "Rishi", "Karen", "Daniel"
        let languageCode: String  // Fallback language: "en-IN", "en-GB"
        let pitchMultiplier: Float
        let rate: Float           // multiplier on default rate
        let accent: VoiceAccent   // grouping for picker
    }

    /// Accent regions for the voice picker
    enum VoiceAccent: String, CaseIterable {
        case india = "India"
        case us    = "US"
        case uk    = "UK"
        case au    = "Australia"
        case tamil = "Tamil"
        case all   = "All (Random)"

        var icon: String {
            switch self {
            case .india: return "🇮🇳"
            case .us:    return "🇺🇸"
            case .uk:    return "🇬🇧"
            case .au:    return "🇦🇺"
            case .tamil: return "த"
            case .all:   return "🔀"
            }
        }
    }

    // MARK: - All Voice Profiles
    //
    // Each profile targets a SPECIFIC iOS voice by name so the label matches
    // what the user actually hears. Pitch/rate tweaks create further variety.
    //
    // Common iOS voices (built-in, no download required):
    //   en-IN : Rishi (male), Sangeeta (female)
    //   en-US : Samantha (female), Fred (male)
    //   en-GB : Daniel (male), Kate (female)
    //   en-AU : Karen (female), Lee (male)
    //   ta-IN : Vani (female)

    static let profiles: [VoiceProfile] = [
        // 🇮🇳 India
        VoiceProfile(name: "Sangeeta (India)",         voiceName: "Sangeeta", languageCode: "en-IN", pitchMultiplier: 1.0,  rate: 0.85, accent: .india),
        VoiceProfile(name: "Sangeeta High (India)",    voiceName: "Sangeeta", languageCode: "en-IN", pitchMultiplier: 1.2,  rate: 0.80, accent: .india),
        VoiceProfile(name: "Rishi (India)",            voiceName: "Rishi",    languageCode: "en-IN", pitchMultiplier: 1.0,  rate: 0.85, accent: .india),
        VoiceProfile(name: "Rishi Deep (India)",       voiceName: "Rishi",    languageCode: "en-IN", pitchMultiplier: 0.75, rate: 0.90, accent: .india),
        VoiceProfile(name: "Rishi Slow (India)",       voiceName: "Rishi",    languageCode: "en-IN", pitchMultiplier: 1.0,  rate: 0.55, accent: .india),
        VoiceProfile(name: "Sangeeta Fast (India)",    voiceName: "Sangeeta", languageCode: "en-IN", pitchMultiplier: 1.0,  rate: 1.10, accent: .india),

        // 🇺🇸 US
        VoiceProfile(name: "Samantha (US)",            voiceName: "Samantha", languageCode: "en-US", pitchMultiplier: 1.0,  rate: 0.80, accent: .us),
        VoiceProfile(name: "Samantha High (US)",       voiceName: "Samantha", languageCode: "en-US", pitchMultiplier: 1.2,  rate: 0.80, accent: .us),
        VoiceProfile(name: "Fred (US)",                voiceName: "Fred",     languageCode: "en-US", pitchMultiplier: 1.0,  rate: 0.85, accent: .us),
        VoiceProfile(name: "Fred Deep (US)",           voiceName: "Fred",     languageCode: "en-US", pitchMultiplier: 0.75, rate: 0.85, accent: .us),
        VoiceProfile(name: "Fred Slow (US)",           voiceName: "Fred",     languageCode: "en-US", pitchMultiplier: 1.0,  rate: 0.50, accent: .us),
        VoiceProfile(name: "Samantha Fast (US)",       voiceName: "Samantha", languageCode: "en-US", pitchMultiplier: 1.0,  rate: 1.15, accent: .us),

        // 🇬🇧 UK
        VoiceProfile(name: "Kate (UK)",                voiceName: "Kate",     languageCode: "en-GB", pitchMultiplier: 1.0,  rate: 0.80, accent: .uk),
        VoiceProfile(name: "Kate High (UK)",           voiceName: "Kate",     languageCode: "en-GB", pitchMultiplier: 1.2,  rate: 0.80, accent: .uk),
        VoiceProfile(name: "Daniel (UK)",              voiceName: "Daniel",   languageCode: "en-GB", pitchMultiplier: 1.0,  rate: 0.85, accent: .uk),
        VoiceProfile(name: "Daniel Deep (UK)",         voiceName: "Daniel",   languageCode: "en-GB", pitchMultiplier: 0.75, rate: 0.90, accent: .uk),
        VoiceProfile(name: "Daniel Slow (UK)",         voiceName: "Daniel",   languageCode: "en-GB", pitchMultiplier: 1.0,  rate: 0.50, accent: .uk),

        // 🇦🇺 Australia
        VoiceProfile(name: "Karen (AU)",               voiceName: "Karen",    languageCode: "en-AU", pitchMultiplier: 1.0,  rate: 0.80, accent: .au),
        VoiceProfile(name: "Karen High (AU)",          voiceName: "Karen",    languageCode: "en-AU", pitchMultiplier: 1.2,  rate: 0.80, accent: .au),
        VoiceProfile(name: "Lee (AU)",                 voiceName: "Lee",      languageCode: "en-AU", pitchMultiplier: 1.0,  rate: 0.85, accent: .au),
        VoiceProfile(name: "Lee Deep (AU)",            voiceName: "Lee",      languageCode: "en-AU", pitchMultiplier: 0.75, rate: 0.85, accent: .au),
        VoiceProfile(name: "Lee Slow (AU)",            voiceName: "Lee",      languageCode: "en-AU", pitchMultiplier: 1.0,  rate: 0.50, accent: .au),

        // Tamil
        VoiceProfile(name: "Vani (Tamil)",             voiceName: "Vani",     languageCode: "ta-IN", pitchMultiplier: 1.0,  rate: 0.85, accent: .tamil),
        VoiceProfile(name: "Vani High (Tamil)",        voiceName: "Vani",     languageCode: "ta-IN", pitchMultiplier: 1.25, rate: 0.80, accent: .tamil),
        VoiceProfile(name: "Vani Low (Tamil)",         voiceName: "Vani",     languageCode: "ta-IN", pitchMultiplier: 0.8,  rate: 0.90, accent: .tamil),
        VoiceProfile(name: "Vani Slow (Tamil)",        voiceName: "Vani",     languageCode: "ta-IN", pitchMultiplier: 1.0,  rate: 0.55, accent: .tamil),
        VoiceProfile(name: "Vani Fast (Tamil)",        voiceName: "Vani",     languageCode: "ta-IN", pitchMultiplier: 1.0,  rate: 1.10, accent: .tamil),
    ]

    /// Currently selected accent filter — .all means use everything
    private(set) var selectedAccent: VoiceAccent = .all

    /// Currently selected profile index — -1 means cycle through filtered set
    private(set) var currentProfileIndex: Int = -1

    /// Cycle index for round-robin
    private var cycleIndex: Int = 0

    // MARK: - Init

    private override init() {
        super.init()
        synthesizer.delegate = self
        buildVoiceCache()
    }

    /// Index all available iOS voices by name for fast lookup
    private func buildVoiceCache() {
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            // Key by the short display name (e.g. "Karen", "Daniel")
            let shortName = voice.name
                .replacingOccurrences(of: " (Enhanced)", with: "")
                .replacingOccurrences(of: " (Premium)", with: "")
                .components(separatedBy: " ").first ?? voice.name
            voiceCache[shortName.lowercased()] = voice
            // Also cache by full name for exact matches
            voiceCache[voice.name.lowercased()] = voice
        }
    }

    // MARK: - Voice Lookup

    /// Find the actual iOS voice for a profile, matching by name first
    private func findVoice(for profile: VoiceProfile) -> AVSpeechSynthesisVoice? {
        // 1. Try exact voice name match
        if let voice = voiceCache[profile.voiceName.lowercased()] {
            return voice
        }

        // 2. Try searching all voices for a name containing our target
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            if voice.name.localizedCaseInsensitiveContains(profile.voiceName)
                && voice.language == profile.languageCode {
                return voice
            }
        }

        // 3. Fall back to language code default
        return AVSpeechSynthesisVoice(language: profile.languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Accent Filtering

    /// Get profiles filtered by accent (English only = excludes Tamil)
    static func englishProfiles(for accent: VoiceAccent) -> [VoiceProfile] {
        switch accent {
        case .all:
            return profiles.filter { $0.accent != .tamil }
        case .tamil:
            return profiles.filter { $0.accent == .tamil }
        default:
            return profiles.filter { $0.accent == accent }
        }
    }

    /// Set the accent filter for subsequent plays
    func selectAccent(_ accent: VoiceAccent) {
        selectedAccent = accent
        cycleIndex = 0
    }

    /// Get the current filtered pool
    private var currentPool: [VoiceProfile] {
        let pool: [VoiceProfile]
        switch selectedAccent {
        case .all:
            pool = Self.profiles.filter { $0.accent != .tamil }
        case .tamil:
            pool = Self.profiles.filter { $0.accent == .tamil }
        default:
            pool = Self.profiles.filter { $0.accent == selectedAccent }
        }
        return pool.isEmpty ? Self.profiles : pool
    }

    // MARK: - Public API

    /// Speak text with a specific voice profile
    func speak(_ text: String, profile: VoiceProfile, completion: (() -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        onFinish = completion

        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = profile.pitchMultiplier
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * profile.rate

        // Use the specific named voice so label matches actual sound
        utterance.voice = findVoice(for: profile)

        synthesizer.speak(utterance)
    }

    /// Speak text with a random voice profile (cycles through all)
    @discardableResult
    func speakRandom(_ text: String, completion: (() -> Void)? = nil) -> VoiceProfile {
        let pool = Self.profiles
        let profile = pool[cycleIndex % pool.count]
        cycleIndex += 1
        speak(text, profile: profile, completion: completion)
        return profile
    }

    /// Speak text with the next voice from the selected accent pool
    @discardableResult
    func speakNextVoice(_ text: String, completion: (() -> Void)? = nil) -> VoiceProfile {
        let pool = currentPool
        let profile: VoiceProfile
        if currentProfileIndex >= 0 {
            profile = pool[currentProfileIndex % pool.count]
        } else {
            profile = pool[cycleIndex % pool.count]
            cycleIndex += 1
        }
        speak(text, profile: profile, completion: completion)
        return profile
    }

    /// Speak using only English voices from the selected accent
    /// For pure phonetic sounds — Tamil TTS mispronounces them
    @discardableResult
    func speakEnglishOnly(_ text: String, completion: (() -> Void)? = nil) -> VoiceProfile {
        let pool: [VoiceProfile]
        if selectedAccent == .tamil || selectedAccent == .all {
            // Use all English accents
            pool = Self.profiles.filter { $0.accent != .tamil }
        } else {
            pool = Self.profiles.filter { $0.accent == selectedAccent }
        }
        let safePool = pool.isEmpty ? Self.profiles : pool
        let profile = safePool[cycleIndex % safePool.count]
        cycleIndex += 1
        speak(text, profile: profile, completion: completion)
        return profile
    }

    /// Set a fixed voice profile (-1 for round-robin)
    func selectProfile(index: Int) {
        currentProfileIndex = index
    }

    /// Stop any current speech
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Get available profiles that actually have voices on this device
    static func availableProfiles() -> [VoiceProfile] {
        let available = Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language })
        return profiles.filter { available.contains($0.languageCode) }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
        onFinish = nil
    }
}
