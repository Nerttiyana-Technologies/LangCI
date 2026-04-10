// PhonemeMatcher.swift
// LangCI — Rule-based word → phoneme matcher inspired by CMU Pronouncing
// Dictionary (ARPAbet) conventions, tuned for the audiologist target sounds
// used in LangCI (sh, mm/m, ush, s, z, th, f, ch, ng, l, r, k, g, t, d, p, b,
// plus vowels ee, ah, oo, i, e).
//
// Why rule-based instead of shipping the full CMU dict?
//   • The full cmudict.0.7b is ~3.5 MB and 134k entries. We'd load it
//     into memory on first use which is wasteful for a mobile app that
//     only needs to answer "does this word exercise /ʃ/?"
//   • Our vocabulary is bounded by the Cochlear library's ~1200 items
//     plus whatever custom words audiologists add. A tight ruleset that
//     correctly handles English letter-to-sound cases is good enough
//     and far smaller.
//   • Edge cases (silent letters, doubled consonants, /ʃ/ spelled as
//     "ti" in "nation", /f/ spelled "ph", etc.) are handled explicitly
//     so we don't emit false positives the way pure substring did.
//
// The matcher returns `true` if a word contains the target phoneme in any
// position. Callers that care about position (initial/medial/final) can
// use `matches(_:positions:)` instead.

import Foundation

enum PhonemePosition {
    case initial, medial, final, anywhere
}

final class PhonemeMatcher {

    static let shared = PhonemeMatcher()

    private init() {}

    /// Return true if `word` exercises the given target sound.
    /// `target` is the audiologist shorthand (e.g. "sh", "mm", "ush").
    func matches(_ word: String, target: String) -> Bool {
        matches(word, target: target, position: .anywhere)
    }

    /// Position-aware variant. Returns true if the target sound appears at
    /// the requested position in the word.
    func matches(_ word: String, target: String, position: PhonemePosition) -> Bool {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return false }
        let normTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normTarget {
        case "sh":          return hasSH(w, position: position)
        case "mm", "m":     return hasM(w, position: position)
        case "ush":         return hasUSH(w, position: position)
        case "s":           return hasS(w, position: position)
        case "z":           return hasZ(w, position: position)
        case "f":           return hasF(w, position: position)
        case "v":           return hasV(w, position: position)
        case "th":          return hasTH(w, position: position)
        case "ch":          return hasCH(w, position: position)
        case "j", "dg":     return hasJ(w, position: position)
        case "ng":          return hasNG(w, position: position)
        case "l":           return hasL(w, position: position)
        case "r":           return hasR(w, position: position)
        case "k", "c":      return hasK(w, position: position)
        case "g":           return hasG(w, position: position)
        case "t":           return hasT(w, position: position)
        case "d":           return hasD(w, position: position)
        case "p":           return hasP(w, position: position)
        case "b":           return hasB(w, position: position)
        case "n":           return hasN(w, position: position)
        case "h":           return hasH(w, position: position)
        case "w":           return hasW(w, position: position)
        case "y":           return hasY(w, position: position)
        case "ee", "i":     return hasEE(w, position: position)
        case "ah", "a":     return hasAH(w, position: position)
        case "oo", "u":     return hasOO(w, position: position)
        case "e":           return hasEShort(w, position: position)
        case "o":           return hasOShort(w, position: position)
        default:
            // Unknown phoneme — fall back to substring match so nothing breaks
            return w.contains(normTarget)
        }
    }

    // MARK: - SH (/ʃ/)

    private func hasSH(_ w: String, position: PhonemePosition) -> Bool {
        // True /ʃ/ sources in English spelling:
        //   • digraph "sh" — shoe, fish, wish
        //   • "ti" before vowel in -tion, -tial — nation, partial
        //   • "ci" before vowel — special, musician
        //   • "ch" in French loan words — machine, chef, Chicago
        //   • "ss" before -ure/-ion — mission, passion, pressure
        //   • "s" before -ure — sure, sugar
        //
        // False friends to exclude: "sh" is NOT present in "pshaw" style
        // cases, but those are vanishingly rare in our library. We also
        // exclude "sch" in some loanwords like "school" (/sk/, not /ʃ/).

        // School/scheme/scholar — "sch" is /sk/ not /ʃ/
        if w.hasPrefix("school") || w.hasPrefix("schem") || w.hasPrefix("scholar") ||
           w.hasPrefix("schizo") || w.hasPrefix("schedule") {
            // Still might contain a real sh later — keep checking below.
        }

        if matchAt(w, pattern: "sh", position: position) { return true }
        if matchAt(w, pattern: "tion", position: position == .initial ? .anywhere : position) { return true }
        if matchAt(w, pattern: "sion", position: position == .initial ? .anywhere : position) { return true }
        if matchAt(w, pattern: "tial", position: position == .initial ? .anywhere : position) { return true }
        if matchAt(w, pattern: "cial", position: position == .initial ? .anywhere : position) { return true }
        if matchAt(w, pattern: "cian", position: position == .initial ? .anywhere : position) { return true }
        if matchAt(w, pattern: "ssure", position: .final) { return true }
        if w.hasPrefix("sure") || w.hasPrefix("sugar") { return position == .initial || position == .anywhere }
        // French-loan "ch" = /ʃ/ — limited list
        let frenchCh = ["machine", "chef", "chicago", "champagne", "chic", "chalet", "brochure", "parachute"]
        if frenchCh.contains(where: { w.contains($0) }) {
            return position == .anywhere || position == .initial
        }
        return false
    }

    // MARK: - M

    private func hasM(_ w: String, position: PhonemePosition) -> Bool {
        // M is one of the most reliable English graphemes — "m" is almost
        // always /m/. Silent "m" only shows up in "mnemonic" and that's /n/.
        if w.hasPrefix("mnemo") {
            // initial m silent, still /m/ nowhere? Actually "mnemonic" is /nɛ/
            // So skip the initial-only case.
            if position == .initial { return false }
        }
        return matchAt(w, pattern: "m", position: position)
    }

    // MARK: - USH (rhyming family)

    private func hasUSH(_ w: String, position: PhonemePosition) -> Bool {
        // "ush" is an audiologist target for CI users learning the
        // /ʊʃ/ or /ʌʃ/ rime. Match any word containing "ush", "ash",
        // "osh", "ish" (all the sh-rimes that contrast vowel coloring).
        let rimes = ["ush", "ash", "osh", "ish"]
        for r in rimes {
            if matchAt(w, pattern: r, position: position) { return true }
        }
        return false
    }

    // MARK: - S (/s/)

    private func hasS(_ w: String, position: PhonemePosition) -> Bool {
        // /s/ sources: "s" (not between vowels and not before voiced),
        // "ss", "c" before e/i/y, "sc" before e/i/y.
        // Exclude: "s" pronounced as /z/ in "rose", "s" in "sure" (already SH).
        if w == "sure" || w.hasPrefix("sugar") { return false }

        // Scan every "s" and check it's not the zh/sh/z variant
        let chars = Array(w)
        for i in 0..<chars.count {
            let c = chars[i]
            if c == "s" {
                // Skip "sh" (caught by SH), "si" before vowel (could be zh)
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if next == "h" { continue }
                // "s" between two vowels is often /z/ (rose, pose) but
                // can still be /s/ (basic). We keep it — conservative.
                if positionMatches(i: i, length: chars.count, position: position) {
                    return true
                }
            }
            // "c" before e, i, y → /s/
            if c == "c", i + 1 < chars.count {
                let nxt = chars[i + 1]
                if nxt == "e" || nxt == "i" || nxt == "y" {
                    if positionMatches(i: i, length: chars.count, position: position) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Z (/z/)

    private func hasZ(_ w: String, position: PhonemePosition) -> Bool {
        if matchAt(w, pattern: "z", position: position) { return true }
        // Final -s after voiced consonant or vowel (dogs, goes, days)
        if position == .final || position == .anywhere {
            let voicedFinal = ["gs", "ds", "ls", "ns", "rs", "bs", "ms", "vs", "ys", "ws", "es"]
            if voicedFinal.contains(where: { w.hasSuffix($0) }) { return true }
        }
        return false
    }

    // MARK: - F (/f/)

    private func hasF(_ w: String, position: PhonemePosition) -> Bool {
        if matchAt(w, pattern: "f", position: position) { return true }
        if matchAt(w, pattern: "ph", position: position) { return true }
        if matchAt(w, pattern: "gh", position: .final) && (position == .final || position == .anywhere) {
            // "gh" as /f/ in laugh, cough, enough, rough, tough
            let ghF = ["laugh", "cough", "enough", "rough", "tough", "trough"]
            if ghF.contains(where: { w.contains($0) }) { return true }
        }
        return false
    }

    // MARK: - V

    private func hasV(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "v", position: position)
    }

    // MARK: - TH (/θ/ or /ð/)

    private func hasTH(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "th", position: position)
    }

    // MARK: - CH (/tʃ/)

    private func hasCH(_ w: String, position: PhonemePosition) -> Bool {
        if matchAt(w, pattern: "ch", position: position) {
            // Exclude French ch (= /ʃ/) and Greek ch (= /k/)
            let excl = ["machine", "chef", "chicago", "chemistry", "chemical", "chorus", "christ", "school", "ache", "echo"]
            if excl.contains(where: { w.contains($0) }) { return false }
            return true
        }
        if matchAt(w, pattern: "tch", position: position) { return true }
        return false
    }

    // MARK: - J / DG

    private func hasJ(_ w: String, position: PhonemePosition) -> Bool {
        if matchAt(w, pattern: "j", position: position) { return true }
        if matchAt(w, pattern: "dge", position: position) { return true }
        if matchAt(w, pattern: "ge", position: .final) && (position == .final || position == .anywhere) { return true }
        // soft g before e, i, y — gym, giraffe, gentle
        if w.hasPrefix("gy") || w.hasPrefix("gi") || w.hasPrefix("ge") {
            return position == .initial || position == .anywhere
        }
        return false
    }

    // MARK: - NG

    private func hasNG(_ w: String, position: PhonemePosition) -> Bool {
        // NG is never initial in English. We allow medial or final.
        if position == .initial { return false }
        return matchAt(w, pattern: "ng", position: position)
    }

    // MARK: - L

    private func hasL(_ w: String, position: PhonemePosition) -> Bool {
        // "l" is usually /l/ but silent in walk/talk/half/would/could etc.
        if matchAt(w, pattern: "l", position: position) {
            let silent = ["walk", "talk", "half", "calf", "would", "could", "should", "yolk", "salmon", "palm", "calm", "balm"]
            if silent.contains(where: { w.contains($0) }) && position != .initial { return false }
            return true
        }
        return false
    }

    // MARK: - R

    private func hasR(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "r", position: position)
    }

    // MARK: - K

    private func hasK(_ w: String, position: PhonemePosition) -> Bool {
        if matchAt(w, pattern: "k", position: position) {
            // silent k — knee, knight, know, knock
            if w.hasPrefix("kn") && position == .initial { return false }
            return true
        }
        // "c" before a/o/u or consonant → /k/
        let chars = Array(w)
        for i in 0..<chars.count where chars[i] == "c" {
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if "aouhrlt".contains(next) || (next == " " && i == chars.count - 1) {
                if positionMatches(i: i, length: chars.count, position: position) { return true }
            }
        }
        if matchAt(w, pattern: "ck", position: position) { return true }
        if matchAt(w, pattern: "que", position: .final) && (position == .final || position == .anywhere) { return true }
        return false
    }

    // MARK: - G (hard)

    private func hasG(_ w: String, position: PhonemePosition) -> Bool {
        let chars = Array(w)
        for i in 0..<chars.count where chars[i] == "g" {
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            // soft g → /dʒ/, not /g/
            if "eiy".contains(next) { continue }
            // silent g — "gn" prefix, "gh" before vowel
            if i == 0 && next == "n" { continue }
            if next == "h" { continue }
            if positionMatches(i: i, length: chars.count, position: position) { return true }
        }
        return false
    }

    // MARK: - T, D, P, B, N, H, W, Y (simple)

    private func hasT(_ w: String, position: PhonemePosition) -> Bool {
        // Silent t in "listen", "castle", "whistle" — ignore for anywhere match,
        // just check letter presence.
        matchAt(w, pattern: "t", position: position)
    }
    private func hasD(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "d", position: position)
    }
    private func hasP(_ w: String, position: PhonemePosition) -> Bool {
        // silent p — pneumonia, psychology, psalm
        if w.hasPrefix("pn") || w.hasPrefix("ps") {
            if position == .initial { return false }
        }
        return matchAt(w, pattern: "p", position: position)
    }
    private func hasB(_ w: String, position: PhonemePosition) -> Bool {
        // silent b — lamb, comb, thumb, climb, debt, doubt
        let silentB = ["lamb", "comb", "thumb", "climb", "crumb", "dumb", "numb", "tomb", "womb", "debt", "doubt", "subtle"]
        if silentB.contains(where: { w.contains($0) }) && position != .initial { return false }
        return matchAt(w, pattern: "b", position: position)
    }
    private func hasN(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "n", position: position)
    }
    private func hasH(_ w: String, position: PhonemePosition) -> Bool {
        // silent h — hour, honest, honor, heir, rhyme, rhythm
        if position == .initial || position == .anywhere {
            let silent = ["hour", "honest", "honor", "heir"]
            if silent.contains(where: { w.hasPrefix($0) }) && position == .initial { return false }
        }
        return matchAt(w, pattern: "h", position: position)
    }
    private func hasW(_ w: String, position: PhonemePosition) -> Bool {
        // silent w — write, wrong, wrap, sword, two, answer
        if w.hasPrefix("wr") && position == .initial { return false }
        return matchAt(w, pattern: "w", position: position)
    }
    private func hasY(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "y", position: position)
    }

    // MARK: - Vowels (coarse)

    private func hasEE(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "ee", position: position) ||
        matchAt(w, pattern: "ea", position: position) ||
        matchAt(w, pattern: "ie", position: position) ||
        matchAt(w, pattern: "ei", position: position)
    }
    private func hasAH(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "a", position: position) ||
        matchAt(w, pattern: "o", position: position)   // "hot" vowel
    }
    private func hasOO(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "oo", position: position) ||
        matchAt(w, pattern: "ue", position: position) ||
        matchAt(w, pattern: "ew", position: position) ||
        matchAt(w, pattern: "u", position: position)
    }
    private func hasEShort(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "e", position: position) ||
        matchAt(w, pattern: "ea", position: position)
    }
    private func hasOShort(_ w: String, position: PhonemePosition) -> Bool {
        matchAt(w, pattern: "o", position: position)
    }

    // MARK: - Helpers

    /// Does `word` contain `pattern` at the requested position?
    private func matchAt(_ word: String, pattern: String, position: PhonemePosition) -> Bool {
        switch position {
        case .initial:
            return word.hasPrefix(pattern)
        case .final:
            return word.hasSuffix(pattern)
        case .medial:
            guard let range = word.range(of: pattern) else { return false }
            return range.lowerBound > word.startIndex && range.upperBound < word.endIndex
        case .anywhere:
            return word.contains(pattern)
        }
    }

    /// Index-based position check used by per-letter scans in hasS/hasK/hasG.
    private func positionMatches(i: Int, length: Int, position: PhonemePosition) -> Bool {
        switch position {
        case .initial:  return i == 0
        case .final:    return i == length - 1
        case .medial:   return i > 0 && i < length - 1
        case .anywhere: return true
        }
    }
}
