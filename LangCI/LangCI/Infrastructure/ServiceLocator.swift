// ServiceLocator.swift
// LangCI
//
// Central registry that wires all service implementations to their protocols.
// Access services anywhere via ServiceLocator.shared.<service>.

import Foundation
import GRDB

final class ServiceLocator {

    // MARK: - Singleton

    static let shared = ServiceLocator()
    private init() { configure() }

    // MARK: - Services

    private(set) var languageService: LanguageService!
    private(set) var wordService: WordService!
    private(set) var familyMemberService: FamilyMemberService!
    private(set) var recordingService: RecordingService!
    private(set) var trainingService: TrainingService!
    private(set) var ling6Service: Ling6Service!
    private(set) var mappingService: MappingService!
    private(set) var fatigueService: FatigueService!
    private(set) var milestoneService: MilestoneService!
    private(set) var progressService: ProgressService!
    private(set) var minimalPairsService: MinimalPairsService!
    private(set) var musicService: MusicPerceptionService!
    private(set) var avtService: AVTService!
    private(set) var confusionPairService: ConfusionPairService!
    private(set) var readingAloudService: ReadingAloudService!
    private(set) var soundTherapyService: SoundTherapyService!
    private(set) var environmentalSoundService: EnvironmentalSoundService!
    private(set) var voiceRecordingService: VoiceRecordingService!
    private(set) var soundDetectionService: SoundDetectionService!

    // MARK: - Configuration

    private func configure() {
        let db = DatabaseManager.shared.dbQueue

        let progress   = GRDBProgressService(db: db)
        let training   = GRDBTrainingService(db: db, progressService: progress)

        languageService      = GRDBLanguageService(db: db)
        wordService          = GRDBWordService(db: db)
        familyMemberService  = GRDBFamilyMemberService(db: db)
        recordingService     = GRDBRecordingService(db: db)
        trainingService      = training
        ling6Service         = GRDBLing6Service(db: db)
        mappingService       = GRDBMappingService(db: db)
        fatigueService       = GRDBFatigueService(db: db)
        milestoneService     = GRDBMilestoneService(db: db)
        progressService      = progress
        minimalPairsService  = GRDBMinimalPairsService(db: db)
        musicService         = GRDBMusicPerceptionService(db: db)
        avtService           = GRDBAvtService(db: db)
        confusionPairService = GRDBConfusionPairService(db: db)
        readingAloudService  = GRDBReadingAloudService(db: db)
        soundTherapyService  = GRDBSoundTherapyService(db: db)
        environmentalSoundService = GRDBEnvironmentalSoundService(db: db)
        voiceRecordingService     = GRDBVoiceRecordingService(db: db)
        soundDetectionService     = GRDBSoundDetectionService(db: db)
    }
}
