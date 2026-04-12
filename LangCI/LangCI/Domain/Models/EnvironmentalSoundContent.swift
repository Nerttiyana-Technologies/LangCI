// EnvironmentalSoundContent.swift
// LangCI — Built-in environmental sound content
//
// Curated everyday sounds ordered by CI difficulty.
// Low-frequency, simple-pattern sounds (knocking, clapping) are easiest.
// High-frequency, complex sounds (birds, music) are hardest.
//
// Audio playback priority (see EnvironmentalSoundTrainingViewController):
// 1. Bundled audio file (audioFileName → Sounds/ folder) — real recordings
// 2. Recorded familiar voice (Voice Library)
// 3. AVSpeechSynthesizer TTS fallback (speechDescription)

import UIKit

enum EnvironmentalSoundContent {

    // MARK: - All Sounds

    static let allSounds: [EnvironmentalSoundItem] = [

        // ── Home (easiest — familiar, low-frequency) ─────────────────

        EnvironmentalSoundItem(
            id: "door_knock", name: "Door Knock", environment: .home,
            description: "Someone knocking on a door",
            systemSoundName: nil,
            speechDescription: "knock knock knock",
            audioFileName: "sound_door_knock.mp3",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "door_close", name: "Door Closing", environment: .home,
            description: "A door closing shut",
            systemSoundName: nil,
            speechDescription: "thud",
            audioFileName: "sound_door_close.mp3",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "clapping", name: "Clapping", environment: .home,
            description: "Hands clapping together",
            systemSoundName: nil,
            speechDescription: "clap clap clap clap",
            audioFileName: "sound_clapping.mp3",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "footsteps", name: "Footsteps", environment: .home,
            description: "Someone walking on a hard floor",
            systemSoundName: nil,
            speechDescription: "tap tap tap tap tap",
            audioFileName: "sound_footsteps.mp3",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "doorbell", name: "Doorbell", environment: .home,
            description: "A doorbell ringing",
            systemSoundName: "1007",
            speechDescription: "ding dong",
            audioFileName: "sound_doorbell.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "vacuum", name: "Vacuum Cleaner", environment: .home,
            description: "A vacuum cleaner running",
            systemSoundName: nil,
            speechDescription: "vrrrrrrrrrrr",
            audioFileName: "sound_vacuum.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "tv_static", name: "Television", environment: .home,
            description: "A television playing in the background",
            systemSoundName: nil,
            speechDescription: "muffled talking and music from a television",
            audioFileName: "sound_tv_static.mp3",
            ciDifficulty: 4
        ),

        // ── Kitchen ──────────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "water_running", name: "Water Running", environment: .kitchen,
            description: "Water flowing from a tap",
            systemSoundName: nil,
            speechDescription: "shhhhhhhh, water flowing",
            audioFileName: "sound_water_running.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "kettle_boil", name: "Kettle Boiling", environment: .kitchen,
            description: "A kettle whistling when water boils",
            systemSoundName: nil,
            speechDescription: "wheeeeeee, a high pitched whistle",
            audioFileName: "sound_kettle_boil.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "microwave", name: "Microwave Beep", environment: .kitchen,
            description: "A microwave beeping when done",
            systemSoundName: nil,
            speechDescription: "beep beep beep",
            audioFileName: "sound_microwave.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "dishes", name: "Dishes Clanking", environment: .kitchen,
            description: "Plates and dishes clinking together",
            systemSoundName: nil,
            speechDescription: "clink clank clink",
            audioFileName: "sound_dishes.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "chopping", name: "Chopping", environment: .kitchen,
            description: "A knife chopping vegetables on a board",
            systemSoundName: nil,
            speechDescription: "chop chop chop chop",
            audioFileName: "sound_chopping.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "sizzling", name: "Frying Pan", environment: .kitchen,
            description: "Food sizzling in a frying pan",
            systemSoundName: nil,
            speechDescription: "sssssizzle sssssizzle",
            audioFileName: "sound_sizzling.mp3",
            ciDifficulty: 3
        ),

        // ── Outdoors ─────────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "rain", name: "Rain", environment: .outdoors,
            description: "Rain falling on a roof",
            systemSoundName: nil,
            speechDescription: "pitter patter pitter patter",
            audioFileName: "sound_rain.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "thunder", name: "Thunder", environment: .outdoors,
            description: "A loud thunder clap",
            systemSoundName: nil,
            speechDescription: "boom, rumble rumble rumble",
            audioFileName: "sound_thunder.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "wind", name: "Wind", environment: .outdoors,
            description: "Wind blowing through trees",
            systemSoundName: nil,
            speechDescription: "whoooosh, whoooosh",
            audioFileName: "sound_wind.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "leaves", name: "Leaves Rustling", environment: .outdoors,
            description: "Dry leaves rustling on the ground",
            systemSoundName: nil,
            speechDescription: "crinkle crinkle, rustle rustle",
            audioFileName: "sound_leaves.mp3",
            ciDifficulty: 4
        ),

        // ── People ───────────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "laughing", name: "Laughing", environment: .people,
            description: "A person laughing",
            systemSoundName: nil,
            speechDescription: "ha ha ha ha ha",
            audioFileName: "sound_laughing.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "coughing", name: "Coughing", environment: .people,
            description: "A person coughing",
            systemSoundName: nil,
            speechDescription: "cough cough, ahem",
            audioFileName: "sound_coughing.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "sneezing", name: "Sneezing", environment: .people,
            description: "A person sneezing",
            systemSoundName: nil,
            speechDescription: "ah ah ah choo!",
            audioFileName: "sound_sneezing.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "crying", name: "Baby Crying", environment: .people,
            description: "A baby crying",
            systemSoundName: nil,
            speechDescription: "waaah waaah waaah",
            audioFileName: "sound_crying.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "whispering", name: "Whispering", environment: .people,
            description: "Someone whispering quietly",
            systemSoundName: nil,
            speechDescription: "psst psst, shh shh",
            audioFileName: "sound_whispering.mp3",
            ciDifficulty: 5
        ),

        // ── Animals ──────────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "dog_bark", name: "Dog Barking", environment: .animals,
            description: "A dog barking",
            systemSoundName: nil,
            speechDescription: "woof woof woof, bow wow",
            audioFileName: "sound_dog_bark.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "cat_meow", name: "Cat Meowing", environment: .animals,
            description: "A cat meowing",
            systemSoundName: nil,
            speechDescription: "meow meow meow",
            audioFileName: "sound_cat_meow.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "bird_chirp", name: "Birds Chirping", environment: .animals,
            description: "Birds singing in the morning",
            systemSoundName: nil,
            speechDescription: "tweet tweet, chirp chirp chirp",
            audioFileName: "sound_bird_chirp.mp3",
            ciDifficulty: 4
        ),
        EnvironmentalSoundItem(
            id: "rooster", name: "Rooster", environment: .animals,
            description: "A rooster crowing at dawn",
            systemSoundName: nil,
            speechDescription: "cock a doodle doo!",
            audioFileName: "sound_rooster.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "cow_moo", name: "Cow Mooing", environment: .animals,
            description: "A cow mooing in a field",
            systemSoundName: nil,
            speechDescription: "moooooo, mooooo",
            audioFileName: "sound_cow_moo.mp3",
            ciDifficulty: 2
        ),

        // ── Transport ────────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "car_horn", name: "Car Horn", environment: .transport,
            description: "A car honking its horn",
            systemSoundName: nil,
            speechDescription: "beep beep! honk honk!",
            audioFileName: "sound_car_horn.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "car_engine", name: "Car Engine", environment: .transport,
            description: "A car engine starting and running",
            systemSoundName: nil,
            speechDescription: "vroom vroom vroom",
            audioFileName: "sound_car_engine.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "siren", name: "Ambulance Siren", environment: .transport,
            description: "An ambulance siren wailing",
            systemSoundName: nil,
            speechDescription: "wee woo wee woo wee woo",
            audioFileName: "sound_siren.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "train", name: "Train", environment: .transport,
            description: "A train horn and wheels on tracks",
            systemSoundName: nil,
            speechDescription: "choo choo, chugga chugga chugga",
            audioFileName: "sound_train.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "airplane", name: "Airplane", environment: .transport,
            description: "An airplane flying overhead",
            systemSoundName: nil,
            speechDescription: "roarrrrr, whoooosh",
            audioFileName: "sound_airplane.mp3",
            ciDifficulty: 4
        ),

        // ── Alerts (most important for safety!) ──────────────────────

        EnvironmentalSoundItem(
            id: "phone_ring", name: "Phone Ringing", environment: .alerts,
            description: "A mobile phone ringing",
            systemSoundName: "1000",
            speechDescription: "ring ring, ring ring",
            audioFileName: "sound_phone_ring.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "alarm_clock", name: "Alarm Clock", environment: .alerts,
            description: "An alarm clock buzzing",
            systemSoundName: "1005",
            speechDescription: "beep beep beep beep beep beep",
            audioFileName: "sound_alarm_clock.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "smoke_alarm", name: "Smoke Alarm", environment: .alerts,
            description: "A smoke detector beeping loudly",
            systemSoundName: nil,
            speechDescription: "BEEP BEEP BEEP, loud high-pitched beeping",
            audioFileName: "sound_smoke_alarm.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "timer", name: "Timer Beep", environment: .alerts,
            description: "A kitchen timer going off",
            systemSoundName: "1013",
            speechDescription: "ding ding ding",
            audioFileName: "sound_timer.mp3",
            ciDifficulty: 2
        ),

        // ── Indian Home (everyday sounds in Indian households) ──────

        EnvironmentalSoundItem(
            id: "pressure_cooker", name: "Pressure Cooker", environment: .indianHome,
            description: "A pressure cooker whistle — the most common Indian kitchen sound",
            systemSoundName: nil,
            speechDescription: "psssshhhh, WEEEEE! psssshhhh, WEEEEE!",
            audioFileName: "sound_pressure_cooker.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "mixer_grinder", name: "Mixer Grinder", environment: .indianHome,
            description: "A wet grinder or mixer running in the kitchen",
            systemSoundName: nil,
            speechDescription: "grrrrrrr, whirrrrrr, grrrrrrr",
            audioFileName: "sound_mixer_grinder.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "temple_bell", name: "Temple Bell", environment: .indianHome,
            description: "A brass bell ringing during pooja",
            systemSoundName: nil,
            speechDescription: "ding ding ding, clang clang clang",
            audioFileName: "sound_temple_bell.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "calling_bell", name: "Calling Bell", environment: .indianHome,
            description: "The front door calling bell",
            systemSoundName: nil,
            speechDescription: "tring tring! tring tring!",
            audioFileName: "sound_calling_bell.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "auto_horn", name: "Auto-Rickshaw Horn", environment: .indianHome,
            description: "A three-wheeler auto horn on the street",
            systemSoundName: nil,
            speechDescription: "pom pom! pom pom pom!",
            audioFileName: "sound_auto_horn.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "ceiling_fan", name: "Ceiling Fan", environment: .indianHome,
            description: "A ceiling fan spinning overhead",
            systemSoundName: nil,
            speechDescription: "whirrrrr, whirrrrr, whirrrrr",
            audioFileName: "sound_ceiling_fan.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "steel_vessels", name: "Steel Vessels", environment: .indianHome,
            description: "Stainless steel vessels clanking together",
            systemSoundName: nil,
            speechDescription: "clang clang, clatter clatter, ting ting",
            audioFileName: "sound_steel_vessels.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "coconut_scraping", name: "Coconut Scraping", environment: .indianHome,
            description: "Scraping coconut with a coconut scraper",
            systemSoundName: nil,
            speechDescription: "scritch scritch scritch, scratch scratch",
            audioFileName: "sound_coconut_scraping.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "kolam_sweeping", name: "Broom Sweeping", environment: .indianHome,
            description: "Sweeping the floor with a broom early morning",
            systemSoundName: nil,
            speechDescription: "swish swish swish, swish swish swish",
            audioFileName: "sound_kolam_sweeping.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "washing_clothes", name: "Clothes Washing", environment: .indianHome,
            description: "Hand-washing clothes and slapping on stone",
            systemSoundName: nil,
            speechDescription: "splash splash, thwack thwack, splash",
            audioFileName: "sound_washing_clothes.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "agarbathi", name: "Match Lighting", environment: .indianHome,
            description: "Striking a match to light agarbathi",
            systemSoundName: nil,
            speechDescription: "scratch, fsssss, fssss",
            audioFileName: "sound_agarbathi.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "water_pump", name: "Water Pump", environment: .indianHome,
            description: "A water pump motor running",
            systemSoundName: nil,
            speechDescription: "brrrrrr, hummmmmm, brrrrrr",
            audioFileName: "sound_water_pump.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "idli_cooker", name: "Idli Cooker Steam", environment: .indianHome,
            description: "Steam escaping from an idli cooker",
            systemSoundName: nil,
            speechDescription: "pssshhhh, psssshhhh, bubbly steam",
            audioFileName: "sound_idli_cooker.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "crow_caw", name: "Crow Cawing", environment: .indianHome,
            description: "Crows cawing outside the window — very common in India",
            systemSoundName: nil,
            speechDescription: "caw caw caw! caw caw!",
            audioFileName: "sound_crow_caw.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "two_wheeler", name: "Two-Wheeler", environment: .indianHome,
            description: "A motorcycle or scooter starting up",
            systemSoundName: nil,
            speechDescription: "vroom vroom vrrrrrrr, put put put put",
            audioFileName: "sound_two_wheeler.mp3",
            ciDifficulty: 2
        ),

        // ── Speech & Voice (critical for CI users learning conversation) ─

        EnvironmentalSoundItem(
            id: "female_hello", name: "Woman Saying Hello", environment: .speech,
            description: "A woman's voice saying hello — higher pitch, easier for CI",
            systemSoundName: nil,
            speechDescription: "Hello! Hello, how are you?",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "male_hello", name: "Man Saying Hello", environment: .speech,
            description: "A man's voice saying hello — lower pitch, harder for CI",
            systemSoundName: nil,
            speechDescription: "Hello there. Good morning.",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "child_voice", name: "Child Speaking", environment: .speech,
            description: "A young child's voice — high pitch, fast",
            systemSoundName: nil,
            speechDescription: "Amma! Amma! Come here! Look at this!",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "name_calling", name: "Someone Calling Name", environment: .speech,
            description: "Someone calling out a name from another room",
            systemSoundName: nil,
            speechDescription: "Suresh! Suresh, are you there?",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "vanakkam", name: "Vanakkam", environment: .speech,
            description: "Tamil greeting — Vanakkam",
            systemSoundName: nil,
            speechDescription: "Vanakkam! Eppadi irukkeenga?",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "thank_you", name: "Thank You", environment: .speech,
            description: "Someone saying thank you",
            systemSoundName: nil,
            speechDescription: "Thank you. Thank you very much.",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "yes_no", name: "Yes and No", environment: .speech,
            description: "Hearing the difference between yes and no",
            systemSoundName: nil,
            speechDescription: "Yes. No. Yes. No.",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "counting", name: "Counting 1-5", environment: .speech,
            description: "Counting numbers slowly — rhythm training",
            systemSoundName: nil,
            speechDescription: "One. Two. Three. Four. Five.",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "question_voice", name: "Question vs Statement", environment: .speech,
            description: "Hearing the rising pitch of a question",
            systemSoundName: nil,
            speechDescription: "This is a statement. Is this a question?",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "whisper_vs_shout", name: "Whisper vs Shout", environment: .speech,
            description: "Difference between soft whisper and loud shout",
            systemSoundName: nil,
            speechDescription: "hello. HELLO!",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "happy_voice", name: "Happy Voice", environment: .speech,
            description: "An excited, happy tone of voice",
            systemSoundName: nil,
            speechDescription: "Oh wonderful! That's great news! I'm so happy!",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "sad_voice", name: "Sad Voice", environment: .speech,
            description: "A slow, quiet, sad tone of voice",
            systemSoundName: nil,
            speechDescription: "Oh no. That's really sad. I'm sorry to hear that.",
            ciDifficulty: 4
        ),
        EnvironmentalSoundItem(
            id: "angry_voice", name: "Angry Voice", environment: .speech,
            description: "A sharp, loud, angry tone",
            systemSoundName: nil,
            speechDescription: "No! Stop that right now! I said NO!",
            ciDifficulty: 3
        ),

        // ── Music & Tones (pitch, rhythm, instrument recognition) ────

        EnvironmentalSoundItem(
            id: "single_drum", name: "Drum Beat", environment: .tones,
            description: "A single drum beat — low-frequency percussion",
            systemSoundName: nil,
            speechDescription: "boom, boom, boom boom boom",
            audioFileName: "sound_single_drum.mp3",
            ciDifficulty: 1
        ),
        EnvironmentalSoundItem(
            id: "clap_rhythm", name: "Clap Rhythm", environment: .tones,
            description: "A simple clapping rhythm pattern",
            systemSoundName: nil,
            speechDescription: "clap, clap, clap clap clap, clap, clap, clap clap clap",
            audioFileName: "sound_clap_rhythm.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "low_pitch", name: "Low Pitch Hum", environment: .tones,
            description: "A deep, low-pitched humming sound",
            systemSoundName: nil,
            speechDescription: "hmmmmmmm, hummmmmmm, very deep and low",
            audioFileName: "sound_low_pitch.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "high_pitch", name: "High Pitch Tone", environment: .tones,
            description: "A bright, high-pitched tone",
            systemSoundName: nil,
            speechDescription: "eeeeee, a high bright sound, eeeeee",
            audioFileName: "sound_high_pitch.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "pitch_up_down", name: "Rising & Falling Pitch", environment: .tones,
            description: "A tone going up then coming down — pitch training",
            systemSoundName: nil,
            speechDescription: "do re mi fa so la ti do, do ti la so fa mi re do",
            audioFileName: "sound_pitch_up_down.mp3",
            ciDifficulty: 4
        ),
        EnvironmentalSoundItem(
            id: "tabla", name: "Tabla", environment: .music,
            description: "Indian tabla drums — dha dhin rhythms",
            systemSoundName: nil,
            speechDescription: "dha dhin dha, dha dhin dha, ta tin ta, ta tin ta",
            audioFileName: "sound_tabla.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "veena", name: "Veena String", environment: .music,
            description: "A veena string being plucked — Carnatic music",
            systemSoundName: nil,
            speechDescription: "twang, twaang, twing twing twang",
            audioFileName: "sound_veena.mp3",
            ciDifficulty: 4
        ),
        EnvironmentalSoundItem(
            id: "flute", name: "Flute", environment: .music,
            description: "A bamboo flute playing a melody",
            systemSoundName: nil,
            speechDescription: "toooo tooo, teee tooo, flowing melody",
            audioFileName: "sound_flute.mp3",
            ciDifficulty: 4
        ),
        EnvironmentalSoundItem(
            id: "harmonium", name: "Harmonium", environment: .music,
            description: "A harmonium drone — continuous reedy sound",
            systemSoundName: nil,
            speechDescription: "hmmmmmm, aaahhhh, a continuous reedy tone",
            audioFileName: "sound_harmonium.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "guitar_strum", name: "Guitar Strum", environment: .music,
            description: "A guitar being strummed once",
            systemSoundName: nil,
            speechDescription: "strum, twang twang twang",
            audioFileName: "sound_guitar_strum.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "piano_key", name: "Piano Key", environment: .music,
            description: "A single piano key being pressed",
            systemSoundName: nil,
            speechDescription: "ding, a clear single note, ding",
            audioFileName: "sound_piano_key.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "fast_vs_slow", name: "Fast vs Slow Rhythm", environment: .tones,
            description: "Comparing fast and slow rhythmic patterns",
            systemSoundName: nil,
            speechDescription: "tap, tap, tap. Now faster: tap tap tap tap tap tap tap",
            audioFileName: "sound_fast_vs_slow.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "loud_vs_soft", name: "Loud vs Soft", environment: .tones,
            description: "The same sound at different volumes — loudness training",
            systemSoundName: nil,
            speechDescription: "hello. Hello. HELLO!",
            audioFileName: "sound_loud_vs_soft.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "two_beat", name: "Two Beats vs Three", environment: .tones,
            description: "Counting beats — 2 taps vs 3 taps",
            systemSoundName: nil,
            speechDescription: "tap tap. Now three: tap tap tap.",
            audioFileName: "sound_two_beat.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "humming_song", name: "Humming a Tune", environment: .music,
            description: "Someone humming a simple melody",
            systemSoundName: nil,
            speechDescription: "hmm hmm hmm, hm hm hm hmm, la la la",
            audioFileName: "sound_humming_song.mp3",
            ciDifficulty: 4
        ),

        // ── More Animals (Indian context) ────────────────────────────

        EnvironmentalSoundItem(
            id: "goat_bleat", name: "Goat Bleating", environment: .animals,
            description: "A goat bleating — common in rural India",
            systemSoundName: nil,
            speechDescription: "maa maa, baa baa, maa maa",
            audioFileName: "sound_goat_bleat.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "parrot", name: "Parrot Squawk", environment: .animals,
            description: "A parrot squawking loudly",
            systemSoundName: nil,
            speechDescription: "squawk! aawk aawk! screech!",
            audioFileName: "sound_parrot.mp3",
            ciDifficulty: 3
        ),
        EnvironmentalSoundItem(
            id: "mosquito", name: "Mosquito Buzz", environment: .animals,
            description: "A mosquito buzzing near your ear",
            systemSoundName: nil,
            speechDescription: "bzzzzzz, zzzzz, bzzzzzzz",
            audioFileName: "sound_mosquito.mp3",
            ciDifficulty: 5
        ),
        EnvironmentalSoundItem(
            id: "bulbul", name: "Bulbul Bird", environment: .animals,
            description: "A red-whiskered bulbul singing",
            systemSoundName: nil,
            speechDescription: "pip pip pip, cheer cheer, pip pip",
            audioFileName: "sound_bulbul.mp3",
            ciDifficulty: 4
        ),

        // ── More Transport (Indian context) ──────────────────────────

        EnvironmentalSoundItem(
            id: "bus_horn", name: "Bus Horn", environment: .transport,
            description: "A city bus honking its loud horn",
            systemSoundName: nil,
            speechDescription: "paaaan paaaan! loud deep horn blast",
            audioFileName: "sound_bus_horn.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "cycle_bell", name: "Cycle Bell", environment: .transport,
            description: "A bicycle bell ringing",
            systemSoundName: nil,
            speechDescription: "tring tring! tring tring tring!",
            audioFileName: "sound_cycle_bell.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "train_horn_indian", name: "Train Horn", environment: .transport,
            description: "An Indian train horn — long and deep",
            systemSoundName: nil,
            speechDescription: "poooooo! poooo poooo! long deep whistle",
            audioFileName: "sound_train_horn_indian.mp3",
            ciDifficulty: 2
        ),

        // ── More Alerts ─────────────────────────────────────────────

        EnvironmentalSoundItem(
            id: "whatsapp_tone", name: "WhatsApp Message", environment: .alerts,
            description: "The WhatsApp notification sound",
            systemSoundName: nil,
            speechDescription: "da dum!",
            audioFileName: "sound_whatsapp_tone.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "gas_stove_click", name: "Gas Stove Click", environment: .alerts,
            description: "Clicking a gas stove igniter",
            systemSoundName: nil,
            speechDescription: "click click click, fwoosh",
            audioFileName: "sound_gas_stove_click.mp3",
            ciDifficulty: 2
        ),
        EnvironmentalSoundItem(
            id: "inverter_beep", name: "Inverter Beep", environment: .alerts,
            description: "Power inverter beeping during power cut",
            systemSoundName: nil,
            speechDescription: "beep, beep, beep, continuous beeping",
            audioFileName: "sound_inverter_beep.mp3",
            ciDifficulty: 2
        ),
    ]

    // MARK: - Helpers

    static func sounds(for environment: SoundEnvironment) -> [EnvironmentalSoundItem] {
        allSounds.filter { $0.environment == environment }
    }

    static func sound(named id: String) -> EnvironmentalSoundItem? {
        allSounds.first { $0.id == id }
    }

    /// Sounds ordered by CI difficulty (easiest first) — ideal for post-activation
    static var soundsByDifficulty: [EnvironmentalSoundItem] {
        allSounds.sorted { $0.ciDifficulty < $1.ciDifficulty }
    }

    /// Get easy sounds for week 1 post-activation (difficulty 1-2)
    static var week1Sounds: [EnvironmentalSoundItem] {
        allSounds.filter { $0.ciDifficulty <= 2 }
    }

    /// Get medium sounds for weeks 2-3 (difficulty 2-3)
    static var week2to3Sounds: [EnvironmentalSoundItem] {
        allSounds.filter { $0.ciDifficulty >= 2 && $0.ciDifficulty <= 3 }
    }

    /// Get harder sounds for weeks 4+ (difficulty 3-5)
    static var week4PlusSounds: [EnvironmentalSoundItem] {
        allSounds.filter { $0.ciDifficulty >= 3 }
    }

    /// Safety-critical sounds that should be learned first
    static var safetySounds: [EnvironmentalSoundItem] {
        let safetyIds = ["smoke_alarm", "siren", "car_horn", "phone_ring", "alarm_clock", "doorbell"]
        return allSounds.filter { safetyIds.contains($0.id) }
    }

    // MARK: - Weekly Sound Packs

    /// Predefined weekly packs that progressively unlock based on CI journey.
    /// Week 1: Simple, low-frequency sounds the brain picks up first.
    /// Week 2: Kitchen + people sounds (medium difficulty).
    /// Week 3: Outdoor + transport sounds.
    /// Week 4+: Complex, high-frequency sounds (animals, music, whispers).
    /// Safety: Always-available critical alert sounds.
    static let weeklyPackDefinitions: [(id: String, title: String, subtitle: String,
                                         icon: String, colorName: String, soundIds: [String])] = [
        // Week 1: 25 sounds — all difficulty 1 + easiest difficulty 2.
        // Focus on low-frequency, familiar, high-contrast sounds.
        // Brain needs LOTS of repetition at this stage (3-4 sessions to finish pack).
        (
            id: "week1",
            title: "Week 1 — First Sounds",
            subtitle: "Simple, familiar sounds your brain maps first",
            icon: "1.circle.fill",
            colorName: "lcGreen",
            soundIds: [
                // Difficulty 1 — easiest (all 6)
                "door_knock", "door_close", "clapping", "footsteps", "yes_no", "single_drum",
                // Difficulty 2 — familiar home & Indian sounds
                "doorbell", "calling_bell", "pressure_cooker", "temple_bell",
                "thunder", "cow_moo", "dog_bark", "crow_caw",
                "laughing", "car_horn", "auto_horn", "two_wheeler",
                // Difficulty 2 — basic speech & rhythm
                "female_hello", "name_calling", "vanakkam", "counting",
                "loud_vs_soft", "clap_rhythm", "piano_key"
            ]
        ),
        // Week 2: 24 sounds — remaining difficulty 2 + kitchen/alert sounds.
        // Brain is starting to map patterns. Introduce more variety.
        (
            id: "week2",
            title: "Week 2 — Home & People",
            subtitle: "Kitchen, alerts, people sounds, and basic speech",
            icon: "2.circle.fill",
            colorName: "lcBlue",
            soundIds: [
                // Kitchen
                "water_running", "microwave", "dishes", "chopping",
                // People
                "coughing", "sneezing", "thank_you",
                // Animals
                "goat_bleat",
                // Transport
                "siren", "bus_horn", "cycle_bell", "train_horn_indian",
                // Indian home
                "steel_vessels",
                // Alerts
                "phone_ring", "alarm_clock", "smoke_alarm", "timer",
                "whatsapp_tone", "gas_stove_click", "inverter_beep",
                // Tones
                "low_pitch", "fast_vs_slow", "two_beat"
            ]
        ),
        // Week 3: 25 sounds — difficulty 3 core. More complex patterns.
        // Brain is adapting. Introduce similar-sounding pairs for discrimination.
        (
            id: "week3",
            title: "Week 3 — World & Voice",
            subtitle: "Outdoor, transport, speech emotions & instruments",
            icon: "3.circle.fill",
            colorName: "lcPurple",
            soundIds: [
                // Kitchen & home (harder)
                "sizzling", "kettle_boil", "vacuum", "mixer_grinder",
                "ceiling_fan", "coconut_scraping", "kolam_sweeping",
                "washing_clothes", "agarbathi", "water_pump", "idli_cooker",
                // Outdoors
                "rain", "wind",
                // Animals
                "cat_meow", "rooster",
                // Transport
                "car_engine", "train",
                // Speech — pitch & emotion
                "male_hello", "child_voice", "question_voice",
                "happy_voice", "angry_voice", "whisper_vs_shout",
                // Music
                "tabla", "harmonium"
            ]
        ),
        // Week 4+: 15 sounds — difficulty 4-5. High-frequency, subtle, complex.
        // Brain needs advanced pattern recognition for these.
        (
            id: "week4",
            title: "Week 4+ — Complex Sounds",
            subtitle: "Challenging speech, music, instruments & pitch",
            icon: "4.circle.fill",
            colorName: "lcOrange",
            soundIds: [
                // High-frequency sounds
                "crying", "parrot", "bird_chirp", "bulbul", "mosquito",
                // Complex environment
                "tv_static", "leaves", "airplane",
                // Subtle speech
                "sad_voice", "whispering",
                // Music & pitch (hardest)
                "high_pitch", "pitch_up_down",
                "veena", "flute", "guitar_strum", "humming_song"
            ]
        ),
        // Safety: 12 sounds — critical alerts, always unlocked.
        (
            id: "safety",
            title: "Safety Sounds",
            subtitle: "Critical alert sounds every CI user must learn",
            icon: "exclamationmark.shield.fill",
            colorName: "lcRed",
            soundIds: ["smoke_alarm", "siren", "car_horn", "phone_ring",
                       "alarm_clock", "doorbell", "timer",
                       "whatsapp_tone", "gas_stove_click", "inverter_beep",
                       "bus_horn", "train_horn_indian"]
        ),
    ]

    /// Build WeeklySoundPack objects from definitions + database unlock state
    static func buildPacks(unlockedIds: Set<String>) -> [WeeklySoundPack] {
        weeklyPackDefinitions.map { def in
            let color: UIColor = {
                switch def.colorName {
                case "lcGreen":  return .lcGreen
                case "lcBlue":   return .lcBlue
                case "lcPurple": return .lcPurple
                case "lcOrange": return .lcOrange
                case "lcRed":    return .lcRed
                default:         return .lcTeal
                }
            }()
            return WeeklySoundPack(
                id: def.id,
                title: def.title,
                subtitle: def.subtitle,
                icon: def.icon,
                color: color,
                soundIds: def.soundIds,
                isUnlocked: unlockedIds.contains(def.id),
                isCompleted: false)
        }
    }
}
