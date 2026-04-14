// CustomVoicePromptModels.swift
// LangCI — Custom voice prompts for Voice Library
//
// Allows family members (wife, audiologist, etc.) to add custom Tamil
// words, phrases, or sentences that they want to record and use for
// cochlear implant training. Includes pre-built Tamil word categories
// AND free text entry.

import Foundation

// MARK: - Custom Voice Prompt

/// A user-created voice recording prompt — either from a pre-built
/// Tamil category or typed as free text.
struct CustomVoicePrompt: Identifiable, Codable {
    var id: Int
    var text: String              // The Tamil text to speak: "வணக்கம்"
    var transliteration: String   // Romanised: "Vanakkam"
    var meaning: String           // English meaning: "Hello"
    var category: String          // "greetings", "family", "custom", etc.
    var createdBy: Int?           // FK → RecordedPerson.id (who added it)
    var isBuiltIn: Bool           // true for pre-built Tamil categories
    var createdAt: Date

    /// Prompt ID for voice recording grouping
    var promptId: String {
        "custom_\(id)"
    }
}

// MARK: - Tamil Word Categories

/// Pre-built Tamil word/phrase categories for CI training.
/// Organised from easiest (short, familiar) to harder (longer sentences).
struct TamilWordCategory: Identifiable {
    let id: String               // "greetings", "family", etc.
    let title: String            // "Greetings"
    let tamilTitle: String       // "வாழ்த்துக்கள்"
    let icon: String             // SF Symbol
    let color: String            // "lcPurple", etc.
    let words: [TamilWord]
}

struct TamilWord: Identifiable {
    let id: String
    let tamil: String            // Tamil script
    let transliteration: String  // Romanised
    let meaning: String          // English
}

// MARK: - Pre-built categories

extension TamilWordCategory {

    static let allCategories: [TamilWordCategory] = [
        // Audiologist-recommended difficulty categories first
        sVsSh, shEndings, sPositions, sVsShTamil,
        rSounds, similarSyllables, consonantPairs, minimalPairsEnglish,
        // General Tamil categories
        greetings, family, numbers, bodyParts, food, household,
        emotions, dailyPhrases, questions, directions
    ]

    static let greetings = TamilWordCategory(
        id: "greetings", title: "Greetings", tamilTitle: "வாழ்த்துக்கள்",
        icon: "hand.wave.fill", color: "lcAmber",
        words: [
            TamilWord(id: "g1", tamil: "வணக்கம்", transliteration: "Vanakkam", meaning: "Hello"),
            TamilWord(id: "g2", tamil: "நன்றி", transliteration: "Nandri", meaning: "Thank you"),
            TamilWord(id: "g3", tamil: "காலை வணக்கம்", transliteration: "Kaalai Vanakkam", meaning: "Good morning"),
            TamilWord(id: "g4", tamil: "மாலை வணக்கம்", transliteration: "Maalai Vanakkam", meaning: "Good evening"),
            TamilWord(id: "g5", tamil: "இரவு வணக்கம்", transliteration: "Iravu Vanakkam", meaning: "Good night"),
            TamilWord(id: "g6", tamil: "எப்படி இருக்கீங்க?", transliteration: "Eppadi Irukkeenga?", meaning: "How are you?"),
            TamilWord(id: "g7", tamil: "நல்லா இருக்கேன்", transliteration: "Nalla Irukken", meaning: "I am fine"),
            TamilWord(id: "g8", tamil: "போய்ட்டு வர்றேன்", transliteration: "Poittu Varren", meaning: "I'll go and come back"),
            TamilWord(id: "g9", tamil: "வா", transliteration: "Vaa", meaning: "Come"),
            TamilWord(id: "g10", tamil: "போ", transliteration: "Po", meaning: "Go"),
        ])

    static let family = TamilWordCategory(
        id: "family", title: "Family", tamilTitle: "குடும்பம்",
        icon: "figure.2.and.child.holdinghands", color: "lcPurple",
        words: [
            TamilWord(id: "f1", tamil: "அம்மா", transliteration: "Amma", meaning: "Mother"),
            TamilWord(id: "f2", tamil: "அப்பா", transliteration: "Appa", meaning: "Father"),
            TamilWord(id: "f3", tamil: "அக்கா", transliteration: "Akka", meaning: "Elder sister"),
            TamilWord(id: "f4", tamil: "அண்ணா", transliteration: "Anna", meaning: "Elder brother"),
            TamilWord(id: "f5", tamil: "தம்பி", transliteration: "Thambi", meaning: "Younger brother"),
            TamilWord(id: "f6", tamil: "தங்கை", transliteration: "Thangai", meaning: "Younger sister"),
            TamilWord(id: "f7", tamil: "மகன்", transliteration: "Magan", meaning: "Son"),
            TamilWord(id: "f8", tamil: "மகள்", transliteration: "Magal", meaning: "Daughter"),
            TamilWord(id: "f9", tamil: "பாட்டி", transliteration: "Paatti", meaning: "Grandmother"),
            TamilWord(id: "f10", tamil: "தாத்தா", transliteration: "Thaaththa", meaning: "Grandfather"),
        ])

    static let numbers = TamilWordCategory(
        id: "numbers", title: "Numbers", tamilTitle: "எண்கள்",
        icon: "number", color: "lcBlue",
        words: [
            TamilWord(id: "n1", tamil: "ஒன்று", transliteration: "Ondru", meaning: "One"),
            TamilWord(id: "n2", tamil: "இரண்டு", transliteration: "Irandu", meaning: "Two"),
            TamilWord(id: "n3", tamil: "மூன்று", transliteration: "Moondru", meaning: "Three"),
            TamilWord(id: "n4", tamil: "நான்கு", transliteration: "Naangu", meaning: "Four"),
            TamilWord(id: "n5", tamil: "ஐந்து", transliteration: "Ainthu", meaning: "Five"),
            TamilWord(id: "n6", tamil: "ஆறு", transliteration: "Aaru", meaning: "Six"),
            TamilWord(id: "n7", tamil: "ஏழு", transliteration: "Ezhu", meaning: "Seven"),
            TamilWord(id: "n8", tamil: "எட்டு", transliteration: "Ettu", meaning: "Eight"),
            TamilWord(id: "n9", tamil: "ஒன்பது", transliteration: "Onbadhu", meaning: "Nine"),
            TamilWord(id: "n10", tamil: "பத்து", transliteration: "Paththu", meaning: "Ten"),
        ])

    static let bodyParts = TamilWordCategory(
        id: "body_parts", title: "Body Parts", tamilTitle: "உடல் உறுப்புகள்",
        icon: "figure.stand", color: "lcTeal",
        words: [
            TamilWord(id: "b1", tamil: "தலை", transliteration: "Thalai", meaning: "Head"),
            TamilWord(id: "b2", tamil: "கண்", transliteration: "Kan", meaning: "Eye"),
            TamilWord(id: "b3", tamil: "காது", transliteration: "Kaathu", meaning: "Ear"),
            TamilWord(id: "b4", tamil: "மூக்கு", transliteration: "Mookku", meaning: "Nose"),
            TamilWord(id: "b5", tamil: "வாய்", transliteration: "Vaai", meaning: "Mouth"),
            TamilWord(id: "b6", tamil: "கை", transliteration: "Kai", meaning: "Hand"),
            TamilWord(id: "b7", tamil: "கால்", transliteration: "Kaal", meaning: "Leg"),
            TamilWord(id: "b8", tamil: "விரல்", transliteration: "Viral", meaning: "Finger"),
            TamilWord(id: "b9", tamil: "பல்", transliteration: "Pal", meaning: "Tooth"),
            TamilWord(id: "b10", tamil: "முடி", transliteration: "Mudi", meaning: "Hair"),
        ])

    static let food = TamilWordCategory(
        id: "food", title: "Food & Drink", tamilTitle: "உணவு",
        icon: "fork.knife", color: "lcOrange",
        words: [
            TamilWord(id: "fd1", tamil: "சாப்பாடு", transliteration: "Saappaadu", meaning: "Food/Meal"),
            TamilWord(id: "fd2", tamil: "தண்ணீர்", transliteration: "Thanneer", meaning: "Water"),
            TamilWord(id: "fd3", tamil: "சோறு", transliteration: "Soru", meaning: "Rice"),
            TamilWord(id: "fd4", tamil: "சாம்பார்", transliteration: "Saambaar", meaning: "Sambar"),
            TamilWord(id: "fd5", tamil: "ரசம்", transliteration: "Rasam", meaning: "Rasam"),
            TamilWord(id: "fd6", tamil: "தயிர்", transliteration: "Thayir", meaning: "Curd/Yogurt"),
            TamilWord(id: "fd7", tamil: "காபி", transliteration: "Kaapi", meaning: "Coffee"),
            TamilWord(id: "fd8", tamil: "தேநீர்", transliteration: "Theneer", meaning: "Tea"),
            TamilWord(id: "fd9", tamil: "இட்லி", transliteration: "Idli", meaning: "Idli"),
            TamilWord(id: "fd10", tamil: "தோசை", transliteration: "Dosai", meaning: "Dosa"),
        ])

    static let household = TamilWordCategory(
        id: "household", title: "Household", tamilTitle: "வீட்டு பொருட்கள்",
        icon: "house.fill", color: "lcGreen",
        words: [
            TamilWord(id: "h1", tamil: "கதவு", transliteration: "Kadhavu", meaning: "Door"),
            TamilWord(id: "h2", tamil: "ஜன்னல்", transliteration: "Jannal", meaning: "Window"),
            TamilWord(id: "h3", tamil: "விளக்கு", transliteration: "Vilakku", meaning: "Light/Lamp"),
            TamilWord(id: "h4", tamil: "நாற்காலி", transliteration: "Naarkaali", meaning: "Chair"),
            TamilWord(id: "h5", tamil: "மேஜை", transliteration: "Mejai", meaning: "Table"),
            TamilWord(id: "h6", tamil: "படுக்கை", transliteration: "Padukkai", meaning: "Bed"),
            TamilWord(id: "h7", tamil: "குடை", transliteration: "Kudai", meaning: "Umbrella"),
            TamilWord(id: "h8", tamil: "சாவி", transliteration: "Saavi", meaning: "Key"),
            TamilWord(id: "h9", tamil: "கண்ணாடி", transliteration: "Kannaadi", meaning: "Mirror/Glass"),
            TamilWord(id: "h10", tamil: "தொலைக்காட்சி", transliteration: "Tholaikkaatchi", meaning: "Television"),
        ])

    static let emotions = TamilWordCategory(
        id: "emotions", title: "Emotions", tamilTitle: "உணர்வுகள்",
        icon: "face.smiling.fill", color: "lcGold",
        words: [
            TamilWord(id: "e1", tamil: "மகிழ்ச்சி", transliteration: "Magizhchi", meaning: "Happiness"),
            TamilWord(id: "e2", tamil: "சிரிப்பு", transliteration: "Sirippu", meaning: "Laughter"),
            TamilWord(id: "e3", tamil: "அழுகை", transliteration: "Azhukai", meaning: "Crying"),
            TamilWord(id: "e4", tamil: "கோபம்", transliteration: "Kobam", meaning: "Anger"),
            TamilWord(id: "e5", tamil: "பயம்", transliteration: "Bayam", meaning: "Fear"),
            TamilWord(id: "e6", tamil: "அன்பு", transliteration: "Anbu", meaning: "Love"),
            TamilWord(id: "e7", tamil: "ஆச்சர்யம்", transliteration: "Aacharyam", meaning: "Surprise"),
            TamilWord(id: "e8", tamil: "சோகம்", transliteration: "Sogam", meaning: "Sadness"),
            TamilWord(id: "e9", tamil: "நம்பிக்கை", transliteration: "Nambikkai", meaning: "Hope/Trust"),
            TamilWord(id: "e10", tamil: "தைரியம்", transliteration: "Dhairiyam", meaning: "Courage"),
        ])

    static let dailyPhrases = TamilWordCategory(
        id: "daily_phrases", title: "Daily Phrases", tamilTitle: "தினசரி வாக்கியங்கள்",
        icon: "text.bubble.fill", color: "lcRed",
        words: [
            TamilWord(id: "dp1", tamil: "சாப்பிட்டீங்களா?", transliteration: "Saapittingala?", meaning: "Have you eaten?"),
            TamilWord(id: "dp2", tamil: "வீட்டுக்கு போகலாம்", transliteration: "Veettukku Pogalaam", meaning: "Let's go home"),
            TamilWord(id: "dp3", tamil: "என்ன விலை?", transliteration: "Enna Vilai?", meaning: "What's the price?"),
            TamilWord(id: "dp4", tamil: "கொஞ்சம் பொறுங்க", transliteration: "Konjam Porunga", meaning: "Please wait a moment"),
            TamilWord(id: "dp5", tamil: "மழை வருது", transliteration: "Mazhai Varudhu", meaning: "It's raining"),
            TamilWord(id: "dp6", tamil: "நேரம் என்ன?", transliteration: "Neram Enna?", meaning: "What time is it?"),
            TamilWord(id: "dp7", tamil: "சரி வரேன்", transliteration: "Sari Varen", meaning: "OK, I'm coming"),
            TamilWord(id: "dp8", tamil: "பசிக்குது", transliteration: "Pasikkudhu", meaning: "I'm hungry"),
            TamilWord(id: "dp9", tamil: "தூக்கம் வருது", transliteration: "Thookkam Varudhu", meaning: "I'm sleepy"),
            TamilWord(id: "dp10", tamil: "மருந்து சாப்பிடு", transliteration: "Marundhu Saappidu", meaning: "Take your medicine"),
        ])

    static let questions = TamilWordCategory(
        id: "questions", title: "Questions", tamilTitle: "கேள்விகள்",
        icon: "questionmark.bubble.fill", color: "lcBlue",
        words: [
            TamilWord(id: "q1", tamil: "என்ன?", transliteration: "Enna?", meaning: "What?"),
            TamilWord(id: "q2", tamil: "ஏன்?", transliteration: "Yen?", meaning: "Why?"),
            TamilWord(id: "q3", tamil: "எப்போ?", transliteration: "Eppo?", meaning: "When?"),
            TamilWord(id: "q4", tamil: "எங்கே?", transliteration: "Engey?", meaning: "Where?"),
            TamilWord(id: "q5", tamil: "யாரு?", transliteration: "Yaaru?", meaning: "Who?"),
            TamilWord(id: "q6", tamil: "எப்படி?", transliteration: "Eppadi?", meaning: "How?"),
            TamilWord(id: "q7", tamil: "எவ்வளவு?", transliteration: "Evvalavu?", meaning: "How much?"),
            TamilWord(id: "q8", tamil: "எது?", transliteration: "Edhu?", meaning: "Which?"),
            TamilWord(id: "q9", tamil: "இது என்ன?", transliteration: "Idhu Enna?", meaning: "What is this?"),
            TamilWord(id: "q10", tamil: "புரியுதா?", transliteration: "Puriyudhaa?", meaning: "Do you understand?"),
        ])

    static let directions = TamilWordCategory(
        id: "directions", title: "Directions & Actions", tamilTitle: "திசைகள்",
        icon: "arrow.triangle.turn.up.right.diamond.fill", color: "lcTeal",
        words: [
            TamilWord(id: "d1", tamil: "வலது", transliteration: "Valadhu", meaning: "Right"),
            TamilWord(id: "d2", tamil: "இடது", transliteration: "Idadhu", meaning: "Left"),
            TamilWord(id: "d3", tamil: "மேலே", transliteration: "Meley", meaning: "Up/Above"),
            TamilWord(id: "d4", tamil: "கீழே", transliteration: "Keezhey", meaning: "Down/Below"),
            TamilWord(id: "d5", tamil: "நில்லு", transliteration: "Nillu", meaning: "Stop"),
            TamilWord(id: "d6", tamil: "உட்காரு", transliteration: "Utkaaru", meaning: "Sit down"),
            TamilWord(id: "d7", tamil: "எழுந்திரு", transliteration: "Ezhundhiru", meaning: "Stand up"),
            TamilWord(id: "d8", tamil: "கொண்டு வா", transliteration: "Kondu Vaa", meaning: "Bring it"),
            TamilWord(id: "d9", tamil: "பாரு", transliteration: "Paaru", meaning: "Look/See"),
            TamilWord(id: "d10", tamil: "கேளு", transliteration: "Kelu", meaning: "Listen/Ask"),
        ])

    // MARK: - Audiologist-Recommended Difficulty Categories

    /// /s/ vs /sh/ — fricative confusion is very common in early CI users
    /// Expanded: CI mapping sibilants to /e/ — need heavy repetition
    static let sVsSh = TamilWordCategory(
        id: "s_vs_sh", title: "/s/ vs /sh/ Pairs", tamilTitle: "ச vs ஷ ஜோடி",
        icon: "waveform.badge.magnifyingglass", color: "lcRed",
        words: [
            // English minimal pairs — s vs sh at word start
            TamilWord(id: "ss1", tamil: "sip", transliteration: "Sip", meaning: "Drink slowly"),
            TamilWord(id: "ss2", tamil: "ship", transliteration: "Ship", meaning: "Boat"),
            TamilWord(id: "ss3", tamil: "see", transliteration: "See", meaning: "Look"),
            TamilWord(id: "ss4", tamil: "she", transliteration: "She", meaning: "Her"),
            TamilWord(id: "ss5", tamil: "so", transliteration: "So", meaning: "Therefore"),
            TamilWord(id: "ss6", tamil: "show", transliteration: "Show", meaning: "Display"),
            TamilWord(id: "ss7", tamil: "suit", transliteration: "Suit", meaning: "Formal wear"),
            TamilWord(id: "ss8", tamil: "shoot", transliteration: "Shoot", meaning: "Fire"),
            TamilWord(id: "ss9", tamil: "save", transliteration: "Save", meaning: "Keep safe"),
            TamilWord(id: "ss10", tamil: "shave", transliteration: "Shave", meaning: "Cut hair"),
            TamilWord(id: "ss11", tamil: "seat", transliteration: "Seat", meaning: "Chair"),
            TamilWord(id: "ss12", tamil: "sheet", transliteration: "Sheet", meaning: "Cloth/Paper"),
            TamilWord(id: "ss13", tamil: "sort", transliteration: "Sort", meaning: "Arrange"),
            TamilWord(id: "ss14", tamil: "short", transliteration: "Short", meaning: "Not tall"),
            TamilWord(id: "ss15", tamil: "sin", transliteration: "Sin", meaning: "Wrong deed"),
            TamilWord(id: "ss16", tamil: "shin", transliteration: "Shin", meaning: "Front of leg"),
            TamilWord(id: "ss17", tamil: "sore", transliteration: "Sore", meaning: "Painful"),
            TamilWord(id: "ss18", tamil: "shore", transliteration: "Shore", meaning: "Beach"),
            TamilWord(id: "ss19", tamil: "sell", transliteration: "Sell", meaning: "Trade"),
            TamilWord(id: "ss20", tamil: "shell", transliteration: "Shell", meaning: "Hard cover"),
            TamilWord(id: "ss21", tamil: "sack", transliteration: "Sack", meaning: "Bag"),
            TamilWord(id: "ss22", tamil: "shack", transliteration: "Shack", meaning: "Small hut"),
            TamilWord(id: "ss23", tamil: "same", transliteration: "Same", meaning: "Identical"),
            TamilWord(id: "ss24", tamil: "shame", transliteration: "Shame", meaning: "Disgrace"),
            TamilWord(id: "ss25", tamil: "sigh", transliteration: "Sigh", meaning: "Deep breath"),
            TamilWord(id: "ss26", tamil: "shy", transliteration: "Shy", meaning: "Timid"),
            TamilWord(id: "ss27", tamil: "sock", transliteration: "Sock", meaning: "Foot cover"),
            TamilWord(id: "ss28", tamil: "shock", transliteration: "Shock", meaning: "Surprise"),
            TamilWord(id: "ss29", tamil: "sue", transliteration: "Sue", meaning: "Legal action"),
            TamilWord(id: "ss30", tamil: "shoe", transliteration: "Shoe", meaning: "Footwear"),
        ])

    /// Word-ending sibilants: /ush/, /ish/, /ash/, /esh/, /osh/
    /// CI users often miss final fricatives — they hear the vowel but not the /sh/
    static let shEndings = TamilWordCategory(
        id: "sh_endings", title: "-sh/-s Endings", tamilTitle: "ஷ் / ஸ் முடிவு",
        icon: "waveform.path", color: "lcRed",
        words: [
            // -ush words
            TamilWord(id: "she1", tamil: "push", transliteration: "Push", meaning: "Press forward"),
            TamilWord(id: "she2", tamil: "bush", transliteration: "Bush", meaning: "Shrub"),
            TamilWord(id: "she3", tamil: "rush", transliteration: "Rush", meaning: "Hurry"),
            TamilWord(id: "she4", tamil: "crush", transliteration: "Crush", meaning: "Press hard"),
            TamilWord(id: "she5", tamil: "brush", transliteration: "Brush", meaning: "Cleaning tool"),
            TamilWord(id: "she6", tamil: "flush", transliteration: "Flush", meaning: "Wash out"),
            TamilWord(id: "she7", tamil: "hush", transliteration: "Hush", meaning: "Be quiet"),
            TamilWord(id: "she8", tamil: "gush", transliteration: "Gush", meaning: "Flow strongly"),
            // -ish words
            TamilWord(id: "she9", tamil: "fish", transliteration: "Fish", meaning: "Fish"),
            TamilWord(id: "she10", tamil: "dish", transliteration: "Dish", meaning: "Plate"),
            TamilWord(id: "she11", tamil: "wish", transliteration: "Wish", meaning: "Desire"),
            TamilWord(id: "she12", tamil: "finish", transliteration: "Finish", meaning: "Complete"),
            TamilWord(id: "she13", tamil: "vanish", transliteration: "Vanish", meaning: "Disappear"),
            TamilWord(id: "she14", tamil: "polish", transliteration: "Polish", meaning: "Make shiny"),
            // -ash words
            TamilWord(id: "she15", tamil: "cash", transliteration: "Cash", meaning: "Money"),
            TamilWord(id: "she16", tamil: "wash", transliteration: "Wash", meaning: "Clean"),
            TamilWord(id: "she17", tamil: "crash", transliteration: "Crash", meaning: "Collision"),
            TamilWord(id: "she18", tamil: "flash", transliteration: "Flash", meaning: "Quick light"),
            TamilWord(id: "she19", tamil: "trash", transliteration: "Trash", meaning: "Waste"),
            TamilWord(id: "she20", tamil: "splash", transliteration: "Splash", meaning: "Water spray"),
            // -esh / -oss / -ess / -us endings with s
            TamilWord(id: "she21", tamil: "fresh", transliteration: "Fresh", meaning: "New/Cool"),
            TamilWord(id: "she22", tamil: "mesh", transliteration: "Mesh", meaning: "Net"),
            TamilWord(id: "she23", tamil: "less", transliteration: "Less", meaning: "Smaller amount"),
            TamilWord(id: "she24", tamil: "mess", transliteration: "Mess", meaning: "Untidy"),
            TamilWord(id: "she25", tamil: "bus", transliteration: "Bus", meaning: "Vehicle"),
            TamilWord(id: "she26", tamil: "plus", transliteration: "Plus", meaning: "Addition"),
            TamilWord(id: "she27", tamil: "yes", transliteration: "Yes", meaning: "Agree"),
            TamilWord(id: "she28", tamil: "miss", transliteration: "Miss", meaning: "Fail to hit"),
            TamilWord(id: "she29", tamil: "kiss", transliteration: "Kiss", meaning: "Touch with lips"),
            TamilWord(id: "she30", tamil: "boss", transliteration: "Boss", meaning: "Leader"),
        ])

    /// /s/ sound in all word positions — beginning, middle, end
    /// Trains the CI to pick up the high-frequency sibilant instead of mapping to /e/
    static let sPositions = TamilWordCategory(
        id: "s_positions", title: "/s/ Sound Drill", tamilTitle: "ஸ் ஒலி பயிற்சி",
        icon: "s.circle.fill", color: "lcOrange",
        words: [
            // /s/ at the START
            TamilWord(id: "sp1", tamil: "sun", transliteration: "Sun", meaning: "Star"),
            TamilWord(id: "sp2", tamil: "six", transliteration: "Six", meaning: "Number 6"),
            TamilWord(id: "sp3", tamil: "soap", transliteration: "Soap", meaning: "Cleaning bar"),
            TamilWord(id: "sp4", tamil: "sand", transliteration: "Sand", meaning: "Beach grains"),
            TamilWord(id: "sp5", tamil: "soft", transliteration: "Soft", meaning: "Not hard"),
            TamilWord(id: "sp6", tamil: "soup", transliteration: "Soup", meaning: "Liquid food"),
            TamilWord(id: "sp7", tamil: "sing", transliteration: "Sing", meaning: "Make music"),
            TamilWord(id: "sp8", tamil: "safe", transliteration: "Safe", meaning: "Secure"),
            TamilWord(id: "sp9", tamil: "sea", transliteration: "Sea", meaning: "Ocean"),
            TamilWord(id: "sp10", tamil: "said", transliteration: "Said", meaning: "Spoke"),
            // /s/ in the MIDDLE
            TamilWord(id: "sp11", tamil: "pasta", transliteration: "Pasta", meaning: "Italian food"),
            TamilWord(id: "sp12", tamil: "basket", transliteration: "Basket", meaning: "Container"),
            TamilWord(id: "sp13", tamil: "sister", transliteration: "Sister", meaning: "Female sibling"),
            TamilWord(id: "sp14", tamil: "master", transliteration: "Master", meaning: "Expert"),
            TamilWord(id: "sp15", tamil: "lesson", transliteration: "Lesson", meaning: "Class"),
            TamilWord(id: "sp16", tamil: "listen", transliteration: "Listen", meaning: "Hear"),
            TamilWord(id: "sp17", tamil: "mister", transliteration: "Mister", meaning: "Mr."),
            TamilWord(id: "sp18", tamil: "pencil", transliteration: "Pencil", meaning: "Writing tool"),
            TamilWord(id: "sp19", tamil: "person", transliteration: "Person", meaning: "Human"),
            TamilWord(id: "sp20", tamil: "dosai", transliteration: "Dosai", meaning: "Dosa"),
            // /s/ at the END
            TamilWord(id: "sp21", tamil: "ice", transliteration: "Ice", meaning: "Frozen water"),
            TamilWord(id: "sp22", tamil: "rice", transliteration: "Rice", meaning: "Grain"),
            TamilWord(id: "sp23", tamil: "nice", transliteration: "Nice", meaning: "Pleasant"),
            TamilWord(id: "sp24", tamil: "face", transliteration: "Face", meaning: "Front of head"),
            TamilWord(id: "sp25", tamil: "place", transliteration: "Place", meaning: "Location"),
            TamilWord(id: "sp26", tamil: "space", transliteration: "Space", meaning: "Area"),
            TamilWord(id: "sp27", tamil: "voice", transliteration: "Voice", meaning: "Sound"),
            TamilWord(id: "sp28", tamil: "house", transliteration: "House", meaning: "Home"),
            TamilWord(id: "sp29", tamil: "mouse", transliteration: "Mouse", meaning: "Small rodent"),
            TamilWord(id: "sp30", tamil: "juice", transliteration: "Juice", meaning: "Fruit drink"),
        ])

    /// Tamil-specific /s/ vs /sh/ — words with ச, ஷ, ஸ sounds
    /// Focused on real Tamil words CI users encounter daily
    static let sVsShTamil = TamilWordCategory(
        id: "s_vs_sh_tamil", title: "Tamil ச/ஷ/ஸ Drill", tamilTitle: "ச ஷ ஸ பயிற்சி",
        icon: "character.textbox", color: "lcPurple",
        words: [
            // ச (sa) words
            TamilWord(id: "st1", tamil: "சரி", transliteration: "Sari", meaning: "OK/Right"),
            TamilWord(id: "st2", tamil: "சாப்பாடு", transliteration: "Saappaadu", meaning: "Food"),
            TamilWord(id: "st3", tamil: "சாமி", transliteration: "Saami", meaning: "God"),
            TamilWord(id: "st4", tamil: "சட்டை", transliteration: "Sattai", meaning: "Shirt"),
            TamilWord(id: "st5", tamil: "சாவி", transliteration: "Saavi", meaning: "Key"),
            TamilWord(id: "st6", tamil: "சாம்பார்", transliteration: "Saambaar", meaning: "Sambar"),
            TamilWord(id: "st7", tamil: "சிரிப்பு", transliteration: "Sirippu", meaning: "Laughter"),
            TamilWord(id: "st8", tamil: "சோறு", transliteration: "Soru", meaning: "Rice"),
            TamilWord(id: "st9", tamil: "சுவர்", transliteration: "Suvar", meaning: "Wall"),
            TamilWord(id: "st10", tamil: "சூடு", transliteration: "Soodu", meaning: "Hot"),
            // ஷ (sha) words — loan words common in daily Tamil
            TamilWord(id: "st11", tamil: "ஷாப்", transliteration: "Shop", meaning: "Shop"),
            TamilWord(id: "st12", tamil: "ஷர்ட்", transliteration: "Shirt", meaning: "Shirt"),
            TamilWord(id: "st13", tamil: "ஷூ", transliteration: "Shoe", meaning: "Shoe"),
            TamilWord(id: "st14", tamil: "ஸ்டேஷன்", transliteration: "Station", meaning: "Station"),
            TamilWord(id: "st15", tamil: "ஷேவிங்", transliteration: "Shaving", meaning: "Shaving"),
            // ச/ஷ confusable Tamil pairs
            TamilWord(id: "st16", tamil: "சங்கு", transliteration: "Sangu", meaning: "Conch"),
            TamilWord(id: "st17", tamil: "சக்கரம்", transliteration: "Sakkaram", meaning: "Wheel"),
            TamilWord(id: "st18", tamil: "சுத்தம்", transliteration: "Suththam", meaning: "Clean"),
            TamilWord(id: "st19", tamil: "ஷாப்பிங்", transliteration: "Shopping", meaning: "Shopping"),
            TamilWord(id: "st20", tamil: "ஷோ", transliteration: "Show", meaning: "Show/Program"),
            // Sentences with /s/ and /sh/ mixed
            TamilWord(id: "st21", tamil: "சிவப்பு ஷர்ட்", transliteration: "Sivappu Shirt", meaning: "Red shirt"),
            TamilWord(id: "st22", tamil: "சாயங்காலம் ஷாப்", transliteration: "Saayangaalam Shop", meaning: "Evening shop"),
            TamilWord(id: "st23", tamil: "சின்ன ஷூ", transliteration: "Sinna Shoe", meaning: "Small shoe"),
            TamilWord(id: "st24", tamil: "சூப்பர் ஷோ", transliteration: "Super Show", meaning: "Super show"),
            TamilWord(id: "st25", tamil: "சீக்கிரம் ஷாப்பிங்", transliteration: "Seekkiram Shopping", meaning: "Quick shopping"),
        ])

    /// Words with 'r' sounds — difficult for CI users to distinguish
    static let rSounds = TamilWordCategory(
        id: "r_sounds", title: "'R' Sound Words", tamilTitle: "ர / ற ஒலிகள்",
        icon: "r.circle.fill", color: "lcOrange",
        words: [
            // Tamil words with different r sounds (ர vs ற vs ழ)
            TamilWord(id: "r1", tamil: "கரும்பு", transliteration: "Karumbu", meaning: "Sugarcane"),
            TamilWord(id: "r2", tamil: "கருப்பு", transliteration: "Karuppu", meaning: "Black"),
            TamilWord(id: "r3", tamil: "அரிசி", transliteration: "Arisi", meaning: "Rice (uncooked)"),
            TamilWord(id: "r4", tamil: "பறவை", transliteration: "Paravai", meaning: "Bird"),
            TamilWord(id: "r5", tamil: "மரம்", transliteration: "Maram", meaning: "Tree"),
            TamilWord(id: "r6", tamil: "வீரன்", transliteration: "Veeran", meaning: "Hero/Brave"),
            TamilWord(id: "r7", tamil: "நிறம்", transliteration: "Niram", meaning: "Colour"),
            TamilWord(id: "r8", tamil: "கரடி", transliteration: "Karadi", meaning: "Bear"),
            TamilWord(id: "r9", tamil: "சிறகு", transliteration: "Chiragu", meaning: "Wing"),
            TamilWord(id: "r10", tamil: "குரல்", transliteration: "Kural", meaning: "Voice"),
            TamilWord(id: "r11", tamil: "தெரு", transliteration: "Theru", meaning: "Street"),
            TamilWord(id: "r12", tamil: "பெரிய", transliteration: "Periya", meaning: "Big"),
            TamilWord(id: "r13", tamil: "சிரிப்பு", transliteration: "Sirippu", meaning: "Laughter"),
            TamilWord(id: "r14", tamil: "கதிரவன்", transliteration: "Kadhiravan", meaning: "Sun"),
            // English r words
            TamilWord(id: "r15", tamil: "rain", transliteration: "Rain", meaning: "Rain"),
            TamilWord(id: "r16", tamil: "run", transliteration: "Run", meaning: "Run"),
            TamilWord(id: "r17", tamil: "red", transliteration: "Red", meaning: "Red colour"),
            TamilWord(id: "r18", tamil: "right", transliteration: "Right", meaning: "Correct/Direction"),
            TamilWord(id: "r19", tamil: "ring", transliteration: "Ring", meaning: "Ring"),
            TamilWord(id: "r20", tamil: "room", transliteration: "Room", meaning: "Room"),
        ])

    /// Similar syllable pairs — audiologist-tested confusions
    /// (mami/babi/papi/vavi/fafi/shasha pattern)
    static let similarSyllables = TamilWordCategory(
        id: "similar_syllables", title: "Similar Syllables", tamilTitle: "ஒத்த ஒலிகள்",
        icon: "repeat", color: "lcPurple",
        words: [
            // CVCV patterns that sound similar — the exact type audiologists test
            TamilWord(id: "sy1", tamil: "மாமி", transliteration: "Maami", meaning: "Aunt (maternal)"),
            TamilWord(id: "sy2", tamil: "பாபி", transliteration: "Baabi", meaning: "(test syllable)"),
            TamilWord(id: "sy3", tamil: "பாப்பி", transliteration: "Paappi", meaning: "(test syllable)"),
            TamilWord(id: "sy4", tamil: "வாவி", transliteration: "Vaavi", meaning: "(test syllable)"),
            TamilWord(id: "sy5", tamil: "தாதி", transliteration: "Thaathi", meaning: "Nurse"),
            TamilWord(id: "sy6", tamil: "காகி", transliteration: "Kaaki", meaning: "Khaki"),
            TamilWord(id: "sy7", tamil: "நானி", transliteration: "Naani", meaning: "Nanny"),
            TamilWord(id: "sy8", tamil: "ராணி", transliteration: "Raani", meaning: "Queen"),
            TamilWord(id: "sy9", tamil: "லாலி", transliteration: "Laali", meaning: "Lullaby"),
            TamilWord(id: "sy10", tamil: "சசா", transliteration: "Shasha", meaning: "(test syllable)"),
            // Ma/Ba/Pa/Ka confusion — voiced vs voiceless
            TamilWord(id: "sy11", tamil: "மா", transliteration: "Maa", meaning: "Mango/Mother"),
            TamilWord(id: "sy12", tamil: "பா", transliteration: "Baa/Paa", meaning: "Song/Look"),
            TamilWord(id: "sy13", tamil: "கா", transliteration: "Kaa", meaning: "Protect"),
            TamilWord(id: "sy14", tamil: "தா", transliteration: "Thaa", meaning: "Give"),
            TamilWord(id: "sy15", tamil: "நா", transliteration: "Naa", meaning: "Tongue"),
            TamilWord(id: "sy16", tamil: "வா", transliteration: "Vaa", meaning: "Come"),
            // Longer similar-sounding Tamil words
            TamilWord(id: "sy17", tamil: "மனம்", transliteration: "Manam", meaning: "Mind"),
            TamilWord(id: "sy18", tamil: "வனம்", transliteration: "Vanam", meaning: "Forest"),
            TamilWord(id: "sy19", tamil: "தனம்", transliteration: "Thanam", meaning: "Wealth"),
            TamilWord(id: "sy20", tamil: "கனம்", transliteration: "Kanam", meaning: "Heavy/Weight"),
        ])

    /// Consonant confusion pairs — common CI difficulty areas
    static let consonantPairs = TamilWordCategory(
        id: "consonant_pairs", title: "Consonant Confusion", tamilTitle: "மெய் குழப்பம்",
        icon: "arrow.left.arrow.right", color: "lcTeal",
        words: [
            // p/b confusion
            TamilWord(id: "cp1", tamil: "பால்", transliteration: "Paal", meaning: "Milk"),
            TamilWord(id: "cp2", tamil: "ball", transliteration: "Ball", meaning: "Ball"),
            TamilWord(id: "cp3", tamil: "pat", transliteration: "Pat", meaning: "Pat/Touch"),
            TamilWord(id: "cp4", tamil: "bat", transliteration: "Bat", meaning: "Bat"),
            // t/d confusion
            TamilWord(id: "cp5", tamil: "தம்", transliteration: "Tham", meaning: "Self"),
            TamilWord(id: "cp6", tamil: "dam", transliteration: "Dam", meaning: "Dam"),
            TamilWord(id: "cp7", tamil: "time", transliteration: "Time", meaning: "Time"),
            TamilWord(id: "cp8", tamil: "dime", transliteration: "Dime", meaning: "Coin"),
            // k/g confusion
            TamilWord(id: "cp9", tamil: "cake", transliteration: "Cake", meaning: "Cake"),
            TamilWord(id: "cp10", tamil: "gate", transliteration: "Gate", meaning: "Gate"),
            TamilWord(id: "cp11", tamil: "cat", transliteration: "Cat", meaning: "Cat"),
            TamilWord(id: "cp12", tamil: "gap", transliteration: "Gap", meaning: "Gap"),
            // f/v confusion
            TamilWord(id: "cp13", tamil: "fan", transliteration: "Fan", meaning: "Fan"),
            TamilWord(id: "cp14", tamil: "van", transliteration: "Van", meaning: "Van"),
            TamilWord(id: "cp15", tamil: "fine", transliteration: "Fine", meaning: "OK/Penalty"),
            TamilWord(id: "cp16", tamil: "vine", transliteration: "Vine", meaning: "Creeper"),
            // m/n confusion
            TamilWord(id: "cp17", tamil: "மணி", transliteration: "Mani", meaning: "Bell/Gem"),
            TamilWord(id: "cp18", tamil: "நணி", transliteration: "Nani", meaning: "Near"),
            TamilWord(id: "cp19", tamil: "மலை", transliteration: "Malai", meaning: "Mountain"),
            TamilWord(id: "cp20", tamil: "நிலை", transliteration: "Nilai", meaning: "State/Position"),
        ])

    /// English minimal pairs — words differing by one sound
    static let minimalPairsEnglish = TamilWordCategory(
        id: "minimal_pairs_en", title: "Minimal Pairs (English)", tamilTitle: "ஆங்கில ஒலி ஜோடிகள்",
        icon: "textformat.abc", color: "lcBlue",
        words: [
            // Vowel minimal pairs
            TamilWord(id: "mp1", tamil: "cat", transliteration: "Cat", meaning: "Cat"),
            TamilWord(id: "mp2", tamil: "cut", transliteration: "Cut", meaning: "Cut"),
            TamilWord(id: "mp3", tamil: "cap", transliteration: "Cap", meaning: "Hat"),
            TamilWord(id: "mp4", tamil: "cup", transliteration: "Cup", meaning: "Cup"),
            TamilWord(id: "mp5", tamil: "bed", transliteration: "Bed", meaning: "Bed"),
            TamilWord(id: "mp6", tamil: "bad", transliteration: "Bad", meaning: "Bad"),
            TamilWord(id: "mp7", tamil: "bit", transliteration: "Bit", meaning: "Small piece"),
            TamilWord(id: "mp8", tamil: "bat", transliteration: "Bat", meaning: "Bat"),
            TamilWord(id: "mp9", tamil: "sit", transliteration: "Sit", meaning: "Sit"),
            TamilWord(id: "mp10", tamil: "set", transliteration: "Set", meaning: "Set"),
            // Consonant minimal pairs
            TamilWord(id: "mp11", tamil: "pin", transliteration: "Pin", meaning: "Pin"),
            TamilWord(id: "mp12", tamil: "bin", transliteration: "Bin", meaning: "Bin"),
            TamilWord(id: "mp13", tamil: "tin", transliteration: "Tin", meaning: "Tin"),
            TamilWord(id: "mp14", tamil: "din", transliteration: "Din", meaning: "Noise"),
            TamilWord(id: "mp15", tamil: "map", transliteration: "Map", meaning: "Map"),
            TamilWord(id: "mp16", tamil: "nap", transliteration: "Nap", meaning: "Short sleep"),
            TamilWord(id: "mp17", tamil: "light", transliteration: "Light", meaning: "Light"),
            TamilWord(id: "mp18", tamil: "right", transliteration: "Right", meaning: "Right"),
            TamilWord(id: "mp19", tamil: "lake", transliteration: "Lake", meaning: "Lake"),
            TamilWord(id: "mp20", tamil: "rake", transliteration: "Rake", meaning: "Garden tool"),
        ])
}
