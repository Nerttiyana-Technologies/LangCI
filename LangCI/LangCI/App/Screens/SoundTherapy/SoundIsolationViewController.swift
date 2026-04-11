// SoundIsolationViewController.swift
// LangCI — Sound Isolation Exercise
//
// Progressive difficulty: isolation → syllable → word → sentence.
// Speaks a target sound via TTS, user picks from multiple choices.
// Supports voice gender switching (female = easier, male = harder).

import UIKit
import AVFoundation

final class SoundIsolationViewController: UIViewController {

    // MARK: - Configuration

    var voiceGender: VoiceGender = .female
    var isKidMode = false
    var targetSound: String?

    // MARK: - State

    private var soundDef: TargetSoundDefinition?
    private var currentLevel: SoundExerciseLevel = .isolation
    private var items: [String] = []           // words/syllables to present
    private var distractors: [String] = []     // wrong answers
    private var currentIndex = 0
    private var correctCount = 0
    private var results: [SoundItemResult] = []
    private var itemStartTime: Date?
    private var isComplete = false

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let levelSegment = UISegmentedControl()
    private let progressLabel = UILabel()
    private let progressBar = ProgressBarView()

    private let speakerCard = LCCard()
    private let speakerButton = LCIconButton(systemIcon: "speaker.wave.3.fill", tint: .lcPurple)
    private let currentWordLabel = UILabel()

    private let instructionLabel = UILabel()
    private var choiceButtons: [UIButton] = []
    private let choiceStack = UIStackView()

    private let feedbackLabel = UILabel()
    private let nextButton = LCButton(title: "Next", color: .lcPurple)
    private let resultsCard = LCCard()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground
        title = isKidMode ? "Listen & Learn" : "Sound Practice"

        // Find sound definition
        if let target = targetSound {
            soundDef = SoundTherapyContent.sound(named: target)
        }
        if soundDef == nil {
            soundDef = SoundTherapyContent.allSounds.first
            targetSound = soundDef?.sound
        }

        // Load current level from progress
        Task {
            if let sound = targetSound,
               let progress = try? await ServiceLocator.shared.soundTherapyService.getProgress(for: sound) {
                await MainActor.run {
                    self.currentLevel = progress.currentLevel
                    self.levelSegment.selectedSegmentIndex = self.currentLevel.rawValue
                    self.startLevel()
                }
            } else {
                self.startLevel()
            }
        }

        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 12, leading: 20, bottom: 32, trailing: 20
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // Level selector
        for level in SoundExerciseLevel.allCases {
            levelSegment.insertSegment(withTitle: level.label, at: level.rawValue, animated: false)
        }
        levelSegment.selectedSegmentIndex = currentLevel.rawValue
        levelSegment.addTarget(self, action: #selector(levelChanged), for: .valueChanged)
        contentStack.addArrangedSubview(levelSegment)

        // Sound title + IPA
        let titleStack = UIStackView()
        titleStack.axis = .horizontal
        titleStack.spacing = 8
        titleStack.alignment = .center

        let soundTitle = UILabel()
        soundTitle.text = "\(soundDef?.sound.uppercased() ?? "?")  \(soundDef?.ipa ?? "")"
        soundTitle.font = .systemFont(ofSize: 22, weight: .bold)
        soundTitle.textColor = .lcPurple

        let freqLabel = UILabel()
        freqLabel.text = soundDef?.frequencyRange ?? ""
        freqLabel.font = UIFont.lcCaption()
        freqLabel.textColor = .tertiaryLabel

        titleStack.addArrangedSubview(soundTitle)
        titleStack.addArrangedSubview(UIView())
        titleStack.addArrangedSubview(freqLabel)
        contentStack.addArrangedSubview(titleStack)

        // Progress
        progressLabel.font = UIFont.lcCaption()
        progressLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(progressLabel)
        contentStack.addArrangedSubview(progressBar)

        // Speaker card
        let speakerStack = UIStackView()
        speakerStack.axis = .vertical
        speakerStack.alignment = .center
        speakerStack.spacing = 8
        speakerStack.translatesAutoresizingMaskIntoConstraints = false

        speakerButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        speakerButton.heightAnchor.constraint(equalToConstant: 72).isActive = true
        speakerButton.addTarget(self, action: #selector(playCurrentItem), for: .touchUpInside)

        currentWordLabel.font = .systemFont(ofSize: 14, weight: .medium)
        currentWordLabel.textColor = .tertiaryLabel
        currentWordLabel.text = "Tap to listen"

        speakerStack.addArrangedSubview(speakerButton)
        speakerStack.addArrangedSubview(currentWordLabel)
        speakerCard.addSubview(speakerStack)
        NSLayoutConstraint.activate([
            speakerStack.topAnchor.constraint(equalTo: speakerCard.topAnchor, constant: 20),
            speakerStack.bottomAnchor.constraint(equalTo: speakerCard.bottomAnchor, constant: -20),
            speakerStack.centerXAnchor.constraint(equalTo: speakerCard.centerXAnchor),
        ])
        contentStack.addArrangedSubview(speakerCard)

        // Instruction
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        contentStack.addArrangedSubview(instructionLabel)

        // Choices (vertical stack of 4 buttons)
        choiceStack.axis = .vertical
        choiceStack.spacing = 10
        for i in 0..<4 {
            let btn = UIButton(type: .system)
            btn.tag = i
            btn.titleLabel?.font = .systemFont(ofSize: isKidMode ? 24 : 18, weight: .semibold)
            btn.setTitleColor(.label, for: .normal)
            btn.backgroundColor = .lcCard
            btn.layer.cornerRadius = LC.cornerRadius
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor.separator.cgColor
            btn.heightAnchor.constraint(equalToConstant: isKidMode ? 60 : 50).isActive = true
            btn.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
            choiceButtons.append(btn)
            choiceStack.addArrangedSubview(btn)
        }
        contentStack.addArrangedSubview(choiceStack)

        // Feedback + next
        feedbackLabel.font = .systemFont(ofSize: 18, weight: .bold)
        feedbackLabel.textAlignment = .center
        feedbackLabel.isHidden = true
        contentStack.addArrangedSubview(feedbackLabel)

        nextButton.isHidden = true
        nextButton.addTarget(self, action: #selector(nextItem), for: .touchUpInside)
        contentStack.addArrangedSubview(nextButton)

        resultsCard.isHidden = true
        contentStack.addArrangedSubview(resultsCard)
    }

    // MARK: - Level Management

    @objc private func levelChanged() {
        currentLevel = SoundExerciseLevel(rawValue: levelSegment.selectedSegmentIndex) ?? .isolation
        startLevel()
    }

    private func startLevel() {
        guard let def = soundDef else { return }

        switch currentLevel {
        case .isolation:
            items = def.isolationForms
            // Distractors: other similar sounds
            distractors = def.confusionPartners
            instructionLabel.text = isKidMode
                ? "Can you hear the sound?"
                : "Listen and identify the sound"
        case .syllable:
            items = def.syllableForms.shuffled()
            distractors = def.confusionPartners.flatMap { partner -> [String] in
                let partnerDef = SoundTherapyContent.sound(named: partner)
                return partnerDef?.syllableForms ?? [partner]
            }
            instructionLabel.text = isKidMode
                ? "Which syllable did you hear?"
                : "Identify the syllable"
        case .word:
            items = Array(def.wordForms.shuffled().prefix(8))
            distractors = def.confusionPartners.flatMap { partner -> [String] in
                let partnerDef = SoundTherapyContent.sound(named: partner)
                return partnerDef?.wordForms ?? [partner]
            }
            instructionLabel.text = isKidMode
                ? "Which word did you hear?"
                : "Identify the word"
        case .sentence:
            items = def.sentenceForms
            distractors = def.confusionPartners.flatMap { partner -> [String] in
                let partnerDef = SoundTherapyContent.sound(named: partner)
                return partnerDef?.sentenceForms.map { String($0.prefix(40)) + "..." } ?? [partner]
            }
            instructionLabel.text = isKidMode
                ? "Which sentence did you hear?"
                : "Identify the sentence"
        }

        currentIndex = 0
        correctCount = 0
        results = []
        isComplete = false

        resultsCard.isHidden = true
        choiceStack.isHidden = false
        speakerCard.isHidden = false
        instructionLabel.isHidden = false

        if !items.isEmpty {
            presentCurrentItem()
        }
    }

    // MARK: - Present Item

    private func presentCurrentItem() {
        guard currentIndex < items.count else { finishLevel(); return }

        let target = items[currentIndex]
        itemStartTime = Date()

        // Build choices: target + 3 distractors
        var choices = [target]
        let available = distractors.filter { $0 != target }.shuffled()
        choices.append(contentsOf: available.prefix(3))

        // If not enough distractors, pad with items from the same definition
        while choices.count < 4 {
            let filler = items.filter { $0 != target && !choices.contains($0) }.randomElement()
                ?? distractors.randomElement() ?? "?"
            choices.append(filler)
        }
        choices.shuffle()

        // Update buttons
        for (i, btn) in choiceButtons.enumerated() {
            if i < choices.count {
                btn.setTitle(choices[i], for: .normal)
                btn.isHidden = false
                btn.isEnabled = true
                btn.layer.borderColor = UIColor.separator.cgColor
                btn.backgroundColor = .lcCard
            } else {
                btn.isHidden = true
            }
        }

        feedbackLabel.isHidden = true
        nextButton.isHidden = true

        // Update progress
        let fraction = Double(currentIndex) / Double(items.count)
        progressBar.setProgress(CGFloat(fraction), animated: true)
        progressLabel.text = "\(currentIndex + 1) of \(items.count) — \(currentLevel.label)"

        currentWordLabel.text = "Tap to listen"

        // Auto-play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.playCurrentItem()
        }
    }

    @objc private func playCurrentItem() {
        guard currentIndex < items.count else { return }
        let target = items[currentIndex]

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: target)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (currentLevel == .sentence ? 0.9 : 0.8)
        utterance.pitchMultiplier = voiceGender == .female ? 1.2 : 0.85
        utterance.volume = 1.0

        if voiceGender == .female {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        } else {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            utterance.voice = voices.first(where: {
                $0.name.lowercased().contains("daniel") || $0.name.lowercased().contains("aaron")
            }) ?? voices.last
            utterance.pitchMultiplier = 0.8
        }

        // Animate
        UIView.animate(withDuration: 0.1) { self.speakerButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15) }
        UIView.animate(withDuration: 0.1, delay: 0.2) { self.speakerButton.transform = .identity }

        synthesizer.speak(utterance)
    }

    // MARK: - Choice Handling

    @objc private func choiceTapped(_ sender: UIButton) {
        guard currentIndex < items.count else { return }
        let target = items[currentIndex]
        let chosen = sender.title(for: .normal) ?? ""
        let isCorrect = chosen == target
        let reactionMs = Int((Date().timeIntervalSince(itemStartTime ?? Date())) * 1000)

        // Disable all buttons
        choiceButtons.forEach { $0.isEnabled = false }

        if isCorrect {
            correctCount += 1
            sender.layer.borderColor = UIColor.lcGreen.cgColor
            sender.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.1)
            feedbackLabel.text = isKidMode ? "You got it!" : "Correct!"
            feedbackLabel.textColor = .lcGreen
            lcHapticSuccess()
        } else {
            sender.layer.borderColor = UIColor.lcRed.cgColor
            sender.backgroundColor = UIColor.lcRed.withAlphaComponent(0.1)
            // Highlight correct
            if let correctBtn = choiceButtons.first(where: { $0.title(for: .normal) == target }) {
                correctBtn.layer.borderColor = UIColor.lcGreen.cgColor
                correctBtn.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.1)
            }
            feedbackLabel.text = isKidMode
                ? "Not quite — it was '\(target)'"
                : "It was '\(target)'"
            feedbackLabel.textColor = .lcRed
            lcHaptic(.heavy)
        }

        feedbackLabel.isHidden = false
        results.append(SoundItemResult(
            presented: target, target: target,
            userChoice: chosen, isCorrect: isCorrect,
            reactionTimeMs: reactionMs
        ))

        if currentIndex < items.count - 1 {
            nextButton.isHidden = false
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishLevel()
            }
        }
    }

    @objc private func nextItem() {
        currentIndex += 1
        presentCurrentItem()
    }

    // MARK: - Finish

    private func finishLevel() {
        isComplete = true
        let accuracy = items.isEmpty ? 0 : Double(correctCount) / Double(items.count) * 100

        progressBar.setProgress(1.0, animated: true)

        choiceStack.isHidden = true
        speakerCard.isHidden = true
        instructionLabel.isHidden = true
        nextButton.isHidden = true
        feedbackLabel.isHidden = true

        resultsCard.isHidden = false
        resultsCard.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = "\(currentLevel.label) Complete!"
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)

        let scoreLbl = UILabel()
        scoreLbl.text = "\(correctCount) / \(items.count)"
        scoreLbl.font = .systemFont(ofSize: 48, weight: .heavy)
        scoreLbl.textColor = accuracy >= 80 ? .lcGreen : accuracy >= 50 ? .lcOrange : .lcRed

        let accLbl = UILabel()
        accLbl.text = String(format: "%.0f%% — %@ voice", accuracy, voiceGender.label)
        accLbl.font = .systemFont(ofSize: 16, weight: .medium)
        accLbl.textColor = .secondaryLabel

        // Advancement hint
        let hintLbl = UILabel()
        hintLbl.numberOfLines = 0
        hintLbl.textAlignment = .center
        hintLbl.font = .systemFont(ofSize: 14, weight: .medium)
        if accuracy >= 80 && currentLevel < .sentence {
            hintLbl.text = isKidMode
                ? "Amazing! Try the next level!"
                : "Great accuracy! Ready to advance to \(SoundExerciseLevel(rawValue: currentLevel.rawValue + 1)?.label ?? "next")."
            hintLbl.textColor = .lcGreen
        } else if accuracy >= 80 && voiceGender == .female {
            hintLbl.text = "Try the male voice for an extra challenge!"
            hintLbl.textColor = .lcTeal
        } else {
            hintLbl.text = isKidMode ? "Keep practising!" : "Keep practising to improve."
            hintLbl.textColor = .secondaryLabel
        }

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let retryBtn = LCButton(title: "Retry", color: .lcPurple)
        retryBtn.addTarget(self, action: #selector(retryLevel), for: .touchUpInside)
        buttonRow.addArrangedSubview(retryBtn)

        if accuracy >= 80 && currentLevel < .sentence {
            let advanceBtn = LCButton(title: "Next Level", color: .lcGreen)
            advanceBtn.addTarget(self, action: #selector(advanceLevel), for: .touchUpInside)
            buttonRow.addArrangedSubview(advanceBtn)
        }

        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(scoreLbl)
        stack.addArrangedSubview(accLbl)
        stack.addArrangedSubview(hintLbl)
        stack.addArrangedSubview(buttonRow)

        resultsCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -20),
        ])

        saveSession()
    }

    @objc private func retryLevel() {
        startLevel()
    }

    @objc private func advanceLevel() {
        if let next = SoundExerciseLevel(rawValue: currentLevel.rawValue + 1) {
            currentLevel = next
            levelSegment.selectedSegmentIndex = next.rawValue
            startLevel()
        }
    }

    private func saveSession() {
        let session = SoundTherapySession(
            id: 0,
            exerciseType: "isolation",
            targetSound: targetSound ?? "",
            voiceGender: voiceGender,
            exerciseLevel: currentLevel,
            startedAt: Date().addingTimeInterval(-Double(items.count * 5)),
            completedAt: Date(),
            totalItems: items.count,
            correctItems: correctCount,
            isAdaptive: true
        )

        Task {
            let service = ServiceLocator.shared.soundTherapyService!
            _ = try? await service.saveSession(session)
            _ = try? await service.updateProgress(
                sound: targetSound ?? "",
                level: currentLevel,
                voiceGender: voiceGender,
                correct: correctCount,
                total: items.count
            )
        }
    }
}
