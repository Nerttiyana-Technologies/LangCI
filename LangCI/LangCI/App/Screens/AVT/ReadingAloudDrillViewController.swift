// ReadingAloudDrillViewController.swift
// LangCI
//
// Shows the passage text, records the user reading it aloud with real-time
// voice metrics: pitch (Hz), loudness (dB), and words-per-minute (WPM)
// via live speech recognition.
//
// Flow:
//   1. Passage text shown in scrollable card
//   2. User taps "Start Reading" — three circular gauges animate live as
//      they read, timer runs, word count increments via speech recognition
//   3. User taps "Done" — recording stops, final stats computed, saved
//   4. Results card appears showing summary + coaching hint

import UIKit
import AVFoundation

final class ReadingAloudDrillViewController: UIViewController, VoiceMetricsDelegate {

    // MARK: - Input

    private let passage: ReadingPassage

    // MARK: - Engine

    private var metricsEngine: VoiceMetricsEngine?
    private var recordingURL: URL?
    private var startTime: Date?

    // Running loudness samples for final average
    private var loudnessSamples: [Double] = []
    private var peakLoudness: Double = -160

    /// Set when engine falls back to syllable estimation — triggers Whisper post-session
    private var needsWhisperPostSession = false

    // MARK: - Display timer

    private var displayTimer: Timer?

    // MARK: - Language

    private let languageOptions: [(label: String, locale: Locale)] = [
        ("தமிழ் Tamil", Locale(identifier: "ta-IN")),
        ("English", Locale(identifier: "en-US"))
    ]
    private let languageControl = UISegmentedControl()
    private var selectedLocale: Locale { languageOptions[languageControl.selectedSegmentIndex].locale }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Passage card
    private let passageCard = LCCard()
    private let passageTitleLabel = UILabel()
    private let passageMetaLabel = UILabel()
    private let passageBodyLabel = UILabel()

    // Metrics card (the three gauges)
    private let metricsCard = LCCard()
    private let gaugeStack = UIStackView()
    private let pitchGauge = CircularGaugeView(config: .init(
        title: "Pitch", unit: "Hz",
        minValue: 60, maxValue: 400,
        color: .lcTeal,
        warningThreshold: nil,
        format: "%.0f"))
    private let loudnessGauge = CircularGaugeView(config: .init(
        title: "Loudness", unit: "dB",
        minValue: -60, maxValue: 0,
        color: .lcBlue,
        warningThreshold: -10,  // very loud
        format: "%.0f"))
    private let wpmGauge = CircularGaugeView(config: .init(
        title: "Speed", unit: "WPM",
        minValue: 0, maxValue: 250,
        color: .lcPurple,
        warningThreshold: 180,  // too fast
        format: "%.0f"))

    // Real-time word count label
    private let wordCountLabel = UILabel()

    // Control card
    private let controlCard = LCCard()
    private let timerLabel = UILabel()
    private let startButton = LCButton(title: "Start Reading", color: .lcBlue)
    private let stopButton = LCButton(title: "Done", color: .lcRed)

    // Results card
    private let resultsCard = LCCard()
    private let resultsContent = UIStackView()

    // MARK: - State

    private enum DrillState {
        case idle
        case recording
        case saving
        case done
    }
    private var state: DrillState = .idle {
        didSet { updateForState() }
    }

    // MARK: - Init

    init(passage: ReadingPassage) {
        self.passage = passage
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        updateForState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        displayTimer?.invalidate()
        displayTimer = nil
        metricsEngine?.stop()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = passage.title
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .lcBackground
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 16, leading: LC.cardPadding,
                                                      bottom: 24, trailing: LC.cardPadding)
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Language picker for speech recognition
        for (i, option) in languageOptions.enumerated() {
            languageControl.insertSegment(withTitle: option.label, at: i, animated: false)
        }
        languageControl.selectedSegmentIndex = 0
        contentStack.addArrangedSubview(languageControl)

        buildPassageCard()
        contentStack.addArrangedSubview(passageCard)

        buildMetricsCard()
        contentStack.addArrangedSubview(metricsCard)
        metricsCard.isHidden = true

        buildControlCard()
        contentStack.addArrangedSubview(controlCard)

        buildResultsCard()
        contentStack.addArrangedSubview(resultsCard)
        resultsCard.isHidden = true
    }

    private func buildPassageCard() {
        passageTitleLabel.text = passage.title
        passageTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        passageTitleLabel.textColor = .label
        passageTitleLabel.numberOfLines = 0

        passageMetaLabel.text = "\(passage.category.emoji) \(passage.category.label) • \(passage.difficultyLabel) • \(passage.wordCount) words"
        passageMetaLabel.font = UIFont.lcCaption()
        passageMetaLabel.textColor = .secondaryLabel

        passageBodyLabel.text = passage.body
        passageBodyLabel.font = UIFont.systemFont(ofSize: 18)
        passageBodyLabel.textColor = .label
        passageBodyLabel.numberOfLines = 0
        passageBodyLabel.setContentHuggingPriority(.defaultLow, for: .vertical)

        let stack = UIStackView(arrangedSubviews: [passageTitleLabel, passageMetaLabel, passageBodyLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(18, after: passageMetaLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        passageCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: passageCard.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: passageCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: passageCard.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: passageCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildMetricsCard() {
        // Three gauges side by side
        gaugeStack.axis = .horizontal
        gaugeStack.distribution = .fillEqually
        gaugeStack.spacing = 8
        gaugeStack.translatesAutoresizingMaskIntoConstraints = false

        for gauge in [pitchGauge, loudnessGauge, wpmGauge] {
            gauge.translatesAutoresizingMaskIntoConstraints = false
            gauge.heightAnchor.constraint(equalTo: gauge.widthAnchor).isActive = true
            gaugeStack.addArrangedSubview(gauge)
        }

        // Word count label below gauges
        wordCountLabel.text = "Words detected: 0"
        wordCountLabel.font = UIFont.lcBodyBold()
        wordCountLabel.textColor = .secondaryLabel
        wordCountLabel.textAlignment = .center
        wordCountLabel.translatesAutoresizingMaskIntoConstraints = false

        metricsCard.addSubview(gaugeStack)
        metricsCard.addSubview(wordCountLabel)

        NSLayoutConstraint.activate([
            gaugeStack.topAnchor.constraint(equalTo: metricsCard.topAnchor, constant: LC.cardPadding),
            gaugeStack.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor, constant: LC.cardPadding),
            gaugeStack.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor, constant: -LC.cardPadding),

            wordCountLabel.topAnchor.constraint(equalTo: gaugeStack.bottomAnchor, constant: 8),
            wordCountLabel.leadingAnchor.constraint(equalTo: metricsCard.leadingAnchor, constant: LC.cardPadding),
            wordCountLabel.trailingAnchor.constraint(equalTo: metricsCard.trailingAnchor, constant: -LC.cardPadding),
            wordCountLabel.bottomAnchor.constraint(equalTo: metricsCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildControlCard() {
        timerLabel.text = "0:00"
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        timerLabel.textColor = .label
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false

        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false

        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        controlCard.addSubview(timerLabel)
        controlCard.addSubview(startButton)
        controlCard.addSubview(stopButton)

        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: controlCard.topAnchor, constant: LC.cardPadding),
            timerLabel.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor),
            timerLabel.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor),

            startButton.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: LC.cardPadding),
            startButton.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -LC.cardPadding),
            startButton.heightAnchor.constraint(equalToConstant: 52),

            stopButton.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 16),
            stopButton.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: LC.cardPadding),
            stopButton.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -LC.cardPadding),
            stopButton.heightAnchor.constraint(equalToConstant: 52),

            stopButton.bottomAnchor.constraint(equalTo: controlCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildResultsCard() {
        resultsContent.axis = .vertical
        resultsContent.spacing = 14
        resultsContent.translatesAutoresizingMaskIntoConstraints = false
        resultsCard.addSubview(resultsContent)
        NSLayoutConstraint.activate([
            resultsContent.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: LC.cardPadding),
            resultsContent.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: LC.cardPadding),
            resultsContent.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -LC.cardPadding),
            resultsContent.bottomAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - State updates

    private func updateForState() {
        switch state {
        case .idle:
            startButton.isHidden = false
            stopButton.isHidden = true
            startButton.isEnabled = true
            timerLabel.text = "0:00"
            metricsCard.isHidden = true
        case .recording:
            startButton.isHidden = true
            stopButton.isHidden = false
            metricsCard.isHidden = false
        case .saving:
            stopButton.isEnabled = false
        case .done:
            startButton.isHidden = false
            stopButton.isHidden = true
            startButton.setTitle("Read Again", for: .normal)
            metricsCard.isHidden = false  // keep gauges visible with final values
        }
    }

    // MARK: - Actions

    @objc private func didTapStart() {
        lcHaptic(.light)
        // Reset for a fresh take
        resultsCard.isHidden = true
        loudnessSamples.removeAll()
        peakLoudness = -160
        pitchGauge.reset()
        loudnessGauge.reset()
        wpmGauge.reset()
        wordCountLabel.text = "Words detected: 0"

        needsWhisperPostSession = false
        let engine = VoiceMetricsEngine(locale: selectedLocale)
        engine.delegate = self
        metricsEngine = engine

        Task {
            do {
                let url = try await engine.start()
                await MainActor.run {
                    self.recordingURL = url
                    self.startTime = Date()
                    self.state = .recording
                    self.startDisplayTimer()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Couldn't start recording: \(error.localizedDescription)",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                }
            }
        }
    }

    @objc private func didTapStop() {
        lcHaptic(.light)
        displayTimer?.invalidate()
        displayTimer = nil
        state = .saving

        let engine = metricsEngine
        let finalWordCount = engine?.wordCount ?? 0
        let finalWPM = engine?.currentWPM ?? 0
        let finalPitch = engine?.currentPitch ?? 0
        engine?.stop()

        let duration = Date().timeIntervalSince(startTime ?? Date())

        // Compute loudness stats
        let nonMinimum = loudnessSamples.filter { $0 > -160 }
        let avgDb: Double
        if nonMinimum.isEmpty {
            avgDb = -160
        } else {
            avgDb = nonMinimum.reduce(0, +) / Double(nonMinimum.count)
        }

        // Use recognised word count if available, else fall back to passage word count
        let wordCount = finalWordCount > 0 ? finalWordCount : passage.wordCount
        let wpm: Double = finalWPM > 0 ? finalWPM
            : (duration > 0 ? (Double(wordCount) / duration) * 60.0 : 0)

        let session = ReadingSession(
            passageId: passage.id == 0 ? nil : passage.id,
            passageTitle: passage.title,
            passageBody: passage.body,
            wordCount: wordCount,
            durationSeconds: duration,
            wordsPerMinute: wpm,
            avgLoudnessDb: avgDb,
            peakLoudnessDb: peakLoudness,
            audioFilePath: recordingURL?.path,
            notes: nil,
            avgPitchHz: finalPitch,
            recordedAt: Date()
        )

        Task {
            do {
                let saved = try await ServiceLocator.shared.readingAloudService.saveSession(session)
                try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.state = .done
                    self.showResults(for: saved, avgPitch: finalPitch)
                    self.stopButton.isEnabled = true

                    // If speech recognition was unavailable, try Whisper
                    if self.needsWhisperPostSession,
                       let url = self.recordingURL,
                       WhisperTranscriptionService.shared.hasAPIKey {
                        self.runWhisperPostSession(
                            session: saved, audioURL: url,
                            avgPitch: finalPitch)
                    }
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Save failed",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                    self.state = .idle
                    self.stopButton.isEnabled = true
                }
            }
        }
    }

    /// Sends recorded audio to Whisper, then updates the results card
    /// and re-saves the session with accurate word count / WPM.
    private func runWhisperPostSession(session: ReadingSession, audioURL: URL,
                                        avgPitch: Double) {
        let analysingLabel = UILabel()
        analysingLabel.text = "⏳ Analysing speech with Whisper…"
        analysingLabel.font = UIFont.lcCaption()
        analysingLabel.textColor = .lcTeal
        analysingLabel.tag = 999
        resultsContent.addArrangedSubview(analysingLabel)

        let lang = selectedLocale.language.languageCode?.identifier
            ?? selectedLocale.identifier.components(separatedBy: "-").first

        // NOTE: Do NOT pass a prompt hint — Whisper hallucinates it into
        // the output for low-resource languages like Tamil.

        Task {
            do {
                let result = try await WhisperTranscriptionService.shared
                    .transcribe(fileURL: audioURL, language: lang)

                guard result.wordCount > 0 else {
                    await MainActor.run {
                        self.resultsContent.viewWithTag(999)?.removeFromSuperview()
                    }
                    return
                }

                let whisperWPM = session.durationSeconds > 2
                    ? (Double(result.wordCount) / session.durationSeconds) * 60.0 : 0

                // Update the saved session in the database
                var updated = session
                updated.wordCount = result.wordCount
                updated.wordsPerMinute = whisperWPM
                _ = try? await ServiceLocator.shared.readingAloudService.saveSession(updated)

                await MainActor.run {
                    self.resultsContent.viewWithTag(999)?.removeFromSuperview()
                    self.showResults(for: updated, avgPitch: avgPitch)

                    let whisperNote = UILabel()
                    whisperNote.text = "✓ WPM refined by Whisper (\(result.wordCount) words detected)"
                    whisperNote.font = UIFont.lcCaption()
                    whisperNote.textColor = .lcTeal
                    whisperNote.numberOfLines = 0
                    self.resultsContent.addArrangedSubview(whisperNote)
                }
            } catch {
                await MainActor.run {
                    self.resultsContent.viewWithTag(999)?.removeFromSuperview()

                    let errLabel = UILabel()
                    errLabel.text = "Whisper: \(error.localizedDescription)"
                    errLabel.font = UIFont.lcCaption()
                    errLabel.textColor = .systemOrange
                    errLabel.numberOfLines = 0
                    self.resultsContent.addArrangedSubview(errLabel)
                }
            }
        }
    }

    // MARK: - VoiceMetricsDelegate

    func voiceMetrics(didUpdate pitch: Double, loudness: Double, wordCount: Int, wpm: Double) {
        // Store samples for final average
        loudnessSamples.append(loudness)
        if loudness > peakLoudness { peakLoudness = loudness }

        // Update gauges
        if pitch > 0 {
            pitchGauge.setValue(pitch)
        }
        loudnessGauge.setValue(loudness)
        if wpm > 0 {
            wpmGauge.setValue(wpm)
        }
        wordCountLabel.text = "Words detected: \(wordCount)"
    }

    func voiceMetricsUsingSyllableEstimation() {
        needsWhisperPostSession = true
        if WhisperTranscriptionService.shared.hasAPIKey {
            wordCountLabel.text = "Words (estimated · Whisper will refine)"
        } else {
            wordCountLabel.text = "Words (estimated from voice)"
        }
    }

    func voiceMetricsRecognitionUnavailable(reason: String) {
        wordCountLabel.text = "Word detection unavailable for this language"
        lcShowToast("WPM tracking unavailable — pitch & loudness still active",
                     icon: "info.circle.fill", tint: .systemOrange)
    }

    // MARK: - Display timer

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateTimerLabel()
        }
        RunLoop.current.add(displayTimer!, forMode: .common)
    }

    private func updateTimerLabel() {
        guard let start = startTime else { return }
        let total = Int(Date().timeIntervalSince(start))
        let m = total / 60
        let s = total % 60
        timerLabel.text = String(format: "%d:%02d", m, s)
    }

    // MARK: - Results card

    private func showResults(for session: ReadingSession, avgPitch: Double = 0) {
        resultsContent.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let header = UILabel()
        header.text = "Your Reading"
        header.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        header.textColor = .label
        resultsContent.addArrangedSubview(header)

        let wpmText   = String(format: "%.0f", session.wordsPerMinute)
        let dbText    = String(format: "%.0f", session.avgLoudnessDb)
        let duration  = formatDuration(session.durationSeconds)
        let pitch     = session.avgPitchHz > 0 ? session.avgPitchHz : avgPitch
        let pitchText = pitch > 0 ? String(format: "%.0f Hz", pitch) : "—"

        let statRow = LCStatRow(items: [
            .init(label: "WPM",       value: wpmText,   tint: .lcPurple),
            .init(label: "Avg dB",    value: dbText,    tint: .lcBlue),
            .init(label: "Pitch",     value: pitchText, tint: .lcTeal),
            .init(label: "Duration",  value: duration,  tint: .systemGray)
        ])
        resultsContent.addArrangedSubview(statRow)

        // Bands explainer
        let bandLabel = UILabel()
        bandLabel.text = "Speed: \(session.wpmBand.label) • Loudness: \(session.loudnessBand.label)"
        bandLabel.font = UIFont.lcBodyBold()
        bandLabel.textColor = .label
        bandLabel.numberOfLines = 0
        resultsContent.addArrangedSubview(bandLabel)

        // Word count comparison
        let wordLabel = UILabel()
        let detected = metricsEngine?.wordCount ?? 0
        if detected > 0 {
            wordLabel.text = "Words detected: \(detected) of \(passage.wordCount) in passage"
        } else {
            wordLabel.text = "\(passage.wordCount) words in passage"
        }
        wordLabel.font = UIFont.lcCaption()
        wordLabel.textColor = .secondaryLabel
        wordLabel.numberOfLines = 0
        resultsContent.addArrangedSubview(wordLabel)

        let hintLabel = UILabel()
        hintLabel.text = coachingHint(for: session)
        hintLabel.font = UIFont.lcCaption()
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0
        resultsContent.addArrangedSubview(hintLabel)

        resultsCard.isHidden = false
    }

    private func coachingHint(for session: ReadingSession) -> String {
        var parts: [String] = []
        switch session.wpmBand {
        case .slow:       parts.append("Try reading a bit faster — aim for 120–150 WPM.")
        case .developing: parts.append("Nice steady pace. Push a little faster as you get comfortable.")
        case .natural:    parts.append("Great natural pace — that's the sweet spot.")
        case .fast:       parts.append("You're reading fast. Slow down slightly for clarity.")
        }
        switch session.loudnessBand {
        case .quiet:       parts.append("Speak up a bit — your voice was very soft.")
        case .soft:        parts.append("A touch louder will help your implant hear you better.")
        case .comfortable: parts.append("Loudness is right where it should be.")
        case .loud:        parts.append("A little quieter would be more comfortable.")
        }
        return parts.joined(separator: " ")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
