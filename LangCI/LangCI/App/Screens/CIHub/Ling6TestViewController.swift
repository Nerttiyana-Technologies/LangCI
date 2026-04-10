// Ling6TestViewController.swift
// LangCI
//
// Redesigned Ling 6 test screen. Clean iOS-native look:
//   • Large title nav with History bar button
//   • Distance card with UIStepper
//   • Program segmented control in a card
//   • 6-sound grid (2x3) with colored detection states
//   • Summary stat row (Detected / Not-heard / Pending)
//   • Save button — persists session + individual attempts
//
// Lives inside CIHub. Users tap each sound to cycle pending → detected → not-detected.

import UIKit

final class Ling6TestViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Distance
    private let distanceCard = LCCard()
    private let distanceValueLabel = UILabel()
    private let distanceStepper = UIStepper()

    // Program
    private let programCard = LCCard()
    private let programSegmented = UISegmentedControl()

    // Sounds
    private let soundsCard = LCCard()
    private var soundButtons: [SoundTileButton] = []
    private let soundLabels = ["ah", "ee", "oo", "sh", "s", "m"]
    private let soundFrequencies = ["250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "6 kHz"]

    // Summary
    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?

    // Save
    private let saveButton = LCButton(title: "Save Session", color: .lcTeal)

    // MARK: - State

    enum SoundState: Int { case pending = 0, detected = 1, notDetected = 2 }
    private var soundStates: [SoundState] = Array(repeating: .pending, count: 6)
    private var currentDistance: Int = 100
    private var currentProgram: ProcessorProgram = .everyday

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        updateSummary()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Ling 6"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let history = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            style: .plain,
            target: self,
            action: #selector(didTapHistory)
        )
        history.tintColor = .lcTeal
        navigationItem.rightBarButtonItem = history
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

        buildDistanceCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Distance", card: distanceCard))

        buildProgramCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Processor Program", card: programCard))

        buildSoundsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Detection", card: soundsCard))

        buildSummaryCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Summary", card: summaryCard))

        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(saveButton)
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Distance card

    private func buildDistanceCard() {
        distanceValueLabel.text = "\(currentDistance) cm"
        distanceValueLabel.font = UIFont.lcCardValue()
        distanceValueLabel.textColor = .lcTeal
        distanceValueLabel.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = UILabel()
        hintLabel.text = "Distance from speaker"
        hintLabel.font = UIFont.lcCaption()
        hintLabel.textColor = .secondaryLabel
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [distanceValueLabel, hintLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        distanceStepper.minimumValue = 25
        distanceStepper.maximumValue = 400
        distanceStepper.stepValue = 25
        distanceStepper.value = Double(currentDistance)
        distanceStepper.tintColor = .lcTeal
        distanceStepper.translatesAutoresizingMaskIntoConstraints = false
        distanceStepper.addTarget(self, action: #selector(didChangeDistance), for: .valueChanged)

        let mainStack = UIStackView(arrangedSubviews: [leftStack, distanceStepper])
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        distanceCard.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: distanceCard.topAnchor, constant: LC.cardPadding),
            mainStack.leadingAnchor.constraint(equalTo: distanceCard.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: distanceCard.trailingAnchor, constant: -LC.cardPadding),
            mainStack.bottomAnchor.constraint(equalTo: distanceCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    @objc private func didChangeDistance() {
        currentDistance = Int(distanceStepper.value)
        distanceValueLabel.text = "\(currentDistance) cm"
        lcHaptic(.light)
    }

    // MARK: - Program card

    private func buildProgramCard() {
        programSegmented.insertSegment(withTitle: "Everyday", at: 0, animated: false)
        programSegmented.insertSegment(withTitle: "Noise", at: 1, animated: false)
        programSegmented.insertSegment(withTitle: "Music", at: 2, animated: false)
        programSegmented.insertSegment(withTitle: "Focus", at: 3, animated: false)
        programSegmented.insertSegment(withTitle: "Telecoil", at: 4, animated: false)
        programSegmented.selectedSegmentIndex = 0
        programSegmented.translatesAutoresizingMaskIntoConstraints = false
        programSegmented.addTarget(self, action: #selector(didChangeProgram), for: .valueChanged)

        programCard.addSubview(programSegmented)
        NSLayoutConstraint.activate([
            programSegmented.topAnchor.constraint(equalTo: programCard.topAnchor, constant: LC.cardPadding),
            programSegmented.leadingAnchor.constraint(equalTo: programCard.leadingAnchor, constant: LC.cardPadding),
            programSegmented.trailingAnchor.constraint(equalTo: programCard.trailingAnchor, constant: -LC.cardPadding),
            programSegmented.bottomAnchor.constraint(equalTo: programCard.bottomAnchor, constant: -LC.cardPadding),
            programSegmented.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc private func didChangeProgram() {
        let programs: [ProcessorProgram] = [.everyday, .noise, .music, .focus, .telecoil]
        let idx = programSegmented.selectedSegmentIndex
        if idx >= 0 && idx < programs.count {
            currentProgram = programs[idx]
        }
        lcHaptic(.light)
    }

    // MARK: - Sounds card

    private func buildSoundsCard() {
        let rows: [[Int]] = [[0, 1], [2, 3], [4, 5]]
        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 12
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        for rowIndices in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 12
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for idx in rowIndices {
                let tile = SoundTileButton(
                    sound: "/\(soundLabels[idx])/",
                    frequency: soundFrequencies[idx]
                )
                tile.tag = idx
                tile.addTarget(self, action: #selector(didTapSound(_:)), for: .touchUpInside)
                tile.heightAnchor.constraint(equalToConstant: 88).isActive = true
                soundButtons.append(tile)
                rowStack.addArrangedSubview(tile)
            }
            outerStack.addArrangedSubview(rowStack)
        }

        let legend = UILabel()
        legend.text = "Tap to cycle: pending → detected → not heard"
        legend.font = UIFont.lcCaption()
        legend.textColor = .tertiaryLabel
        legend.textAlignment = .center
        legend.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIStackView(arrangedSubviews: [outerStack, legend])
        wrap.axis = .vertical
        wrap.spacing = 12
        wrap.translatesAutoresizingMaskIntoConstraints = false

        soundsCard.addSubview(wrap)
        NSLayoutConstraint.activate([
            wrap.topAnchor.constraint(equalTo: soundsCard.topAnchor, constant: LC.cardPadding),
            wrap.leadingAnchor.constraint(equalTo: soundsCard.leadingAnchor, constant: LC.cardPadding),
            wrap.trailingAnchor.constraint(equalTo: soundsCard.trailingAnchor, constant: -LC.cardPadding),
            wrap.bottomAnchor.constraint(equalTo: soundsCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    @objc private func didTapSound(_ sender: SoundTileButton) {
        let idx = sender.tag
        let next: SoundState
        switch soundStates[idx] {
        case .pending: next = .detected
        case .detected: next = .notDetected
        case .notDetected: next = .pending
        }
        soundStates[idx] = next
        sender.setState(next)
        updateSummary()
        lcHaptic(.light)
    }

    // MARK: - Summary card

    private func buildSummaryCard() {
        rebuildSummary(detected: 0, notHeard: 0, pending: 6)
    }

    private func rebuildSummary(detected: Int, notHeard: Int, pending: Int) {
        summaryRow?.removeFromSuperview()
        let row = LCStatRow(items: [
            .init(label: "Detected", value: "\(detected)", tint: .lcGreen),
            .init(label: "Not Heard", value: "\(notHeard)", tint: .lcRed),
            .init(label: "Pending", value: "\(pending)", tint: .lcOrange)
        ])
        summaryCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        summaryRow = row
    }

    private func updateSummary() {
        let detected = soundStates.filter { $0 == .detected }.count
        let notHeard = soundStates.filter { $0 == .notDetected }.count
        let pending = soundStates.filter { $0 == .pending }.count
        rebuildSummary(detected: detected, notHeard: notHeard, pending: pending)
    }

    // MARK: - Save

    @objc private func didTapSave() {
        // Require at least one marked
        let anyMarked = soundStates.contains { $0 != .pending }
        guard anyMarked else {
            lcShowToast("Mark at least one sound", icon: "exclamationmark.triangle.fill", tint: .lcAmber)
            return
        }

        saveButton.isEnabled = false
        Task {
            do {
                let session = try await ServiceLocator.shared.ling6Service.startSession(
                    distanceCm: currentDistance,
                    program: currentProgram
                )
                for (idx, state) in soundStates.enumerated() where state != .pending {
                    try await ServiceLocator.shared.ling6Service.recordAttempt(
                        sessionId: session.id,
                        sound: soundLabels[idx],
                        isDetected: state == .detected,
                        isRecognised: state == .detected
                    )
                }
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.lcShowToast("Session saved", icon: "checkmark.circle.fill", tint: .lcGreen)
                    self.resetForm()
                    self.saveButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self.saveButton.isEnabled = true
                    self.lcShowToast("Save failed", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }

    private func resetForm() {
        soundStates = Array(repeating: .pending, count: 6)
        for button in soundButtons {
            button.setState(.pending)
        }
        updateSummary()
    }

    // MARK: - History

    @objc private func didTapHistory() {
        lcHaptic(.light)
        navigationController?.pushViewController(Ling6HistoryViewController(), animated: true)
    }
}

// MARK: - SoundTileButton

final class SoundTileButton: UIControl {

    private let soundLabel = UILabel()
    private let freqLabel = UILabel()
    private let iconView = UIImageView()
    private let container = UIView()

    init(sound: String, frequency: String) {
        super.init(frame: .zero)
        buildUI(sound: sound, frequency: frequency)
        setState(.pending)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(sound: String, frequency: String) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 14
        clipsToBounds = true

        soundLabel.text = sound
        soundLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        soundLabel.textColor = .white
        soundLabel.textAlignment = .center
        soundLabel.translatesAutoresizingMaskIntoConstraints = false

        freqLabel.text = frequency
        freqLabel.font = UIFont.lcCaption()
        freqLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        freqLabel.textAlignment = .center
        freqLabel.translatesAutoresizingMaskIntoConstraints = false

        iconView.tintColor = UIColor.white.withAlphaComponent(0.9)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [soundLabel, freqLabel, iconView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 16)
        ])
    }

    func setState(_ state: Ling6TestViewController.SoundState) {
        switch state {
        case .pending:
            backgroundColor = UIColor.secondarySystemFill
            soundLabel.textColor = .label
            freqLabel.textColor = .secondaryLabel
            iconView.tintColor = .tertiaryLabel
            iconView.image = nil
        case .detected:
            backgroundColor = .lcGreen
            soundLabel.textColor = .white
            freqLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            iconView.tintColor = .white
            iconView.image = UIImage(systemName: "checkmark.circle.fill")
        case .notDetected:
            backgroundColor = .lcRed
            soundLabel.textColor = .white
            freqLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            iconView.tintColor = .white
            iconView.image = UIImage(systemName: "xmark.circle.fill")
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

// MARK: - Ling6HistoryViewController

final class Ling6HistoryViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sessions: [Ling6Session] = []
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(Ling6SessionCell.self, forCellReuseIdentifier: Ling6SessionCell.identifier)
        tableView.backgroundColor = .lcBackground
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)

        emptyLabel.text = "No sessions yet.\nRun a Ling 6 test to see results here."
        emptyLabel.font = UIFont.lcBody()
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        loadSessions()
    }

    private func loadSessions() {
        Task {
            do {
                let sessions = try await ServiceLocator.shared.ling6Service.getRecentSessions(count: 30)
                await MainActor.run {
                    self.sessions = sessions
                    self.tableView.reloadData()
                    self.emptyLabel.isHidden = !sessions.isEmpty
                }
            } catch {
                await MainActor.run {
                    self.emptyLabel.isHidden = false
                }
            }
        }
    }
}

extension Ling6HistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Ling6SessionCell.identifier, for: indexPath) as! Ling6SessionCell
        cell.configure(with: sessions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - Ling6SessionCell

final class Ling6SessionCell: UITableViewCell {
    static let identifier = "Ling6SessionCell"

    private let dateLabel = UILabel()
    private let detailLabel = UILabel()
    private let scoreBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildCell() {
        backgroundColor = .lcCard
        selectionStyle = .none

        dateLabel.font = UIFont.lcBodyBold()
        dateLabel.textColor = .label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = UIFont.lcCaption()
        detailLabel.textColor = .secondaryLabel
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        scoreBadge.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        scoreBadge.textColor = .white
        scoreBadge.backgroundColor = .lcGreen
        scoreBadge.textAlignment = .center
        scoreBadge.layer.cornerRadius = 14
        scoreBadge.clipsToBounds = true
        scoreBadge.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [dateLabel, detailLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 3
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [leftStack, scoreBadge])
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LC.cardPadding),
            scoreBadge.widthAnchor.constraint(equalToConstant: 56),
            scoreBadge.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func configure(with session: Ling6Session) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: session.testedAt)

        let detected = session.attempts.filter { $0.isDetected }.count
        let total = session.attempts.count
        detailLabel.text = "\(session.distanceCm) cm • \(session.programUsed.displayName)"
        scoreBadge.text = "\(detected)/\(total)"

        // Color the badge based on score
        if total == 0 {
            scoreBadge.backgroundColor = .systemGray4
        } else {
            let ratio = Double(detected) / Double(total)
            switch ratio {
            case 0.83...: scoreBadge.backgroundColor = .lcGreen
            case 0.5..<0.83: scoreBadge.backgroundColor = .lcAmber
            default: scoreBadge.backgroundColor = .lcRed
            }
        }
    }
}

// MARK: - ProcessorProgram display name

extension ProcessorProgram {
    var displayName: String {
        switch self {
        case .everyday: return "Everyday"
        case .noise: return "Noise"
        case .music: return "Music"
        case .focus: return "Focus"
        case .telecoil: return "Telecoil"
        case .custom1: return "Custom 1"
        case .custom2: return "Custom 2"
        }
    }
}
