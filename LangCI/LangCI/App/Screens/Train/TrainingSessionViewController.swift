// TrainingSessionViewController.swift
// LangCI
//
// Redesigned active training screen — large flashcard layout with progress card,
// tap-to-reveal translation, rating buttons with haptics, and clean completion state.

import UIKit
import AVFoundation

final class TrainingSessionViewController: UIViewController {

    // MARK: - UI (Training)

    private let progressCard         = LCCard()
    private let progressBar          = ProgressBarView()
    private let progressCountLabel   = UILabel()
    private let progressPercentLabel = UILabel()

    private let wordCard             = LCCard()
    private let nativeScriptLabel    = UILabel()
    private let ipaLabel             = UILabel()
    private let playButton: LCIconButton
    private let translationLabel     = UILabel()
    private let tapRevealHint        = UILabel()

    private let ratingStack          = UIStackView()
    private let againButton          = LCButton(title: "Again", color: .lcRed)
    private let hardButton           = LCButton(title: "Hard",  color: .lcOrange)
    private let goodButton           = LCButton(title: "Good",  color: .lcGreen)
    private let easyButton           = LCButton(title: "Easy",  color: .lcBlue)

    // MARK: - UI (Completion)

    private let completionContainer = UIView()
    private let checkmarkImageView  = UIImageView()
    private let completionTitle     = UILabel()
    private let completionStatsCard = LCCard()
    private let doneButton          = LCButton(title: "Done", color: .lcGreen)

    // MARK: - Loading

    private let loadingView = LCLoadingView(message: "Loading words…")

    // MARK: - State

    private let session: TrainingSession
    private var sessionWords: [SessionWord] = []
    private var currentWordIndex: Int = 0
    private var isRevealed: Bool = false

    private var correctCount: Int = 0
    private var totalAttempts: Int = 0
    private var currentWord: WordEntry?
    private var currentSessionWord: SessionWord?
    private var currentTranslation: String?

    // MARK: - Multi-Voice Audio

    /// Voice Library recordings keyed by word text (lowercased)
    private var voiceClips: [String: [VoiceRecording]] = [:]
    private var audioPlayer: AVAudioPlayer?
    /// Label showing which voice is playing ("Tamil Female", "Priya", etc.)
    private let voiceNameLabel = UILabel()

    // MARK: - Init

    init(session: TrainingSession) {
        self.session = session
        self.playButton = LCIconButton(systemIcon: "speaker.wave.2.fill", tint: .lcBlue, size: 64)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadVoiceLibrary()
        loadSessionWords()
    }

    // MARK: - Navigation

    private func setupNavigation() {
        view.backgroundColor = .lcBackground
        navigationItem.title = "Training"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(handleClose)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "End",
            style: .plain,
            target: self,
            action: #selector(handleEndSession)
        )
    }

    // MARK: - UI Setup

    private let accentPicker = VoiceAccentPicker()

    private func buildUI() {
        buildProgressCard()
        buildWordCard()
        buildRatingStack()
        buildCompletion()

        // Voice accent picker — includes Tamil for word training
        accentPicker.includeTamil = true

        let mainStack = UIStackView(arrangedSubviews: [progressCard, accentPicker, wordCard, ratingStack])
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        completionContainer.alpha = 0
        completionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(completionContainer)

        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LC.cardPadding),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            completionContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            completionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LC.cardPadding),
            completionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LC.cardPadding),
            completionContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 200),
            loadingView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func buildProgressCard() {
        progressCard.translatesAutoresizingMaskIntoConstraints = false

        progressCountLabel.font = UIFont.lcBodyBold()
        progressCountLabel.textColor = .label
        progressCountLabel.text = "Word 0 of 0"

        progressPercentLabel.font = UIFont.lcCaption()
        progressPercentLabel.textColor = .secondaryLabel
        progressPercentLabel.textAlignment = .right
        progressPercentLabel.text = "0%"
        progressPercentLabel.setContentHuggingPriority(.required, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [progressCountLabel, progressPercentLabel])
        topRow.axis = .horizontal
        topRow.distribution = .fill
        topRow.alignment = .center

        progressBar.color = .lcGreen
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let stack = UIStackView(arrangedSubviews: [topRow, progressBar])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        progressCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildWordCard() {
        wordCard.translatesAutoresizingMaskIntoConstraints = false

        nativeScriptLabel.font = .systemFont(ofSize: 44, weight: .bold)
        nativeScriptLabel.textColor = .label
        nativeScriptLabel.textAlignment = .center
        nativeScriptLabel.numberOfLines = 1
        nativeScriptLabel.adjustsFontSizeToFitWidth = true
        nativeScriptLabel.minimumScaleFactor = 0.5

        ipaLabel.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        ipaLabel.textColor = .secondaryLabel
        ipaLabel.textAlignment = .center

        playButton.addTarget(self, action: #selector(handlePlayAudio), for: .touchUpInside)

        let playWrap = UIView()
        playWrap.translatesAutoresizingMaskIntoConstraints = false
        playWrap.addSubview(playButton)
        NSLayoutConstraint.activate([
            playButton.topAnchor.constraint(equalTo: playWrap.topAnchor),
            playButton.bottomAnchor.constraint(equalTo: playWrap.bottomAnchor),
            playButton.centerXAnchor.constraint(equalTo: playWrap.centerXAnchor)
        ])

        // Voice name indicator (shows "🔊 Tamil Female" etc. when playing)
        voiceNameLabel.font = UIFont.lcCaption()
        voiceNameLabel.textColor = .lcBlue
        voiceNameLabel.textAlignment = .center
        voiceNameLabel.alpha = 0

        translationLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        translationLabel.textColor = .label
        translationLabel.textAlignment = .center
        translationLabel.numberOfLines = 0
        translationLabel.alpha = 0

        tapRevealHint.text = "Tap card to reveal translation"
        tapRevealHint.font = UIFont.lcCaption()
        tapRevealHint.textColor = .tertiaryLabel
        tapRevealHint.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            nativeScriptLabel, ipaLabel, playWrap, voiceNameLabel, translationLabel, tapRevealHint
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(22, after: playWrap)
        stack.translatesAutoresizingMaskIntoConstraints = false
        wordCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wordCard.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: wordCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: wordCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: wordCard.trailingAnchor, constant: -LC.cardPadding),
            wordCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        // Tap gesture — restricted so UIControl subviews (the play button) still fire first
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCardTap))
        tap.delegate = self
        wordCard.addGestureRecognizer(tap)
    }

    private func buildRatingStack() {
        ratingStack.axis = .horizontal
        ratingStack.distribution = .fillEqually
        ratingStack.spacing = 8
        ratingStack.alpha = 0
        ratingStack.translatesAutoresizingMaskIntoConstraints = false

        for btn in [againButton, hardButton, goodButton, easyButton] {
            btn.addTarget(self, action: #selector(handleRating(_:)), for: .touchUpInside)
            btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
            ratingStack.addArrangedSubview(btn)
        }
    }

    private func buildCompletion() {
        let checkmarkCfg = UIImage.SymbolConfiguration(pointSize: 88, weight: .light)
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkmarkCfg)
        checkmarkImageView.tintColor = .lcGreen
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.heightAnchor.constraint(equalToConstant: 104).isActive = true
        checkmarkImageView.widthAnchor.constraint(equalToConstant: 104).isActive = true

        completionTitle.text = "Session Complete"
        completionTitle.font = UIFont.lcHeroTitle()
        completionTitle.textColor = .label
        completionTitle.textAlignment = .center

        completionStatsCard.translatesAutoresizingMaskIntoConstraints = false

        doneButton.addTarget(self, action: #selector(handleDoneSession), for: .touchUpInside)
        doneButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            checkmarkImageView, completionTitle, completionStatsCard, doneButton
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(12, after: checkmarkImageView)
        stack.setCustomSpacing(24, after: completionTitle)

        completionContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: completionContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: completionContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: completionContainer.trailingAnchor),
            checkmarkImageView.centerXAnchor.constraint(equalTo: stack.centerXAnchor)
        ])
    }

    private func updateCompletionStats(correct: Int, total: Int, points: Int) {
        completionStatsCard.subviews.forEach { $0.removeFromSuperview() }
        let accuracy = total > 0 ? Int((Double(correct) / Double(total)) * 100) : 0
        let row = LCStatRow(items: [
            .init(label: "Correct",  value: "\(correct)/\(total)", tint: .lcGreen),
            .init(label: "Accuracy", value: "\(accuracy)%",        tint: .lcBlue),
            .init(label: "Points",   value: "+\(points)",          tint: .lcOrange)
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        completionStatsCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: completionStatsCard.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: completionStatsCard.bottomAnchor, constant: -18),
            row.leadingAnchor.constraint(equalTo: completionStatsCard.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: completionStatsCard.trailingAnchor, constant: -12)
        ])
    }

    // MARK: - Data Loading

    private func loadSessionWords() {
        loadingView.start()
        loadingView.isHidden = false
        Task {
            do {
                let words = try await ServiceLocator.shared.trainingService.getDueWords(
                    dialectId: session.dialectId, limit: 200)

                await MainActor.run {
                    self.sessionWords = words
                    self.loadingView.isHidden = true
                    self.loadingView.stop()
                }

                if words.isEmpty {
                    await MainActor.run {
                        self.showCompletionScreen(correct: 0, total: 0, award: nil)
                    }
                } else {
                    await self.loadAndDisplayWord(at: 0)
                    await MainActor.run { self.updateProgress() }
                }
            } catch {
                await MainActor.run {
                    self.loadingView.isHidden = true
                    self.showErrorAlert(title: "Load Error",
                                        message: "Failed to load words: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadAndDisplayWord(at index: Int) async {
        guard index < sessionWords.count else {
            await MainActor.run {
                self.showCompletionScreen(correct: self.correctCount,
                                          total: self.totalAttempts,
                                          award: nil)
            }
            return
        }

        let sessionWord = sessionWords[index]

        await MainActor.run {
            self.currentWordIndex = index
            self.currentSessionWord = sessionWord
            self.isRevealed = false
            self.resetCardView()
        }

        do {
            let word = try await ServiceLocator.shared.wordService.getWord(id: sessionWord.wordEntryId)
            var translation: String? = nil
            if let w = word {
                let translations = try await ServiceLocator.shared.wordService.getTranslations(for: w.id)
                translation = translations.first?.translation
            }

            await MainActor.run {
                self.currentWord = word
                self.currentTranslation = translation ?? "(no translation)"
                if let w = word {
                    self.nativeScriptLabel.text = w.nativeScript
                    self.ipaLabel.text = w.ipaPhoneme.isEmpty ? "—" : w.ipaPhoneme
                } else {
                    self.nativeScriptLabel.text = "?"
                    self.ipaLabel.text = "—"
                }
            }
        } catch {
            await MainActor.run {
                self.nativeScriptLabel.text = "Error"
                self.ipaLabel.text = "—"
                self.currentTranslation = nil
            }
        }
    }

    private func resetCardView() {
        translationLabel.text = ""
        translationLabel.alpha = 0
        tapRevealHint.alpha = 1
        ratingStack.alpha = 0
    }

    private func updateProgress() {
        let total = sessionWords.count
        let current = currentWordIndex
        let progress = total > 0 ? Double(current) / Double(total) : 0
        progressBar.setProgress(progress, animated: true)
        progressCountLabel.text = "Word \(min(current + 1, total)) of \(total)"
        progressPercentLabel.text = "\(Int(progress * 100))%"
    }

    // MARK: - Actions

    @objc private func handleCardTap() {
        guard !sessionWords.isEmpty, !isRevealed else { return }
        isRevealed = true
        lcHaptic(.light)

        UIView.animate(withDuration: 0.3) {
            self.tapRevealHint.alpha = 0
            self.translationLabel.text = self.currentTranslation ?? "(no translation)"
            self.translationLabel.alpha = 1
            self.ratingStack.alpha = 1
        }
    }

    @objc private func handlePlayAudio() {
        guard let word = currentWord else { return }
        lcHaptic(.light)

        // Strategy:
        // 1. Try family word recordings (RecordingService)
        // 2. Try Voice Library clips matching this word text
        // 3. Fall back to MultiVoiceTTS with rotating voices
        Task {
            // 1. Check family recordings for this specific word
            let familyRecordings = (try? await ServiceLocator.shared.recordingService.getRecordings(for: word.id)) ?? []
            if let rec = familyRecordings.randomElement(), !rec.filePath.isEmpty {
                if let played = try? await ServiceLocator.shared.recordingService.playRecording(path: rec.filePath) {
                    await MainActor.run {
                        self.showVoiceName("Family Recording")
                    }
                    return
                }
            }

            // 2. Check Voice Library clips matching word text
            let key = word.nativeScript.lowercased().trimmingCharacters(in: .whitespaces)
            if let clips = self.voiceClips[key], !clips.isEmpty,
               let clip = clips.randomElement() {
                await MainActor.run {
                    self.playVoiceClip(clip)
                }
                return
            }

            // 3. TTS with rotating voice profiles
            await MainActor.run {
                let text = word.nativeScript
                let profile = MultiVoiceTTS.shared.speakNextVoice(text)
                self.showVoiceName(profile.name)
            }
        }
    }

    /// Play a Voice Library recording via AVAudioPlayer
    private func playVoiceClip(_ clip: VoiceRecording) {
        let url = clip.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Fallback to TTS if file missing
            let profile = MultiVoiceTTS.shared.speakNextVoice(currentWord?.nativeScript ?? "")
            showVoiceName(profile.name)
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            // Look up the person name
            Task {
                let people = (try? await ServiceLocator.shared.voiceRecordingService?.getAllPeople()) ?? []
                let name = people.first(where: { $0.id == clip.personId })?.name ?? "Recorded"
                await MainActor.run {
                    self.showVoiceName(name)
                }
            }
        } catch {
            let profile = MultiVoiceTTS.shared.speakNextVoice(currentWord?.nativeScript ?? "")
            showVoiceName(profile.name)
        }
    }

    /// Load all Voice Library recordings and index by word text
    /// Indexes by both label and soundId for flexible matching
    private func loadVoiceLibrary() {
        Task {
            guard let voiceService = ServiceLocator.shared.voiceRecordingService else { return }
            let allClips = (try? await voiceService.getAllRecordings()) ?? []
            var index: [String: [VoiceRecording]] = [:]
            for clip in allClips {
                // Index by label (e.g. "Push", "Say Hello")
                let labelKey = clip.label.lowercased().trimmingCharacters(in: .whitespaces)
                index[labelKey, default: []].append(clip)
                // Also index by soundId if present (e.g. "custom_42")
                if let sid = clip.soundId {
                    index[sid.lowercased(), default: []].append(clip)
                }
            }
            self.voiceClips = index
        }
    }

    /// Show which voice is playing under the play button
    private func showVoiceName(_ name: String) {
        voiceNameLabel.text = "🔊 \(name)"
        voiceNameLabel.alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.voiceNameLabel.alpha = 1
        }
        // Fade out after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.5) {
                self.voiceNameLabel.alpha = 0
            }
        }
    }

    @objc private func handleRating(_ sender: UIButton) {
        let rating: Int
        switch sender {
        case againButton: rating = 0
        case hardButton:  rating = 1
        case goodButton:  rating = 2; correctCount += 1
        default:          rating = 3; correctCount += 1
        }
        totalAttempts += 1
        lcHaptic(.medium)

        guard let sessionWord = currentSessionWord else { return }

        Task {
            do {
                let award = try await ServiceLocator.shared.trainingService.recordAnswer(
                    sessionId: session.id,
                    wordEntryId: sessionWord.wordEntryId,
                    rating: rating
                )
                await self.animateToNextWord(award: award)
            } catch {
                await MainActor.run {
                    self.showErrorAlert(title: "Rating Error",
                                        message: "Failed to record answer: \(error.localizedDescription)")
                }
            }
        }
    }

    private func animateToNextWord(award: AwardResult) async {
        let nextIndex = currentWordIndex + 1
        if nextIndex < sessionWords.count {
            await MainActor.run {
                UIView.animate(withDuration: 0.22, animations: {
                    self.wordCard.alpha = 0
                    self.wordCard.transform = CGAffineTransform(translationX: -30, y: 0)
                }, completion: { _ in
                    self.wordCard.transform = .identity
                    Task {
                        await self.loadAndDisplayWord(at: nextIndex)
                        await MainActor.run {
                            self.updateProgress()
                            UIView.animate(withDuration: 0.22) {
                                self.wordCard.alpha = 1
                            }
                        }
                    }
                })
            }
        } else {
            await MainActor.run {
                self.showCompletionScreen(correct: self.correctCount,
                                          total: self.totalAttempts,
                                          award: award)
            }
        }
    }

    private func showCompletionScreen(correct: Int, total: Int, award: AwardResult?) {
        let points = award?.totalPoints ?? 0
        updateCompletionStats(correct: correct, total: total, points: points)
        lcHapticSuccess()

        UIView.animate(withDuration: 0.4) {
            self.progressCard.alpha = 0
            self.wordCard.alpha = 0
            self.ratingStack.alpha = 0
            self.completionContainer.alpha = 1
        }

        // Spring checkmark in
        checkmarkImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(
            withDuration: 0.55,
            delay: 0.2,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut,
            animations: { self.checkmarkImageView.transform = .identity }
        )
    }

    @objc private func handleDoneSession() {
        Task {
            do {
                _ = try await ServiceLocator.shared.trainingService.completeSession(id: session.id)
                await MainActor.run {
                    _ = self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.showErrorAlert(title: "Error",
                                        message: "Failed to complete session: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func handleEndSession() {
        let alert = UIAlertController(
            title: "End Session?",
            message: "Are you sure you want to end training?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    _ = try await ServiceLocator.shared.trainingService.completeSession(id: self.session.id)
                    await MainActor.run {
                        _ = self.navigationController?.popViewController(animated: true)
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorAlert(title: "Error",
                                            message: "Failed to end session: \(error.localizedDescription)")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func handleClose() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Helpers

    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TrainingSessionViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // Ignore taps that land on UIControl subviews (e.g. the play button)
        return !(touch.view is UIControl)
    }
}
