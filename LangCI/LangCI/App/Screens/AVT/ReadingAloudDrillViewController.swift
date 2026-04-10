// ReadingAloudDrillViewController.swift
// LangCI
//
// Shows the passage text, records the user reading it aloud, and computes
// WPM + loudness stats. Uses AVAudioRecorder with metering enabled for
// dBFS loudness sampling.
//
// Flow:
//   1. Passage text shown in scrollable card
//   2. User taps "Start Reading" — red record button, timer runs, live
//      loudness meter bar animates
//   3. User taps "Done" — recording stops, stats computed, saved to GRDB
//   4. Results card appears showing WPM, duration, loudness, bands

import UIKit
import AVFoundation

final class ReadingAloudDrillViewController: UIViewController {

    // MARK: - Input

    private let passage: ReadingPassage

    // MARK: - Audio

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meterTimer: Timer?
    private var displayTimer: Timer?
    private var startTime: Date?

    // Running loudness samples (dBFS)
    private var loudnessSamples: [Float] = []

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Passage card
    private let passageCard = LCCard()
    private let passageTitleLabel = UILabel()
    private let passageMetaLabel = UILabel()
    private let passageBodyLabel = UILabel()

    // Control card
    private let controlCard = LCCard()
    private let timerLabel = UILabel()
    private let meterBarContainer = UIView()
    private let meterBarFill = UIView()
    private var meterBarFillWidthConstraint: NSLayoutConstraint?
    private let meterLabel = UILabel()
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
        stopMeterTimers()
        audioRecorder?.stop()
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

        buildPassageCard()
        contentStack.addArrangedSubview(passageCard)

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

    private func buildControlCard() {
        timerLabel.text = "0:00"
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        timerLabel.textColor = .label
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Loudness meter bar
        meterBarContainer.backgroundColor = .systemFill
        meterBarContainer.layer.cornerRadius = 6
        meterBarContainer.clipsToBounds = true
        meterBarContainer.translatesAutoresizingMaskIntoConstraints = false

        meterBarFill.backgroundColor = .lcBlue
        meterBarFill.layer.cornerRadius = 6
        meterBarFill.translatesAutoresizingMaskIntoConstraints = false
        meterBarContainer.addSubview(meterBarFill)

        meterLabel.text = "Tap Start when you're ready to read."
        meterLabel.font = UIFont.lcCaption()
        meterLabel.textColor = .secondaryLabel
        meterLabel.textAlignment = .center
        meterLabel.translatesAutoresizingMaskIntoConstraints = false

        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false

        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        controlCard.addSubview(timerLabel)
        controlCard.addSubview(meterBarContainer)
        controlCard.addSubview(meterLabel)
        controlCard.addSubview(startButton)
        controlCard.addSubview(stopButton)

        let fillWidth = meterBarFill.widthAnchor.constraint(equalToConstant: 0)
        meterBarFillWidthConstraint = fillWidth

        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: controlCard.topAnchor, constant: LC.cardPadding),
            timerLabel.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor),
            timerLabel.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor),

            meterBarContainer.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 14),
            meterBarContainer.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: LC.cardPadding),
            meterBarContainer.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -LC.cardPadding),
            meterBarContainer.heightAnchor.constraint(equalToConstant: 12),

            meterBarFill.topAnchor.constraint(equalTo: meterBarContainer.topAnchor),
            meterBarFill.bottomAnchor.constraint(equalTo: meterBarContainer.bottomAnchor),
            meterBarFill.leadingAnchor.constraint(equalTo: meterBarContainer.leadingAnchor),
            fillWidth,

            meterLabel.topAnchor.constraint(equalTo: meterBarContainer.bottomAnchor, constant: 10),
            meterLabel.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: LC.cardPadding),
            meterLabel.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -LC.cardPadding),

            startButton.topAnchor.constraint(equalTo: meterLabel.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: LC.cardPadding),
            startButton.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -LC.cardPadding),
            startButton.heightAnchor.constraint(equalToConstant: 52),

            stopButton.topAnchor.constraint(equalTo: meterLabel.bottomAnchor, constant: 16),
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
            meterLabel.text = "Tap Start when you're ready to read."
            setMeterFill(level: 0)
        case .recording:
            startButton.isHidden = true
            stopButton.isHidden = false
            meterLabel.text = "Recording… read at a comfortable pace."
        case .saving:
            stopButton.isEnabled = false
            meterLabel.text = "Saving…"
        case .done:
            startButton.isHidden = false
            stopButton.isHidden = true
            startButton.setTitle("Read Again", for: .normal)
            meterLabel.text = "Nice reading! Try again to see if you improve."
            setMeterFill(level: 0)
        }
    }

    // MARK: - Actions

    @objc private func didTapStart() {
        lcHaptic(.light)
        // Reset for a fresh take
        resultsCard.isHidden = true
        loudnessSamples.removeAll()
        Task {
            do {
                try await startRecording()
                await MainActor.run {
                    self.startTime = Date()
                    self.state = .recording
                    self.startMeterTimers()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Couldn't start recording",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                }
            }
        }
    }

    @objc private func didTapStop() {
        lcHaptic(.light)
        stopMeterTimers()
        state = .saving

        let duration = Date().timeIntervalSince(startTime ?? Date())
        let recorder = audioRecorder
        recorder?.stop()

        // Compute loudness stats
        let nonMinimum = loudnessSamples.filter { $0 > -160 }
        let avgDb: Double
        let peakDb: Double
        if nonMinimum.isEmpty {
            avgDb = -160
            peakDb = -160
        } else {
            avgDb = Double(nonMinimum.reduce(0, +)) / Double(nonMinimum.count)
            peakDb = Double(nonMinimum.max() ?? -160)
        }

        let wordCount = passage.wordCount
        let wpm: Double = duration > 0
            ? (Double(wordCount) / duration) * 60.0
            : 0

        let session = ReadingSession(
            passageId: passage.id == 0 ? nil : passage.id,
            passageTitle: passage.title,
            passageBody: passage.body,
            wordCount: wordCount,
            durationSeconds: duration,
            wordsPerMinute: wpm,
            avgLoudnessDb: avgDb,
            peakLoudnessDb: peakDb,
            audioFilePath: recordingURL?.path,
            notes: nil,
            recordedAt: Date()
        )

        Task {
            do {
                let saved = try await ServiceLocator.shared.readingAloudService.saveSession(session)
                // Mark the "first reading aloud" milestone if the user
                // doesn't already have one. Fire-and-forget.
                try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.state = .done
                    self.showResults(for: saved)
                    self.stopButton.isEnabled = true
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

    // MARK: - Recording

    private func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
        try session.setActive(true)

        let dir = try recordingsDirectory()
        let url = dir.appendingPathComponent("reading_\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey:             Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:           44_100,
            AVNumberOfChannelsKey:     1,
            AVEncoderAudioQualityKey:  AVAudioQuality.high.rawValue
        ]
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
    }

    private func recordingsDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .documentDirectory,
                              in: .userDomainMask,
                              appropriateFor: nil,
                              create: true)
        let dir = base.appendingPathComponent("reading")
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Meter / display timers

    private func startMeterTimers() {
        // Sample meter ~10x/s
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.sampleMeter()
        }
        RunLoop.current.add(meterTimer!, forMode: .common)

        // Update timer label 1x/s
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateTimerLabel()
        }
        RunLoop.current.add(displayTimer!, forMode: .common)
    }

    private func stopMeterTimers() {
        meterTimer?.invalidate()
        meterTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func sampleMeter() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        loudnessSamples.append(db)
        // Normalise -60 dBFS → 0 … 0 dBFS → 1
        let normalized = max(0, min(1, (Double(db) + 60) / 60))
        setMeterFill(level: CGFloat(normalized))
    }

    private func setMeterFill(level: CGFloat) {
        let containerWidth = meterBarContainer.bounds.width
        meterBarFillWidthConstraint?.constant = containerWidth * level
        UIView.animate(withDuration: 0.08) {
            self.meterBarContainer.layoutIfNeeded()
        }
        // Colour hint based on level
        if level < 0.33 {
            meterBarFill.backgroundColor = .lcAmber
        } else if level < 0.75 {
            meterBarFill.backgroundColor = .lcGreen
        } else {
            meterBarFill.backgroundColor = .lcBlue
        }
    }

    private func updateTimerLabel() {
        guard let start = startTime else { return }
        let total = Int(Date().timeIntervalSince(start))
        let m = total / 60
        let s = total % 60
        timerLabel.text = String(format: "%d:%02d", m, s)
    }

    // MARK: - Results card

    private func showResults(for session: ReadingSession) {
        resultsContent.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let header = UILabel()
        header.text = "Your Reading"
        header.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        header.textColor = .label
        resultsContent.addArrangedSubview(header)

        let wpmText   = String(format: "%.0f", session.wordsPerMinute)
        let dbText    = String(format: "%.0f", session.avgLoudnessDb)
        let duration  = formatDuration(session.durationSeconds)

        let statRow = LCStatRow(items: [
            .init(label: "WPM",       value: wpmText,  tint: .lcPurple),
            .init(label: "Avg dBFS",  value: dbText,   tint: .lcTeal),
            .init(label: "Duration",  value: duration, tint: .lcBlue)
        ])
        resultsContent.addArrangedSubview(statRow)

        // Bands explainer
        let bandLabel = UILabel()
        bandLabel.text = "Speed: \(session.wpmBand.label) • Loudness: \(session.loudnessBand.label)"
        bandLabel.font = UIFont.lcBodyBold()
        bandLabel.textColor = .label
        bandLabel.numberOfLines = 0
        resultsContent.addArrangedSubview(bandLabel)

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
