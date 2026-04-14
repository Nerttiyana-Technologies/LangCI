// AudiologistTestViewController.swift
// LangCI — Audiologist Mode Sound Detection Test
//
// Replicates the paper tracking grid digitally:
//   • Sound chips + tappable grid — audiologist can pick any cell
//   • Play sound → mark ✓/✗/~/– → cell fills, auto-advances
//   • Audiologist can test in ANY order (random or sequential)
//   • Long-press a sound chip to edit its TTS pronunciation
//   • 9 trials per sound (configurable)

import UIKit
import AVFoundation

final class AudiologistTestViewController: UIViewController {

    // MARK: - Services

    private let service = ServiceLocator.shared.soundDetectionService!

    // MARK: - Prefilled patient info (set before pushing)

    var prefilledPatient: Patient?
    var prefilledTesterName: String?
    var prefilledTestedAt: Date = Date()

    // MARK: - State

    private var session: DetectionTestSession!
    private var sounds: [TestSound] = []
    private var trialsPerSound = 9
    /// Grid data: [soundIndex][trialIndex] = result (nil = not tested)
    private var grid: [[TrialResult?]] = []
    private var currentSoundIndex = 0
    /// Which trial row is selected for the current sound (1-based)
    private var selectedTrialForSound: [Int] = []

    /// For playing recorded audio files
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Patient info UI

    private let patientCard = LCCard()
    private let patientNameLabel = UILabel()
    private let sessionDateLabel = UILabel()
    private let editPatientButton = UIButton(type: .system)

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Sound selector row
    private let soundScrollView = UIScrollView()
    private let soundRow = UIStackView()
    private var soundChips: [UIButton] = []

    // Voice accent picker
    private let accentScrollView = UIScrollView()
    private let accentRow = UIStackView()
    private var accentChips: [UIButton] = []

    // Play button + pronunciation info
    private let playButton = LCButton(title: "▶ Play Sound", color: .lcTeal)
    private let pronunciationLabel = UILabel()
    private let editPronunciationButton = UIButton(type: .system)

    // Status
    private let statusLabel = UILabel()
    private let trialLabel = UILabel()

    // Mark buttons — icon-only for quick audiologist tapping
    private let correctButton = UIButton(type: .system)
    private let heardWrongButton = UIButton(type: .system)
    private let wrongButton = UIButton(type: .system)
    private let noResponseButton = UIButton(type: .system)

    // Grid display
    private let gridScrollView = UIScrollView()
    private let gridContainer = UIView()
    /// gridButtons[row][col] — tappable grid cells
    private var gridButtons: [[UIButton]] = []

    // Notes
    private let notesField = UITextField()
    private let saveButton = LCButton(title: "Save Session", color: .lcTeal)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Audiologist Test"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        loadSoundsAndStart()
    }

    private func loadSoundsAndStart() {
        Task {
            sounds = (try? await service.getActiveSounds()) ?? []
            guard !sounds.isEmpty else {
                await MainActor.run {
                    let alert = UIAlertController(title: "No Sounds", message: "Add sounds in Manage Sounds first.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.navigationController?.popViewController(animated: true) })
                    self.present(alert, animated: true)
                }
                return
            }

            session = try? await service.createSession(
                mode: .audiologist, trialsPerSound: trialsPerSound,
                distanceCm: 100,
                patientId: prefilledPatient?.id,
                patientName: prefilledPatient?.name,
                testerName: prefilledTesterName,
                testedAt: prefilledTestedAt)

            // Init grid + per-sound trial selection (start at row 1)
            grid = Array(repeating: Array(repeating: nil, count: trialsPerSound), count: sounds.count)
            selectedTrialForSound = Array(repeating: 1, count: sounds.count)

            await MainActor.run {
                self.buildUI()
                self.updateState()
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
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 40, trailing: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        buildPatientCard()
        buildAccentPicker()
        buildSoundChips()
        buildControls()
        buildGrid()
        buildSaveArea()
    }

    // MARK: - Patient Info Card

    private func buildPatientCard() {
        patientCard.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = UILabel()
        headerLabel.text = "Patient"
        headerLabel.font = UIFont.lcCaption()
        headerLabel.textColor = .secondaryLabel

        patientNameLabel.font = UIFont.lcBodyBold()
        patientNameLabel.textColor = .label
        patientNameLabel.numberOfLines = 0

        sessionDateLabel.font = UIFont.lcCaption()
        sessionDateLabel.textColor = .secondaryLabel
        sessionDateLabel.numberOfLines = 0

        let editCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        editPatientButton.setImage(UIImage(systemName: "pencil.circle", withConfiguration: editCfg), for: .normal)
        editPatientButton.tintColor = .lcTeal
        editPatientButton.addTarget(self, action: #selector(editPatientTapped), for: .touchUpInside)
        editPatientButton.translatesAutoresizingMaskIntoConstraints = false
        editPatientButton.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let textStack = UIStackView(arrangedSubviews: [headerLabel, patientNameLabel, sessionDateLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [textStack, editPatientButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        patientCard.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: patientCard.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: patientCard.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: patientCard.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: patientCard.trailingAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(patientCard)
        updatePatientCard()
    }

    private func updatePatientCard() {
        patientNameLabel.text = session.patientName?.isEmpty == false
            ? session.patientName
            : "No patient selected"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var subtitle = formatter.string(from: session.testedAt)

        // Show identifier if we have a linked patient
        if let patient = prefilledPatient, let id = patient.identifier, !id.isEmpty {
            subtitle = "\(id)  •  \(subtitle)"
        }

        if let tester = session.testerName, !tester.isEmpty {
            subtitle += "  •  \(tester)"
        }
        sessionDateLabel.text = subtitle
    }

    @objc private func editPatientTapped() {
        lcHaptic(.light)

        // Simple inline editor for tester name + backdated time.
        // Patient identity stays fixed during a running session — to switch
        // patients the audiologist must start a new session.
        let alert = UIAlertController(
            title: "Edit Session Info",
            message: "Update tester name or adjust the recorded date/time for this session.",
            preferredStyle: .alert)

        alert.addTextField { tf in
            tf.text = self.session.testerName
            tf.placeholder = "Tester / Audiologist"
            tf.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Change Date…", style: .default) { [weak self] _ in
            self?.presentDatePicker()
        })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let tester = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces)
            self.session.testerName = tester?.isEmpty == true ? nil : tester
            Task {
                try? await self.service.updateSessionInfo(
                    id: self.session.id,
                    testedAt: self.session.testedAt,
                    patientId: self.session.patientId,
                    patientName: self.session.patientName,
                    testerName: self.session.testerName)
                await MainActor.run { self.updatePatientCard() }
            }
        })
        present(alert, animated: true)
    }

    private func presentDatePicker() {
        let sheet = UIAlertController(title: "Test Date & Time", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.date = session.testedAt
        picker.maximumDate = Date()
        picker.translatesAutoresizingMaskIntoConstraints = false
        sheet.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: sheet.view.centerXAnchor),
            picker.topAnchor.constraint(equalTo: sheet.view.topAnchor, constant: 50),
        ])
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.session.testedAt = picker.date
            Task {
                try? await self.service.updateSessionInfo(
                    id: self.session.id,
                    testedAt: self.session.testedAt,
                    patientId: self.session.patientId,
                    patientName: self.session.patientName,
                    testerName: self.session.testerName)
                await MainActor.run { self.updatePatientCard() }
            }
        })
        // iPad compatibility
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = editPatientButton
            pop.sourceRect = editPatientButton.bounds
        }
        present(sheet, animated: true)
    }

    // MARK: - Accent Picker

    private func buildAccentPicker() {
        let label = UILabel()
        label.text = "Voice Accent"
        label.font = UIFont.lcCaption()
        label.textColor = .secondaryLabel
        contentStack.addArrangedSubview(label)

        accentScrollView.showsHorizontalScrollIndicator = false
        accentScrollView.translatesAutoresizingMaskIntoConstraints = false

        accentRow.axis = .horizontal
        accentRow.spacing = 8
        accentRow.translatesAutoresizingMaskIntoConstraints = false
        accentScrollView.addSubview(accentRow)

        NSLayoutConstraint.activate([
            accentRow.topAnchor.constraint(equalTo: accentScrollView.topAnchor, constant: 2),
            accentRow.bottomAnchor.constraint(equalTo: accentScrollView.bottomAnchor, constant: -2),
            accentRow.leadingAnchor.constraint(equalTo: accentScrollView.leadingAnchor, constant: 2),
            accentRow.trailingAnchor.constraint(equalTo: accentScrollView.trailingAnchor, constant: -2),
            accentScrollView.heightAnchor.constraint(equalToConstant: 44),
        ])

        let accents: [MultiVoiceTTS.VoiceAccent] = [.all, .india, .us, .uk, .au]
        for (i, accent) in accents.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle("\(accent.icon) \(accent.rawValue)", for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            chip.layer.cornerRadius = 16
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            chip.tag = i
            chip.addTarget(self, action: #selector(accentChipTapped(_:)), for: .touchUpInside)

            if accent == .all {
                chip.backgroundColor = .lcTeal
                chip.tintColor = .white
            } else {
                chip.backgroundColor = .secondarySystemFill
                chip.tintColor = .label
            }

            accentRow.addArrangedSubview(chip)
            accentChips.append(chip)
        }

        contentStack.addArrangedSubview(accentScrollView)
    }

    private let accentOptions: [MultiVoiceTTS.VoiceAccent] = [.all, .india, .us, .uk, .au]

    @objc private func accentChipTapped(_ sender: UIButton) {
        lcHaptic(.light)
        MultiVoiceTTS.shared.selectAccent(accentOptions[sender.tag])
        for (i, chip) in accentChips.enumerated() {
            chip.backgroundColor = i == sender.tag ? .lcTeal : .secondarySystemFill
            chip.tintColor = i == sender.tag ? .white : .label
        }
    }

    // MARK: - Sound Chips (long-press to edit pronunciation)

    private func buildSoundChips() {
        soundScrollView.showsHorizontalScrollIndicator = false
        soundScrollView.translatesAutoresizingMaskIntoConstraints = false

        soundRow.axis = .horizontal
        soundRow.spacing = 8
        soundRow.translatesAutoresizingMaskIntoConstraints = false
        soundScrollView.addSubview(soundRow)

        NSLayoutConstraint.activate([
            soundRow.topAnchor.constraint(equalTo: soundScrollView.topAnchor, constant: 4),
            soundRow.bottomAnchor.constraint(equalTo: soundScrollView.bottomAnchor, constant: -4),
            soundRow.leadingAnchor.constraint(equalTo: soundScrollView.leadingAnchor, constant: 4),
            soundRow.trailingAnchor.constraint(equalTo: soundScrollView.trailingAnchor, constant: -4),
            soundScrollView.heightAnchor.constraint(equalToConstant: 52),
        ])

        for (i, sound) in sounds.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle(sound.symbol, for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            chip.backgroundColor = .secondarySystemFill
            chip.tintColor = .label
            chip.layer.cornerRadius = 20
            chip.tag = i
            chip.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                chip.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
                chip.heightAnchor.constraint(equalToConstant: 44),
            ])
            chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            chip.addTarget(self, action: #selector(soundChipTapped(_:)), for: .touchUpInside)

            // Long-press to edit pronunciation
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(soundChipLongPressed(_:)))
            chip.addGestureRecognizer(longPress)

            soundRow.addArrangedSubview(chip)
            soundChips.append(chip)
        }

        contentStack.addArrangedSubview(soundScrollView)
    }

    // MARK: - Controls (play + pronunciation + mark buttons)

    private func buildControls() {
        statusLabel.font = UIFont.lcBodyBold()
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center

        trialLabel.font = UIFont.lcCaption()
        trialLabel.textColor = .secondaryLabel
        trialLabel.textAlignment = .center

        // Pronunciation info row: "Says: father" + [Edit] button
        pronunciationLabel.font = UIFont.lcCaption()
        pronunciationLabel.textColor = .lcBlue
        pronunciationLabel.textAlignment = .center

        let editCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        editPronunciationButton.setImage(UIImage(systemName: "pencil.circle", withConfiguration: editCfg), for: .normal)
        editPronunciationButton.setTitle(" Edit", for: .normal)
        editPronunciationButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        editPronunciationButton.tintColor = .lcTeal
        editPronunciationButton.addTarget(self, action: #selector(editPronunciationTapped), for: .touchUpInside)

        let pronunciationRow = UIStackView(arrangedSubviews: [pronunciationLabel, editPronunciationButton])
        pronunciationRow.axis = .horizontal
        pronunciationRow.spacing = 8
        pronunciationRow.alignment = .center
        // Center the row
        let pronunciationWrapper = UIStackView(arrangedSubviews: [UIView(), pronunciationRow, UIView()])
        pronunciationWrapper.axis = .horizontal
        pronunciationWrapper.distribution = .equalCentering

        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        // Icon-only mark buttons
        configureMarkButton(correctButton, icon: "checkmark.circle.fill", color: .lcGreen)
        configureMarkButton(heardWrongButton, icon: "ear.trianglebadge.exclamationmark", color: .lcAmber)
        configureMarkButton(wrongButton, icon: "xmark.circle.fill", color: .lcRed)
        configureMarkButton(noResponseButton, icon: "minus.circle.fill", color: .systemGray)

        correctButton.addTarget(self, action: #selector(markCorrect), for: .touchUpInside)
        heardWrongButton.addTarget(self, action: #selector(markDetected), for: .touchUpInside)
        wrongButton.addTarget(self, action: #selector(markWrong), for: .touchUpInside)
        noResponseButton.addTarget(self, action: #selector(markNoResponse), for: .touchUpInside)

        let markRow = UIStackView(arrangedSubviews: [correctButton, heardWrongButton, wrongButton, noResponseButton])
        markRow.axis = .horizontal
        markRow.spacing = 12
        markRow.distribution = .fillEqually

        let controlCard = LCCard()
        let stack = UIStackView(arrangedSubviews: [statusLabel, trialLabel, pronunciationWrapper, playButton, markRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        controlCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: controlCard.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: controlCard.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(controlCard)
    }

    private func configureMarkButton(_ button: UIButton, icon: String, color: UIColor) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    // MARK: - Grid (tappable cells)

    private func buildGrid() {
        let headerLabel = UILabel()
        headerLabel.text = "Results Grid  (tap any cell to select)"
        headerLabel.font = UIFont.lcCaption()
        headerLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(headerLabel)

        gridScrollView.showsHorizontalScrollIndicator = true
        gridScrollView.translatesAutoresizingMaskIntoConstraints = false

        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        gridScrollView.addSubview(gridContainer)

        let cellSize: CGFloat = 40
        let headerWidth: CGFloat = 50
        let gridWidth = headerWidth + CGFloat(sounds.count) * cellSize
        let gridHeight = CGFloat(trialsPerSound + 1) * cellSize

        NSLayoutConstraint.activate([
            gridContainer.topAnchor.constraint(equalTo: gridScrollView.topAnchor),
            gridContainer.leadingAnchor.constraint(equalTo: gridScrollView.leadingAnchor),
            gridContainer.trailingAnchor.constraint(equalTo: gridScrollView.trailingAnchor),
            gridContainer.bottomAnchor.constraint(equalTo: gridScrollView.bottomAnchor),
            gridContainer.widthAnchor.constraint(equalToConstant: gridWidth),
            gridContainer.heightAnchor.constraint(equalToConstant: gridHeight),
            gridScrollView.heightAnchor.constraint(equalToConstant: gridHeight + 8),
        ])

        // Header row — sound symbols (tappable to select column)
        for (col, sound) in sounds.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(sound.symbol, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            btn.tintColor = .label
            btn.tag = col  // encode: just col
            btn.frame = CGRect(x: headerWidth + CGFloat(col) * cellSize, y: 0, width: cellSize, height: cellSize)
            btn.addTarget(self, action: #selector(gridHeaderTapped(_:)), for: .touchUpInside)
            gridContainer.addSubview(btn)
        }

        // Row labels + tappable cells
        gridButtons = []
        for row in 0..<trialsPerSound {
            let rowLabel = UILabel()
            rowLabel.text = "\(row + 1)"
            rowLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            rowLabel.textAlignment = .center
            rowLabel.textColor = .secondaryLabel
            rowLabel.frame = CGRect(x: 0, y: CGFloat(row + 1) * cellSize, width: headerWidth, height: cellSize)
            gridContainer.addSubview(rowLabel)

            var rowButtons: [UIButton] = []
            for col in 0..<sounds.count {
                let btn = UIButton(type: .system)
                btn.setTitle("—", for: .normal)
                btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
                btn.tintColor = .tertiaryLabel
                btn.backgroundColor = .secondarySystemFill
                btn.layer.cornerRadius = 4
                btn.clipsToBounds = true
                // Encode row + col in tag: row * 1000 + col
                btn.tag = row * 1000 + col
                btn.frame = CGRect(
                    x: headerWidth + CGFloat(col) * cellSize + 2,
                    y: CGFloat(row + 1) * cellSize + 2,
                    width: cellSize - 4,
                    height: cellSize - 4)
                btn.addTarget(self, action: #selector(gridCellTapped(_:)), for: .touchUpInside)
                gridContainer.addSubview(btn)
                rowButtons.append(btn)
            }
            gridButtons.append(rowButtons)
        }

        let gridCard = LCCard()
        gridCard.addSubview(gridScrollView)
        gridScrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gridScrollView.topAnchor.constraint(equalTo: gridCard.topAnchor, constant: 8),
            gridScrollView.bottomAnchor.constraint(equalTo: gridCard.bottomAnchor, constant: -8),
            gridScrollView.leadingAnchor.constraint(equalTo: gridCard.leadingAnchor, constant: 8),
            gridScrollView.trailingAnchor.constraint(equalTo: gridCard.trailingAnchor, constant: -8),
        ])
        contentStack.addArrangedSubview(gridCard)
    }

    private func buildSaveArea() {
        notesField.placeholder = "Session notes (optional)"
        notesField.font = UIFont.lcBody()
        notesField.borderStyle = .roundedRect
        notesField.translatesAutoresizingMaskIntoConstraints = false
        notesField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(notesField)
        contentStack.addArrangedSubview(saveButton)
    }

    // MARK: - State Management

    /// The currently selected trial number for the current sound (1-based)
    private var currentTrialNumber: Int {
        guard currentSoundIndex < selectedTrialForSound.count else { return 1 }
        return selectedTrialForSound[currentSoundIndex]
    }

    private func updateState() {
        guard !sounds.isEmpty else { return }
        let sound = sounds[currentSoundIndex]
        let trial = currentTrialNumber
        statusLabel.text = "Sound: \(sound.symbol)"

        if trial > trialsPerSound {
            trialLabel.text = "All \(trialsPerSound) trials done for \(sound.symbol)"
        } else {
            trialLabel.text = "Trial \(trial) of \(trialsPerSound)"
        }

        // Show pronunciation source
        if sound.audioFileName != nil {
            pronunciationLabel.text = "🎙 Recorded audio"
        } else {
            pronunciationLabel.text = "TTS says: \"\(sound.speakableText)\""
        }

        // Highlight current sound chip
        for (i, chip) in soundChips.enumerated() {
            chip.backgroundColor = i == currentSoundIndex ? .lcTeal : .secondarySystemFill
            chip.tintColor = i == currentSoundIndex ? .white : .label
        }

        highlightCurrentCell()
    }

    private func highlightCurrentCell() {
        // Reset all cells
        for row in 0..<trialsPerSound {
            for col in 0..<sounds.count {
                let btn = gridButtons[row][col]
                btn.layer.borderWidth = 0
                btn.layer.borderColor = nil

                let result = grid[col][row]
                switch result {
                case .correct:
                    btn.backgroundColor = .lcGreen.withAlphaComponent(0.2)
                case .wrong:
                    btn.backgroundColor = .lcRed.withAlphaComponent(0.2)
                case .detected:
                    btn.backgroundColor = .lcAmber.withAlphaComponent(0.2)
                case .notTested:
                    btn.backgroundColor = .systemGray.withAlphaComponent(0.15)
                case nil:
                    btn.backgroundColor = .secondarySystemFill
                }
            }
        }

        // Highlight selected cell
        if currentTrialNumber <= trialsPerSound {
            let row = currentTrialNumber - 1
            let col = currentSoundIndex
            gridButtons[row][col].backgroundColor = .lcBlue.withAlphaComponent(0.3)
            gridButtons[row][col].layer.borderWidth = 2
            gridButtons[row][col].layer.borderColor = UIColor.lcBlue.cgColor
        }
    }

    private func updateGridCell(col: Int, row: Int, result: TrialResult) {
        grid[col][row] = result
        let btn = gridButtons[row][col]
        btn.layer.borderWidth = 0

        switch result {
        case .correct:
            btn.setTitle("✓", for: .normal)
            btn.tintColor = .lcGreen
            btn.backgroundColor = .lcGreen.withAlphaComponent(0.2)
        case .wrong:
            btn.setTitle("✗", for: .normal)
            btn.tintColor = .lcRed
            btn.backgroundColor = .lcRed.withAlphaComponent(0.2)
        case .detected:
            btn.setTitle("~", for: .normal)
            btn.tintColor = .lcAmber
            btn.backgroundColor = .lcAmber.withAlphaComponent(0.2)
        case .notTested:
            btn.setTitle("–", for: .normal)
            btn.tintColor = .systemGray
            btn.backgroundColor = .systemGray.withAlphaComponent(0.15)
        }
    }

    // MARK: - Grid Tapping

    @objc private func gridCellTapped(_ sender: UIButton) {
        let row = sender.tag / 1000
        let col = sender.tag % 1000
        guard col < sounds.count, row < trialsPerSound else { return }
        lcHaptic(.light)

        currentSoundIndex = col
        selectedTrialForSound[col] = row + 1   // 1-based
        updateState()
    }

    @objc private func gridHeaderTapped(_ sender: UIButton) {
        let col = sender.tag
        guard col < sounds.count else { return }
        lcHaptic(.light)

        currentSoundIndex = col
        // Jump to the first empty trial for this sound
        let firstEmpty = (0..<trialsPerSound).first(where: { grid[col][$0] == nil }) ?? trialsPerSound
        selectedTrialForSound[col] = firstEmpty + 1
        updateState()
    }

    // MARK: - Sound Chip Actions

    @objc private func soundChipTapped(_ sender: UIButton) {
        lcHaptic(.light)
        currentSoundIndex = sender.tag
        // Jump to first empty trial for this sound
        let firstEmpty = (0..<trialsPerSound).first(where: { grid[sender.tag][$0] == nil }) ?? trialsPerSound
        selectedTrialForSound[sender.tag] = firstEmpty + 1
        updateState()
    }

    @objc private func soundChipLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let btn = gesture.view as? UIButton else { return }
        lcHaptic(.medium)
        presentRecorder(for: btn.tag)
    }

    // MARK: - Edit Pronunciation (Record)

    @objc private func editPronunciationTapped() {
        presentRecorder(for: currentSoundIndex)
    }

    private func presentRecorder(for soundIndex: Int) {
        guard soundIndex < sounds.count else { return }

        let recorder = SoundRecorderViewController()
        recorder.sound = sounds[soundIndex]
        recorder.onSaved = { [weak self] fileName in
            guard let self = self else { return }
            self.sounds[soundIndex].audioFileName = fileName
            Task {
                try? await self.service.updateSound(self.sounds[soundIndex])
                await MainActor.run { self.updateState() }
            }
        }

        if let sheet = recorder.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(recorder, animated: true)
    }

    // MARK: - Play & Mark

    @objc private func playTapped() {
        guard currentSoundIndex < sounds.count else { return }
        let trial = currentTrialNumber
        guard trial <= trialsPerSound else {
            lcHaptic(.heavy)
            return
        }
        lcHaptic(.light)
        let sound = sounds[currentSoundIndex]

        // 1. Try recorded audio file first
        if let fileName = sound.audioFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    trialLabel.text = "Trial \(trial) of \(trialsPerSound) — 🎙 Recording"
                    return
                } catch { }
            }
        }

        // 2. Fall back to TTS
        let profile = MultiVoiceTTS.shared.speakEnglishOnly(sound.speakableText)
        trialLabel.text = "Trial \(trial) of \(trialsPerSound) — \(profile.name)"
    }

    @objc private func markCorrect() {
        recordResult(.correct, isDetected: true, isCorrect: true)
    }

    @objc private func markDetected() {
        recordResult(.detected, isDetected: true, isCorrect: false)
    }

    @objc private func markWrong() {
        recordResult(.wrong, isDetected: false, isCorrect: false)
    }

    @objc private func markNoResponse() {
        recordResult(.notTested, isDetected: false, isCorrect: false)
    }

    private func recordResult(_ result: TrialResult, isDetected: Bool, isCorrect: Bool) {
        let trial = currentTrialNumber
        guard trial <= trialsPerSound else { return }
        lcHaptic(isCorrect ? .light : .medium)

        let row = trial - 1
        updateGridCell(col: currentSoundIndex, row: row, result: result)

        let trialRecord = DetectionTrial(
            id: 0, sessionId: session.id,
            soundId: sounds[currentSoundIndex].id,
            trialNumber: trial,
            isDetected: isDetected, isCorrect: isCorrect,
            userResponse: nil, responseTimeMs: nil,
            createdAt: Date())
        Task {
            _ = try? await service.recordTrial(trialRecord)
        }

        // Auto-advance to next empty cell for this sound
        advanceToNext()
    }

    private func advanceToNext() {
        let col = currentSoundIndex

        // Find next empty trial for the same sound
        let nextEmpty = (0..<trialsPerSound).first(where: { grid[col][$0] == nil })
        if let next = nextEmpty {
            selectedTrialForSound[col] = next + 1
            updateState()
            return
        }

        // Current sound fully tested — find the next sound with empty trials
        for i in 1...sounds.count {
            let nextCol = (col + i) % sounds.count
            if let nextRow = (0..<trialsPerSound).first(where: { grid[nextCol][$0] == nil }) {
                currentSoundIndex = nextCol
                selectedTrialForSound[nextCol] = nextRow + 1
                updateState()
                return
            }
        }

        // All done!
        statusLabel.text = "All sounds tested!"
        trialLabel.text = "Tap Save to complete"
        pronunciationLabel.text = ""
    }

    // MARK: - Save

    @objc private func saveTapped() {
        lcHaptic(.medium)
        Task {
            try? await service.completeSession(id: session.id, notes: notesField.text)
            await MainActor.run {
                self.lcHapticSuccess()
                let vc = DetectionResultsGridViewController(sessionId: self.session.id)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
