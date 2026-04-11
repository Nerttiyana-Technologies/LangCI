// SoundTherapyContent.swift
// LangCI — Built-in sound therapy content
//
// Curated exercise content for cochlear implant users.
// Sounds are ordered by typical CI difficulty (high-frequency
// fricatives are hardest). Minimal pairs target the most
// common confusions reported by CI users.

import Foundation

enum SoundTherapyContent {

    // MARK: - Target Sound Definitions

    static let allSounds: [TargetSoundDefinition] = [

        // ── Fricatives (most challenging for CI) ─────────────────────

        TargetSoundDefinition(
            sound: "sh", ipa: "/ʃ/", category: .fricatives,
            frequencyRange: "3500-8000 Hz",
            isolationForms: ["sh"],
            syllableForms: ["sha", "she", "shi", "sho", "shu"],
            wordForms: ["ship", "shop", "push", "fish", "shell", "shoe", "shower", "brush", "wish", "shout"],
            sentenceForms: [
                "She sells shells by the shore.",
                "The ship sailed through the shallow water.",
                "Please push the shopping cart.",
                "I wish I had a new shirt.",
                "The shiny shoe is in the closet."
            ],
            confusionPartners: ["s", "ch", "th"]
        ),

        TargetSoundDefinition(
            sound: "s", ipa: "/s/", category: .fricatives,
            frequencyRange: "4000-8000 Hz",
            isolationForms: ["s"],
            syllableForms: ["sa", "se", "si", "so", "su"],
            wordForms: ["sun", "sit", "bus", "ice", "sand", "soap", "six", "house", "class", "yes"],
            sentenceForms: [
                "The sun is shining in the sky.",
                "Please sit down on the seat.",
                "I saw six small snails.",
                "The house has a nice garden.",
                "She said yes to the surprise."
            ],
            confusionPartners: ["sh", "z", "th"]
        ),

        TargetSoundDefinition(
            sound: "f", ipa: "/f/", category: .fricatives,
            frequencyRange: "2500-8000 Hz",
            isolationForms: ["f"],
            syllableForms: ["fa", "fe", "fi", "fo", "fu"],
            wordForms: ["fish", "fun", "leaf", "off", "five", "food", "fast", "roof", "family", "farm"],
            sentenceForms: [
                "The fish swam in the fountain.",
                "We had fun at the farm.",
                "Five fingers on each hand.",
                "The food was fresh and tasty.",
                "A leaf fell from the tree."
            ],
            confusionPartners: ["th", "v", "p"]
        ),

        TargetSoundDefinition(
            sound: "th", ipa: "/θ/", category: .fricatives,
            frequencyRange: "4000-8000 Hz",
            isolationForms: ["th"],
            syllableForms: ["tha", "the", "thi", "tho", "thu"],
            wordForms: ["think", "bath", "three", "thumb", "tooth", "math", "thing", "path", "both", "mouth"],
            sentenceForms: [
                "I think three is a good number.",
                "She hurt her thumb on Thursday.",
                "Both of them took a bath.",
                "The path leads through the trees.",
                "My tooth is under my mouth."
            ],
            confusionPartners: ["f", "s", "t"]
        ),

        TargetSoundDefinition(
            sound: "z", ipa: "/z/", category: .fricatives,
            frequencyRange: "3500-7000 Hz",
            isolationForms: ["z"],
            syllableForms: ["za", "ze", "zi", "zo", "zu"],
            wordForms: ["zoo", "zip", "buzz", "nose", "zero", "zone", "zigzag", "prize", "freeze", "maze"],
            sentenceForms: [
                "We went to the zoo today.",
                "Please zip up your jacket.",
                "The bees buzz near the flowers.",
                "Zero is a round number.",
                "The maze was hard to solve."
            ],
            confusionPartners: ["s", "sh", "v"]
        ),

        TargetSoundDefinition(
            sound: "v", ipa: "/v/", category: .fricatives,
            frequencyRange: "2000-6000 Hz",
            isolationForms: ["v"],
            syllableForms: ["va", "ve", "vi", "vo", "vu"],
            wordForms: ["van", "very", "love", "five", "vine", "voice", "vowel", "wave", "over", "violin"],
            sentenceForms: [
                "The van drove over the bridge.",
                "I love the view from the valley.",
                "Her voice is very lovely.",
                "Five violins played at the show.",
                "The wave washed over the sand."
            ],
            confusionPartners: ["f", "b", "w"]
        ),

        // ── Nasals ──────────────────────────────────────────────────

        TargetSoundDefinition(
            sound: "m", ipa: "/m/", category: .nasals,
            frequencyRange: "150-500 Hz",
            isolationForms: ["mm"],
            syllableForms: ["ma", "me", "mi", "mo", "mu"],
            wordForms: ["mom", "man", "milk", "time", "come", "more", "moon", "home", "name", "small"],
            sentenceForms: [
                "Mom made me some warm milk.",
                "The moon came out at midnight.",
                "My name starts with the letter M.",
                "Come home when the music stops.",
                "The small mouse ate some cream."
            ],
            confusionPartners: ["n", "ng"]
        ),

        TargetSoundDefinition(
            sound: "n", ipa: "/n/", category: .nasals,
            frequencyRange: "200-600 Hz",
            isolationForms: ["nn"],
            syllableForms: ["na", "ne", "ni", "no", "nu"],
            wordForms: ["no", "run", "new", "nine", "noon", "rain", "moon", "nice", "bone", "nurse"],
            sentenceForms: [
                "Nine nice nurses ran to noon.",
                "No one knew about the news.",
                "The rain fell on the new barn.",
                "A bone lay near the fence.",
                "She is a very nice friend."
            ],
            confusionPartners: ["m", "ng", "d"]
        ),

        TargetSoundDefinition(
            sound: "ng", ipa: "/ŋ/", category: .nasals,
            frequencyRange: "200-500 Hz",
            isolationForms: ["ng"],
            syllableForms: ["ang", "eng", "ing", "ong", "ung"],
            wordForms: ["ring", "sing", "long", "king", "song", "hang", "thing", "young", "wrong", "spring"],
            sentenceForms: [
                "The king sang a long song.",
                "Hang the ring on the string.",
                "The young bird can sing.",
                "Something is wrong with the swing.",
                "Spring brings everything to life."
            ],
            confusionPartners: ["n", "m", "nk"]
        ),

        // ── Plosives ────────────────────────────────────────────────

        TargetSoundDefinition(
            sound: "p", ipa: "/p/", category: .plosives,
            frequencyRange: "1000-5000 Hz",
            isolationForms: ["p"],
            syllableForms: ["pa", "pe", "pi", "po", "pu"],
            wordForms: ["pen", "cup", "play", "park", "pig", "pop", "put", "map", "keep", "cap"],
            sentenceForms: [
                "Put the pen in the cup.",
                "The pig plays in the park.",
                "Pop the cap off the top.",
                "Please keep the map safe.",
                "I plan to paint the pot."
            ],
            confusionPartners: ["b", "t", "f"]
        ),

        TargetSoundDefinition(
            sound: "b", ipa: "/b/", category: .plosives,
            frequencyRange: "800-4000 Hz",
            isolationForms: ["b"],
            syllableForms: ["ba", "be", "bi", "bo", "bu"],
            wordForms: ["ball", "bed", "big", "book", "bus", "bird", "bag", "box", "baby", "boat"],
            sentenceForms: [
                "The big bird sat on the bed.",
                "Put the ball in the box.",
                "The baby ate a banana.",
                "The boat sailed past the bridge.",
                "I bought a blue book bag."
            ],
            confusionPartners: ["p", "d", "v"]
        ),

        TargetSoundDefinition(
            sound: "t", ipa: "/t/", category: .plosives,
            frequencyRange: "2000-6000 Hz",
            isolationForms: ["t"],
            syllableForms: ["ta", "te", "ti", "to", "tu"],
            wordForms: ["top", "cat", "two", "time", "ten", "tree", "table", "hot", "boat", "right"],
            sentenceForms: [
                "The cat sat on top of the table.",
                "Two tall trees grow on the hill.",
                "Tell me the time please.",
                "Ten tigers ate at the tent.",
                "That coat is too tight."
            ],
            confusionPartners: ["d", "p", "k"]
        ),

        TargetSoundDefinition(
            sound: "d", ipa: "/d/", category: .plosives,
            frequencyRange: "1500-5000 Hz",
            isolationForms: ["d"],
            syllableForms: ["da", "de", "di", "do", "du"],
            wordForms: ["dog", "bed", "door", "do", "dad", "day", "red", "hand", "old", "good"],
            sentenceForms: [
                "The dog dug under the door.",
                "Dad had a good day today.",
                "The red bird landed on my hand.",
                "Do your best every day.",
                "The old door made a loud sound."
            ],
            confusionPartners: ["t", "b", "g"]
        ),

        // ── Affricates ──────────────────────────────────────────────

        TargetSoundDefinition(
            sound: "ch", ipa: "/tʃ/", category: .affricates,
            frequencyRange: "2500-8000 Hz",
            isolationForms: ["ch"],
            syllableForms: ["cha", "che", "chi", "cho", "chu"],
            wordForms: ["chair", "cheese", "chip", "lunch", "church", "catch", "watch", "much", "beach", "child"],
            sentenceForms: [
                "The child ate cheese for lunch.",
                "We watched birds at the beach.",
                "Sit on the chair in the church.",
                "Catch the ball with both hands.",
                "I chose chocolate chip ice cream."
            ],
            confusionPartners: ["sh", "t", "j"]
        ),

        // ── Vowels ──────────────────────────────────────────────────

        TargetSoundDefinition(
            sound: "ee", ipa: "/iː/", category: .vowels,
            frequencyRange: "300-3000 Hz",
            isolationForms: ["ee"],
            syllableForms: ["bee", "fee", "key", "me", "see"],
            wordForms: ["tree", "sea", "green", "sleep", "keep", "feet", "read", "team", "clean", "street"],
            sentenceForms: [
                "The green tree stands by the sea.",
                "Keep your feet clean please.",
                "I need to sleep before the meeting.",
                "The team will read the sheet.",
                "Three bees flew down the street."
            ],
            confusionPartners: ["ih", "ay", "oo"]
        ),

        TargetSoundDefinition(
            sound: "oo", ipa: "/uː/", category: .vowels,
            frequencyRange: "250-2500 Hz",
            isolationForms: ["oo"],
            syllableForms: ["boo", "moo", "too", "zoo", "coo"],
            wordForms: ["moon", "food", "blue", "shoe", "pool", "cool", "room", "noon", "school", "spoon"],
            sentenceForms: [
                "The moon shone over the pool.",
                "We ate food at noon in the room.",
                "The cool blue pool felt good.",
                "Take a spoon to school tomorrow.",
                "The goose flew over the roof."
            ],
            confusionPartners: ["ee", "uh", "oh"]
        ),

        // ── Blends ──────────────────────────────────────────────────

        TargetSoundDefinition(
            sound: "ush", ipa: "/ʌʃ/", category: .blends,
            frequencyRange: "500-8000 Hz",
            isolationForms: ["ush"],
            syllableForms: ["ush", "usha", "ushe", "usho"],
            wordForms: ["push", "bush", "rush", "crush", "gush", "hush", "blush", "brush", "mush", "lush"],
            sentenceForms: [
                "Please push past the bush.",
                "She had to rush to brush her hair.",
                "Hush now, do not crush the flowers.",
                "The lush garden was behind the bush.",
                "He began to blush with a gush of feeling."
            ],
            confusionPartners: ["us", "uch", "ush"]
        ),

        TargetSoundDefinition(
            sound: "ash", ipa: "/æʃ/", category: .blends,
            frequencyRange: "500-8000 Hz",
            isolationForms: ["ash"],
            syllableForms: ["ash", "asha", "ashe", "asho"],
            wordForms: ["cash", "crash", "flash", "trash", "dash", "splash", "smash", "rash", "lash", "hash"],
            sentenceForms: [
                "The car made a loud crash.",
                "A flash of light lit the dash.",
                "Please put the trash in the can.",
                "Water made a big splash.",
                "She paid with cash at the shop."
            ],
            confusionPartners: ["as", "ach", "ath"]
        ),
    ]

    // MARK: - Minimal Pairs (curated for CI confusions)

    static let minimalPairs: [SoundMinimalPairItem] = [
        // sh vs s (most common CI confusion)
        SoundMinimalPairItem(sound1: "ship", sound2: "sip", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 1),
        SoundMinimalPairItem(sound1: "shoe", sound2: "sue", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 1),
        SoundMinimalPairItem(sound1: "share", sound2: "stare", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 2),
        SoundMinimalPairItem(sound1: "shell", sound2: "sell", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 1),
        SoundMinimalPairItem(sound1: "shin", sound2: "sin", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 1),
        SoundMinimalPairItem(sound1: "shave", sound2: "save", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 2),
        SoundMinimalPairItem(sound1: "shock", sound2: "sock", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 1),
        SoundMinimalPairItem(sound1: "sheep", sound2: "seep", phoneme1: "sh", phoneme2: "s", contrastLabel: "sh vs s", difficulty: 2),

        // sh vs ch
        SoundMinimalPairItem(sound1: "share", sound2: "chair", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 2),
        SoundMinimalPairItem(sound1: "ship", sound2: "chip", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 2),
        SoundMinimalPairItem(sound1: "sheep", sound2: "cheap", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 2),
        SoundMinimalPairItem(sound1: "shore", sound2: "chore", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 3),
        SoundMinimalPairItem(sound1: "wash", sound2: "watch", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 2),
        SoundMinimalPairItem(sound1: "mash", sound2: "match", phoneme1: "sh", phoneme2: "ch", contrastLabel: "sh vs ch", difficulty: 3),

        // m vs n (nasal confusion)
        SoundMinimalPairItem(sound1: "map", sound2: "nap", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),
        SoundMinimalPairItem(sound1: "mat", sound2: "gnat", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 2),
        SoundMinimalPairItem(sound1: "mice", sound2: "nice", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),
        SoundMinimalPairItem(sound1: "might", sound2: "night", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),
        SoundMinimalPairItem(sound1: "met", sound2: "net", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),
        SoundMinimalPairItem(sound1: "mug", sound2: "nut", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 2),
        SoundMinimalPairItem(sound1: "mow", sound2: "no", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),
        SoundMinimalPairItem(sound1: "mail", sound2: "nail", phoneme1: "m", phoneme2: "n", contrastLabel: "m vs n", difficulty: 1),

        // f vs th
        SoundMinimalPairItem(sound1: "fin", sound2: "thin", phoneme1: "f", phoneme2: "th", contrastLabel: "f vs th", difficulty: 3),
        SoundMinimalPairItem(sound1: "free", sound2: "three", phoneme1: "f", phoneme2: "th", contrastLabel: "f vs th", difficulty: 2),
        SoundMinimalPairItem(sound1: "fought", sound2: "thought", phoneme1: "f", phoneme2: "th", contrastLabel: "f vs th", difficulty: 3),
        SoundMinimalPairItem(sound1: "reef", sound2: "wreath", phoneme1: "f", phoneme2: "th", contrastLabel: "f vs th", difficulty: 4),

        // p vs b (voiced/unvoiced)
        SoundMinimalPairItem(sound1: "pat", sound2: "bat", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 1),
        SoundMinimalPairItem(sound1: "pin", sound2: "bin", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 1),
        SoundMinimalPairItem(sound1: "pull", sound2: "bull", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 2),
        SoundMinimalPairItem(sound1: "pear", sound2: "bear", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 1),
        SoundMinimalPairItem(sound1: "cap", sound2: "cab", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 2),
        SoundMinimalPairItem(sound1: "pie", sound2: "buy", phoneme1: "p", phoneme2: "b", contrastLabel: "p vs b", difficulty: 1),

        // t vs d (voiced/unvoiced)
        SoundMinimalPairItem(sound1: "ten", sound2: "den", phoneme1: "t", phoneme2: "d", contrastLabel: "t vs d", difficulty: 1),
        SoundMinimalPairItem(sound1: "tie", sound2: "die", phoneme1: "t", phoneme2: "d", contrastLabel: "t vs d", difficulty: 1),
        SoundMinimalPairItem(sound1: "time", sound2: "dime", phoneme1: "t", phoneme2: "d", contrastLabel: "t vs d", difficulty: 2),
        SoundMinimalPairItem(sound1: "bat", sound2: "bad", phoneme1: "t", phoneme2: "d", contrastLabel: "t vs d", difficulty: 2),
        SoundMinimalPairItem(sound1: "coat", sound2: "code", phoneme1: "t", phoneme2: "d", contrastLabel: "t vs d", difficulty: 3),

        // s vs z
        SoundMinimalPairItem(sound1: "sip", sound2: "zip", phoneme1: "s", phoneme2: "z", contrastLabel: "s vs z", difficulty: 2),
        SoundMinimalPairItem(sound1: "sue", sound2: "zoo", phoneme1: "s", phoneme2: "z", contrastLabel: "s vs z", difficulty: 1),
        SoundMinimalPairItem(sound1: "seal", sound2: "zeal", phoneme1: "s", phoneme2: "z", contrastLabel: "s vs z", difficulty: 3),
        SoundMinimalPairItem(sound1: "bus", sound2: "buzz", phoneme1: "s", phoneme2: "z", contrastLabel: "s vs z", difficulty: 2),
        SoundMinimalPairItem(sound1: "ice", sound2: "eyes", phoneme1: "s", phoneme2: "z", contrastLabel: "s vs z", difficulty: 3),

        // f vs v
        SoundMinimalPairItem(sound1: "fan", sound2: "van", phoneme1: "f", phoneme2: "v", contrastLabel: "f vs v", difficulty: 2),
        SoundMinimalPairItem(sound1: "fine", sound2: "vine", phoneme1: "f", phoneme2: "v", contrastLabel: "f vs v", difficulty: 2),
        SoundMinimalPairItem(sound1: "few", sound2: "view", phoneme1: "f", phoneme2: "v", contrastLabel: "f vs v", difficulty: 3),
        SoundMinimalPairItem(sound1: "leaf", sound2: "leave", phoneme1: "f", phoneme2: "v", contrastLabel: "f vs v", difficulty: 3),
        SoundMinimalPairItem(sound1: "safe", sound2: "save", phoneme1: "f", phoneme2: "v", contrastLabel: "f vs v", difficulty: 2),

        // ee (female easier) vs male
        SoundMinimalPairItem(sound1: "beat", sound2: "bit", phoneme1: "ee", phoneme2: "ih", contrastLabel: "ee vs ih", difficulty: 2),
        SoundMinimalPairItem(sound1: "feet", sound2: "fit", phoneme1: "ee", phoneme2: "ih", contrastLabel: "ee vs ih", difficulty: 2),
        SoundMinimalPairItem(sound1: "sheep", sound2: "ship", phoneme1: "ee", phoneme2: "ih", contrastLabel: "ee vs ih", difficulty: 1),
        SoundMinimalPairItem(sound1: "seat", sound2: "sit", phoneme1: "ee", phoneme2: "ih", contrastLabel: "ee vs ih", difficulty: 1),
        SoundMinimalPairItem(sound1: "peel", sound2: "pill", phoneme1: "ee", phoneme2: "ih", contrastLabel: "ee vs ih", difficulty: 2),
    ]

    // MARK: - Helpers

    /// Get all sounds in a category
    static func sounds(for category: SoundCategory) -> [TargetSoundDefinition] {
        allSounds.filter { $0.category == category }
    }

    /// Get a specific sound definition
    static func sound(named name: String) -> TargetSoundDefinition? {
        allSounds.first { $0.sound == name }
    }

    /// Get minimal pairs for a specific contrast
    static func minimalPairs(for contrast: String) -> [SoundMinimalPairItem] {
        minimalPairs.filter { $0.contrastLabel == contrast }
    }

    /// Get minimal pairs involving a specific sound
    static func minimalPairs(involving sound: String) -> [SoundMinimalPairItem] {
        minimalPairs.filter { $0.phoneme1 == sound || $0.phoneme2 == sound }
    }

    /// All unique contrast labels
    static var allContrasts: [String] {
        Array(Set(minimalPairs.map(\.contrastLabel))).sorted()
    }

    /// Sounds ordered by CI difficulty (hardest first)
    static var soundsByDifficulty: [TargetSoundDefinition] {
        // High-frequency fricatives first, then affricates, then lower frequency sounds
        let order: [SoundCategory] = [.fricatives, .affricates, .blends, .nasals, .plosives, .vowels]
        return order.flatMap { cat in sounds(for: cat) }
    }
}
