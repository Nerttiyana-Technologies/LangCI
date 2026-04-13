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
}
