// MusicTrainingViewController.swift
// LangCI — Music training drill
//
// Plays a music item (audio file if available, TTS description as fallback),
// shows multiple-choice answers, records accuracy, and gives feedback.
//
// For CI users: music is decoded differently through electrical stimulation.
// Rhythm is easiest (amplitude patterns), instruments are moderate (timbre),
// and melody is hardest (pitch discrimination). This screen adapts to all three.

import UIKit
import AVFoundation

final class MusicTrainingViewController: UIViewController {

    // MARK: - Configuration

    var trainingMode: MusicTrainingType = .rhythm

    // MARK: - State

    private let service = ServiceLocator.shared.musicService!
    private var items: [MusicItem] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var isComplete = false
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let progressLabel = UILabel()
    private let progressBar = ProgressBarView()

    private let instructionCard = LCCard()
    private let emojiLabel = UILabel()
    private let instructionLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let playHint = UILabel()

    private let choiceStack = UIStackView()
    private var choiceButtons: [UIButton] = []

    private let feedbackLabel = UILabel()
    private let nextButton = LCButton(title: "Next", color: .lcTeal)

    private let resultsCard = LCCard()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never
        buildUI()
        loadItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Data

    private func loadItems() {
        items = service.getItems(for: trainingMode).shuffled()
        currentIndex = 0
        correctCount = 0
        isComplete = false
        if !items.isEmpty { showCurrentItem() }
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
            top: 12, leading: 20, bottom: 32, trailing: 20)
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

        // Mode badge
        let badge = UILabel()
        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.layer.cornerRadius = 12
        badge.clipsToBounds = true
        badge.heightAnchor.constraint(equalToConstant: 24).isActive = true
        switch trainingMode {
        case .rhythm:
            badge.text = "  🥁  Rhythm  "
            badge.backgroundColor = .lcOrange
        case .instrument:
            badge.text = "  🎹  Instrument  "
            badge.backgroundColor = .lcPurple
        case .melody:
            badge.text = "  🎵  Melody  "
            badge.backgroundColor = .lcGreen
        }
        contentStack.addArrangedSubview(badge)

        // Progress
        progressLabel.font = UIFont.lcCaption()
        progressLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(progressLabel)
        contentStack.addArrangedSubview(progressBar)

        // Instruction card
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.alignment = .center
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        emojiLabel.font = .systemFont(ofSize: 48)
        emojiLabel.textAlignment = .center

        instructionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        instructionLabel.textColor = .label
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        descriptionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        // Play button
        var playConfig = UIButton.Configuration.filled()
        playConfig.image = UIImage(systemName: "play.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold))
        playConfig.baseBackgroundColor = UIColor.lcPurple.withAlphaComponent(0.15)
        playConfig.baseForegroundColor = .lcPurple
        playConfig.cornerStyle = .capsule
        playButton.configuration = playConfig
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 80).isActive = true
        playButton.addTarget(self, action: #selector(playSound), for: .touchUpInside)

        playHint.text = "Tap to listen"
        playHint.font = UIFont.lcCaption()
        playHint.textColor = .tertiaryLabel

        cardStack.addArrangedSubview(emojiLabel)
        cardStack.addArrangedSubview(instructionLabel)
        cardStack.addArrangedSubview(playButton)
        cardStack.addArrangedSubview(playHint)
        cardStack.addArrangedSubview(descriptionLabel)

        instructionCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 20),
            cardStack.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -16),
            cardStack.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(instructionCard)

        // Choices
        choiceStack.axis = .vertical
        choiceStack.spacing = 10
        contentStack.addArrangedSubview(choiceStack)

        // Feedback
        feedbackLabel.font = .systemFont(ofSize: 18, weight: .bold)
        feedbackLabel.textAlignment = .center
        feedbackLabel.numberOfLines = 0
        feedbackLabel.isHidden = true
        contentStack.addArrangedSubview(feedbackLabel)

        // Next
        nextButton.isHidden = true
        nextButton.addTarget(self, action: #selector(nextItem), for: .touchUpInside)
        contentStack.addArrangedSubview(nextButton)

        // Results
        resultsCard.isHidden = true
        contentStack.addArrangedSubview(resultsCard)
    }

    // MARK: - Show Item

    private func showCurrentItem() {
        guard currentIndex < items.count else { finishSession(); return }

        let item = items[currentIndex]

        progressLabel.text = "\(currentIndex + 1) of \(items.count)"
        progressBar.setProgress(CGFloat(currentIndex) / CGFloat(items.count), animated: true)

        emojiLabel.text = item.emoji

        switch trainingMode {
        case .rhythm:     instructionLabel.text = "What rhythm pattern is this?"
        case .instrument: instructionLabel.text = "Which instrument is playing?"
        case .melody:     instructionLabel.text = "Which melody is this?"
        }

        descriptionLabel.text = item.description
        descriptionLabel.isHidden = true  // reveal after answer

        // Reset
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        choiceButtons.removeAll()
        feedbackLabel.isHidden = true
        nextButton.isHidden = true

        // Build choices: correct answer + distractors
        var choices = [item.name] + item.distractors.prefix(3)
        choices.shuffle()

        for choice in choices {
            let btn = makeChoiceButton(title: choice, isCorrect: choice == item.name)
            choiceStack.addArrangedSubview(btn)
        }

        // Auto-play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playSound()
        }
    }

    // MARK: - Play Sound

    @objc private func playSound() {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]

        // Try audio file first
        if !item.audioFile.isEmpty,
           let url = Bundle.main.url(forResource: item.audioFile.replacingOccurrences(of: ".mp3", with: ""),
                                      withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                animatePlayButton()
                return
            } catch { }
        }

        // Fallback: TTS description of the sound
        synthesizer.stopSpeaking(at: .immediate)
        let ttsText: String
        switch trainingMode {
        case .rhythm:
            ttsText = "This is a \(item.name) rhythm. \(item.description)"
        case .instrument:
            ttsText = "Listen to this instrument. \(item.description)"
        case .melody:
            ttsText = "Listen to this melody. \(item.description)"
        }

        let utterance = AVSpeechUtterance(string: ttsText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        animatePlayButton()
    }

    private func animatePlayButton() {
        UIView.animate(withDuration: 0.1) {
            self.playButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
        UIView.animate(withDuration: 0.1, delay: 0.25) {
            self.playButton.transform = .identity
        }
    }

    // MARK: - Choice Handling

    @objc private func choiceTapped(_ sender: UIButton) {
        let isCorrect = sender.tag == 1

        choiceButtons.forEach { $0.isEnabled = false }

        if isCorrect {
            correctCount += 1
            sender.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.15)
            sender.layer.borderColor = UIColor.lcGreen.cgColor
            feedbackLabel.text = "Correct! 🎉"
            feedbackLabel.textColor = .lcGreen
            lcHapticSuccess()
        } else {
            sender.backgroundColor = UIColor.lcRed.withAlphaComponent(0.15)
            sender.layer.borderColor = UIColor.lcRed.cgColor

            let item = items[currentIndex]
            feedbackLabel.text = "It was: \(item.name)\n\(item.description)"
            feedbackLabel.textColor = .lcRed

            // Highlight correct
            choiceButtons.filter { $0.tag == 1 }.first?.backgroundColor =
                UIColor.lcGreen.withAlphaComponent(0.15)
            choiceButtons.filter { $0.tag == 1 }.first?.layer.borderColor =
                UIColor.lcGreen.cgColor

            lcHaptic(.heavy)
        }

        // Reveal description
        descriptionLabel.isHidden = false

        feedbackLabel.isHidden = false

        // Record attempt
        let item = items[currentIndex]
        let attempt = MusicAttempt(
            id: 0,
            trainingType: trainingMode,
            playedItem: item.name,
            userAnswer: sender.accessibilityIdentifier ?? "",
            isCorrect: isCorrect,
            programUsed: .everyday,
            attemptedAt: Date())
        Task { _ = try? await service.recordAttempt(attempt) }

        if currentIndex < items.count - 1 {
            nextButton.isHidden = false
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishSession()
            }
        }
    }

    @objc private func nextItem() {
        currentIndex += 1
        showCurrentItem()
    }

    // MARK: - Finish

    private func finishSession() {
        isComplete = true
        let accuracy = items.isEmpty ? 0 : Double(correctCount) / Double(items.count) * 100

        progressBar.setProgress(1.0, animated: true)
        instructionCard.isHidden = true
        choiceStack.isHidden = true
        feedbackLabel.isHidden = true
        nextButton.isHidden = true

        resultsCard.isHidden = false
        resultsCard.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.font = .systemFont(ofSize: 48)
        emoji.text = accuracy >= 80 ? "🌟" : accuracy >= 50 ? "🎶" : "💪"

        let titleLbl = UILabel()
        titleLbl.text = {
            switch trainingMode {
            case .rhythm:     return "Rhythm Complete!"
            case .instrument: return "Instruments Complete!"
            case .melody:     return "Melody Complete!"
            }
        }()
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)

        let scoreLbl = UILabel()
        scoreLbl.text = "\(correctCount) / \(items.count)"
        scoreLbl.font = .systemFont(ofSize: 48, weight: .heavy)
        scoreLbl.textColor = accuracy >= 80 ? .lcGreen : accuracy >= 50 ? .lcOrange : .lcRed

        let accLbl = UILabel()
        accLbl.text = String(format: "%.0f%% accuracy", accuracy)
        accLbl.font = .systemFont(ofSize: 16, weight: .medium)
        accLbl.textColor = .secondaryLabel

        let tipLbl = UILabel()
        tipLbl.numberOfLines = 0
        tipLbl.textAlignment = .center
        tipLbl.font = .systemFont(ofSize: 14, weight: .medium)
        tipLbl.textColor = .secondaryLabel

        switch trainingMode {
        case .rhythm:
            tipLbl.text = accuracy >= 80
                ? "Great rhythm recognition! CI users typically do best with rhythm because beat patterns map well to electrical stimulation."
                : "Rhythm is the most accessible music skill for CI users. Keep practising — your brain will get better at detecting beat patterns!"
        case .instrument:
            tipLbl.text = accuracy >= 80
                ? "Excellent instrument discrimination! Your brain is learning to distinguish different timbres through the CI."
                : "Instruments differ in timbre (tone quality). Listen for the attack (how the note starts) — that's often clearest through a CI."
        case .melody:
            tipLbl.text = accuracy >= 80
                ? "Amazing melody recognition! Pitch is the hardest thing for CI users — you're doing incredibly well."
                : "Melody is the hardest music skill for CI users because pitch discrimination is limited. Focus on rhythm patterns within the melody to help identify tunes."
        }

        let retryBtn = LCButton(title: "Practice Again", color: .lcTeal)
        retryBtn.addTarget(self, action: #selector(retrySession), for: .touchUpInside)

        stack.addArrangedSubview(emoji)
        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(scoreLbl)
        stack.addArrangedSubview(accLbl)
        stack.addArrangedSubview(tipLbl)
        stack.addArrangedSubview(retryBtn)

        resultsCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -20),
        ])
    }

    @objc private func retrySession() {
        resultsCard.isHidden = true
        instructionCard.isHidden = false
        choiceStack.isHidden = false
        loadItems()
    }

    // MARK: - Choice Button Builder

    private func makeChoiceButton(title: String, isCorrect: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = isCorrect ? 1 : 0
        btn.accessibilityIdentifier = title
        btn.backgroundColor = .lcCard
        btn.layer.cornerRadius = LC.cornerRadius
        btn.layer.borderWidth = 2
        btn.layer.borderColor = UIColor.separator.cgColor
        btn.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.isUserInteractionEnabled = false

        let iconName: String
        switch trainingMode {
        case .rhythm:     iconName = "metronome"
        case .instrument: iconName = "pianokeys"
        case .melody:     iconName = "music.note"
        }
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .lcPurple
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLbl.textColor = .label

        hStack.addArrangedSubview(iconView)
        hStack.addArrangedSubview(titleLbl)

        btn.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: btn.topAnchor, constant: 14),
            hStack.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -14),
            hStack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -16),
        ])

        choiceButtons.append(btn)
        return btn
    }
}
