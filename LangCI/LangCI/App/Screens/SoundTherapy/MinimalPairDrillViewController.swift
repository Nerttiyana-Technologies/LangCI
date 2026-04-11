// MinimalPairDrillViewController.swift
// LangCI — Minimal Pair Drill
//
// Plays two similar words via TTS, user identifies which one they heard.
// Tracks accuracy per sound contrast with voice gender difficulty.

import UIKit
import AVFoundation

final class MinimalPairDrillViewController: UIViewController {

    // MARK: - Configuration

    var voiceGender: VoiceGender = .female
    var isKidMode = false
    var focusSound: String?         // pre-select a specific sound
    var contrastFilter: String?     // e.g. "sh vs s"

    // MARK: - State

    private var pairs: [SoundMinimalPairItem] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var results: [SoundItemResult] = []
    private var currentTarget: SoundMinimalPairItem?
    private var currentCorrectSide: Int = 0  // 0 = left, 1 = right
    private var itemStartTime: Date?
    private var isComplete = false

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let progressLabel = UILabel()
    private let progressDotsStack = UIStackView()
    private let taskCard = LCCard()
    private let speakerButton = LCIconButton(systemIcon: "speaker.wave.3.fill", tint: .lcTeal)
    private let instructionLabel = UILabel()

    private let choiceStack = UIStackView()
    private let choice1Button = UIButton(type: .system)
    private let choice2Button = UIButton(type: .system)

    private let feedbackLabel = UILabel()
    private let nextButton = LCButton(title: "Next", color: .lcTeal)

    // Results
    private let resultsCard = LCCard()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadPairs()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = isKidMode ? "Same or Different?" : "Minimal Pairs"
        view.backgroundColor = .lcBackground
    }

    private func loadPairs() {
        if let contrast = contrastFilter {
            pairs = SoundTherapyContent.minimalPairs(for: contrast).shuffled()
        } else if let focus = focusSound {
            pairs = SoundTherapyContent.minimalPairs(involving: focus).shuffled()
        } else {
            pairs = SoundTherapyContent.minimalPairs.shuffled()
        }

        // Limit to 10 per drill
        pairs = Array(pairs.prefix(10))
        currentIndex = 0
        correctCount = 0
        results = []
        isComplete = false

        if !pairs.isEmpty {
            presentItem(pairs[0])
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 16, leading: 20, bottom: 32, trailing: 20
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

        // Progress dots
        progressDotsStack.axis = .horizontal
        progressDotsStack.spacing = 6
        progressDotsStack.alignment = .center
        progressDotsStack.distribution = .fillEqually
        contentStack.addArrangedSubview(progressDotsStack)

        // Progress label
        progressLabel.font = UIFont.lcCaption()
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        contentStack.addArrangedSubview(progressLabel)

        // Speaker button (big, centered)
        let speakerContainer = UIView()
        speakerButton.translatesAutoresizingMaskIntoConstraints = false
        speakerContainer.addSubview(speakerButton)
        NSLayoutConstraint.activate([
            speakerButton.centerXAnchor.constraint(equalTo: speakerContainer.centerXAnchor),
            speakerButton.topAnchor.constraint(equalTo: speakerContainer.topAnchor),
            speakerButton.bottomAnchor.constraint(equalTo: speakerContainer.bottomAnchor),
            speakerButton.widthAnchor.constraint(equalToConstant: 80),
            speakerButton.heightAnchor.constraint(equalToConstant: 80),
        ])
        speakerButton.addTarget(self, action: #selector(playSound), for: .touchUpInside)
        contentStack.addArrangedSubview(speakerContainer)

        // Instruction
        instructionLabel.text = isKidMode ? "Which word did you hear?" : "Tap the word you heard"
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        contentStack.addArrangedSubview(instructionLabel)

        // Choice buttons
        choiceStack.axis = .horizontal
        choiceStack.spacing = 16
        choiceStack.distribution = .fillEqually

        configureChoiceButton(choice1Button, tag: 0)
        configureChoiceButton(choice2Button, tag: 1)
        choiceStack.addArrangedSubview(choice1Button)
        choiceStack.addArrangedSubview(choice2Button)
        contentStack.addArrangedSubview(choiceStack)

        // Feedback
        feedbackLabel.font = .systemFont(ofSize: 18, weight: .bold)
        feedbackLabel.textAlignment = .center
        feedbackLabel.numberOfLines = 0
        feedbackLabel.isHidden = true
        contentStack.addArrangedSubview(feedbackLabel)

        // Next button
        nextButton.isHidden = true
        nextButton.addTarget(self, action: #selector(nextItem), for: .touchUpInside)
        contentStack.addArrangedSubview(nextButton)

        // Results (hidden initially)
        resultsCard.isHidden = true
        contentStack.addArrangedSubview(resultsCard)
    }

    private func configureChoiceButton(_ button: UIButton, tag: Int) {
        button.tag = tag
        button.titleLabel?.font = .systemFont(ofSize: isKidMode ? 28 : 22, weight: .bold)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .lcCard
        button.layer.cornerRadius = LC.cornerRadius
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.separator.cgColor
        button.heightAnchor.constraint(equalToConstant: isKidMode ? 80 : 64).isActive = true
        button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
    }

    // MARK: - Present Item

    private func presentItem(_ pair: SoundMinimalPairItem) {
        currentTarget = pair
        itemStartTime = Date()

        // Randomly assign correct answer to left or right
        currentCorrectSide = Int.random(in: 0...1)

        if currentCorrectSide == 0 {
            choice1Button.setTitle(pair.sound1, for: .normal)
            choice2Button.setTitle(pair.sound2, for: .normal)
        } else {
            choice1Button.setTitle(pair.sound2, for: .normal)
            choice2Button.setTitle(pair.sound1, for: .normal)
        }

        // Reset button states
        choice1Button.layer.borderColor = UIColor.separator.cgColor
        choice2Button.layer.borderColor = UIColor.separator.cgColor
        choice1Button.backgroundColor = .lcCard
        choice2Button.backgroundColor = .lcCard
        choice1Button.isEnabled = true
        choice2Button.isEnabled = true

        feedbackLabel.isHidden = true
        nextButton.isHidden = true

        // Update progress
        updateProgressDots()
        progressLabel.text = "\(currentIndex + 1) of \(pairs.count)"

        // Auto-play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playSound()
        }
    }

    private func updateProgressDots() {
        progressDotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for i in 0..<pairs.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dot.layer.cornerRadius = 3

            if i < currentIndex {
                // Completed — green or red
                let wasCorrect = i < results.count && results[i].isCorrect
                dot.backgroundColor = wasCorrect ? .lcGreen : .lcRed
            } else if i == currentIndex {
                dot.backgroundColor = .lcTeal
            } else {
                dot.backgroundColor = .separator
            }

            progressDotsStack.addArrangedSubview(dot)
        }
    }

    // MARK: - Play Sound (TTS)

    @objc private func playSound() {
        guard let pair = currentTarget else { return }

        synthesizer.stopSpeaking(at: .immediate)

        // Speak the FIRST sound of the pair (sound1 is always the target)
        let utterance = AVSpeechUtterance(string: pair.sound1)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = voiceGender == .female ? 1.2 : 0.9
        utterance.volume = 1.0

        // Pick a voice matching the gender
        if voiceGender == .female {
            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            }
        } else {
            // Try to find a male voice
            let voices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("en") }
            if let maleVoice = voices.first(where: { $0.name.lowercased().contains("daniel") || $0.name.lowercased().contains("aaron") }) {
                utterance.voice = maleVoice
            } else if let anyEn = voices.last {
                utterance.voice = anyEn
                utterance.pitchMultiplier = 0.8
            }
        }

        // Animate speaker button
        UIView.animate(withDuration: 0.15) { self.speakerButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2) }
        UIView.animate(withDuration: 0.15, delay: 0.3) { self.speakerButton.transform = .identity }

        synthesizer.speak(utterance)
    }

    // MARK: - Choice Handling

    @objc private func choiceTapped(_ sender: UIButton) {
        guard let pair = currentTarget else { return }

        choice1Button.isEnabled = false
        choice2Button.isEnabled = false

        let chosenText = sender.title(for: .normal) ?? ""
        let isCorrect = chosenText == pair.sound1

        // Reaction time
        let reactionMs = Int((Date().timeIntervalSince(itemStartTime ?? Date())) * 1000)

        if isCorrect {
            correctCount += 1
            sender.layer.borderColor = UIColor.lcGreen.cgColor
            sender.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.1)
            feedbackLabel.text = isKidMode ? "Great job!" : "Correct!"
            feedbackLabel.textColor = .lcGreen
            lcHapticSuccess()
        } else {
            sender.layer.borderColor = UIColor.lcRed.cgColor
            sender.backgroundColor = UIColor.lcRed.withAlphaComponent(0.1)
            // Highlight correct answer
            let correctButton = currentCorrectSide == 0 ? choice1Button : choice2Button
            correctButton.layer.borderColor = UIColor.lcGreen.cgColor
            correctButton.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.1)
            feedbackLabel.text = isKidMode
                ? "Almost! It was '\(pair.sound1)'"
                : "It was '\(pair.sound1)' (\(pair.phoneme1))"
            feedbackLabel.textColor = .lcRed
            lcHaptic(.heavy)
        }

        feedbackLabel.isHidden = false
        results.append(SoundItemResult(
            presented: pair.sound1, target: pair.sound1,
            userChoice: chosenText, isCorrect: isCorrect,
            reactionTimeMs: reactionMs
        ))

        // Show next or finish
        if currentIndex < pairs.count - 1 {
            nextButton.setTitle(isKidMode ? "Next Sound!" : "Next", for: .normal)
            nextButton.isHidden = false
        } else {
            finishDrill()
        }
    }

    @objc private func nextItem() {
        currentIndex += 1
        if currentIndex < pairs.count {
            presentItem(pairs[currentIndex])
        }
    }

    // MARK: - Finish

    private func finishDrill() {
        isComplete = true
        let accuracy = pairs.isEmpty ? 0 : Double(correctCount) / Double(pairs.count) * 100

        // Hide drill UI
        choiceStack.isHidden = true
        speakerButton.isHidden = true
        instructionLabel.isHidden = true
        nextButton.isHidden = true

        feedbackLabel.isHidden = true

        // Show results
        resultsCard.isHidden = false
        resultsCard.subviews.forEach { $0.removeFromSuperview() }

        let resultStack = UIStackView()
        resultStack.axis = .vertical
        resultStack.spacing = 12
        resultStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = isKidMode ? "All Done!" : "Drill Complete"
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)
        titleLbl.textAlignment = .center

        let scoreLbl = UILabel()
        scoreLbl.text = "\(correctCount) / \(pairs.count)"
        scoreLbl.font = .systemFont(ofSize: 48, weight: .heavy)
        scoreLbl.textColor = accuracy >= 80 ? .lcGreen : accuracy >= 50 ? .lcOrange : .lcRed
        scoreLbl.textAlignment = .center

        let accLbl = UILabel()
        accLbl.text = String(format: "%.0f%% accuracy", accuracy)
        accLbl.font = .systemFont(ofSize: 16, weight: .medium)
        accLbl.textColor = .secondaryLabel
        accLbl.textAlignment = .center

        let voiceLbl = UILabel()
        voiceLbl.text = "\(voiceGender.label) voice"
        voiceLbl.font = UIFont.lcCaption()
        voiceLbl.textColor = .tertiaryLabel
        voiceLbl.textAlignment = .center

        // Encouraging message
        let msgLbl = UILabel()
        if accuracy >= 90 {
            msgLbl.text = isKidMode ? "You're a superstar!" : "Excellent! Try male voice for extra challenge."
        } else if accuracy >= 70 {
            msgLbl.text = isKidMode ? "Great work! Keep practising!" : "Good progress. Keep at it!"
        } else {
            msgLbl.text = isKidMode ? "Nice try! Let's practise more!" : "Keep practising — it gets easier!"
        }
        msgLbl.font = .systemFont(ofSize: 14, weight: .medium)
        msgLbl.textColor = .secondaryLabel
        msgLbl.textAlignment = .center
        msgLbl.numberOfLines = 0

        let retryBtn = LCButton(title: isKidMode ? "Play Again!" : "Try Again", color: .lcTeal)
        retryBtn.addTarget(self, action: #selector(retryDrill), for: .touchUpInside)

        resultStack.addArrangedSubview(titleLbl)
        resultStack.addArrangedSubview(scoreLbl)
        resultStack.addArrangedSubview(accLbl)
        resultStack.addArrangedSubview(voiceLbl)
        resultStack.addArrangedSubview(msgLbl)
        resultStack.addArrangedSubview(retryBtn)

        resultsCard.addSubview(resultStack)
        NSLayoutConstraint.activate([
            resultStack.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: 24),
            resultStack.bottomAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: -24),
            resultStack.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 20),
            resultStack.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -20),
        ])

        // Save session
        saveSession(accuracy: accuracy)
    }

    @objc private func retryDrill() {
        resultsCard.isHidden = true
        choiceStack.isHidden = false
        speakerButton.isHidden = false
        instructionLabel.isHidden = false
        loadPairs()
    }

    // MARK: - Save

    private func saveSession(accuracy: Double) {
        guard let first = pairs.first else { return }
        let session = SoundTherapySession(
            id: 0,
            exerciseType: "minimal_pair",
            targetSound: contrastFilter ?? first.contrastLabel,
            voiceGender: voiceGender,
            exerciseLevel: .word, // minimal pairs are word-level
            startedAt: Date().addingTimeInterval(-Double(pairs.count * 5)),
            completedAt: Date(),
            totalItems: pairs.count,
            correctItems: correctCount,
            isAdaptive: true
        )

        Task {
            let service = ServiceLocator.shared.soundTherapyService!
            _ = try? await service.saveSession(session)

            // Update progress for both sounds in the contrast
            for pair in pairs {
                let pairCorrect = results.filter { $0.target == pair.sound1 && $0.isCorrect }.count
                let pairTotal = results.filter { $0.target == pair.sound1 }.count
                if pairTotal > 0 {
                    _ = try? await service.updateProgress(
                        sound: pair.phoneme1, level: .word,
                        voiceGender: voiceGender,
                        correct: pairCorrect, total: pairTotal
                    )
                }
            }
        }
    }
}
