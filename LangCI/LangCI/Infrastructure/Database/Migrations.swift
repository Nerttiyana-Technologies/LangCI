// Migrations.swift
// LangCI
//
// All dates are stored as REAL (Unix epoch seconds / Double).
// All booleans are stored as INTEGER (0/1).
// All enums are stored as INTEGER (rawValue).

import Foundation
import GRDB

enum Migrations {

    static func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        // ─── v1 — Initial schema ───────────────────────────────────────────────
        migrator.registerMigration("v1_initial_schema") { db in

            // language
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS language (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    code            TEXT    NOT NULL UNIQUE,
                    name            TEXT    NOT NULL,
                    native_name     TEXT    NOT NULL DEFAULT '',
                    script_code     TEXT    NOT NULL DEFAULT '',
                    font_family     TEXT    NOT NULL DEFAULT '',
                    is_right_to_left INTEGER NOT NULL DEFAULT 0,
                    is_active       INTEGER NOT NULL DEFAULT 1
                )
            """)

            // dialect
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS dialect (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    language_id INTEGER REFERENCES language(id) ON DELETE CASCADE,
                    name        TEXT    NOT NULL DEFAULT '',
                    native_name TEXT    NOT NULL DEFAULT '',
                    region_code TEXT    NOT NULL DEFAULT '',
                    color_hex   TEXT    NOT NULL DEFAULT '',
                    is_active   INTEGER NOT NULL DEFAULT 1
                )
            """)

            // word_category
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS word_category (
                    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                    language_id          INTEGER NOT NULL REFERENCES language(id) ON DELETE CASCADE,
                    code                 TEXT    NOT NULL,
                    native_display_name  TEXT    NOT NULL DEFAULT '',
                    english_display_name TEXT    NOT NULL DEFAULT '',
                    sort_order           INTEGER NOT NULL DEFAULT 0
                )
            """)

            // phonetic_group
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS phonetic_group (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    language_id         INTEGER NOT NULL REFERENCES language(id) ON DELETE CASCADE,
                    group_key           TEXT    NOT NULL,
                    description         TEXT    NOT NULL DEFAULT '',
                    shared_ipa_pattern  TEXT    NOT NULL DEFAULT '',
                    ci_difficulty_level INTEGER NOT NULL DEFAULT 3
                )
            """)

            // publisher_pack
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS publisher_pack (
                    id               INTEGER PRIMARY KEY AUTOINCREMENT,
                    global_id        TEXT    NOT NULL UNIQUE,
                    language_id      INTEGER NOT NULL REFERENCES language(id),
                    name             TEXT    NOT NULL DEFAULT '',
                    description      TEXT    NOT NULL DEFAULT '',
                    difficulty_level INTEGER NOT NULL DEFAULT 1,
                    version          INTEGER NOT NULL DEFAULT 1,
                    published_at     REAL    NOT NULL,
                    synced_at        REAL,
                    is_installed     INTEGER NOT NULL DEFAULT 0,
                    is_premium       INTEGER NOT NULL DEFAULT 0
                )
            """)

            // word_entry
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS word_entry (
                    id                INTEGER PRIMARY KEY AUTOINCREMENT,
                    global_id         TEXT    NOT NULL UNIQUE,
                    language_id       INTEGER NOT NULL REFERENCES language(id),
                    native_script     TEXT    NOT NULL DEFAULT '',
                    ipa_phoneme       TEXT    NOT NULL DEFAULT '',
                    phonetic_key      TEXT,
                    is_slang          INTEGER NOT NULL DEFAULT 0,
                    source            INTEGER NOT NULL DEFAULT 0,
                    status            INTEGER NOT NULL DEFAULT 1,
                    publisher_pack_id INTEGER REFERENCES publisher_pack(id),
                    sync_status       INTEGER NOT NULL DEFAULT 0,
                    last_synced_at    REAL,
                    created_at        REAL    NOT NULL,
                    updated_at        REAL    NOT NULL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_word_entry_language ON word_entry(language_id)")

            // word_translation
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS word_translation (
                    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                    word_entry_id        INTEGER NOT NULL REFERENCES word_entry(id) ON DELETE CASCADE,
                    target_language_code TEXT    NOT NULL DEFAULT '',
                    translation          TEXT    NOT NULL DEFAULT '',
                    transliteration      TEXT    NOT NULL DEFAULT '',
                    example_native       TEXT,
                    example_translation  TEXT
                )
            """)

            // word_category_map
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS word_category_map (
                    id               INTEGER PRIMARY KEY AUTOINCREMENT,
                    word_entry_id    INTEGER NOT NULL REFERENCES word_entry(id) ON DELETE CASCADE,
                    word_category_id INTEGER NOT NULL REFERENCES word_category(id) ON DELETE CASCADE
                )
            """)

            // word_dialect_map
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS word_dialect_map (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    word_entry_id INTEGER NOT NULL REFERENCES word_entry(id) ON DELETE CASCADE,
                    dialect_id    INTEGER NOT NULL REFERENCES dialect(id) ON DELETE CASCADE
                )
            """)

            // phonetic_group_member
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS phonetic_group_member (
                    id                INTEGER PRIMARY KEY AUTOINCREMENT,
                    phonetic_group_id INTEGER NOT NULL REFERENCES phonetic_group(id) ON DELETE CASCADE,
                    word_entry_id     INTEGER NOT NULL REFERENCES word_entry(id) ON DELETE CASCADE
                )
            """)

            // family_member
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS family_member (
                    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
                    name                   TEXT    NOT NULL DEFAULT '',
                    relationship           TEXT    NOT NULL DEFAULT '',
                    avatar_initials        TEXT    NOT NULL DEFAULT '',
                    avatar_color_hex       TEXT    NOT NULL DEFAULT '#1D9E75',
                    preferred_dialect_id   INTEGER NOT NULL REFERENCES dialect(id),
                    baseline_frequency_hz  REAL,
                    created_at             REAL    NOT NULL
                )
            """)

            // recording
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recording (
                    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                    word_entry_id        INTEGER NOT NULL REFERENCES word_entry(id),
                    dialect_id           INTEGER NOT NULL REFERENCES dialect(id),
                    family_member_id     INTEGER NOT NULL REFERENCES family_member(id),
                    file_path            TEXT    NOT NULL DEFAULT '',
                    format               TEXT    NOT NULL DEFAULT 'wav',
                    duration_seconds     REAL    NOT NULL DEFAULT 0,
                    peak_amplitude       REAL    NOT NULL DEFAULT 0,
                    average_frequency_hz REAL,
                    is_approved          INTEGER NOT NULL DEFAULT 1,
                    recorded_at          REAL    NOT NULL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recording_word ON recording(word_entry_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recording_member ON recording(family_member_id)")

            // recording_request
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recording_request (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    token               TEXT    NOT NULL UNIQUE,
                    family_member_id    INTEGER NOT NULL REFERENCES family_member(id),
                    requested_word_ids  TEXT    NOT NULL DEFAULT '',
                    message             TEXT,
                    status              INTEGER NOT NULL DEFAULT 0,
                    total_words         INTEGER NOT NULL DEFAULT 0,
                    completed_count     INTEGER NOT NULL DEFAULT 0,
                    created_at          REAL    NOT NULL,
                    expires_at          REAL    NOT NULL
                )
            """)

            // training_session
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS training_session (
                    id                INTEGER PRIMARY KEY AUTOINCREMENT,
                    dialect_id        INTEGER NOT NULL REFERENCES dialect(id),
                    category_code     TEXT    NOT NULL DEFAULT '',
                    started_at        REAL    NOT NULL,
                    completed_at      REAL,
                    total_words       INTEGER NOT NULL DEFAULT 0,
                    completed_words   INTEGER NOT NULL DEFAULT 0,
                    publisher_pack_id INTEGER REFERENCES publisher_pack(id),
                    training_mode     INTEGER NOT NULL DEFAULT 0,
                    noise_environment INTEGER NOT NULL DEFAULT 0,
                    noise_level       REAL    NOT NULL DEFAULT 0.3,
                    processor_program INTEGER NOT NULL DEFAULT 0
                )
            """)

            // session_word
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS session_word (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    training_session_id INTEGER NOT NULL REFERENCES training_session(id) ON DELETE CASCADE,
                    word_entry_id       INTEGER NOT NULL REFERENCES word_entry(id),
                    rating              INTEGER NOT NULL DEFAULT 0,
                    ease_factor         REAL    NOT NULL DEFAULT 2.5,
                    interval_days       INTEGER NOT NULL DEFAULT 1,
                    repetition_count    INTEGER NOT NULL DEFAULT 0,
                    next_review_date    REAL    NOT NULL,
                    reviewed_at         REAL    NOT NULL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_session_word_review ON session_word(next_review_date)")

            // ling6_session
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS ling6_session (
                    id           INTEGER PRIMARY KEY AUTOINCREMENT,
                    tested_at    REAL    NOT NULL,
                    distance_cm  INTEGER NOT NULL DEFAULT 100,
                    program_used INTEGER NOT NULL DEFAULT 0,
                    notes        TEXT
                )
            """)

            // ling6_attempt
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS ling6_attempt (
                    id           INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id   INTEGER NOT NULL REFERENCES ling6_session(id) ON DELETE CASCADE,
                    sound        TEXT    NOT NULL DEFAULT '',
                    is_detected  INTEGER NOT NULL DEFAULT 0,
                    is_recognised INTEGER NOT NULL DEFAULT 0,
                    sort_order   INTEGER NOT NULL DEFAULT 0
                )
            """)

            // mapping_session
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mapping_session (
                    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_date          REAL    NOT NULL,
                    audiologist_name      TEXT    NOT NULL DEFAULT '',
                    clinic_name           TEXT    NOT NULL DEFAULT '',
                    notes                 TEXT,
                    next_appointment_date REAL
                )
            """)

            // electrode_level
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS electrode_level (
                    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
                    mapping_session_id INTEGER NOT NULL REFERENCES mapping_session(id) ON DELETE CASCADE,
                    electrode_number   INTEGER NOT NULL,
                    t_level            REAL    NOT NULL DEFAULT 0,
                    c_level            REAL    NOT NULL DEFAULT 0,
                    is_active          INTEGER NOT NULL DEFAULT 1,
                    notes              TEXT
                )
            """)

            // fatigue_entry
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS fatigue_entry (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    logged_at     REAL    NOT NULL,
                    effort_level  INTEGER NOT NULL DEFAULT 3,
                    fatigue_level INTEGER NOT NULL DEFAULT 3,
                    environment   INTEGER NOT NULL DEFAULT 0,
                    program_used  INTEGER NOT NULL DEFAULT 0,
                    hours_worn    INTEGER NOT NULL DEFAULT 8,
                    notes         TEXT
                )
            """)

            // milestone_entry
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS milestone_entry (
                    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
                    type                  INTEGER NOT NULL,
                    achieved_at           REAL    NOT NULL,
                    accuracy_at_milestone REAL,
                    description           TEXT    NOT NULL DEFAULT '',
                    notes                 TEXT,
                    emoji                 TEXT    NOT NULL DEFAULT '🎉'
                )
            """)

            // minimal_pair
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS minimal_pair (
                    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                    language_id          INTEGER NOT NULL REFERENCES language(id),
                    word_entry_id_1      INTEGER NOT NULL REFERENCES word_entry(id),
                    word_entry_id_2      INTEGER NOT NULL REFERENCES word_entry(id),
                    contrast_description TEXT    NOT NULL DEFAULT '',
                    ci_difficulty_level  INTEGER NOT NULL DEFAULT 1
                )
            """)

            // minimal_pair_attempt
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS minimal_pair_attempt (
                    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                    minimal_pair_id      INTEGER NOT NULL REFERENCES minimal_pair(id),
                    played_word_entry_id INTEGER NOT NULL REFERENCES word_entry(id),
                    selected_word_entry_id INTEGER REFERENCES word_entry(id),
                    is_correct           INTEGER NOT NULL DEFAULT 0,
                    family_member_id     INTEGER REFERENCES family_member(id),
                    attempted_at         REAL    NOT NULL
                )
            """)

            // music_attempt
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS music_attempt (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    training_type INTEGER NOT NULL DEFAULT 0,
                    played_item   TEXT    NOT NULL DEFAULT '',
                    user_answer   TEXT    NOT NULL DEFAULT '',
                    is_correct    INTEGER NOT NULL DEFAULT 0,
                    program_used  INTEGER NOT NULL DEFAULT 0,
                    attempted_at  REAL    NOT NULL
                )
            """)

            // badge
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS badge (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    code        TEXT    NOT NULL UNIQUE,
                    title       TEXT    NOT NULL DEFAULT '',
                    description TEXT    NOT NULL DEFAULT '',
                    emoji       TEXT    NOT NULL DEFAULT '🏅',
                    sort_order  INTEGER NOT NULL DEFAULT 0
                )
            """)

            // user_badge
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS user_badge (
                    id         INTEGER PRIMARY KEY AUTOINCREMENT,
                    badge_id   INTEGER NOT NULL REFERENCES badge(id),
                    earned_at  REAL    NOT NULL
                )
            """)

            // user_progress (single row, id=1)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS user_progress (
                    id               INTEGER PRIMARY KEY,
                    total_points     INTEGER NOT NULL DEFAULT 0,
                    current_level    INTEGER NOT NULL DEFAULT 1,
                    current_streak   INTEGER NOT NULL DEFAULT 0,
                    longest_streak   INTEGER NOT NULL DEFAULT 0,
                    total_sessions   INTEGER NOT NULL DEFAULT 0,
                    total_correct    INTEGER NOT NULL DEFAULT 0,
                    total_attempts   INTEGER NOT NULL DEFAULT 0,
                    last_trained_at  REAL
                )
            """)
            // Seed the single progress row
            try db.execute(sql: "INSERT OR IGNORE INTO user_progress (id) VALUES (1)")

            // Seed default badges
            try seedBadges(db)
        }

        // ─── v2 — AVT (Auditory Verbal Therapy) ───────────────────────────────
        migrator.registerMigration("v2_avt") { db in

            // avt_target — phonemes assigned by audiologist
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS avt_target (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    sound               TEXT    NOT NULL,
                    phoneme_ipa         TEXT    NOT NULL DEFAULT '',
                    frequency_range     TEXT    NOT NULL DEFAULT '',
                    sound_description   TEXT    NOT NULL DEFAULT '',
                    current_level       INTEGER NOT NULL DEFAULT 0,
                    is_active           INTEGER NOT NULL DEFAULT 1,
                    assigned_at         REAL    NOT NULL,
                    audiologist_note    TEXT
                )
            """)

            // avt_session — one practice session for a specific sound + level
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS avt_session (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    target_sound    TEXT    NOT NULL,
                    hierarchy_level INTEGER NOT NULL DEFAULT 0,
                    started_at      REAL    NOT NULL,
                    completed_at    REAL,
                    total_attempts  INTEGER NOT NULL DEFAULT 0,
                    correct_attempts INTEGER NOT NULL DEFAULT 0
                )
            """)

            // avt_attempt — individual response within a session
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS avt_attempt (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id      INTEGER NOT NULL REFERENCES avt_session(id) ON DELETE CASCADE,
                    target_sound    TEXT    NOT NULL,
                    presented_sound TEXT    NOT NULL,
                    user_response   TEXT    NOT NULL DEFAULT '',
                    is_correct      INTEGER NOT NULL DEFAULT 0,
                    hierarchy_level INTEGER NOT NULL DEFAULT 0,
                    attempted_at    REAL    NOT NULL
                )
            """)

            // avt_audiologist_note — notes from audiologist appointments
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS avt_audiologist_note (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    noted_at            REAL    NOT NULL,
                    target_sounds       TEXT    NOT NULL DEFAULT '',
                    notes               TEXT    NOT NULL DEFAULT '',
                    next_appointment    REAL
                )
            """)

            // Seed the user's known targets from their audiologist visit
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                INSERT INTO avt_target
                    (sound, phoneme_ipa, frequency_range, sound_description,
                     current_level, is_active, assigned_at)
                VALUES
                    ('sh',  '/ʃ/',  '3500–8000 Hz', 'Voiceless palato-alveolar fricative', 0, 1, ?),
                    ('ush', '/ʌʃ/', '500–8000 Hz',  'Vowel-fricative transition /ʌ/ + /ʃ/', 0, 1, ?),
                    ('mm',  '/m/',  '150–500 Hz',   'Voiced bilabial nasal continuant',    0, 1, ?)
            """, arguments: [now, now, now])

            // Indices
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_avt_session_sound ON avt_session(target_sound)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_avt_attempt_session ON avt_attempt(session_id)")
        }

        // ─── v3 — Confusion Log, Reading Aloud, Activation Date ───────────────
        migrator.registerMigration("v3_confusion_reading_activation") { db in

            // confusion_pair — tracks "said X, heard Y" moments the user notices
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS confusion_pair (
                    id             INTEGER PRIMARY KEY AUTOINCREMENT,
                    said_word      TEXT    NOT NULL DEFAULT '',
                    heard_word     TEXT    NOT NULL DEFAULT '',
                    target_sound   TEXT    NOT NULL DEFAULT '',
                    source         INTEGER NOT NULL DEFAULT 0,
                    avt_session_id INTEGER REFERENCES avt_session(id) ON DELETE SET NULL,
                    context_note   TEXT,
                    logged_at      REAL    NOT NULL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_confusion_pair_logged ON confusion_pair(logged_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_confusion_pair_sound  ON confusion_pair(target_sound)")

            // reading_passage — bundled or user-saved passages
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS reading_passage (
                    id           INTEGER PRIMARY KEY AUTOINCREMENT,
                    title        TEXT    NOT NULL DEFAULT '',
                    category     INTEGER NOT NULL DEFAULT 0,
                    difficulty   INTEGER NOT NULL DEFAULT 1,
                    body         TEXT    NOT NULL DEFAULT '',
                    word_count   INTEGER NOT NULL DEFAULT 0,
                    is_bundled   INTEGER NOT NULL DEFAULT 0,
                    created_at   REAL    NOT NULL
                )
            """)

            // reading_session — one recorded read-aloud attempt
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS reading_session (
                    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
                    passage_id         INTEGER REFERENCES reading_passage(id) ON DELETE SET NULL,
                    passage_title      TEXT    NOT NULL DEFAULT '',
                    passage_body       TEXT    NOT NULL DEFAULT '',
                    word_count         INTEGER NOT NULL DEFAULT 0,
                    duration_seconds   REAL    NOT NULL DEFAULT 0,
                    words_per_minute   REAL    NOT NULL DEFAULT 0,
                    avg_loudness_db    REAL    NOT NULL DEFAULT 0,
                    peak_loudness_db   REAL    NOT NULL DEFAULT 0,
                    audio_file_path    TEXT,
                    notes              TEXT,
                    recorded_at        REAL    NOT NULL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_reading_session_recorded ON reading_session(recorded_at)")

            // user_progress.activated_at — nullable column for implant activation date
            try db.execute(sql: """
                ALTER TABLE user_progress ADD COLUMN activated_at REAL
            """)

            // Seed a handful of bundled passages at three difficulty levels
            try seedReadingPassages(db)
        }

        // ─── v4 — Seed languages + core Cochlear word vocabulary ────────────
        //
        // The `language`, `dialect`, and `word_entry` tables were created
        // in v1 but never seeded, so the Library screen was empty and the
        // user had no "active language" to pick from. This migration
        // bootstraps Tamil + English (with region dialects) and populates
        // the word_entry table with the core vocabulary from the Cochlear
        // AVT exercise bank so the Library is immediately useful.
        migrator.registerMigration("v4_seed_languages_and_words") { db in
            try seedLanguagesAndDialects(db)
            try seedCoreCochlearWords(db)
        }

        // ─── v5 — Add pitch column to reading_session ─────────────────────
        //
        // The voice-metrics feature now tracks fundamental frequency (Hz)
        // during Reading Aloud drills. We need a dedicated numeric column
        // so pitch data is queryable for trends and progress dashboards.
        migrator.registerMigration("v5_reading_session_pitch") { db in
            try db.execute(sql: """
                ALTER TABLE reading_session
                ADD COLUMN avg_pitch_hz REAL NOT NULL DEFAULT 0
            """)
        }

        // ─── v6 — Sound Therapy module ───────────────────────────────────────
        migrator.registerMigration("v6_sound_therapy") { db in

            // sound_progress — per-sound cumulative progress
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sound_progress (
                    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
                    sound                   TEXT    NOT NULL UNIQUE,
                    category                TEXT    NOT NULL DEFAULT '',
                    current_level           INTEGER NOT NULL DEFAULT 0,
                    total_sessions          INTEGER NOT NULL DEFAULT 0,
                    total_correct           INTEGER NOT NULL DEFAULT 0,
                    total_attempts          INTEGER NOT NULL DEFAULT 0,
                    best_accuracy           REAL    NOT NULL DEFAULT 0,
                    last_practiced_at       REAL,
                    is_unlocked             INTEGER NOT NULL DEFAULT 0,
                    female_voice_accuracy   REAL    NOT NULL DEFAULT 0,
                    male_voice_accuracy     REAL    NOT NULL DEFAULT 0
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sound_progress_sound ON sound_progress(sound)")

            // sound_therapy_session — individual practice sessions
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sound_therapy_session (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    exercise_type   TEXT    NOT NULL DEFAULT '',
                    target_sound    TEXT    NOT NULL DEFAULT '',
                    voice_gender    INTEGER NOT NULL DEFAULT 0,
                    exercise_level  INTEGER NOT NULL DEFAULT 0,
                    started_at      REAL    NOT NULL,
                    completed_at    REAL,
                    total_items     INTEGER NOT NULL DEFAULT 0,
                    correct_items   INTEGER NOT NULL DEFAULT 0,
                    is_adaptive     INTEGER NOT NULL DEFAULT 1
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_st_session_sound ON sound_therapy_session(target_sound)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_st_session_date ON sound_therapy_session(started_at)")

            // Seed initial unlocked sounds — the user's known weak sounds
            let now = Date().timeIntervalSince1970
            for sound in ["sh", "s", "m", "n", "ush", "mm", "f", "th"] {
                let cat = SoundTherapyContent.sound(named: sound)?.category.rawValue ?? "fricatives"
                try db.execute(sql: """
                    INSERT OR IGNORE INTO sound_progress
                        (sound, category, current_level, total_sessions, total_correct,
                         total_attempts, best_accuracy, last_practiced_at, is_unlocked,
                         female_voice_accuracy, male_voice_accuracy)
                    VALUES (?, ?, 0, 0, 0, 0, 0, ?, 1, 0, 0)
                """, arguments: [sound, cat, now])
            }
        }

        // ─── v7 — Environmental Sound Training ───────────────────────────
        migrator.registerMigration("v7_environmental_sound") { db in

            // environmental_sound_progress — per-sound cumulative progress
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS environmental_sound_progress (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    sound_id            TEXT    NOT NULL UNIQUE,
                    environment         TEXT    NOT NULL DEFAULT '',
                    current_level       INTEGER NOT NULL DEFAULT 0,
                    total_attempts      INTEGER NOT NULL DEFAULT 0,
                    correct_attempts    INTEGER NOT NULL DEFAULT 0,
                    is_unlocked         INTEGER NOT NULL DEFAULT 1,
                    last_practiced_at   REAL
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_env_sound_id ON environmental_sound_progress(sound_id)")

            // environmental_sound_session — individual practice sessions
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS environmental_sound_session (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    environment         TEXT    NOT NULL DEFAULT '',
                    listening_level     INTEGER NOT NULL DEFAULT 0,
                    started_at          REAL    NOT NULL,
                    completed_at        REAL,
                    total_items         INTEGER NOT NULL DEFAULT 0,
                    correct_items       INTEGER NOT NULL DEFAULT 0,
                    days_post_activation INTEGER NOT NULL DEFAULT 0
                )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_env_session_date ON environmental_sound_session(started_at)")

            // Seed all environmental sounds as unlocked
            let now = Date().timeIntervalSince1970
            for sound in EnvironmentalSoundContent.allSounds {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO environmental_sound_progress
                        (sound_id, environment, current_level, total_attempts,
                         correct_attempts, is_unlocked, last_practiced_at)
                    VALUES (?, ?, 0, 0, 0, 1, ?)
                """, arguments: [sound.id, sound.environment.rawValue, now])
            }
        }

        // ─── v8 — Custom sounds + weekly packs ─────────────────────────
        migrator.registerMigration("v8_custom_sounds_and_packs") { db in

            // custom_environmental_sound — user-created sounds
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS custom_environmental_sound (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    sound_id            TEXT    NOT NULL UNIQUE,
                    name                TEXT    NOT NULL,
                    environment         TEXT    NOT NULL DEFAULT 'home',
                    description         TEXT    NOT NULL DEFAULT '',
                    speech_description  TEXT    NOT NULL DEFAULT '',
                    ci_difficulty       INTEGER NOT NULL DEFAULT 2,
                    is_active           INTEGER NOT NULL DEFAULT 1,
                    created_at          REAL    NOT NULL,
                    updated_at          REAL    NOT NULL
                )
            """)

            // sound_edit_override — edits to built-in sounds (name, description, TTS)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sound_edit_override (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    sound_id            TEXT    NOT NULL UNIQUE,
                    name                TEXT,
                    description         TEXT,
                    speech_description  TEXT,
                    ci_difficulty       INTEGER,
                    updated_at          REAL    NOT NULL
                )
            """)

            // weekly_pack_progress — tracks which weekly packs are unlocked
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS weekly_pack_progress (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    pack_id     TEXT    NOT NULL UNIQUE,
                    is_unlocked INTEGER NOT NULL DEFAULT 0,
                    unlocked_at REAL,
                    completed   INTEGER NOT NULL DEFAULT 0
                )
            """)

            // Seed weekly packs: Week 1 unlocked by default
            let now = Date().timeIntervalSince1970
            let packs = ["week1", "week2", "week3", "week4", "safety"]
            for (i, pack) in packs.enumerated() {
                let unlocked = (i == 0 || pack == "safety") ? 1 : 0
                try db.execute(sql: """
                    INSERT OR IGNORE INTO weekly_pack_progress
                        (pack_id, is_unlocked, unlocked_at, completed)
                    VALUES (?, ?, ?, 0)
                """, arguments: [pack, unlocked, unlocked == 1 ? now : nil])
            }
        }

        // ─── v9 — Voice recordings (real voices for training) ──────────────
        migrator.registerMigration("v9_voice_recordings") { db in

            // People whose voices have been recorded (wife, audiologist, etc.)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recorded_person (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    name            TEXT    NOT NULL,
                    relationship    TEXT    NOT NULL DEFAULT '',
                    color           TEXT    NOT NULL DEFAULT 'lcPurple',
                    icon            TEXT    NOT NULL DEFAULT 'person.fill',
                    is_active       INTEGER NOT NULL DEFAULT 1,
                    created_at      REAL    NOT NULL,
                    updated_at      REAL    NOT NULL
                )
            """)

            // Individual voice recordings linked to a person and optionally a sound
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS voice_recording (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    person_id           INTEGER NOT NULL REFERENCES recorded_person(id) ON DELETE CASCADE,
                    sound_id            TEXT,
                    label               TEXT    NOT NULL,
                    file_name           TEXT    NOT NULL,
                    duration_seconds    REAL    NOT NULL DEFAULT 0,
                    created_at          REAL    NOT NULL
                )
            """)

            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_voice_recording_person
                ON voice_recording(person_id)
            """)

            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_voice_recording_sound
                ON voice_recording(sound_id)
            """)
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Seed data

    private static func seedReadingPassages(_ db: Database) throws {
        // (title, category, difficulty, body)
        // category: 0 = news, 1 = story, 2 = technical, 3 = everyday, 4 = childrens
        let passages: [(String, Int, Int, String)] = [
            (
                "The Morning Walk", 3, 1,
                "Every morning Ravi takes a slow walk around the park near his house. The air is cool and the birds are loud. He stops at the tea stall, drinks one small cup of hot tea, and then walks back home. It is a simple habit, but it makes his whole day better."
            ),
            (
                "A Cat Named Mittu", 4, 1,
                "Mittu is a small black cat with white paws. She lives on the third floor and loves to sit by the window. When the sun is warm, she sleeps for hours. When the door opens, she runs out to say hello. Everyone in the building knows her name."
            ),
            (
                "City Traffic Report", 0, 2,
                "Commuters in the downtown area faced heavy traffic this morning after a water pipe burst on Fifth Avenue. Officials said repair work began at six o'clock and should be finished by noon. Drivers are advised to use Seventh Street or the river road as an alternative. Buses are running on a modified schedule."
            ),
            (
                "How Plants Make Food", 2, 2,
                "Plants make their own food through a process called photosynthesis. They use sunlight, water from the soil, and carbon dioxide from the air. Inside green leaves, a pigment called chlorophyll captures light energy and turns it into sugar. This sugar is what keeps the plant alive and growing."
            ),
            (
                "The Old Lighthouse", 1, 3,
                "For nearly a century, the lighthouse on the cliff had guided fishing boats home. Its white tower, streaked with salt and weather, still stood proud against the wind. Local children believed an old keeper lived inside, polishing the lamp each night, though the town knew the light had been automated years ago. On quiet evenings, people claimed they could still hear him whistling an old tune."
            ),
            (
                "Cochlear Implants Explained", 2, 3,
                "A cochlear implant is a small electronic device that can help a person with severe hearing loss understand speech. Unlike a hearing aid, which only makes sounds louder, an implant bypasses the damaged parts of the inner ear and stimulates the auditory nerve directly. After surgery, the brain needs several weeks or months of practice to learn how to interpret the new signals. This adjustment period is called auditory training, and it is a vital part of recovery."
            )
        ]
        let now = Date().timeIntervalSince1970
        for p in passages {
            let wordCount = p.3.split { $0.isWhitespace || $0.isNewline }.count
            try db.execute(sql: """
                INSERT INTO reading_passage
                    (title, category, difficulty, body, word_count, is_bundled, created_at)
                VALUES (?, ?, ?, ?, ?, 1, ?)
            """, arguments: [p.0, p.1, p.2, p.3, wordCount, now])
        }
    }

    private static func seedBadges(_ db: Database) throws {
        let badges: [(code: String, title: String, description: String, emoji: String, sort: Int)] = [
            ("first_session",    "First Steps",       "Complete your first training session",           "👣",  1),
            ("streak_3",         "3-Day Streak",      "Train 3 days in a row",                          "🔥",  2),
            ("streak_7",         "Week Warrior",      "Train 7 days in a row",                          "⚡",  3),
            ("streak_30",        "Monthly Master",    "Train 30 days in a row",                         "🏆",  4),
            ("ling6_first",      "Ling 6 Listener",   "Complete your first Ling 6 check",               "👂",  5),
            ("ling6_perfect",    "All Six!",          "Detect all 6 sounds in a single Ling 6 check",   "🎯",  6),
            ("ling6_streak_7",   "Consistent Tester", "Complete Ling 6 checks 7 days in a row",         "📅",  7),
            ("words_10",         "Word Learner",      "Learn 10 words",                                 "📖",  8),
            ("words_50",         "Vocabulary Builder","Learn 50 words",                                 "📚",  9),
            ("words_100",        "Century!",          "Learn 100 words",                                "💯", 10),
            ("accuracy_80",      "Sharp Ears",        "Achieve 80% accuracy in a session",              "🎧", 11),
            ("accuracy_95",      "Near Perfect",      "Achieve 95% accuracy in a session",              "⭐", 12),
            ("family_1",         "Family Voice",      "Add your first family member",                   "👨‍👩‍👦", 13),
            ("recordings_10",    "Voice Collector",   "Collect 10 family recordings",                   "🎤", 14),
            ("milestone_first",  "Milestone Maker",   "Log your first milestone",                       "🎉", 15),
        ]
        for b in badges {
            try db.execute(sql: """
                INSERT OR IGNORE INTO badge (code, title, description, emoji, sort_order)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [b.code, b.title, b.description, b.emoji, b.sort])
        }
    }

    // MARK: - v4 seeds

    /// Seed the language + dialect tables with Tamil and English. Uses
    /// INSERT OR IGNORE so re-running the migration on an existing DB
    /// (or future schema bumps) is safe.
    private static func seedLanguagesAndDialects(_ db: Database) throws {
        let langs: [(code: String, name: String, native: String, script: String)] = [
            ("en", "English", "English", "Latin"),
            ("ta", "Tamil",   "தமிழ்",  "Tamil"),
        ]
        for l in langs {
            try db.execute(sql: """
                INSERT OR IGNORE INTO language
                    (code, name, native_name, script_code, font_family,
                     is_right_to_left, is_active)
                VALUES (?, ?, ?, ?, '', 0, 1)
            """, arguments: [l.code, l.name, l.native, l.script])
        }

        // Region dialects for Tamil and English. id lookup by code so we
        // don't rely on a specific auto-increment order.
        let dialects: [(langCode: String, name: String, native: String, region: String)] = [
            ("en", "US English",      "US English",      "US"),
            ("en", "Indian English",  "Indian English",  "IN"),
            ("en", "British English", "British English", "GB"),
            ("ta", "Chennai Tamil",   "சென்னை தமிழ்",   "IN-TN"),
            ("ta", "Madurai Tamil",   "மதுரை தமிழ்",    "IN-TN-MA"),
            ("ta", "Jaffna Tamil",    "யாழ் தமிழ்",     "LK-JA"),
        ]
        for d in dialects {
            guard let langId = try Int.fetchOne(db,
                sql: "SELECT id FROM language WHERE code = ?",
                arguments: [d.langCode])
            else { continue }
            // Skip if a dialect with same (language_id, name) already exists
            let exists = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM dialect
                WHERE language_id = ? AND name = ?
            """, arguments: [langId, d.name]) ?? 0
            if exists > 0 { continue }
            try db.execute(sql: """
                INSERT INTO dialect
                    (language_id, name, native_name, region_code, color_hex, is_active)
                VALUES (?, ?, ?, ?, '', 1)
            """, arguments: [langId, d.name, d.native, d.region])
        }
    }

    /// Seed the word_entry table with the core vocabulary that drives the
    /// existing Cochlear AVT drills (Ling 6 sounds, /sh/ targets, common
    /// minimal pairs, etc.). These are bundled so the Library has content
    /// from day 0 even if the user hasn't installed any publisher packs.
    private static func seedCoreCochlearWords(_ db: Database) throws {
        guard let enId = try Int.fetchOne(db,
            sql: "SELECT id FROM language WHERE code = 'en'") else { return }

        // Curated list mined from Cochlear exercise 3.x phoneme bank and
        // the Ling 6 test. Each tuple: (native_script, ipa, phonetic_key,
        // category_code).
        //
        // category_code matches the filter pills on the Library screen.
        let words: [(String, String, String, String)] = [
            // Ling 6 sounds
            ("ah",      "/ɑ/",    "ling6",    "Ling 6"),
            ("oo",      "/u/",    "ling6",    "Ling 6"),
            ("ee",      "/i/",    "ling6",    "Ling 6"),
            ("sh",      "/ʃ/",    "ling6",    "Ling 6"),
            ("ss",      "/s/",    "ling6",    "Ling 6"),
            ("mm",      "/m/",    "ling6",    "Ling 6"),

            // /sh/ target words
            ("ship",    "/ʃɪp/",  "sh",       "Phonemes"),
            ("shoe",    "/ʃu/",   "sh",       "Phonemes"),
            ("shell",   "/ʃɛl/",  "sh",       "Phonemes"),
            ("shop",    "/ʃɒp/",  "sh",       "Phonemes"),
            ("sheep",   "/ʃip/",  "sh",       "Phonemes"),
            ("shark",   "/ʃɑrk/", "sh",       "Phonemes"),
            ("wash",    "/wɒʃ/",  "sh",       "Phonemes"),
            ("fish",    "/fɪʃ/",  "sh",       "Phonemes"),
            ("dish",    "/dɪʃ/",  "sh",       "Phonemes"),
            ("brush",   "/brʌʃ/", "sh",       "Phonemes"),

            // /s/ target words
            ("sun",     "/sʌn/",  "s",        "Phonemes"),
            ("soap",    "/soʊp/", "s",        "Phonemes"),
            ("sock",    "/sɒk/",  "s",        "Phonemes"),
            ("seed",    "/sid/",  "s",        "Phonemes"),
            ("bus",     "/bʌs/",  "s",        "Phonemes"),
            ("house",   "/haʊs/", "s",        "Phonemes"),

            // /m/ target words
            ("mom",     "/mʌm/",  "m",        "Phonemes"),
            ("man",     "/mæn/",  "m",        "Phonemes"),
            ("moon",    "/mun/",  "m",        "Phonemes"),
            ("milk",    "/mɪlk/", "m",        "Phonemes"),
            ("drum",    "/drʌm/", "m",        "Phonemes"),
            ("ham",     "/hæm/",  "m",        "Phonemes"),

            // Family words
            ("mother",  "/ˈmʌðər/","m",       "Family"),
            ("father",  "/ˈfɑðər/","f",       "Family"),
            ("sister",  "/ˈsɪstər/","s",      "Family"),
            ("brother", "/ˈbrʌðər/","b",      "Family"),
            ("baby",    "/ˈbeɪbi/", "b",      "Family"),

            // Common everyday nouns
            ("dog",     "/dɒɡ/",  "d",        "Animals"),
            ("cat",     "/kæt/",  "k",        "Animals"),
            ("bird",    "/bɜrd/", "b",        "Animals"),
            ("cow",     "/kaʊ/",  "k",        "Animals"),
            ("horse",   "/hɔrs/", "h",        "Animals"),

            ("apple",   "/ˈæpəl/","a",        "Food"),
            ("bread",   "/brɛd/", "b",        "Food"),
            ("water",   "/ˈwɔtər/","w",       "Food"),
            ("rice",    "/raɪs/", "r",        "Food"),
            ("egg",     "/ɛɡ/",   "e",        "Food"),

            ("car",     "/kɑr/",  "k",        "Vehicles"),
            ("bus",     "/bʌs/",  "b",        "Vehicles"),
            ("train",   "/treɪn/","t",        "Vehicles"),
            ("boat",    "/boʊt/", "b",        "Vehicles"),
            ("plane",   "/pleɪn/","p",        "Vehicles"),
        ]

        let now = Date().timeIntervalSince1970

        // Ensure the categories we reference exist so they show as pills.
        let categories: [(code: String, label: String, order: Int)] = [
            ("Ling 6",   "Ling 6",    0),
            ("Phonemes", "Phonemes",  1),
            ("Family",   "Family",    2),
            ("Animals",  "Animals",   3),
            ("Food",     "Food",      4),
            ("Vehicles", "Vehicles",  5),
        ]
        for c in categories {
            let exists = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM word_category
                WHERE language_id = ? AND code = ?
            """, arguments: [enId, c.code]) ?? 0
            if exists == 0 {
                try db.execute(sql: """
                    INSERT INTO word_category
                        (language_id, code, native_display_name,
                         english_display_name, sort_order)
                    VALUES (?, ?, ?, ?, ?)
                """, arguments: [enId, c.code, c.label, c.label, c.order])
            }
        }

        for w in words {
            // Skip if this word already exists for English (by native_script)
            let exists = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM word_entry
                WHERE language_id = ? AND native_script = ?
            """, arguments: [enId, w.0]) ?? 0
            if exists > 0 { continue }

            try db.execute(sql: """
                INSERT INTO word_entry
                    (global_id, language_id, native_script, ipa_phoneme,
                     phonetic_key, is_slang, source, status, publisher_pack_id,
                     sync_status, last_synced_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, 0, 0, 1, NULL, 0, NULL, ?, ?)
            """, arguments: [
                UUID().uuidString, enId, w.0, w.1, w.2, now, now
            ])

            // Link to the category via word_category_map so category filter
            // pills work from day 0.
            let wordId = Int(db.lastInsertedRowID)
            if let catId = try Int.fetchOne(db, sql: """
                SELECT id FROM word_category
                WHERE language_id = ? AND code = ?
            """, arguments: [enId, w.3]) {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO word_category_map
                        (word_entry_id, word_category_id)
                    VALUES (?, ?)
                """, arguments: [wordId, catId])
            }

            // Also stamp category_code directly on word_entry so the
            // Library grouping works even without joining through the map.
            // word_entry has no category_code column though — the Library
            // reads it off a field on WordEntry that's set at decode time.
            // We'll skip this; the map covers filter pills, and the
            // Library can fall back to "Uncategorized" until category_code
            // is added. (See comment in LibraryViewController.)
        }
    }
}
