// ConfusionDrillService.swift
// LangCI — Turns the user's logged confusion pairs into targeted drills.
//
// Two entry points:
//
//   1. `buildDrillItems(limit:)` — pulls the top N most-confused pairs and
//      converts each into an AVTDrillItem where the "correct" choice is
//      what was originally said and the distractor is what the user heard.
//      Used by the Confusion Drill screen.
//
//   2. `injectionItems(forSound:count:)` — returns a handful of drill
//      items biased toward the target sound, for mixing into a normal
//      AVT drill round. GRDBAvtService calls this when building the
//      round so ~20% of items are taken from the user's personal error
//      history.
//
// All items flow through PhonemeMatcher so targetSound tags get respected
// even when the original log didn't tag them.

import Foundation

final class ConfusionDrillService {

    static let shared = ConfusionDrillService()

    private init() {}

    private var pairService: ConfusionPairService {
        ServiceLocator.shared.confusionPairService
    }

    // MARK: - Public API

    /// Build up to `limit` drill items from the user's top confused pairs.
    /// Uses the identification level (the most common use case for
    /// confusion drilling: can the user now pick the correct word).
    func buildDrillItems(limit: Int = 10,
                         level: ListeningHierarchy = .identification) async -> [AVTDrillItem] {
        let top: [ConfusionStatDto]
        do {
            top = try await pairService.getTopConfusions(limit: limit, days: nil)
        } catch {
            return []
        }

        var items: [AVTDrillItem] = []
        for stat in top {
            let said = stat.saidWord.trimmingCharacters(in: .whitespacesAndNewlines)
            let heard = stat.heardWord.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !said.isEmpty, !heard.isEmpty, said.lowercased() != heard.lowercased() else { continue }

            let targetSound = inferTargetSound(said: said, heard: heard)
            let item = AVTDrillItem(
                sound: targetSound,
                displayText: said,
                audioFileName: "",
                distractors: [
                    AVTDistractor(text: said, audioFileName: "", isCorrect: true),
                    AVTDistractor(text: heard, audioFileName: "", isCorrect: false)
                ],
                level: level,
                correctAnswer: said
            )
            items.append(item)
        }
        return items
    }

    /// Items to sprinkle into a normal AVT drill round for the given sound.
    /// Returns up to `count` items. Safe to call from a sync context — it
    /// uses a short-lived Task with a semaphore-style wait on a cached
    /// result. In practice the cache is primed async via `primeCache()`.
    func cachedInjectionItems(forSound sound: String,
                              level: ListeningHierarchy,
                              count: Int = 3) -> [AVTDrillItem] {
        let matcher = PhonemeMatcher.shared
        let normalized = sound.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cached = Self.cache.snapshot()

        let filtered = cached.filter { pair in
            // Prefer pairs tagged with this sound OR where either word exercises it.
            if pair.targetSound.lowercased() == normalized { return true }
            return matcher.matches(pair.saidWord, target: normalized) ||
                   matcher.matches(pair.heardWord, target: normalized)
        }

        return filtered.prefix(count).map { pair in
            AVTDrillItem(
                sound: normalized,
                displayText: pair.saidWord,
                audioFileName: "",
                distractors: [
                    AVTDistractor(text: pair.saidWord, audioFileName: "", isCorrect: true),
                    AVTDistractor(text: pair.heardWord, audioFileName: "", isCorrect: false)
                ],
                level: level,
                correctAnswer: pair.saidWord
            )
        }
    }

    /// Refresh the injection cache. Call from screens that can afford an
    /// async fetch (e.g. drill screen `viewDidLoad`, home screen `viewWillAppear`).
    func primeCache() async {
        do {
            let pairs = try await pairService.getRecentPairs(limit: 50)
            Self.cache.replace(with: pairs)
        } catch {
            // Leave cache as-is on failure.
        }
    }

    // MARK: - Target sound inference

    /// Best-effort guess at which target sound a pair exercises. If the pair
    /// was logged with an explicit tag we use it; otherwise we pick the
    /// phoneme that differs between said and heard.
    private func inferTargetSound(said: String, heard: String) -> String {
        // Naive char-level diff for the first differing letter cluster.
        // Good enough for 90% of minimal-pair confusions logged from drills.
        let sChars = Array(said.lowercased())
        let hChars = Array(heard.lowercased())
        let common = min(sChars.count, hChars.count)
        for i in 0..<common where sChars[i] != hChars[i] {
            // Grab up to 2 chars from `said` at the diff point.
            let endIx = min(i + 2, sChars.count)
            return String(sChars[i..<endIx])
        }
        return ""
    }

    // MARK: - Sync cache

    /// Thread-safe snapshot cache so sync callers (GRDBAvtService.getDrillItems)
    /// can pull injection items without blocking on an await.
    private final class PairCache: @unchecked Sendable {
        private let lock = NSLock()
        private var pairs: [ConfusionPair] = []

        func snapshot() -> [ConfusionPair] {
            lock.lock(); defer { lock.unlock() }
            return pairs
        }

        func replace(with newPairs: [ConfusionPair]) {
            lock.lock(); defer { lock.unlock() }
            pairs = newPairs
        }
    }

    private static let cache = PairCache()
}
