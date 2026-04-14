// SoundRecorderViewController.swift
// LangCI — Record real pronunciation for a test sound
//
// Presented as a half-sheet modal so the audiologist can record
// the actual sound (e.g. "aah", "shh") with their own voice.
// The recording replaces TTS for that sound in all tests.
//
// Flow: Tap Record → speak the sound → Tap Stop → Play to preview → Save

import UIKit
import AVFoundation

final class SoundRecorderViewController: UIViewController, AVAudioRecorderDelegate {

    // MARK: - Public

    /// The sound being recorded for
    var sound: TestSound!

    /// Called with the saved file name (relative to documents dir) on save
    var onSaved: ((String) -> Void)?

    // MARK: - Audio

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL!
    private var hasRecording = false

    // MARK: - UI

    private let symbolLabel = UILabel()
    private let currentLabel = UILabel()
    private let timerLabel = UILabel()

    private let recordButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let playOriginalButton = UIButton(type: .system)

    private let saveButton = LCButton(title: "Save Recording", color: .lcTeal)
    private let cancelButton = UIButton(type: .system)

    private var timer: Timer?
    private var recordingSeconds: Int = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground

        // File path in documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "sound_\(sound.id)_\(Int(Date().timeIntervalSince1970)).m4a"
        recordingURL = docs.appendingPathComponent(fileName)

        setupAudioSession()
        buildUI()
        updateButtons()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRecording()
        audioPlayer?.stop()
        timer?.invalidate()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 24, leading: 24, bottom: 24, trailing: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Record Sound"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        // Sound symbol
        symbolLabel.text = "\"\(sound.symbol)\""
        symbolLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        symbolLabel.textColor = .lcTeal
        symbolLabel.textAlignment = .center
        stack.addArrangedSubview(symbolLabel)

        // Current pronunciation info
        if let existing = sound.audioFileName {
            currentLabel.text = "Has recording: \(existing)"
        } else {
            currentLabel.text = "Currently using TTS: \"\(sound.speakableText)\""
        }
        currentLabel.font = UIFont.lcCaption()
        currentLabel.textColor = .secondaryLabel
        currentLabel.textAlignment = .center
        currentLabel.numberOfLines = 0
        stack.addArrangedSubview(currentLabel)

        // Timer
        timerLabel.text = "0:00"
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .light)
        timerLabel.textColor = .label
        timerLabel.textAlignment = .center
        stack.addArrangedSubview(timerLabel)

        // Record button — large red circle
        let recCfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        recordButton.setImage(UIImage(systemName: "record.circle", withConfiguration: recCfg), for: .normal)
        recordButton.tintColor = .lcRed
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        stack.addArrangedSubview(recordButton)

        // Play buttons row
        let playCfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)

        playButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: playCfg), for: .normal)
        playButton.setTitle(" Play Recording", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        playButton.tintColor = .lcBlue
        playButton.addTarget(self, action: #selector(playRecordingTapped), for: .touchUpInside)

        playOriginalButton.setImage(UIImage(systemName: "speaker.wave.2.circle", withConfiguration: playCfg), for: .normal)
        playOriginalButton.setTitle(" Play Original", for: .normal)
        playOriginalButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        playOriginalButton.tintColor = .secondaryLabel
        playOriginalButton.addTarget(self, action: #selector(playOriginalTapped), for: .touchUpInside)

        let playRow = UIStackView(arrangedSubviews: [playButton, playOriginalButton])
        playRow.axis = .horizontal
        playRow.spacing = 20
        playRow.alignment = .center
        stack.addArrangedSubview(playRow)

        // Save / Cancel
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.widthAnchor.constraint(equalToConstant: 250).isActive = true
        stack.addArrangedSubview(saveButton)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.tintColor = .secondaryLabel
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        stack.addArrangedSubview(cancelButton)
    }

    private func updateButtons() {
        let isRecording = audioRecorder?.isRecording == true
        let recCfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)

        if isRecording {
            recordButton.setImage(UIImage(systemName: "stop.circle.fill", withConfiguration: recCfg), for: .normal)
            recordButton.tintColor = .lcRed
            playButton.isEnabled = false
            playButton.alpha = 0.4
            saveButton.isEnabled = false
            saveButton.alpha = 0.4
        } else {
            recordButton.setImage(UIImage(systemName: "record.circle", withConfiguration: recCfg), for: .normal)
            recordButton.tintColor = .lcRed
            playButton.isEnabled = hasRecording
            playButton.alpha = hasRecording ? 1.0 : 0.4
            saveButton.isEnabled = hasRecording
            saveButton.alpha = hasRecording ? 1.0 : 0.4
        }
    }

    // MARK: - Recording

    @objc private func recordTapped() {
        if audioRecorder?.isRecording == true {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        lcHaptic(.medium)
        audioPlayer?.stop()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            recordingSeconds = 0
            timerLabel.text = "0:00"
            timerLabel.textColor = .lcRed
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingSeconds += 1
                let mins = self.recordingSeconds / 60
                let secs = self.recordingSeconds % 60
                self.timerLabel.text = String(format: "%d:%02d", mins, secs)
            }

            updateButtons()
        } catch {
            print("Recording error: \(error)")
        }
    }

    private func stopRecording() {
        guard audioRecorder?.isRecording == true else { return }
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        timerLabel.textColor = .label
        hasRecording = true
        lcHaptic(.light)
        updateButtons()
    }

    // MARK: - Playback

    @objc private func playRecordingTapped() {
        guard hasRecording else { return }
        lcHaptic(.light)
        audioPlayer?.stop()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.play()
        } catch {
            print("Playback error: \(error)")
        }
    }

    @objc private func playOriginalTapped() {
        lcHaptic(.light)
        audioPlayer?.stop()

        // If there's an existing recording on disk, play that
        if let existingFile = sound.audioFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent(existingFile)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    return
                } catch { }
            }
        }

        // Fall back to TTS
        MultiVoiceTTS.shared.speakEnglishOnly(sound.speakableText)
    }

    // MARK: - Save / Cancel

    @objc private func saveTapped() {
        guard hasRecording else { return }
        lcHaptic(.medium)

        // Delete old recording if exists
        if let oldFile = sound.audioFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let oldURL = docs.appendingPathComponent(oldFile)
            try? FileManager.default.removeItem(at: oldURL)
        }

        let fileName = recordingURL.lastPathComponent
        onSaved?(fileName)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        // Clean up temp recording if not saved
        if hasRecording {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        dismiss(animated: true)
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            hasRecording = false
        }
        updateButtons()
    }
}
