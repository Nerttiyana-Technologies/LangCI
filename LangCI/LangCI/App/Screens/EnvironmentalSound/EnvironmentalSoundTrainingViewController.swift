// EnvironmentalSoundTrainingViewController.swift
// LangCI — Environmental Sound Training
//
// Helps early CI users learn to identify everyday sounds.
// Uses TTS to describe/mimic sounds, then asks the user to identify them.
// Progresses through: Detection → Discrimination → Identification → Categorisation
//
// Day 1-7:  Focus on detection ("Did you hear something?") with easy sounds
// Day 7-21: Discrimination ("Same or different?") and identification
// Day 21+:  Full identification and categorisation

import UIKit
import AVFoundation

final class EnvironmentalSoundTrainingViewController: UIViewController {

    // MARK: - Configuration

    var environment: SoundEnvironment?  // nil = mixed/auto
    var startingLevel: EnvironmentalListeningLevel = .detection

    /// Learning mode: no quiz, just "see name → hear sound → replay".
    /// Ideal for first 2 weeks post-activation when everything is static.
    var learningMode = false

    // MARK: - State

    private var items: [EnvironmentalSoundItem] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var currentLevel: EnvironmentalListeningLevel = .detection
    private var isComplete = false
    private let service = ServiceLocator.shared.environmentalSoundService!
    private var sessionStartedAt = Date()

    // For discrimination level — pair of sounds
    private var discriminationPair: (EnvironmentalSoundItem, EnvironmentalSoundItem)?
    private var discriminationIsSame = false

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Voice Personas

    /// 4 distinct TTS voices: 2 female (higher pitch), 2 male (lower pitch).
    /// Cycling through them trains the brain to recognize sounds regardless of speaker.
    private struct VoicePersona {
        let label: String          // "Female 1", "Male 2", etc.
        let icon: String           // SF Symbol
        let voiceId: String        // AVSpeechSynthesisVoice identifier
        let pitchMultiplier: Float // <1 = deeper, >1 = higher
        let rate: Float            // speech rate multiplier
        let color: UIColor
    }

    private let voicePersonas: [VoicePersona] = {
        // Pick the best available en voices; fallback to generic en-US
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        // Try to find distinct voices by name/quality
        func findVoice(_ keywords: [String]) -> String {
            for kw in keywords {
                if let v = allVoices.first(where: {
                    $0.identifier.lowercased().contains(kw.lowercased())
                }) {
                    return v.identifier
                }
            }
            return AVSpeechSynthesisVoice(language: "en-US")?.identifier ?? ""
        }

        let female1Id = findVoice(["Samantha", "Karen", "Moira", "com.apple.voice.compact.en-US.Samantha"])
        let female2Id = findVoice(["Rishi", "Tessa", "Kate", "com.apple.voice.compact.en-GB.Daniel"])
        let male1Id = findVoice(["Daniel", "Aaron", "com.apple.voice.compact.en-AU"])
        let male2Id = findVoice(["Oliver", "Tom", "com.apple.voice.compact.en-IN"])

        return [
            VoicePersona(label: "Female 1", icon: "person.fill",
                         voiceId: female1Id, pitchMultiplier: 1.15, rate: 0.85,
                         color: .lcPurple),
            VoicePersona(label: "Female 2", icon: "person.fill",
                         voiceId: female2Id, pitchMultiplier: 1.25, rate: 0.80,
                         color: .lcTeal),
            VoicePersona(label: "Male 1", icon: "person.fill",
                         voiceId: male1Id, pitchMultiplier: 0.85, rate: 0.85,
                         color: .lcBlue),
            VoicePersona(label: "Male 2", icon: "person.fill",
                         voiceId: male2Id, pitchMultiplier: 0.75, rate: 0.90,
                         color: .lcOrange),
        ]
    }()

    private var currentVoiceIndex = 0
    private let voiceLabel = UILabel()     // Shows "Female 1" / "Male 2"
    private let voicePickerStack = UIStackView()

    // MARK: - Recorded (real) voices

    private let voiceService = ServiceLocator.shared.voiceRecordingService!
    private var recordedPeople: [RecordedPerson] = []
    /// Map: personId → [soundId/promptId → [VoiceRecording]]
    private var recordedClips: [Int: [String: [VoiceRecording]]] = [:]
    private var audioPlayer: AVAudioPlayer?
    /// Index into recordedPeople for the currently selected real voice (-1 = TTS)
    private var selectedRealVoiceIndex: Int = -1
    private let realVoicePickerStack = UIStackView()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let levelBadge = UILabel()
    private let progressLabel = UILabel()
    private let progressBar = ProgressBarView()

    private let instructionCard = LCCard()
    private let instructionLabel = UILabel()
    private let speakerButton = UIButton(type: .system)

    private let choiceStack = UIStackView()
    private var choiceButtons: [UIButton] = []

    private let soundNameLabel = UILabel()   // Shows "🔔 Doorbell" while playing
    private let soundDescLabel = UILabel()  // Shows description in learning mode
    private let replayCountLabel = UILabel() // Shows "Listened 3 times"
    private var replayCount = 0
    private let feedbackLabel = UILabel()
    private let nextButton = LCButton(title: "Next", color: .lcTeal)
    private let resultsCard = LCCard()

    // Learning mode UI
    private let learningTipCard = LCCard()
    private let replayButton = LCButton(title: "Replay Sound", color: .lcTeal)
    private let gotItButton = LCButton(title: "Next Sound", color: .lcGreen)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sound Training"
        view.backgroundColor = .lcBackground
        currentLevel = startingLevel
        buildUI()
        loadItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Data

    /// Set externally to limit drill to a specific pack's sound IDs
    var packSoundIds: [String]?

    private func loadItems() {
        // Start with built-in sounds
        let allItems = EnvironmentalSoundContent.allSounds

        // Load custom sounds + overrides + recorded voices async
        Task {
            // Merge custom sounds
            let customSounds = (try? await service.getAllCustomSounds()) ?? []
            let customItems = customSounds.map { $0.toItem() }

            // Apply edit overrides to built-in sounds
            let overrides = (try? await service.getAllOverrides()) ?? []
            let overrideMap = Dictionary(uniqueKeysWithValues: overrides.map { ($0.soundId, $0) })

            var mergedItems = allItems.map { item -> EnvironmentalSoundItem in
                guard let ovr = overrideMap[item.id] else { return item }
                return EnvironmentalSoundItem(
                    id: item.id,
                    name: ovr.name ?? item.name,
                    environment: item.environment,
                    description: ovr.description ?? item.description,
                    systemSoundName: item.systemSoundName,
                    speechDescription: ovr.speechDescription ?? item.speechDescription,
                    ciDifficulty: ovr.ciDifficulty ?? item.ciDifficulty)
            }
            mergedItems.append(contentsOf: customItems)

            // Load recorded voices
            let people = (try? await voiceService.getAllPeople()) ?? []
            var clipMap: [Int: [String: [VoiceRecording]]] = [:]
            for person in people {
                let clips = (try? await voiceService.getRecordings(forPerson: person.id)) ?? []
                var grouped: [String: [VoiceRecording]] = [:]
                for clip in clips {
                    let key = clip.soundId ?? clip.label
                    grouped[key, default: []].append(clip)
                }
                clipMap[person.id] = grouped
            }

            await MainActor.run {
                self.recordedPeople = people
                self.recordedClips = clipMap
                self.buildRealVoicePicker()

                // Filter by pack, environment, or show all
                if let packIds = self.packSoundIds {
                    self.items = mergedItems.filter { packIds.contains($0.id) }
                } else if let env = self.environment {
                    self.items = mergedItems.filter { $0.environment == env }
                        .sorted { $0.ciDifficulty < $1.ciDifficulty }
                } else {
                    self.items = mergedItems.sorted { $0.ciDifficulty < $1.ciDifficulty }
                }

                // Limit to 10 per session
                self.items = Array(self.items.shuffled().prefix(10))
                self.currentIndex = 0
                self.correctCount = 0
                self.isComplete = false

                if !self.items.isEmpty {
                    self.showCurrentItem()
                }
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

        // Level badge
        levelBadge.font = .systemFont(ofSize: 13, weight: .bold)
        levelBadge.textColor = .white
        levelBadge.backgroundColor = .lcTeal
        levelBadge.textAlignment = .center
        levelBadge.layer.cornerRadius = 12
        levelBadge.clipsToBounds = true
        levelBadge.heightAnchor.constraint(equalToConstant: 24).isActive = true
        contentStack.addArrangedSubview(levelBadge)

        // Progress
        progressLabel.font = UIFont.lcCaption()
        progressLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(progressLabel)
        contentStack.addArrangedSubview(progressBar)

        // Instruction card with speaker button
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.alignment = .center
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        instructionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        instructionLabel.textColor = .label
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        // Big speaker button
        var speakerConfig = UIButton.Configuration.filled()
        speakerConfig.image = UIImage(systemName: "speaker.wave.3.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
        speakerConfig.baseBackgroundColor = UIColor.lcTeal.withAlphaComponent(0.15)
        speakerConfig.baseForegroundColor = .lcTeal
        speakerConfig.cornerStyle = .capsule
        speakerButton.configuration = speakerConfig
        speakerButton.translatesAutoresizingMaskIntoConstraints = false
        speakerButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        speakerButton.heightAnchor.constraint(equalToConstant: 80).isActive = true
        speakerButton.addTarget(self, action: #selector(playCurrentSound), for: .touchUpInside)

        let tapHintLabel = UILabel()
        tapHintLabel.text = "Tap to listen"
        tapHintLabel.font = UIFont.lcCaption()
        tapHintLabel.textColor = .tertiaryLabel

        // Sound name label — shows what's playing so early CI users can
        // associate the static pattern they hear with the actual sound name.
        soundNameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        soundNameLabel.textColor = .lcTeal
        soundNameLabel.textAlignment = .center
        soundNameLabel.numberOfLines = 0
        soundNameLabel.alpha = 0  // starts hidden, fades in on play

        // Voice label — shows current speaker
        voiceLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        voiceLabel.textAlignment = .center
        voiceLabel.textColor = voicePersonas[0].color
        voiceLabel.text = voicePersonas[0].label

        // Voice picker — 4 small buttons for F1, F2, M1, M2
        voicePickerStack.axis = .horizontal
        voicePickerStack.spacing = 8
        voicePickerStack.alignment = .center
        voicePickerStack.distribution = .fillEqually

        for (i, persona) in voicePersonas.enumerated() {
            let btn = UIButton(type: .system)
            btn.tag = i
            let shortLabel = String(persona.label.prefix(1)) + String(persona.label.last ?? " ")
            btn.setTitle(shortLabel, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = i == 0 ? persona.color : persona.color.withAlphaComponent(0.3)
            btn.layer.cornerRadius = 16
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            btn.addTarget(self, action: #selector(voicePickerTapped(_:)), for: .touchUpInside)
            voicePickerStack.addArrangedSubview(btn)
        }

        // Real voice picker row (recorded voices from Voice Library)
        realVoicePickerStack.axis = .horizontal
        realVoicePickerStack.spacing = 8
        realVoicePickerStack.alignment = .center
        realVoicePickerStack.distribution = .fillEqually
        realVoicePickerStack.isHidden = true  // shown after loading

        cardStack.addArrangedSubview(instructionLabel)
        cardStack.addArrangedSubview(speakerButton)
        cardStack.addArrangedSubview(voiceLabel)
        cardStack.addArrangedSubview(voicePickerStack)
        cardStack.addArrangedSubview(realVoicePickerStack)
        cardStack.addArrangedSubview(soundNameLabel)
        cardStack.addArrangedSubview(tapHintLabel)

        instructionCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 20),
            cardStack.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -16),
            cardStack.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(instructionCard)

        // Sound description (visible in learning mode)
        soundDescLabel.font = .systemFont(ofSize: 15, weight: .medium)
        soundDescLabel.textColor = .secondaryLabel
        soundDescLabel.textAlignment = .center
        soundDescLabel.numberOfLines = 0
        soundDescLabel.isHidden = true
        contentStack.addArrangedSubview(soundDescLabel)

        // Replay count
        replayCountLabel.font = .systemFont(ofSize: 13, weight: .medium)
        replayCountLabel.textColor = .tertiaryLabel
        replayCountLabel.textAlignment = .center
        replayCountLabel.isHidden = true
        contentStack.addArrangedSubview(replayCountLabel)

        // Learning mode buttons (no quiz, just listen & move on)
        replayButton.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        replayButton.isHidden = true
        contentStack.addArrangedSubview(replayButton)

        gotItButton.addTarget(self, action: #selector(gotItTapped), for: .touchUpInside)
        gotItButton.isHidden = true
        contentStack.addArrangedSubview(gotItButton)

        // Learning tip card
        buildLearningTipCard()
        learningTipCard.isHidden = true
        contentStack.addArrangedSubview(learningTipCard)

        // Choice buttons (quiz mode)
        choiceStack.axis = .vertical
        choiceStack.spacing = 10
        choiceStack.isHidden = learningMode
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

    // MARK: - Show Current Item

    private func showCurrentItem() {
        guard currentIndex < items.count else { finishSession(); return }

        let item = items[currentIndex]

        // Update level badge
        if learningMode {
            levelBadge.text = "  👂  Learning Mode  "
            levelBadge.backgroundColor = .lcGreen
        } else {
            levelBadge.text = "  \(currentLevel.emoji)  \(currentLevel.label)  "
        }

        // Progress
        progressLabel.text = "\(currentIndex + 1) of \(items.count)"
        let fraction = CGFloat(currentIndex) / CGFloat(items.count)
        progressBar.setProgress(fraction, animated: true)

        // Reset replay counter
        replayCount = 0
        replayCountLabel.text = ""

        // Clear old choices
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        choiceButtons.removeAll()
        feedbackLabel.isHidden = true
        nextButton.isHidden = true
        soundNameLabel.alpha = 0

        if learningMode {
            showLearningUI(item)
        } else {
            switch currentLevel {
            case .detection:
                showDetectionUI(item)
            case .discrimination:
                showDiscriminationUI(item)
            case .identification:
                showIdentificationUI(item)
            case .categorisation:
                showCategorisationUI(item)
            }
        }

        // Auto-play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playCurrentSound()
        }
    }

    // MARK: - Learning Mode

    private func showLearningUI(_ item: EnvironmentalSoundItem) {
        // Show everything upfront — no quiz
        instructionLabel.text = "Listen & Learn"

        // Show sound name immediately
        setSoundNameLabel(item)
        soundNameLabel.alpha = 1

        // Show description
        soundDescLabel.text = "\(item.description)\n\nTTS: \"\(item.speechDescription)\""
        soundDescLabel.isHidden = false

        // Show replay counter
        replayCountLabel.isHidden = false

        // Show learning mode buttons
        replayButton.isHidden = false
        gotItButton.isHidden = false
        learningTipCard.isHidden = false

        // Hide quiz UI
        choiceStack.isHidden = true
    }

    private func buildLearningTipCard() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false

        let bulb = UIImageView(image: UIImage(systemName: "brain.head.profile"))
        bulb.tintColor = .lcGreen
        bulb.contentMode = .scaleAspectFit
        bulb.widthAnchor.constraint(equalToConstant: 28).isActive = true
        bulb.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let tipText = UILabel()
        tipText.text = "Your brain is building new pathways. The static you hear IS the sound — your brain just hasn't learned to decode it yet. Listen to each sound 3+ times while reading its name. Over days and weeks, the static will start sounding like the real thing."
        tipText.font = .systemFont(ofSize: 13, weight: .medium)
        tipText.textColor = .secondaryLabel
        tipText.numberOfLines = 0

        stack.addArrangedSubview(bulb)
        stack.addArrangedSubview(tipText)

        learningTipCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: learningTipCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: learningTipCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: learningTipCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: learningTipCard.trailingAnchor, constant: -14),
        ])
    }

    @objc private func voicePickerTapped(_ sender: UIButton) {
        currentVoiceIndex = sender.tag
        selectedRealVoiceIndex = -1  // deselect real voice
        updateVoicePickerUI()
        playCurrentSound()
        lcHaptic(.light)
    }

    private func updateVoicePickerUI() {
        let persona = voicePersonas[currentVoiceIndex]

        if selectedRealVoiceIndex >= 0 {
            let person = recordedPeople[selectedRealVoiceIndex]
            voiceLabel.text = "🎙 \(person.name)"
            voiceLabel.textColor = colorForKey(person.color)
            // Dim TTS buttons
            for case let btn as UIButton in voicePickerStack.arrangedSubviews {
                btn.backgroundColor = voicePersonas[btn.tag].color.withAlphaComponent(0.15)
            }
        } else {
            voiceLabel.text = persona.label
            voiceLabel.textColor = persona.color
            for case let btn as UIButton in voicePickerStack.arrangedSubviews {
                let p = voicePersonas[btn.tag]
                btn.backgroundColor = btn.tag == currentVoiceIndex
                    ? p.color
                    : p.color.withAlphaComponent(0.3)
            }
        }

        // Highlight real voice buttons
        for case let btn as UIButton in realVoicePickerStack.arrangedSubviews {
            let idx = btn.tag - 100
            if idx >= 0, idx < recordedPeople.count {
                let c = colorForKey(recordedPeople[idx].color)
                btn.backgroundColor = idx == selectedRealVoiceIndex
                    ? c : c.withAlphaComponent(0.2)
            }
        }
    }

    // MARK: - Real Voice Picker

    private func buildRealVoicePicker() {
        realVoicePickerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !recordedPeople.isEmpty else {
            realVoicePickerStack.isHidden = true
            return
        }
        realVoicePickerStack.isHidden = false

        for (i, person) in recordedPeople.enumerated() {
            let btn = UIButton(type: .system)
            btn.tag = 100 + i  // offset to distinguish from TTS buttons
            let initial = String(person.name.prefix(2))
            btn.setTitle("🎙\(initial)", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
            btn.setTitleColor(.white, for: .normal)
            let c = colorForKey(person.color)
            btn.backgroundColor = c.withAlphaComponent(0.2)
            btn.layer.cornerRadius = 16
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            btn.addTarget(self, action: #selector(realVoiceTapped(_:)), for: .touchUpInside)
            realVoicePickerStack.addArrangedSubview(btn)
        }
    }

    @objc private func realVoiceTapped(_ sender: UIButton) {
        let idx = sender.tag - 100
        guard idx >= 0, idx < recordedPeople.count else { return }
        selectedRealVoiceIndex = idx
        updateVoicePickerUI()
        playCurrentSound()
        lcHaptic(.light)
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

    @objc private func replayTapped() {
        replayCount += 1
        // Auto-cycle through all voices: TTS personas first, then real voices
        if learningMode {
            let totalVoices = voicePersonas.count + recordedPeople.count
            let nextIdx = (replayCount) % totalVoices
            if nextIdx < voicePersonas.count {
                selectedRealVoiceIndex = -1
                currentVoiceIndex = nextIdx
            } else {
                selectedRealVoiceIndex = nextIdx - voicePersonas.count
            }
            updateVoicePickerUI()
        }
        let totalListens = replayCount + 1
        let voiceName: String
        if selectedRealVoiceIndex >= 0, selectedRealVoiceIndex < recordedPeople.count {
            voiceName = "🎙 \(recordedPeople[selectedRealVoiceIndex].name)"
        } else {
            voiceName = voicePersonas[currentVoiceIndex].label
        }
        replayCountLabel.text = "Listened \(totalListens) time\(totalListens > 1 ? "s" : "") — \(voiceName)"
        playCurrentSound()
        lcHaptic(.light)
    }

    @objc private func gotItTapped() {
        // Count as "correct" since it's learning mode
        correctCount += 1

        // Hide learning UI
        soundDescLabel.isHidden = true
        replayCountLabel.isHidden = true
        replayButton.isHidden = true
        gotItButton.isHidden = true
        learningTipCard.isHidden = true

        currentIndex += 1
        if currentIndex < items.count {
            showCurrentItem()
        } else {
            finishSession()
        }
    }

    // MARK: - Detection Level

    private func showDetectionUI(_ item: EnvironmentalSoundItem) {
        // Hide learning mode elements
        soundDescLabel.isHidden = true
        replayCountLabel.isHidden = true
        replayButton.isHidden = true
        gotItButton.isHidden = true
        learningTipCard.isHidden = true
        choiceStack.isHidden = false

        instructionLabel.text = "Did you hear a sound?"

        let yesBtn = makeChoiceButton(title: "Yes, I heard it!", tag: 1)
        let noBtn = makeChoiceButton(title: "I didn't hear anything", tag: 0)

        choiceStack.addArrangedSubview(yesBtn)
        choiceStack.addArrangedSubview(noBtn)
    }

    // MARK: - Discrimination Level

    private func showDiscriminationUI(_ item: EnvironmentalSoundItem) {
        instructionLabel.text = "Are these two sounds the same or different?\n(Listen carefully — it will play twice)"

        // Pick a second sound — 50% chance same, 50% different
        discriminationIsSame = Bool.random()
        if discriminationIsSame {
            discriminationPair = (item, item)
        } else {
            let other = items.filter { $0.id != item.id }.randomElement() ?? item
            discriminationPair = (item, other)
        }

        let sameBtn = makeChoiceButton(title: "Same Sound", tag: 1)
        let diffBtn = makeChoiceButton(title: "Different Sounds", tag: 0)

        choiceStack.addArrangedSubview(sameBtn)
        choiceStack.addArrangedSubview(diffBtn)
    }

    // MARK: - Identification Level

    private func showIdentificationUI(_ item: EnvironmentalSoundItem) {
        instructionLabel.text = "Which sound did you hear?"

        // Correct answer + 3 distractors
        var choices = [item]
        let distractors = items.filter { $0.id != item.id }.shuffled().prefix(3)
        choices.append(contentsOf: distractors)
        choices.shuffle()

        for (i, choice) in choices.enumerated() {
            let icon = choice.environment.icon
            let btn = makeChoiceButton(
                title: "\(choice.name)",
                subtitle: choice.description,
                systemIcon: icon,
                tag: choice.id == item.id ? 1 : 0
            )
            btn.accessibilityIdentifier = choice.id
            choiceStack.addArrangedSubview(btn)
        }
    }

    // MARK: - Categorisation Level

    private func showCategorisationUI(_ item: EnvironmentalSoundItem) {
        instructionLabel.text = "What type of sound was that?"

        // Show environment categories as choices
        var categories = [item.environment]
        let otherCats = SoundEnvironment.allCases.filter { $0 != item.environment }.shuffled().prefix(3)
        categories.append(contentsOf: otherCats)
        categories.shuffle()

        for cat in categories {
            let btn = makeChoiceButton(
                title: cat.label,
                subtitle: nil,
                systemIcon: cat.icon,
                tag: cat == item.environment ? 1 : 0
            )
            choiceStack.addArrangedSubview(btn)
        }
    }

    // MARK: - Play Sound

    @objc private func playCurrentSound() {
        guard currentIndex < items.count else { return }

        let item = items[currentIndex]
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()

        if currentLevel == .discrimination, let pair = discriminationPair {
            setSoundNameLabel(pair.0)
            UIView.animate(withDuration: 0.25) { self.soundNameLabel.alpha = 1 }
            playSound(pair.0) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.setSoundNameLabel(pair.1)
                    self.playSound(pair.1, completion: nil)
                }
            }
        } else {
            setSoundNameLabel(item)
            UIView.animate(withDuration: 0.25) { self.soundNameLabel.alpha = 1 }
            playSound(item, completion: nil)
        }

        // Animate speaker pulse
        UIView.animate(withDuration: 0.1) {
            self.speakerButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
        UIView.animate(withDuration: 0.1, delay: 0.25) {
            self.speakerButton.transform = .identity
        }
    }

    /// Unified play: uses recorded voice if available for selected person, else TTS
    private func playSound(_ item: EnvironmentalSoundItem, completion: (() -> Void)?) {
        if selectedRealVoiceIndex >= 0,
           selectedRealVoiceIndex < recordedPeople.count {
            let person = recordedPeople[selectedRealVoiceIndex]
            // Try to find a clip for this person — any clip works since
            // the point is hearing their familiar voice, not a perfect match
            if let clips = recordedClips[person.id],
               let anyClip = clips.values.flatMap({ $0 }).randomElement() {
                let url = anyClip.fileURL
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        audioPlayer = try AVAudioPlayer(contentsOf: url)
                        audioPlayer?.play()
                        if let completion = completion {
                            let dur = audioPlayer?.duration ?? 2.0
                            DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.3) { completion() }
                        }
                        return
                    } catch { }
                }
            }
        }
        // Fallback to TTS
        speakSound(item, completion: completion)
    }

    /// Build an attributed string with the environment SF Symbol + sound name
    private func setSoundNameLabel(_ item: EnvironmentalSoundItem) {
        let attachment = NSTextAttachment()
        let symbolCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        attachment.image = UIImage(systemName: item.environment.icon, withConfiguration: symbolCfg)?
            .withTintColor(.lcTeal, renderingMode: .alwaysOriginal)

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "  \(item.name)"))
        soundNameLabel.attributedText = result
    }

    private func speakSound(_ item: EnvironmentalSoundItem, completion: (() -> Void)?) {
        let persona = voicePersonas[currentVoiceIndex]

        let utterance = AVSpeechUtterance(string: item.speechDescription)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * persona.rate
        utterance.volume = 1.0
        utterance.pitchMultiplier = persona.pitchMultiplier

        // Try to use the persona's specific voice; fall back to en-US
        if let voice = AVSpeechSynthesisVoice(identifier: persona.voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            // Still apply pitch to differentiate
            utterance.pitchMultiplier = persona.pitchMultiplier
        }

        synthesizer.speak(utterance)

        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { completion() }
        }
    }

    // MARK: - Choice Handling

    @objc private func choiceTapped(_ sender: UIButton) {
        let isCorrect: Bool

        switch currentLevel {
        case .detection:
            // "Yes" (tag=1) is always correct since we always play a sound
            isCorrect = sender.tag == 1
        case .discrimination:
            // tag=1 means "Same", tag=0 means "Different"
            let userSaidSame = sender.tag == 1
            isCorrect = userSaidSame == discriminationIsSame
        case .identification, .categorisation:
            isCorrect = sender.tag == 1
        }

        // Disable all buttons
        choiceButtons.forEach { $0.isEnabled = false }

        if isCorrect {
            correctCount += 1
            sender.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.15)
            sender.layer.borderColor = UIColor.lcGreen.cgColor
            feedbackLabel.text = "Correct!"
            feedbackLabel.textColor = .lcGreen
            lcHapticSuccess()
        } else {
            sender.backgroundColor = UIColor.lcRed.withAlphaComponent(0.15)
            sender.layer.borderColor = UIColor.lcRed.cgColor

            let item = items[currentIndex]
            switch currentLevel {
            case .detection:
                feedbackLabel.text = "There was a sound! It was: \(item.name)"
            case .discrimination:
                feedbackLabel.text = discriminationIsSame
                    ? "They were the same sound: \(item.name)"
                    : "They were different sounds!"
            case .identification:
                feedbackLabel.text = "It was: \(item.name)\n\(item.description)"
            case .categorisation:
                feedbackLabel.text = "It was a \(item.environment.label) sound: \(item.name)"
            }
            feedbackLabel.textColor = .lcRed

            // Highlight correct button
            if currentLevel == .identification || currentLevel == .categorisation {
                choiceButtons.filter { $0.tag == 1 }.first?.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.15)
                choiceButtons.filter { $0.tag == 1 }.first?.layer.borderColor = UIColor.lcGreen.cgColor
            }

            lcHaptic(.heavy)
        }

        feedbackLabel.isHidden = false

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

        // Persist session & per-sound progress
        Task {
            let envName = environment?.rawValue ?? "mixed"
            let session = EnvironmentalSoundSession(
                id: 0, environment: envName,
                listeningLevel: currentLevel,
                startedAt: sessionStartedAt, completedAt: Date(),
                totalItems: items.count, correctItems: correctCount,
                daysPostActivation: 0)
            _ = try? await service.saveSession(session)

            // Update progress for each sound practised
            for item in items {
                _ = try? await service.updateProgress(
                    soundId: item.id, environment: item.environment.rawValue,
                    level: currentLevel, correct: 1, total: 1)
            }
        }

        progressBar.setProgress(1.0, animated: true)

        instructionCard.isHidden = true
        choiceStack.isHidden = true
        feedbackLabel.isHidden = true
        nextButton.isHidden = true
        soundDescLabel.isHidden = true
        replayCountLabel.isHidden = true
        replayButton.isHidden = true
        gotItButton.isHidden = true
        learningTipCard.isHidden = true

        resultsCard.isHidden = false
        resultsCard.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.font = .systemFont(ofSize: 48)

        let titleLbl = UILabel()
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)

        if learningMode {
            emoji.text = "🧠"
            titleLbl.text = "Session Complete!"
        } else {
            emoji.text = accuracy >= 80 ? "🌟" : accuracy >= 50 ? "👏" : "💪"
            titleLbl.text = "\(currentLevel.label) Complete!"
        }

        let scoreLbl = UILabel()
        scoreLbl.font = .systemFont(ofSize: 48, weight: .heavy)

        let accLbl = UILabel()
        accLbl.font = .systemFont(ofSize: 16, weight: .medium)
        accLbl.textColor = .secondaryLabel

        let tipLbl = UILabel()
        tipLbl.numberOfLines = 0
        tipLbl.textAlignment = .center
        tipLbl.font = .systemFont(ofSize: 14, weight: .medium)
        tipLbl.textColor = .secondaryLabel

        if learningMode {
            scoreLbl.text = "\(items.count) sounds"
            scoreLbl.textColor = .lcGreen
            accLbl.text = "You listened to \(items.count) sounds this session"

            tipLbl.text = "Every time you listen, your brain gets a little better at decoding the electrical signals. The static WILL start making sense — it takes most CI users 2-4 weeks. Come back tomorrow and listen again!"
        } else {
            scoreLbl.text = "\(correctCount) / \(items.count)"
            scoreLbl.textColor = accuracy >= 80 ? .lcGreen : accuracy >= 50 ? .lcOrange : .lcRed
            accLbl.text = String(format: "%.0f%% accuracy", accuracy)

            if accuracy >= 80 && currentLevel < .categorisation {
                let nextLevelName = EnvironmentalListeningLevel(rawValue: currentLevel.rawValue + 1)?.label ?? "next"
                tipLbl.text = "Great progress! You're ready for \(nextLevelName) level. Your brain is adapting well to your CI!"
            } else if accuracy >= 80 {
                tipLbl.text = "Excellent! You've mastered environmental sounds at this level. Your brain is learning fast!"
            } else {
                tipLbl.text = "Keep practising daily — your brain needs time to learn these new electrical patterns. Each session builds stronger neural connections!"
            }
        }

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let retryBtn = LCButton(title: learningMode ? "Listen Again" : "Practice Again", color: .lcTeal)
        retryBtn.addTarget(self, action: #selector(retrySession), for: .touchUpInside)
        buttonRow.addArrangedSubview(retryBtn)

        if !learningMode && accuracy >= 80 && currentLevel < .categorisation {
            let advBtn = LCButton(title: "Next Level", color: .lcGreen)
            advBtn.addTarget(self, action: #selector(advanceLevel), for: .touchUpInside)
            buttonRow.addArrangedSubview(advBtn)
        }

        stack.addArrangedSubview(emoji)
        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(scoreLbl)
        stack.addArrangedSubview(accLbl)
        stack.addArrangedSubview(tipLbl)
        stack.addArrangedSubview(buttonRow)

        resultsCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -20),
        ])
    }

    @objc private func retrySession() {
        sessionStartedAt = Date()
        resultsCard.isHidden = true
        instructionCard.isHidden = false
        choiceStack.isHidden = false
        loadItems()
    }

    @objc private func advanceLevel() {
        sessionStartedAt = Date()
        if let next = EnvironmentalListeningLevel(rawValue: currentLevel.rawValue + 1) {
            currentLevel = next
        }
        resultsCard.isHidden = true
        instructionCard.isHidden = false
        choiceStack.isHidden = false
        loadItems()
    }

    // MARK: - Choice Button Builder

    private func makeChoiceButton(title: String, subtitle: String? = nil,
                                   systemIcon: String? = nil, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag
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

        if let icon = systemIcon {
            let iconView = UIImageView(image: UIImage(systemName: icon))
            iconView.tintColor = .lcTeal
            iconView.contentMode = .scaleAspectFit
            iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
            hStack.addArrangedSubview(iconView)
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLbl.textColor = .label
        textStack.addArrangedSubview(titleLbl)

        if let sub = subtitle {
            let subLbl = UILabel()
            subLbl.text = sub
            subLbl.font = UIFont.lcCaption()
            subLbl.textColor = .secondaryLabel
            subLbl.numberOfLines = 2
            textStack.addArrangedSubview(subLbl)
        }

        hStack.addArrangedSubview(textStack)

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
