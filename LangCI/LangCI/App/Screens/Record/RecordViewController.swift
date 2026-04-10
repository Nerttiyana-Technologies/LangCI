// RecordViewController.swift
// LangCI
//
// Redesigned Record screen — clean iOS-native layout with large title, horizontal
// family-member pill selector, prominent word card, animated record button with
// pulse ring, and a recent-recordings list card.

import UIKit
import AVFoundation

final class RecordViewController: UIViewController {

    // MARK: - UI

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    // Family member card
    private let familyCard       = LCCard()
    private let familyScrollView = UIScrollView()
    private let familyPillStack  = UIStackView()
    private let addMemberButton  = LCPillButton(title: "Add", systemIcon: "plus", tint: .lcRed)

    // Current word card
    private let wordCard              = LCCard()
    private let wordNativeScriptLabel = UILabel()
    private let wordIPALabel          = UILabel()
    private let wordEnglishLabel      = UILabel()
    private let prevWordButton        = LCIconButton(systemIcon: "chevron.left",  tint: .lcRed, size: 40)
    private let nextWordButton        = LCIconButton(systemIcon: "chevron.right", tint: .lcRed, size: 40)
    private let wordIndexLabel        = UILabel()

    // Record card
    private let recordCard     = LCCard()
    private let recordButton   = UIButton(type: .custom)
    private let recordRingView = UIView()
    private let waveformView   = WaveformVisualizerView()
    private let statusLabel    = UILabel()

    // Recent recordings card
    private let recentCard         = LCCard()
    private let recentTitleLabel   = UILabel()
    private let recentEmptyState   = EmptyStateView(
        icon: "waveform",
        title: "No recordings yet",
        message: "Record a word above to start building the voice bank.",
        tint: .lcRed
    )
    private let recentTable        = UITableView(frame: .zero, style: .plain)
    private var recentTableHeight: NSLayoutConstraint!

    // Services
    private var wordService: WordService { ServiceLocator.shared.wordService }
    private var familyMemberService: FamilyMemberService { ServiceLocator.shared.familyMemberService }
    private var recordingService: RecordingService { ServiceLocator.shared.recordingService }

    // State
    private var allWords: [WordEntry] = []
    private var currentWordIndex: Int = 0
    private var currentWord: WordEntry?
    private var selectedLanguageId: Int = 1

    private var familyMembers: [FamilyMember] = []
    private var selectedFamilyMember: FamilyMember?
    private var memberPillButtons: [(member: FamilyMember, button: LCPillButton)] = []

    private var recentRecordings: [Recording] = []

    private var isRecording = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadFamilyMembers()
        loadWords()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isRecording { cancelRecording() }
    }

    // MARK: - Navigation

    private func setupNavigation() {
        view.backgroundColor = .lcBackground
        navigationItem.title = "Record"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }

    // MARK: - UI Setup

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        buildFamilyCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Family Member", card: familyCard))

        buildWordCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Current Word", card: wordCard))

        buildRecordCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Record", card: recordCard))

        buildRecentCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Recent Recordings", card: recentCard))

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: LC.cardPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -LC.cardPadding),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * LC.cardPadding)
        ])
    }

    private func sectionBlock(title: String, card: UIView) -> UIStackView {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 6
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addArrangedSubview(SectionHeaderView(title: title))
        wrapper.addArrangedSubview(card)
        return wrapper
    }

    private func buildFamilyCard() {
        familyCard.translatesAutoresizingMaskIntoConstraints = false

        familyScrollView.showsHorizontalScrollIndicator = false
        familyScrollView.translatesAutoresizingMaskIntoConstraints = false

        familyPillStack.axis = .horizontal
        familyPillStack.spacing = 8
        familyPillStack.alignment = .center
        familyPillStack.translatesAutoresizingMaskIntoConstraints = false
        familyScrollView.addSubview(familyPillStack)

        addMemberButton.addTarget(self, action: #selector(addMemberTapped), for: .touchUpInside)
        familyPillStack.addArrangedSubview(addMemberButton)

        familyCard.addSubview(familyScrollView)
        NSLayoutConstraint.activate([
            familyScrollView.topAnchor.constraint(equalTo: familyCard.topAnchor, constant: 14),
            familyScrollView.bottomAnchor.constraint(equalTo: familyCard.bottomAnchor, constant: -14),
            familyScrollView.leadingAnchor.constraint(equalTo: familyCard.leadingAnchor),
            familyScrollView.trailingAnchor.constraint(equalTo: familyCard.trailingAnchor),
            familyScrollView.heightAnchor.constraint(equalToConstant: 40),

            familyPillStack.topAnchor.constraint(equalTo: familyScrollView.topAnchor),
            familyPillStack.bottomAnchor.constraint(equalTo: familyScrollView.bottomAnchor),
            familyPillStack.leadingAnchor.constraint(equalTo: familyScrollView.leadingAnchor, constant: LC.cardPadding),
            familyPillStack.trailingAnchor.constraint(equalTo: familyScrollView.trailingAnchor, constant: -LC.cardPadding),
            familyPillStack.heightAnchor.constraint(equalTo: familyScrollView.heightAnchor)
        ])
    }

    private func buildWordCard() {
        wordCard.translatesAutoresizingMaskIntoConstraints = false

        wordNativeScriptLabel.font = .systemFont(ofSize: 36, weight: .bold)
        wordNativeScriptLabel.textAlignment = .center
        wordNativeScriptLabel.numberOfLines = 1
        wordNativeScriptLabel.adjustsFontSizeToFitWidth = true
        wordNativeScriptLabel.minimumScaleFactor = 0.5
        wordNativeScriptLabel.textColor = .label
        wordNativeScriptLabel.text = "—"

        wordIPALabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        wordIPALabel.textColor = .secondaryLabel
        wordIPALabel.textAlignment = .center
        wordIPALabel.numberOfLines = 1

        wordEnglishLabel.font = UIFont.lcBody()
        wordEnglishLabel.textColor = .tertiaryLabel
        wordEnglishLabel.textAlignment = .center
        wordEnglishLabel.numberOfLines = 1

        wordIndexLabel.font = UIFont.lcCaption()
        wordIndexLabel.textColor = .secondaryLabel
        wordIndexLabel.textAlignment = .center
        wordIndexLabel.text = "– of –"

        let wordTextStack = UIStackView(arrangedSubviews: [
            wordNativeScriptLabel, wordIPALabel, wordEnglishLabel
        ])
        wordTextStack.axis = .vertical
        wordTextStack.alignment = .center
        wordTextStack.spacing = 4

        prevWordButton.addTarget(self, action: #selector(prevWordTapped), for: .touchUpInside)
        nextWordButton.addTarget(self, action: #selector(nextWordTapped), for: .touchUpInside)

        let navStack = UIStackView(arrangedSubviews: [prevWordButton, wordTextStack, nextWordButton])
        navStack.axis = .horizontal
        navStack.alignment = .center
        navStack.spacing = 12
        wordTextStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        wordTextStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [navStack, wordIndexLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        wordCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wordCard.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: wordCard.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: wordCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: wordCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildRecordCard() {
        recordCard.translatesAutoresizingMaskIntoConstraints = false

        // Pulsing ring (behind the button)
        recordRingView.layer.borderColor = UIColor.lcRed.cgColor
        recordRingView.layer.borderWidth = 3
        recordRingView.layer.cornerRadius = 44
        recordRingView.isUserInteractionEnabled = false
        recordRingView.alpha = 0
        recordRingView.translatesAutoresizingMaskIntoConstraints = false

        // Record button
        recordButton.backgroundColor = .lcRed
        recordButton.tintColor = .white
        recordButton.layer.cornerRadius = 40
        recordButton.clipsToBounds = true
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        recordButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: iconCfg), for: .normal)
        recordButton.lcApplyShadow(radius: 10, opacity: 0.25)

        let buttonWrap = UIView()
        buttonWrap.translatesAutoresizingMaskIntoConstraints = false
        buttonWrap.addSubview(recordRingView)
        buttonWrap.addSubview(recordButton)

        NSLayoutConstraint.activate([
            buttonWrap.heightAnchor.constraint(equalToConstant: 120),

            recordRingView.widthAnchor.constraint(equalToConstant: 88),
            recordRingView.heightAnchor.constraint(equalToConstant: 88),
            recordRingView.centerXAnchor.constraint(equalTo: buttonWrap.centerXAnchor),
            recordRingView.centerYAnchor.constraint(equalTo: buttonWrap.centerYAnchor),

            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            recordButton.centerXAnchor.constraint(equalTo: buttonWrap.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: buttonWrap.centerYAnchor)
        ])

        // Waveform
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        // Status
        statusLabel.font = UIFont.lcBody()
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.text = "Tap to record"

        let stack = UIStackView(arrangedSubviews: [buttonWrap, waveformView, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        recordCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: recordCard.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: recordCard.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: recordCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: recordCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildRecentCard() {
        recentCard.translatesAutoresizingMaskIntoConstraints = false

        recentTitleLabel.font = UIFont.lcBodyBold()
        recentTitleLabel.textColor = .label
        recentTitleLabel.text = "Latest"
        recentTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        recentTable.delegate = self
        recentTable.dataSource = self
        recentTable.register(RecentRecordingCell.self, forCellReuseIdentifier: RecentRecordingCell.identifier)
        recentTable.backgroundColor = .clear
        recentTable.isScrollEnabled = false
        recentTable.separatorStyle = .singleLine
        recentTable.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        recentTable.tableFooterView = UIView()
        recentTable.estimatedRowHeight = 70
        recentTable.rowHeight = UITableView.automaticDimension
        recentTable.translatesAutoresizingMaskIntoConstraints = false

        recentEmptyState.translatesAutoresizingMaskIntoConstraints = false
        recentEmptyState.isHidden = true

        recentCard.addSubview(recentTitleLabel)
        recentCard.addSubview(recentTable)
        recentCard.addSubview(recentEmptyState)

        recentTableHeight = recentTable.heightAnchor.constraint(equalToConstant: 80)

        NSLayoutConstraint.activate([
            recentTitleLabel.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 14),
            recentTitleLabel.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor, constant: LC.cardPadding),
            recentTitleLabel.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor, constant: -LC.cardPadding),

            recentTable.topAnchor.constraint(equalTo: recentTitleLabel.bottomAnchor, constant: 8),
            recentTable.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor),
            recentTable.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor),
            recentTable.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -10),
            recentTableHeight,

            recentEmptyState.topAnchor.constraint(equalTo: recentTable.topAnchor),
            recentEmptyState.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor),
            recentEmptyState.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor),
            recentEmptyState.bottomAnchor.constraint(equalTo: recentTable.bottomAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadFamilyMembers() {
        Task {
            do {
                let members = try await familyMemberService.getAllMembers()
                await MainActor.run {
                    self.familyMembers = members
                    self.rebuildFamilyPills()
                    if self.selectedFamilyMember == nil, let first = members.first {
                        self.selectFamilyMember(first)
                    }
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to load family members: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadWords() {
        Task {
            do {
                let words = try await wordService.getWords(languageId: selectedLanguageId, dialectId: nil)
                await MainActor.run {
                    self.allWords = words
                    self.currentWordIndex = 0
                    self.updateWordDisplay()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to load words: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadRecentRecordings() {
        guard let memberId = selectedFamilyMember?.id else {
            recentRecordings = []
            refreshRecentTable()
            return
        }
        Task {
            do {
                let all = try await recordingService.getRecentRecordings(count: 20)
                let filtered = all.filter { $0.familyMemberId == memberId }
                await MainActor.run {
                    self.recentRecordings = Array(filtered.prefix(5))
                    self.refreshRecentTable()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to load recordings: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - UI Updates

    private func rebuildFamilyPills() {
        memberPillButtons.forEach { $0.button.removeFromSuperview() }
        memberPillButtons.removeAll()

        for (index, member) in familyMembers.enumerated() {
            let pill = LCPillButton(title: member.name, systemIcon: "person.fill", tint: .lcRed)
            pill.tag = index
            pill.addTarget(self, action: #selector(familyPillTapped(_:)), for: .touchUpInside)
            familyPillStack.insertArrangedSubview(pill, at: index)
            memberPillButtons.append((member, pill))
        }
        updatePillSelection()
    }

    private func updatePillSelection() {
        for (entry, _) in memberPillButtons {
            let pill = memberPillButtons.first { $0.member.id == entry.id }?.button
            pill?.isSelectedPill = (entry.id == selectedFamilyMember?.id)
        }
    }

    private func updateWordDisplay() {
        guard !allWords.isEmpty else {
            currentWord = nil
            wordNativeScriptLabel.text = "—"
            wordIPALabel.text = ""
            wordEnglishLabel.text = "No words available"
            wordIndexLabel.text = "– of –"
            prevWordButton.isEnabled = false
            nextWordButton.isEnabled = false
            return
        }

        let index = max(0, min(currentWordIndex, allWords.count - 1))
        currentWordIndex = index
        let word = allWords[index]
        currentWord = word

        wordNativeScriptLabel.text = word.nativeScript
        wordIPALabel.text = word.ipaPhoneme.isEmpty ? "—" : word.ipaPhoneme
        wordEnglishLabel.text = word.phoneticKey
        wordIndexLabel.text = "\(index + 1) of \(allWords.count)"

        prevWordButton.isEnabled = index > 0
        nextWordButton.isEnabled = index < allWords.count - 1
        prevWordButton.alpha = prevWordButton.isEnabled ? 1 : 0.35
        nextWordButton.alpha = nextWordButton.isEnabled ? 1 : 0.35
    }

    private func refreshRecentTable() {
        recentTable.reloadData()
        recentTable.layoutIfNeeded()
        let rowHeight: CGFloat = 70
        let height = max(CGFloat(recentRecordings.count) * rowHeight, 80)
        recentTableHeight.constant = height
        recentEmptyState.isHidden = !recentRecordings.isEmpty
        recentTable.isHidden = recentRecordings.isEmpty
    }

    private func setRecording(_ recording: Bool) {
        isRecording = recording

        let iconName = recording ? "stop.fill" : "mic.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        recordButton.setImage(UIImage(systemName: iconName, withConfiguration: cfg), for: .normal)
        recordButton.backgroundColor = recording ? .lcRed.withAlphaComponent(0.85) : .lcRed

        if recording {
            startRingPulse()
            waveformView.startAnimating()
            statusLabel.text = "Recording…"
            statusLabel.textColor = .lcRed
        } else {
            stopRingPulse()
            waveformView.stopAnimating()
            statusLabel.text = "Tap to record"
            statusLabel.textColor = .secondaryLabel
        }
    }

    private func startRingPulse() {
        recordRingView.alpha = 1
        recordRingView.transform = .identity
        UIView.animate(withDuration: 1.2,
                       delay: 0,
                       options: [.repeat, .autoreverse, .curveEaseInOut],
                       animations: {
            self.recordRingView.alpha = 0.15
            self.recordRingView.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        })
    }

    private func stopRingPulse() {
        recordRingView.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) {
            self.recordRingView.alpha = 0
            self.recordRingView.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    @objc private func familyPillTapped(_ sender: LCPillButton) {
        let index = sender.tag
        guard index >= 0, index < familyMembers.count else { return }
        selectFamilyMember(familyMembers[index])
    }

    private func selectFamilyMember(_ member: FamilyMember) {
        lcHaptic(.light)
        selectedFamilyMember = member
        updatePillSelection()
        loadRecentRecordings()
    }

    @objc private func addMemberTapped() {
        lcHaptic(.light)
        let alert = UIAlertController(title: "Add Family Member", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Name" }
        alert.addTextField { $0.placeholder = "Relationship (e.g., Mom, Dad)" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let nameField = alert?.textFields?[0],
                  let relationshipField = alert?.textFields?[1],
                  let name = nameField.text, !name.isEmpty else { return }
            let relationship = relationshipField.text ?? ""
            let initials = String(name.prefix(2)).uppercased()
            let newMember = FamilyMember(
                id: 0,
                name: name,
                relationship: relationship,
                avatarInitials: initials,
                preferredDialectId: 0
            )
            Task {
                do {
                    _ = try await self.familyMemberService.saveMember(newMember)
                    await MainActor.run {
                        self.loadFamilyMembers()
                        self.lcShowToast("Member added", icon: "checkmark.circle.fill", tint: .lcGreen)
                    }
                } catch {
                    await MainActor.run {
                        self.showError("Failed to add member: \(error.localizedDescription)")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func prevWordTapped() {
        lcHaptic(.light)
        guard currentWordIndex > 0 else { return }
        currentWordIndex -= 1
        updateWordDisplay()
    }

    @objc private func nextWordTapped() {
        lcHaptic(.light)
        guard currentWordIndex < allWords.count - 1 else { return }
        currentWordIndex += 1
        updateWordDisplay()
    }

    // MARK: - Recording

    private func startRecording() {
        guard currentWord != nil else {
            showError("No word selected")
            return
        }
        guard selectedFamilyMember != nil else {
            showError("Please select a family member first")
            return
        }

        lcHaptic(.medium)
        Task {
            do {
                try await recordingService.startRecording()
                await MainActor.run { self.setRecording(true) }
            } catch {
                await MainActor.run {
                    self.showError("Failed to start recording: \(error.localizedDescription)")
                }
            }
        }
    }

    private func stopRecording() {
        guard let word = currentWord, let member = selectedFamilyMember else { return }

        lcHaptic(.medium)
        Task {
            do {
                _ = try await recordingService.stopRecording(
                    wordEntryId: word.id,
                    dialectId: 0,
                    familyMemberId: member.id
                )
                await MainActor.run {
                    self.setRecording(false)
                    self.lcHapticSuccess()
                    self.lcShowToast("Recording saved", icon: "checkmark.circle.fill", tint: .lcGreen)
                    self.nextWordTapped()
                    self.loadRecentRecordings()
                }
            } catch {
                await MainActor.run {
                    self.setRecording(false)
                    self.showError("Failed to save recording: \(error.localizedDescription)")
                }
            }
        }
    }

    private func cancelRecording() {
        setRecording(false)
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View

extension RecordViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentRecordings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecentRecordingCell.identifier, for: indexPath)
        let recording = recentRecordings[indexPath.row]
        if let cell = cell as? RecentRecordingCell {
            cell.configure(with: recording)
            cell.onPlay = { [weak self] in
                self?.playRecording(recording)
            }
            cell.onDelete = { [weak self] in
                self?.confirmDelete(recording)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    private func playRecording(_ recording: Recording) {
        guard !recording.filePath.isEmpty else {
            lcShowToast("No audio file", icon: "exclamationmark.triangle.fill", tint: .lcOrange)
            return
        }
        lcHaptic(.light)
        Task {
            do {
                try await recordingService.playRecording(path: recording.filePath)
            } catch {
                await MainActor.run {
                    self.showError("Playback failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func confirmDelete(_ recording: Recording) {
        let alert = UIAlertController(
            title: "Delete Recording",
            message: "Are you sure you want to delete this recording?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await self.recordingService.deleteRecording(id: recording.id)
                    await MainActor.run {
                        self.loadRecentRecordings()
                        self.lcShowToast("Deleted", icon: "trash.fill", tint: .lcRed)
                    }
                } catch {
                    await MainActor.run {
                        self.showError("Failed to delete recording: \(error.localizedDescription)")
                    }
                }
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - RecentRecordingCell

final class RecentRecordingCell: UITableViewCell {
    static let identifier = "RecentRecordingCell"

    private let iconBadge     = UIView()
    private let iconView      = UIImageView()
    private let wordLabel     = UILabel()
    private let dateLabel     = UILabel()
    private let durationLabel = UILabel()
    private let playButton    = UIButton(type: .system)
    private let deleteButton  = UIButton(type: .system)

    var onDelete: (() -> Void)?
    var onPlay: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        iconBadge.backgroundColor = UIColor.lcRed.withAlphaComponent(0.12)
        iconBadge.layer.cornerRadius = 9
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.image = UIImage(systemName: "waveform", withConfiguration: cfg)
        iconView.tintColor = .lcRed
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        wordLabel.font = UIFont.lcBodyBold()
        wordLabel.textColor = .label
        wordLabel.numberOfLines = 1

        dateLabel.font = UIFont.lcCaption()
        dateLabel.textColor = .secondaryLabel
        dateLabel.numberOfLines = 1

        durationLabel.font = UIFont.lcCaption()
        durationLabel.textColor = .tertiaryLabel
        durationLabel.textAlignment = .right
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)

        configureCircleButton(playButton,   icon: "play.fill", tint: .lcRed, filled: true)
        configureCircleButton(deleteButton, icon: "trash",     tint: .lcRed, filled: false)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [wordLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconBadge)
        contentView.addSubview(textStack)
        contentView.addSubview(durationLabel)
        contentView.addSubview(playButton)
        contentView.addSubview(deleteButton)

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LC.cardPadding),
            iconBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),

            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: durationLabel.leadingAnchor, constant: -6),

            durationLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -8),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            playButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            playButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 38),
            playButton.heightAnchor.constraint(equalToConstant: 38),

            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LC.cardPadding),
            deleteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 38),
            deleteButton.heightAnchor.constraint(equalToConstant: 38),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 66)
        ])
    }

    private func configureCircleButton(_ button: UIButton, icon: String, tint: UIColor, filled: Bool) {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.image = UIImage(systemName: icon,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        config.baseBackgroundColor = tint
        config.baseForegroundColor = filled ? .white : tint
        config.cornerStyle = .capsule
        button.configuration = config
    }

    func configure(with recording: Recording) {
        wordLabel.text = recording.wordEntry?.nativeScript ?? "Recording"

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        dateLabel.text = df.string(from: recording.recordedAt)

        let duration = recording.durationSeconds
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        durationLabel.text = String(format: "%d:%02d", mins, secs)
    }

    @objc private func playTapped()   { onPlay?() }
    @objc private func deleteTapped() { onDelete?() }
}

// MARK: - WaveformVisualizerView

final class WaveformVisualizerView: UIView {
    private let barStack = UIStackView()
    private var isAnimating = false
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor.lcRed.withAlphaComponent(0.06)
        layer.cornerRadius = 12
        layer.borderColor = UIColor.lcRed.withAlphaComponent(0.18).cgColor
        layer.borderWidth = 1

        barStack.axis = .horizontal
        barStack.distribution = .equalSpacing
        barStack.alignment = .center
        barStack.layoutMargins = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        barStack.isLayoutMarginsRelativeArrangement = true
        barStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(barStack)

        NSLayoutConstraint.activate([
            barStack.topAnchor.constraint(equalTo: topAnchor),
            barStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            barStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            barStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for _ in 0..<18 {
            let bar = UIView()
            bar.backgroundColor = .lcRed
            bar.layer.cornerRadius = 2
            bar.clipsToBounds = true
            barStack.addArrangedSubview(bar)
            bar.widthAnchor.constraint(equalToConstant: 4).isActive = true
        }
    }

    func startAnimating() {
        isAnimating = true
        displayLink = CADisplayLink(target: self, selector: #selector(updateBars))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
        for subview in barStack.arrangedSubviews {
            UIView.animate(withDuration: 0.15) {
                subview.transform = CGAffineTransform(scaleX: 1, y: 0.2)
            }
        }
    }

    @objc private func updateBars() {
        guard isAnimating else { return }
        for subview in barStack.arrangedSubviews {
            let randomHeight = CGFloat.random(in: 0.3...1.0)
            UIView.animate(withDuration: 0.1, animations: {
                subview.transform = CGAffineTransform(scaleX: 1, y: randomHeight)
            })
        }
    }

    func updateWaveform() {}
}
