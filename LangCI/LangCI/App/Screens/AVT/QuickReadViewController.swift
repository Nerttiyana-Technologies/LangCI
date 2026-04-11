// QuickReadViewController.swift
// LangCI
//
// Live voice metrics for reading any physical text (newspaper, book, etc.)
// without needing a passage in the app. Shows real-time pitch (Hz),
// loudness (dB), and speed (WPM) gauges. Nothing is saved to the database.
//
// Flow:
//   1. User taps "Start Reading" — gauges animate live
//   2. User reads from their physical newspaper / book
//   3. User taps "Done" — final stats shown on screen
//   4. Tap "Read Again" to reset, or navigate back

import UIKit
import AVFoundation

final class QuickReadViewController: UIViewController, VoiceMetricsDelegate {

    // MARK: - Engine

    private var metricsEngine: VoiceMetricsEngine?
    private var startTime: Date?

    // Running loudness samples for final average
    private var loudnessSamples: [Double] = []
    private var peakLoudness: Double = -160

    /// Set to true when the engine falls back to syllable estimation
    /// (speech recognition unavailable). Triggers Whisper post-session.
    private var needsWhisperPostSession = false

    // MARK: - Display timer

    private var displayTimer: Timer?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Language picker
    private let languageOptions: [(label: String, locale: Locale)] = [
        ("தமிழ் Tamil", Locale(identifier: "ta-IN")),
        ("English", Locale(identifier: "en-US"))
    ]
    private let languageControl = UISegmentedControl()
    private var selectedLocale: Locale { languageOptions[languageControl.selectedSegmentIndex].locale }

    // Instruction card
    private let instructionCard = LCCard()

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
        warningThreshold: -10,
        format: "%.0f"))
    private let wpmGauge = CircularGaugeView(config: .init(
        title: "Speed", unit: "WPM",
        minValue: 0, maxValue: 250,
        color: .lcPurple,
        warningThreshold: 180,
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
        case idle, recording, done
    }
    private var state: DrillState = .idle {
        didSet { updateForState() }
    }

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
        title = "Read Newspaper"
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

        // Language picker
        for (i, option) in languageOptions.enumerated() {
            languageControl.insertSegment(withTitle: option.label, at: i, animated: false)
        }
        languageControl.selectedSegmentIndex = 0
        contentStack.addArrangedSubview(languageControl)

        buildInstructionCard()
        contentStack.addArrangedSubview(instructionCard)

        buildMetricsCard()
        contentStack.addArrangedSubview(metricsCard)
        metricsCard.isHidden = true

        buildControlCard()
        contentStack.addArrangedSubview(controlCard)

        buildResultsCard()
        contentStack.addArrangedSubview(resultsCard)
        resultsCard.isHidden = true
    }

    private func buildInstructionCard() {
        let icon = UIImageView(image: UIImage(systemName: "newspaper.fill"))
        icon.tintColor = .lcTeal
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Read from any text"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label

        let bodyLabel = UILabel()
        bodyLabel.text = "Hold your newspaper, book, or any printed text and read aloud. The app will measure your pitch, loudness, and speed in real time."
        bodyLabel.font = UIFont.lcBody()
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0

        let headerRow = UIStackView(arrangedSubviews: [icon, titleLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [headerRow, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        instructionCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildMetricsCard() {
        gaugeStack.axis = .horizontal
        gaugeStack.distribution = .fillEqually
        gaugeStack.spacing = 8
        gaugeStack.translatesAutoresizingMaskIntoConstraints = false

        for gauge in [pitchGauge, loudnessGauge, wpmGauge] {
            gauge.translatesAutoresizingMaskIntoConstraints = false
            gauge.heightAnchor.constraint(equalTo: gauge.widthAnchor).isActive = true
            gaugeStack.addArrangedSubview(gauge)
        }

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
            instructionCard.isHidden = false
        case .recording:
            startButton.isHidden = true
            stopButton.isHidden = false
            metricsCard.isHidden = false
            instructionCard.isHidden = true
        case .done:
            startButton.isHidden = false
            stopButton.isHidden = true
            startButton.setTitle("Read Again", for: .normal)
            metricsCard.isHidden = false
            instructionCard.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func didTapStart() {
        lcHaptic(.light)
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
                // We don't need the recording URL — pass true to skip file writing
                _ = try await engine.start()
                await MainActor.run {
                    self.startTime = Date()
                    self.state = .recording
                    self.startDisplayTimer()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Couldn't start: \(error.localizedDescription)",
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

        let engine = metricsEngine
        let finalWordCount = engine?.wordCount ?? 0
        let finalWPM = engine?.currentWPM ?? 0
        let finalPitch = engine?.currentPitch ?? 0
        let recordingURL = engine?.recordingURL
        engine?.stop()

        let duration = Date().timeIntervalSince(startTime ?? Date())

        // Compute loudness stats
        let nonMinimum = loudnessSamples.filter { $0 > -160 }
        let avgDb: Double = nonMinimum.isEmpty ? -160
            : nonMinimum.reduce(0, +) / Double(nonMinimum.count)

        lcHapticSuccess()
        state = .done
        showResults(wordCount: finalWordCount, wpm: finalWPM,
                    avgDb: avgDb, avgPitch: finalPitch, duration: duration)

        // If speech recognition was unavailable, try Whisper for accurate WPM
        if needsWhisperPostSession, let url = recordingURL,
           WhisperTranscriptionService.shared.hasAPIKey {
            runWhisperPostSession(audioURL: url, duration: duration,
                                  avgDb: avgDb, avgPitch: finalPitch)
        }
    }

    /// Sends the recorded audio to OpenAI Whisper for accurate transcription,
    /// then updates the results card with the real word count / WPM.
    private func runWhisperPostSession(audioURL: URL, duration: Double,
                                        avgDb: Double, avgPitch: Double) {
        // Show analysing indicator
        let analysingLabel = UILabel()
        analysingLabel.text = "⏳ Analysing speech with Whisper…"
        analysingLabel.font = UIFont.lcCaption()
        analysingLabel.textColor = .lcTeal
        analysingLabel.tag = 999
        resultsContent.addArrangedSubview(analysingLabel)

        let lang = selectedLocale.language.languageCode?.identifier
            ?? selectedLocale.identifier.components(separatedBy: "-").first

        Task {
            do {
                // NOTE: Do NOT pass a prompt hint — Whisper hallucinates it into
                // the output for low-resource languages like Tamil.
                let result = try await WhisperTranscriptionService.shared
                    .transcribe(fileURL: audioURL, language: lang)

                await MainActor.run {
                    // Remove analysing label
                    self.resultsContent.viewWithTag(999)?.removeFromSuperview()

                    guard result.wordCount > 0 else { return }

                    let whisperWPM = duration > 2
                        ? (Double(result.wordCount) / duration) * 60.0 : 0

                    // Rebuild the results with accurate Whisper data
                    self.showResults(wordCount: result.wordCount, wpm: whisperWPM,
                                     avgDb: avgDb, avgPitch: avgPitch, duration: duration)

                    // Add a note that this was Whisper-analysed
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
        loudnessSamples.append(loudness)
        if loudness > peakLoudness { peakLoudness = loudness }

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

    private func showResults(wordCount: Int, wpm: Double,
                              avgDb: Double, avgPitch: Double, duration: Double) {
        resultsContent.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let header = UILabel()
        header.text = "Your Reading"
        header.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        header.textColor = .label
        resultsContent.addArrangedSubview(header)

        let wpmText   = String(format: "%.0f", wpm)
        let dbText    = String(format: "%.0f", avgDb)
        let pitchText = avgPitch > 0 ? String(format: "%.0f Hz", avgPitch) : "—"
        let durText   = formatDuration(duration)

        let statRow = LCStatRow(items: [
            .init(label: "WPM",      value: wpmText,   tint: .lcPurple),
            .init(label: "Avg dB",   value: dbText,    tint: .lcBlue),
            .init(label: "Pitch",    value: pitchText, tint: .lcTeal),
            .init(label: "Duration", value: durText,   tint: .systemGray)
        ])
        resultsContent.addArrangedSubview(statRow)

        if wordCount > 0 {
            let wordLabel = UILabel()
            wordLabel.text = "Words detected: \(wordCount)"
            wordLabel.font = UIFont.lcCaption()
            wordLabel.textColor = .secondaryLabel
            resultsContent.addArrangedSubview(wordLabel)
        }

        // Coaching hints
        let hintLabel = UILabel()
        hintLabel.numberOfLines = 0
        hintLabel.font = UIFont.lcCaption()
        hintLabel.textColor = .secondaryLabel
        var hints: [String] = []
        if wpm > 0 && wpm < 100 {
            hints.append("Try reading a bit faster — aim for 120-150 WPM.")
        } else if wpm >= 100 && wpm < 140 {
            hints.append("Nice steady pace. Push a little faster as you get comfortable.")
        } else if wpm >= 140 && wpm <= 180 {
            hints.append("Great natural pace — that's the sweet spot.")
        } else if wpm > 180 {
            hints.append("You're reading fast. Slow down slightly for clarity.")
        }
        if avgDb > -160 && avgDb < -40 {
            hints.append("Speak up a bit — your voice was very soft.")
        } else if avgDb >= -20 {
            hints.append("A little quieter would be more comfortable.")
        }
        if !hints.isEmpty {
            hintLabel.text = hints.joined(separator: " ")
            resultsContent.addArrangedSubview(hintLabel)
        }

        let noteLabel = UILabel()
        noteLabel.text = "This session is not saved — it's for quick practice only."
        noteLabel.font = UIFont.lcCaption()
        noteLabel.textColor = .tertiaryLabel
        noteLabel.numberOfLines = 0
        resultsContent.addArrangedSubview(noteLabel)

        resultsCard.isHidden = false
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
