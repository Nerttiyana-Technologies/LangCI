// RecordVoiceViewController.swift
// LangCI — Record familiar voices for CI training
//
// Instead of recording every sound (boring!), we record a small set of
// key phrases per person. These get used in "Familiar Voices" training
// where the CI user practises recognising WHO is speaking and WHAT.
//
// Pre-built prompt cards make recording fun and quick:
//   "Say your name", "Say hello", "Count 1-5", "Call Suresh",
//   "Say something funny", "Read this sentence", etc.
//
// ~5-8 clips per person is plenty for effective training.

import UIKit
import AVFoundation

final class RecordVoiceViewController: UIViewController, AVAudioRecorderDelegate {

    // MARK: - Configuration

    /// Pre-selected person (skip person picker step)
    var preselectedPerson: RecordedPerson?

    /// Callback when a recording is saved
    var onSave: ((VoiceRecording) -> Void)?

    // MARK: - Prompt cards

    /// Pre-built recording prompts — fun, quick, and CI-relevant
    private static let prompts: [(id: String, title: String, instruction: String, icon: String)] = [
        ("greeting",      "Say Hello",         "Say \"Hello!\" or \"Hi!\" in your natural voice",           "hand.wave.fill"),
        ("name_call",     "Call by Name",       "Say \"Suresh!\" like you're calling from another room",    "megaphone.fill"),
        ("counting",      "Count 1 to 5",      "Count slowly: \"One, two, three, four, five\"",            "number"),
        ("question",      "Ask a Question",     "Ask: \"How are you today?\"",                               "questionmark.bubble.fill"),
        ("come_here",     "Call to Come",       "Say: \"Come here, let's eat!\"",                            "figure.walk"),
        ("good_morning",  "Morning Greeting",   "Say: \"Good morning! Did you sleep well?\"",                "sun.max.fill"),
        ("vanakkam",      "Say Vanakkam",       "Say: \"Vanakkam!\" with warmth",                            "sparkles"),
        ("laugh",         "Laugh or Giggle",    "Just laugh naturally — giggles count!",                     "face.smiling.fill"),
        ("free_speech",   "Say Anything",       "Say any sentence you want — something you'd normally say",  "text.bubble.fill"),
        ("read_sentence", "Read This Aloud",    "Read: \"The weather is nice today, let's go for a walk\"", "book.fill"),
    ]

    // MARK: - State

    private let service = ServiceLocator.shared.voiceRecordingService!
    private var people: [RecordedPerson] = []
    private var selectedPerson: RecordedPerson?
    private var currentPromptIndex = 0
    private var recordedClips: [String: URL] = [:]  // promptId → file URL

    /// Combined prompts: built-in + custom Tamil words from DB
    private var allPrompts: [(id: String, title: String, instruction: String, icon: String)] = []
    private var customPrompts: [CustomVoicePrompt] = []

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var isRecording = false
    private var recordingTimer: Timer?
    private var elapsedSeconds: Double = 0

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Person picker
    private let personPickerScroll = UIScrollView()
    private let personPickerRow = UIStackView()
    private let addPersonButton = UIButton(type: .system)

    // Prompt card
    private let promptCard = LCCard()
    private let promptIcon = UIImageView()
    private let promptTitle = UILabel()
    private let promptInstruction = UILabel()
    private let promptProgress = UILabel()

    // Record controls
    private let timerLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    // After recording
    private let playButton = LCButton(title: "Play Back", color: .lcBlue)
    private let reRecordButton = LCButton(title: "Re-record", color: .lcOrange)
    private let saveAndNextButton = LCButton(title: "Save & Next", color: .lcGreen)
    private let skipButton = UIButton(type: .system)
    private let postRecordStack = UIStackView()

    // Done
    private let doneCard = LCCard()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Record Voices"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        setupAudioSession()
        buildUI()
        loadData()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Data

    private func loadData() {
        Task {
            people = (try? await service.getAllPeople()) ?? []
            customPrompts = (try? await service.getAllCustomPrompts()) ?? []
            buildAllPrompts()
            await MainActor.run {
                rebuildPersonPicker()
                if let pre = preselectedPerson {
                    selectedPerson = pre
                    highlightPerson()
                }
                updatePromptCard()
            }
        }
    }

    private func buildAllPrompts() {
        allPrompts = Self.prompts
        // Append custom Tamil prompts
        for cp in customPrompts {
            let title = cp.transliteration.isEmpty ? cp.text : cp.transliteration
            let instruction = cp.meaning.isEmpty
                ? "Say: \"\(cp.text)\""
                : "Say: \"\(cp.text)\" (\(cp.meaning))"
            allPrompts.append((
                id: cp.promptId,
                title: title,
                instruction: instruction,
                icon: "character.textbox"
            ))
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
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 12, leading: 20, bottom: 40, trailing: 20)
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

        // — Tip label
        let tipLabel = UILabel()
        tipLabel.text = "Record 5-8 short clips per person. These familiar voices will help your brain learn to recognise speech from people you know!"
        tipLabel.font = .systemFont(ofSize: 13, weight: .medium)
        tipLabel.textColor = .secondaryLabel
        tipLabel.numberOfLines = 0
        contentStack.addArrangedSubview(tipLabel)

        // — Person picker
        let personLabel = makeSectionLabel("WHO IS RECORDING?")
        contentStack.addArrangedSubview(personLabel)

        personPickerScroll.showsHorizontalScrollIndicator = false
        personPickerScroll.translatesAutoresizingMaskIntoConstraints = false
        personPickerScroll.heightAnchor.constraint(equalToConstant: 80).isActive = true

        personPickerRow.axis = .horizontal
        personPickerRow.spacing = 10
        personPickerRow.translatesAutoresizingMaskIntoConstraints = false
        personPickerScroll.addSubview(personPickerRow)

        NSLayoutConstraint.activate([
            personPickerRow.topAnchor.constraint(equalTo: personPickerScroll.contentLayoutGuide.topAnchor),
            personPickerRow.bottomAnchor.constraint(equalTo: personPickerScroll.contentLayoutGuide.bottomAnchor),
            personPickerRow.leadingAnchor.constraint(equalTo: personPickerScroll.contentLayoutGuide.leadingAnchor),
            personPickerRow.trailingAnchor.constraint(equalTo: personPickerScroll.contentLayoutGuide.trailingAnchor),
            personPickerRow.heightAnchor.constraint(equalTo: personPickerScroll.frameLayoutGuide.heightAnchor),
        ])
        contentStack.addArrangedSubview(personPickerScroll)

        addPersonButton.setTitle("+ Add Person", for: .normal)
        addPersonButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        addPersonButton.setTitleColor(.lcTeal, for: .normal)
        addPersonButton.addTarget(self, action: #selector(addPersonTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(addPersonButton)

        // — Add Tamil Words button
        let addWordsBtn = UIButton(type: .system)
        addWordsBtn.setTitle("+ Add Tamil Words to Record", for: .normal)
        addWordsBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        addWordsBtn.setTitleColor(.lcAmber, for: .normal)
        addWordsBtn.setImage(UIImage(systemName: "character.textbox"), for: .normal)
        addWordsBtn.tintColor = .lcAmber
        addWordsBtn.addTarget(self, action: #selector(addTamilWordsTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(addWordsBtn)

        // — Prompt card
        buildPromptCard()
        contentStack.addArrangedSubview(promptCard)

        // — Record controls
        timerLabel.text = "0:00"
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 42, weight: .bold)
        timerLabel.textColor = .label
        timerLabel.textAlignment = .center
        contentStack.addArrangedSubview(timerLabel)

        var recConfig = UIButton.Configuration.filled()
        recConfig.image = UIImage(systemName: "mic.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold))
        recConfig.baseBackgroundColor = UIColor.lcRed.withAlphaComponent(0.15)
        recConfig.baseForegroundColor = .lcRed
        recConfig.cornerStyle = .capsule
        recordButton.configuration = recConfig
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        recordButton.heightAnchor.constraint(equalToConstant: 100).isActive = true
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)

        let recWrap = UIView()
        recWrap.translatesAutoresizingMaskIntoConstraints = false
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recWrap.addSubview(recordButton)
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: recWrap.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: recWrap.topAnchor),
            recordButton.bottomAnchor.constraint(equalTo: recWrap.bottomAnchor),
        ])
        contentStack.addArrangedSubview(recWrap)

        statusLabel.text = "Select a person to start"
        statusLabel.font = UIFont.lcCaption()
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        contentStack.addArrangedSubview(statusLabel)

        // — Post-record buttons
        postRecordStack.axis = .vertical
        postRecordStack.spacing = 10
        postRecordStack.isHidden = true

        let btnRow = UIStackView(arrangedSubviews: [playButton, reRecordButton])
        btnRow.axis = .horizontal
        btnRow.spacing = 12
        btnRow.distribution = .fillEqually
        postRecordStack.addArrangedSubview(btnRow)
        postRecordStack.addArrangedSubview(saveAndNextButton)

        skipButton.setTitle("Skip this prompt", for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        skipButton.setTitleColor(.secondaryLabel, for: .normal)
        skipButton.addTarget(self, action: #selector(skipPrompt), for: .touchUpInside)
        postRecordStack.addArrangedSubview(skipButton)

        contentStack.addArrangedSubview(postRecordStack)

        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        reRecordButton.addTarget(self, action: #selector(reRecordTapped), for: .touchUpInside)
        saveAndNextButton.addTarget(self, action: #selector(saveAndNextTapped), for: .touchUpInside)

        // — Done card (hidden)
        doneCard.isHidden = true
        contentStack.addArrangedSubview(doneCard)

        // — Skip visible even before recording
        let skipAlso = UIButton(type: .system)
        skipAlso.setTitle("Skip this prompt →", for: .normal)
        skipAlso.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        skipAlso.setTitleColor(.tertiaryLabel, for: .normal)
        skipAlso.addTarget(self, action: #selector(skipPrompt), for: .touchUpInside)
        contentStack.addArrangedSubview(skipAlso)
    }

    private func buildPromptCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        promptIcon.tintColor = .lcAmber
        promptIcon.contentMode = .scaleAspectFit
        promptIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        promptIcon.heightAnchor.constraint(equalToConstant: 32).isActive = true

        promptTitle.font = .systemFont(ofSize: 18, weight: .bold)
        promptTitle.textColor = .label
        promptTitle.textAlignment = .center

        promptInstruction.font = .systemFont(ofSize: 15, weight: .medium)
        promptInstruction.textColor = .secondaryLabel
        promptInstruction.textAlignment = .center
        promptInstruction.numberOfLines = 0

        promptProgress.font = .systemFont(ofSize: 12, weight: .semibold)
        promptProgress.textColor = .tertiaryLabel
        promptProgress.textAlignment = .center

        stack.addArrangedSubview(promptIcon)
        stack.addArrangedSubview(promptTitle)
        stack.addArrangedSubview(promptInstruction)
        stack.addArrangedSubview(promptProgress)

        promptCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: promptCard.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: promptCard.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: promptCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: promptCard.trailingAnchor, constant: -16),
        ])
    }

    private func updatePromptCard() {
        guard currentPromptIndex < allPrompts.count else {
            showDoneCard()
            return
        }
        let prompt = allPrompts[currentPromptIndex]
        promptIcon.image = UIImage(systemName: prompt.icon)
        promptTitle.text = prompt.title
        promptInstruction.text = prompt.instruction
        promptProgress.text = "\(currentPromptIndex + 1) of \(allPrompts.count)"
        promptCard.isHidden = false

        // Reset record state
        timerLabel.text = "0:00"
        timerLabel.textColor = .label
        postRecordStack.isHidden = true
        doneCard.isHidden = true

        if selectedPerson != nil {
            statusLabel.text = "Tap the mic to record"
            recordButton.isEnabled = true
            recordButton.alpha = 1
        } else {
            statusLabel.text = "Select a person to start"
            recordButton.isEnabled = false
            recordButton.alpha = 0.4
        }
    }

    // MARK: - Person Picker

    private func rebuildPersonPicker() {
        personPickerRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for person in people {
            personPickerRow.addArrangedSubview(buildPersonChip(person))
        }
    }

    private func buildPersonChip(_ person: RecordedPerson) -> UIView {
        let chip = UIView()
        chip.backgroundColor = .lcCard
        chip.layer.cornerRadius = 12
        chip.lcApplyShadow(radius: 4, opacity: 0.08)
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.widthAnchor.constraint(equalToConstant: 90).isActive = true
        chip.isUserInteractionEnabled = true
        chip.tag = person.id

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        chip.addSubview(stack)

        let color = colorForKey(person.color)
        let iconView = UIImageView(image: UIImage(systemName: person.icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = person.name
        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center

        let countLabel = UILabel()
        countLabel.text = "\(person.recordingCount) clips"
        countLabel.font = .systemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = .secondaryLabel

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(countLabel)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
        ])

        chip.addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(personChipTapped(_:))))
        return chip
    }

    @objc private func personChipTapped(_ gesture: UITapGestureRecognizer) {
        guard let v = gesture.view else { return }
        selectedPerson = people.first { $0.id == v.tag }
        highlightPerson()
        updatePromptCard()
        lcHaptic(.light)
    }

    private func highlightPerson() {
        for chip in personPickerRow.arrangedSubviews {
            let sel = chip.tag == selectedPerson?.id
            chip.layer.borderWidth = sel ? 2.5 : 0
            chip.layer.borderColor = sel ? UIColor.lcTeal.cgColor : nil
        }
    }

    // MARK: - Add Person

    @objc private func addPersonTapped() {
        let alert = UIAlertController(title: "Add a Person",
            message: "Who will be recording their voice?",
            preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Name (e.g. Priya)" }

        alert.addAction(UIAlertAction(title: "Next", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self?.pickRelationship(forName: name)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func pickRelationship(forName name: String) {
        let alert = UIAlertController(title: "Relationship",
            message: "How do you know \(name)?",
            preferredStyle: .actionSheet)

        for rel in PersonRelationship.allCases {
            alert.addAction(UIAlertAction(title: rel.rawValue, style: .default) { [weak self] _ in
                self?.createPerson(name: name, relationship: rel)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func createPerson(name: String, relationship: PersonRelationship) {
        Task {
            let person = RecordedPerson(
                id: 0, name: name, relationship: relationship.rawValue,
                color: relationship.color, icon: relationship.icon,
                isActive: true, createdAt: Date(), updatedAt: Date())
            if let saved = try? await service.addPerson(person) {
                await MainActor.run {
                    people.append(saved)
                    selectedPerson = saved
                    rebuildPersonPicker()
                    highlightPerson()
                    updatePromptCard()
                }
            }
        }
    }

    // MARK: - Add Tamil Words

    @objc private func addTamilWordsTapped() {
        let vc = CustomPromptsViewController()
        vc.person = selectedPerson
        vc.onPromptsAdded = { [weak self] newPrompts in
            guard let self = self else { return }
            self.customPrompts.append(contentsOf: newPrompts)
            self.buildAllPrompts()
            self.updatePromptCard()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Recording

    @objc private func recordTapped() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        guard selectedPerson != nil else { return }
        guard currentPromptIndex < allPrompts.count else { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("VoiceRecordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let prompt = allPrompts[currentPromptIndex]
        let ts = Int(Date().timeIntervalSince1970)
        let tag = selectedPerson?.name.lowercased().replacingOccurrences(of: " ", with: "_") ?? "x"
        let fileName = "voice_\(tag)_\(prompt.id)_\(ts).m4a"
        let fileURL = dir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true

            // Delete previous attempt for this prompt
            if let old = recordedClips[prompt.id] {
                try? FileManager.default.removeItem(at: old)
            }
            recordedClips[prompt.id] = fileURL

            var config = recordButton.configuration
            config?.image = UIImage(systemName: "stop.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold))
            config?.baseBackgroundColor = UIColor.lcRed.withAlphaComponent(0.3)
            recordButton.configuration = config

            statusLabel.text = "Recording... tap to stop"
            statusLabel.textColor = .lcRed
            postRecordStack.isHidden = true

            elapsedSeconds = 0
            timerLabel.textColor = .lcRed
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.elapsedSeconds += 0.1
                let s = Int(self.elapsedSeconds)
                self.timerLabel.text = String(format: "%d:%02d", s / 60, s % 60)
            }
            lcHaptic(.medium)
        } catch {
            statusLabel.text = "Failed: \(error.localizedDescription)"
            statusLabel.textColor = .lcRed
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()

        var config = recordButton.configuration
        config?.image = UIImage(systemName: "mic.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold))
        config?.baseBackgroundColor = UIColor.lcRed.withAlphaComponent(0.15)
        recordButton.configuration = config

        timerLabel.textColor = .label
        statusLabel.text = String(format: "Recorded %.1f seconds", elapsedSeconds)
        statusLabel.textColor = .secondaryLabel

        postRecordStack.isHidden = false
        lcHaptic(.light)
    }

    // MARK: - Playback

    @objc private func playTapped() {
        let prompt = allPrompts[currentPromptIndex]
        guard let url = recordedClips[prompt.id] else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            lcHaptic(.light)
        } catch {
            statusLabel.text = "Playback failed"
        }
    }

    @objc private func reRecordTapped() {
        let prompt = allPrompts[currentPromptIndex]
        if let url = recordedClips[prompt.id] {
            try? FileManager.default.removeItem(at: url)
            recordedClips.removeValue(forKey: prompt.id)
        }
        postRecordStack.isHidden = true
        timerLabel.text = "0:00"
        statusLabel.text = "Tap the mic to re-record"
        statusLabel.textColor = .secondaryLabel
    }

    // MARK: - Save & Next

    @objc private func saveAndNextTapped() {
        guard let person = selectedPerson else { return }
        let prompt = allPrompts[currentPromptIndex]
        guard let url = recordedClips[prompt.id] else { return }

        let recording = VoiceRecording(
            id: 0, personId: person.id,
            soundId: prompt.id,  // use prompt.id as a grouping key
            label: prompt.title,
            fileName: url.lastPathComponent,
            durationSeconds: elapsedSeconds,
            createdAt: Date())

        Task {
            let saved = try? await service.addRecording(recording)
            await MainActor.run {
                if let saved = saved { onSave?(saved) }
                lcHapticSuccess()
                currentPromptIndex += 1
                updatePromptCard()
            }
        }
    }

    @objc private func skipPrompt() {
        currentPromptIndex += 1
        updatePromptCard()
    }

    // MARK: - Done

    private func showDoneCard() {
        promptCard.isHidden = true
        recordButton.isHidden = true
        timerLabel.isHidden = true
        statusLabel.isHidden = true
        postRecordStack.isHidden = true

        doneCard.isHidden = false
        doneCard.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.text = "🎉"
        emoji.font = .systemFont(ofSize: 48)

        let title = UILabel()
        title.text = "All Done!"
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let count = recordedClips.count
        let subtitle = UILabel()
        subtitle.text = "Recorded \(count) clips for \(selectedPerson?.name ?? "this person"). These will appear as voice options in your training sessions."
        subtitle.font = .systemFont(ofSize: 14, weight: .medium)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        let doneBtn = LCButton(title: "Back to Voice Library", color: .lcGreen)
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        let moreBtn = LCButton(title: "Record Another Person", color: .lcTeal)
        moreBtn.addTarget(self, action: #selector(recordAnotherPerson), for: .touchUpInside)

        stack.addArrangedSubview(emoji)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(doneBtn)
        stack.addArrangedSubview(moreBtn)

        doneCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: doneCard.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: doneCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: doneCard.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: doneCard.trailingAnchor, constant: -20),
        ])
    }

    @objc private func doneTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func recordAnotherPerson() {
        selectedPerson = nil
        currentPromptIndex = 0
        recordedClips.removeAll()
        highlightPerson()

        promptCard.isHidden = false
        recordButton.isHidden = false
        timerLabel.isHidden = false
        statusLabel.isHidden = false
        doneCard.isHidden = true
        updatePromptCard()
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            statusLabel.text = "Recording failed"
            statusLabel.textColor = .lcRed
        }
    }

    // MARK: - Helpers

    private func makeSectionLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .tertiaryLabel
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: 1.2, range: NSRange(location: 0, length: text.count))
        lbl.attributedText = attr
        return lbl
    }

    private func colorForKey(_ key: String) -> UIColor {
        switch key {
        case "lcBlue":   return .lcBlue
        case "lcPurple": return .lcPurple
        case "lcTeal":   return .lcTeal
        case "lcGreen":  return .lcGreen
        case "lcAmber":  return .lcAmber
        case "lcOrange": return .lcOrange
        case "lcRed":    return .lcRed
        case "lcGold":   return .lcGold
        default:         return .lcTeal
        }
    }
}
