// SelfTestViewController.swift
// LangCI — Self-Test Sound Detection
//
// App plays a sound → user picks which sound they heard from choices.
// Auto-marks correct/wrong based on their selection.
// Great for daily home practice between audiologist visits.
//
// Flow: "Listen" button → sound plays → tap what you heard → feedback → next

import UIKit
import AVFoundation

final class SelfTestViewController: UIViewController {

    // MARK: - Services

    private let service = ServiceLocator.shared.soundDetectionService!

    // MARK: - State

    private var session: DetectionTestSession!
    private var sounds: [TestSound] = []
    private var trialsPerSound = 5  // shorter for self-test
    /// Flat list of all trials to present: (soundIndex, trialNumber)
    private var trialQueue: [(soundIdx: Int, trial: Int)] = []
    private var currentQueueIndex = 0
    private var correctCount = 0
    private var totalCount = 0

    /// Time when sound was played (for response time)
    private var playTimestamp: Date?

    /// For playing recorded audio files
    private var audioPlayer: AVAudioPlayer?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let progressBar = ProgressBarView()
    private let progressLabel = UILabel()

    private let instructionCard = LCCard()
    private let instructionLabel = UILabel()

    private let listenButton = LCButton(title: "▶ Listen", color: .lcTeal)
    private let voiceLabel = UILabel()
    private let pronunciationLabel = UILabel()
    private let editPronunciationButton = UIButton(type: .system)

    private let choiceCard = LCCard()
    private let choiceStack = UIStackView()
    private var choiceButtons: [UIButton] = []

    private let feedbackLabel = UILabel()
    private let nextButton = LCButton(title: "Next →", color: .lcBlue)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Self Test"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        loadAndStart()
    }

    private func loadAndStart() {
        Task {
            sounds = (try? await service.getActiveSounds()) ?? []
            guard !sounds.isEmpty else { return }

            session = try? await service.createSession(
                mode: .selfTest, trialsPerSound: trialsPerSound,
                distanceCm: 0,
                patientId: nil, patientName: nil, testerName: nil, testedAt: Date())

            // Build shuffled trial queue
            var queue: [(Int, Int)] = []
            for si in 0..<sounds.count {
                for t in 1...trialsPerSound {
                    queue.append((si, t))
                }
            }
            trialQueue = queue.shuffled()

            await MainActor.run {
                self.buildUI()
                self.showCurrentTrial()
            }
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 12, leading: LC.cardPadding, bottom: 40, trailing: LC.cardPadding)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Progress
        progressBar.color = .lcTeal
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.heightAnchor.constraint(equalToConstant: 6).isActive = true
        progressLabel.font = UIFont.lcCaption()
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        contentStack.addArrangedSubview(progressBar)
        contentStack.addArrangedSubview(progressLabel)

        // Instruction
        instructionLabel.text = "Tap Listen, then pick the sound you heard"
        instructionLabel.font = UIFont.lcBody()
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionCard.addSubview(instructionLabel)
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 16),
            instructionLabel.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -16),
            instructionLabel.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(instructionCard)

        // Voice accent picker (English only for phonetic tests)
        let accentPicker = VoiceAccentPicker()
        accentPicker.includeTamil = false
        contentStack.addArrangedSubview(accentPicker)

        // Listen button
        listenButton.addTarget(self, action: #selector(listenTapped), for: .touchUpInside)
        listenButton.translatesAutoresizingMaskIntoConstraints = false
        listenButton.heightAnchor.constraint(equalToConstant: 64).isActive = true
        contentStack.addArrangedSubview(listenButton)

        voiceLabel.font = UIFont.lcCaption()
        voiceLabel.textColor = .lcBlue
        voiceLabel.textAlignment = .center
        voiceLabel.alpha = 0
        contentStack.addArrangedSubview(voiceLabel)

        // Pronunciation info + edit
        pronunciationLabel.font = UIFont.lcCaption()
        pronunciationLabel.textColor = .secondaryLabel
        pronunciationLabel.textAlignment = .center
        pronunciationLabel.alpha = 0

        let editCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        editPronunciationButton.setImage(UIImage(systemName: "pencil.circle", withConfiguration: editCfg), for: .normal)
        editPronunciationButton.setTitle(" Edit", for: .normal)
        editPronunciationButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        editPronunciationButton.tintColor = .lcTeal
        editPronunciationButton.alpha = 0
        editPronunciationButton.addTarget(self, action: #selector(editPronunciationTapped), for: .touchUpInside)

        let pronRow = UIStackView(arrangedSubviews: [pronunciationLabel, editPronunciationButton])
        pronRow.axis = .horizontal
        pronRow.spacing = 6
        pronRow.alignment = .center
        let pronWrapper = UIStackView(arrangedSubviews: [UIView(), pronRow, UIView()])
        pronWrapper.axis = .horizontal
        pronWrapper.distribution = .equalCentering
        contentStack.addArrangedSubview(pronWrapper)

        // Choice buttons (sound options)
        choiceStack.axis = .vertical
        choiceStack.spacing = 8
        choiceStack.translatesAutoresizingMaskIntoConstraints = false
        choiceCard.addSubview(choiceStack)
        NSLayoutConstraint.activate([
            choiceStack.topAnchor.constraint(equalTo: choiceCard.topAnchor, constant: 12),
            choiceStack.bottomAnchor.constraint(equalTo: choiceCard.bottomAnchor, constant: -12),
            choiceStack.leadingAnchor.constraint(equalTo: choiceCard.leadingAnchor, constant: 12),
            choiceStack.trailingAnchor.constraint(equalTo: choiceCard.trailingAnchor, constant: -12),
        ])
        choiceCard.alpha = 0
        contentStack.addArrangedSubview(choiceCard)

        // Feedback
        feedbackLabel.font = UIFont.lcBodyBold()
        feedbackLabel.textAlignment = .center
        feedbackLabel.alpha = 0
        contentStack.addArrangedSubview(feedbackLabel)

        // Next
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.alpha = 0
        contentStack.addArrangedSubview(nextButton)

        buildChoiceButtons()
    }

    private func buildChoiceButtons() {
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        choiceButtons = []

        // Create 2-column rows of sound choice buttons
        var rows: [[TestSound]] = []
        var currentRow: [TestSound] = []
        for sound in sounds {
            currentRow.append(sound)
            if currentRow.count == 3 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually

            for sound in row {
                let btn = UIButton(type: .system)
                btn.setTitle(sound.symbol, for: .normal)
                btn.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
                btn.backgroundColor = .secondarySystemFill
                btn.tintColor = .label
                btn.layer.cornerRadius = 12
                btn.tag = sound.id
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.heightAnchor.constraint(equalToConstant: 56).isActive = true
                btn.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(btn)
                choiceButtons.append(btn)
            }

            // Pad incomplete rows
            if row.count < 3 {
                for _ in row.count..<3 {
                    let spacer = UIView()
                    rowStack.addArrangedSubview(spacer)
                }
            }

            choiceStack.addArrangedSubview(rowStack)
        }
    }

    // MARK: - Trial Management

    private func showCurrentTrial() {
        guard currentQueueIndex < trialQueue.count else {
            showCompletion()
            return
        }

        let total = trialQueue.count
        let progress = Double(currentQueueIndex) / Double(total)
        progressBar.setProgress(progress, animated: true)
        progressLabel.text = "\(currentQueueIndex + 1) of \(total)"

        // Reset UI for new trial
        choiceCard.alpha = 0
        feedbackLabel.alpha = 0
        nextButton.alpha = 0
        voiceLabel.alpha = 0
        pronunciationLabel.alpha = 0
        editPronunciationButton.alpha = 0
        listenButton.isEnabled = true
        listenButton.alpha = 1

        // Reset choice button colors
        for btn in choiceButtons {
            btn.backgroundColor = .secondarySystemFill
            btn.tintColor = .label
            btn.isEnabled = true
        }

        instructionLabel.text = "Tap Listen, then pick the sound you heard"
    }

    @objc private func listenTapped() {
        guard currentQueueIndex < trialQueue.count else { return }
        let (soundIdx, _) = trialQueue[currentQueueIndex]
        let sound = sounds[soundIdx]
        lcHaptic(.light)

        // 1. Try recorded audio file first
        if let fileName = sound.audioFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    voiceLabel.text = "🎙 Recording"
                    pronunciationLabel.text = "Recorded audio"
                    UIView.animate(withDuration: 0.2) {
                        self.voiceLabel.alpha = 1
                        self.pronunciationLabel.alpha = 1
                        self.editPronunciationButton.alpha = 1
                    }
                    playTimestamp = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UIView.animate(withDuration: 0.3) {
                            self.choiceCard.alpha = 1
                            self.instructionLabel.text = "What sound did you hear?"
                        }
                    }
                    return
                } catch { }
            }
        }

        // 2. Fall back to TTS
        let profile = MultiVoiceTTS.shared.speakEnglishOnly(sound.speakableText)
        voiceLabel.text = "🔊 \(profile.name)"
        pronunciationLabel.text = "TTS says: \"\(sound.speakableText)\""
        UIView.animate(withDuration: 0.2) {
            self.voiceLabel.alpha = 1
            self.pronunciationLabel.alpha = 1
            self.editPronunciationButton.alpha = 1
        }

        playTimestamp = Date()

        // Show choices after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.animate(withDuration: 0.3) {
                self.choiceCard.alpha = 1
                self.instructionLabel.text = "What sound did you hear?"
            }
        }
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        guard currentQueueIndex < trialQueue.count else { return }
        let (soundIdx, trialNum) = trialQueue[currentQueueIndex]
        let correctSound = sounds[soundIdx]
        let chosenSoundId = sender.tag

        let isCorrect = chosenSoundId == correctSound.id
        let responseTime: Int?
        if let ts = playTimestamp {
            responseTime = Int(Date().timeIntervalSince(ts) * 1000)
        } else {
            responseTime = nil
        }

        // Visual feedback
        lcHaptic(isCorrect ? .light : .heavy)
        for btn in choiceButtons {
            btn.isEnabled = false
            if btn.tag == correctSound.id {
                btn.backgroundColor = .lcGreen.withAlphaComponent(0.3)
                btn.tintColor = .lcGreen
            }
            if btn.tag == chosenSoundId && !isCorrect {
                btn.backgroundColor = .lcRed.withAlphaComponent(0.3)
                btn.tintColor = .lcRed
            }
        }

        let chosenSymbol = sounds.first(where: { $0.id == chosenSoundId })?.symbol ?? "?"
        if isCorrect {
            feedbackLabel.text = "✓ Correct!"
            feedbackLabel.textColor = .lcGreen
            correctCount += 1
        } else {
            feedbackLabel.text = "✗ It was \"\(correctSound.symbol)\" — you chose \"\(chosenSymbol)\""
            feedbackLabel.textColor = .lcRed
        }
        totalCount += 1

        UIView.animate(withDuration: 0.2) {
            self.feedbackLabel.alpha = 1
            self.nextButton.alpha = 1
        }

        // Save trial
        let trial = DetectionTrial(
            id: 0, sessionId: session.id,
            soundId: correctSound.id,
            trialNumber: trialNum,
            isDetected: true, isCorrect: isCorrect,
            userResponse: chosenSymbol,
            responseTimeMs: responseTime,
            createdAt: Date())
        Task {
            _ = try? await service.recordTrial(trial)
        }
    }

    @objc private func nextTapped() {
        lcHaptic(.light)
        currentQueueIndex += 1
        showCurrentTrial()
    }

    // MARK: - Completion

    private func showCompletion() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let checkmark = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        checkmark.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg)
        checkmark.tintColor = .lcGreen
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let title = UILabel()
        title.text = "Test Complete!"
        title.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        title.textAlignment = .center

        let accuracy = totalCount > 0 ? Int(Double(correctCount) / Double(totalCount) * 100) : 0
        let scoreLabel = UILabel()
        scoreLabel.text = "\(correctCount)/\(totalCount) correct (\(accuracy)%)"
        scoreLabel.font = UIFont.lcBodyBold()
        scoreLabel.textColor = accuracy >= 80 ? .lcGreen : (accuracy >= 50 ? .lcAmber : .lcRed)
        scoreLabel.textAlignment = .center

        let viewResults = LCButton(title: "View Results Grid", color: .lcTeal)
        viewResults.addTarget(self, action: #selector(viewResultsTapped), for: .touchUpInside)

        let doneBtn = LCButton(title: "Done", color: .lcBlue)
        doneBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        [checkmark, title, scoreLabel, viewResults, doneBtn].forEach {
            contentStack.addArrangedSubview($0)
        }

        // Mark complete
        Task {
            try? await service.completeSession(id: session.id, notes: nil)
        }

        lcHapticSuccess()
    }

    // MARK: - Navigation

    @objc private func closeTapped() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func viewResultsTapped() {
        let vc = DetectionResultsGridViewController(sessionId: session.id)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Edit Pronunciation (Record)

    @objc private func editPronunciationTapped() {
        guard currentQueueIndex < trialQueue.count else { return }
        let (soundIdx, _) = trialQueue[currentQueueIndex]
        presentRecorder(for: soundIdx)
    }

    private func presentRecorder(for soundIndex: Int) {
        guard soundIndex < sounds.count else { return }

        let recorder = SoundRecorderViewController()
        recorder.sound = sounds[soundIndex]
        recorder.onSaved = { [weak self] fileName in
            guard let self = self else { return }
            self.sounds[soundIndex].audioFileName = fileName
            self.pronunciationLabel.text = "🎙 Recorded audio"
            Task {
                try? await self.service.updateSound(self.sounds[soundIndex])
            }
        }

        if let sheet = recorder.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(recorder, animated: true)
    }
}
