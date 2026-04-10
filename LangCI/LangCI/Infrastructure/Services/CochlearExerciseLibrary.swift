// CochlearExerciseLibrary.swift
// LangCI — Loads and queries the Cochlear adult AVT exercise bank.
//
// The library is a static, read-only catalog of 75 exercises (1213 items)
// shipped as Resources/cochlear_exercises.json. It is loaded once on first
// access and held in memory.

import Foundation

final class CochlearExerciseLibrary {

    static let shared = CochlearExerciseLibrary()

    let exercises: [CochlearExercise]
    let loadError: Error?

    private init() {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "cochlear_exercises", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do {
                let decoded = try JSONDecoder().decode([CochlearExercise].self, from: data)
                self.exercises = decoded
                self.loadError = nil
            } catch {
                self.exercises = []
                self.loadError = error
                #if DEBUG
                print("⚠️ CochlearExerciseLibrary: failed to decode JSON: \(error)")
                #endif
            }
        } else {
            self.exercises = []
            self.loadError = NSError(
                domain: "CochlearExerciseLibrary",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "cochlear_exercises.json not found in bundle"]
            )
            #if DEBUG
            print("⚠️ CochlearExerciseLibrary: cochlear_exercises.json missing from bundle")
            #endif
        }
    }

    // MARK: - Browsing

    /// All exercises in a given section.
    func exercises(inSection section: CochlearSection) -> [CochlearExercise] {
        exercises.filter { $0.section == section }
    }

    /// Exercises whose category matches (case-insensitive substring).
    func exercises(matchingCategory query: String) -> [CochlearExercise] {
        let q = query.lowercased()
        return exercises.filter { $0.category.lowercased().contains(q) }
    }

    /// Exercises whose `format` matches.
    func exercises(ofFormat format: CochlearExerciseFormat) -> [CochlearExercise] {
        exercises.filter { $0.format == format }
    }

    /// Exercises at a given listening hierarchy level.
    func exercises(atLevel level: ListeningHierarchy) -> [CochlearExercise] {
        exercises.filter { $0.listeningLevel == level }
    }

    // MARK: - Phoneme matching
    //
    // For a given audiologist target sound (sh, mm, ush, etc.) we want to
    // surface exercises that exercise that phoneme. The Cochlear curriculum
    // doesn't tag exercises by phoneme, so we mine them by content:
    //
    //  • For phoneme analytic exercises (Section 3.x in PDF; "Phonemes" cat),
    //    we just return the whole exercise — every word in it is relevant.
    //  • For other exercises we look at every word in every item and keep the
    //    items whose visible text contains a token matching the phoneme rule.
    //
    // The matcher is intentionally crude — these are seed drills, not a
    // pronunciation dictionary. The goal is more practice content, not
    // perfect phonetic accuracy.

    /// Find drill items matching a target sound and listening level. Returns
    /// drill items already converted to `AVTDrillItem` so the existing
    /// AVT screens can use them directly.
    func drillItems(forSound sound: String, level: ListeningHierarchy) -> [AVTDrillItem] {
        let normalized = sound.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        // Pull every exercise at this level (or close)
        let levelMatches = exercises(atLevel: level)

        var built: [AVTDrillItem] = []

        for ex in levelMatches {
            let matchingItems = ex.items.filter { itemMatches($0, sound: normalized) }
            for it in matchingItems {
                built.append(buildDrillItem(from: it, parent: ex, target: normalized))
                if built.count >= 60 { return built }
            }
        }

        // Fallback: if we didn't find anything at this level, mine from
        // any phoneme exercise (great for sh / mm / ush which are common)
        if built.isEmpty {
            let phonemeEx = exercises(matchingCategory: "phonemes")
            for ex in phonemeEx {
                let matchingItems = ex.items.filter { itemMatches($0, sound: normalized) }
                for it in matchingItems {
                    built.append(buildDrillItem(from: it, parent: ex, target: normalized))
                    if built.count >= 30 { return built }
                }
            }
        }

        return built
    }

    private func itemMatches(_ item: CochlearExerciseItem, sound: String) -> Bool {
        // Use the CMU-inspired PhonemeMatcher instead of raw substrings.
        // This correctly rejects false positives like "ache" for /sh/
        // (the "ch" here is /k/, not /ʃ/) and catches "nation" for /sh/
        // (the "ti" before vowel in -tion is /ʃ/).
        let matcher = PhonemeMatcher.shared
        for word in item.allWords {
            if matcher.matches(word, target: sound) { return true }
        }
        return false
    }

    private func buildDrillItem(from item: CochlearExerciseItem,
                                parent: CochlearExercise,
                                target: String) -> AVTDrillItem {
        let display: String
        var distractors: [AVTDistractor] = []
        var correct = ""

        switch parent.format {
        case .wordPair:
            display = "\(item.pairA ?? "") vs \(item.pairB ?? "")"
            correct = item.pairA ?? ""
            distractors = [
                AVTDistractor(text: item.pairA ?? "", audioFileName: "", isCorrect: true),
                AVTDistractor(text: item.pairB ?? "", audioFileName: "", isCorrect: false),
            ]

        case .wordChoice:
            display = (item.choices ?? []).joined(separator: " / ")
            correct = item.choices?.first ?? ""
            distractors = (item.choices ?? []).enumerated().map { (ix, w) in
                AVTDistractor(text: w, audioFileName: "", isCorrect: ix == 0)
            }

        case .sentenceChoice:
            display = item.letteredChoices?.first?.text ?? item.displaySummary
            correct = item.letteredChoices?.first?.text ?? ""
            distractors = (item.letteredChoices ?? []).enumerated().map { (ix, c) in
                AVTDistractor(text: c.text, audioFileName: "", isCorrect: ix == 0)
            }

        case .sentenceCompletion:
            display = item.carrier ?? ""
            correct = item.choices?.first ?? ""
            distractors = (item.choices ?? []).enumerated().map { (ix, w) in
                AVTDistractor(text: w, audioFileName: "", isCorrect: ix == 0)
            }

        case .sentenceWithChoice:
            display = item.template ?? item.sentences?.first ?? ""
            correct = item.choices?.first ?? ""
            distractors = (item.choices ?? []).enumerated().map { (ix, w) in
                AVTDistractor(text: w, audioFileName: "", isCorrect: ix == 0)
            }

        case .fillBlank:
            display = item.text ?? ""
            correct = item.alternatives?.first ?? ""
            distractors = (item.alternatives ?? []).enumerated().map { (ix, w) in
                AVTDistractor(text: w, audioFileName: "", isCorrect: ix == 0)
            }

        case .cuedSentence, .letteredClueSentence:
            display = item.text ?? ""
            correct = item.text ?? ""
            distractors = [
                AVTDistractor(text: item.text ?? "", audioFileName: "", isCorrect: true)
            ]

        default:
            display = item.displaySummary
            correct = item.text ?? item.displaySummary
            distractors = [
                AVTDistractor(text: correct, audioFileName: "", isCorrect: true)
            ]
        }

        return AVTDrillItem(
            sound: target,
            displayText: display,
            audioFileName: "",
            distractors: distractors,
            level: parent.listeningLevel,
            correctAnswer: correct
        )
    }

    // MARK: - Diagnostics
    var summary: String {
        let total = exercises.reduce(0) { $0 + $1.items.count }
        return "\(exercises.count) exercises · \(total) items"
    }
}
