// AVTViewController.swift
// LangCI
//
// Redesigned AVT (Auditory Verbal Therapy) hub. Clean iOS-native look:
//   • Large title nav
//   • Today's focus: horizontal scrolling chip row of target sounds
//   • Quick-start drill button
//   • Progress card with 4 ListeningHierarchy levels (emoji + progress bar)
//   • Recent Sessions card with row-style entries
//   • Audiologist note preview card + "Add Note" button
//   • Sound Wall quick link row

import UIKit

final class AVTViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Today's focus
    private let focusCard = LCCard()
    private let focusScrollView = UIScrollView()
    private let focusStack = UIStackView()
    private let focusEmptyLabel = UILabel()

    // Progress
    private let progressCard = LCCard()
    private let progressContentStack = UIStackView()

    // Recent sessions
    private let recentCard = LCCard()
    private let recentContentStack = UIStackView()

    // Audiologist note
    private let noteCard = LCCard()
    private let noteContentStack = UIStackView()

    // Quick actions
    private let drillButton = LCButton(title: "Start Today's Drill", color: .lcPurple)
    private let soundWallRow = LCListRow(icon: "square.grid.3x3.fill",
                                         title: "Sound Wall",
                                         subtitle: "Explore phonemes & targets",
                                         tint: .lcTeal)
    private let confusionLogRow = LCListRow(icon: "arrow.left.arrow.right.circle.fill",
                                            title: "Confusion Log",
                                            subtitle: "Track said X, heard Y moments",
                                            tint: .lcOrange)
    private let readingAloudRow = LCListRow(icon: "text.book.closed.fill",
                                            title: "Reading Aloud",
                                            subtitle: "Passages, speed & loudness",
                                            tint: .lcBlue)
    private let reportRow = LCListRow(icon: "doc.text.fill",
                                      title: "Audiology Report",
                                      subtitle: "Full progress summary to share",
                                      tint: .lcPurple)

    // MARK: - State

    private var activeTargets: [AVTTarget] = []
    private var recentSessions: [AVTSession] = []
    private var latestNote: AVTAudiologistNote?
    private var homeStats: AVTHomeStats?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadData()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "AVT"
        navigationItem.largeTitleDisplayMode = .always
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

        buildFocusCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Today's Focus", card: focusCard))

        // Drill button
        drillButton.addTarget(self, action: #selector(didTapQuickDrill), for: .touchUpInside)
        drillButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(drillButton)

        buildProgressCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Your Progress", card: progressCard))

        buildRecentCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Recent Sessions", card: recentCard))

        buildNoteCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Audiologist Notes", card: noteCard))

        // More card holds Sound Wall, Confusion Log, Reading Aloud, Audiology Report rows
        let moreCard = LCCard()
        soundWallRow.addTarget(self, action: #selector(didTapSoundWall), for: .touchUpInside)
        confusionLogRow.addTarget(self, action: #selector(didTapConfusionLog), for: .touchUpInside)
        readingAloudRow.addTarget(self, action: #selector(didTapReadingAloud), for: .touchUpInside)
        reportRow.addTarget(self, action: #selector(didTapReport), for: .touchUpInside)

        let d1 = LCDivider()
        let d2 = LCDivider()
        let d3 = LCDivider()

        moreCard.addSubview(soundWallRow)
        moreCard.addSubview(d1)
        moreCard.addSubview(confusionLogRow)
        moreCard.addSubview(d2)
        moreCard.addSubview(readingAloudRow)
        moreCard.addSubview(d3)
        moreCard.addSubview(reportRow)

        soundWallRow.translatesAutoresizingMaskIntoConstraints = false
        confusionLogRow.translatesAutoresizingMaskIntoConstraints = false
        readingAloudRow.translatesAutoresizingMaskIntoConstraints = false
        reportRow.translatesAutoresizingMaskIntoConstraints = false
        d1.translatesAutoresizingMaskIntoConstraints = false
        d2.translatesAutoresizingMaskIntoConstraints = false
        d3.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            soundWallRow.topAnchor.constraint(equalTo: moreCard.topAnchor, constant: 4),
            soundWallRow.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor),
            soundWallRow.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor),

            d1.topAnchor.constraint(equalTo: soundWallRow.bottomAnchor),
            d1.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor, constant: LC.cardPadding),
            d1.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor, constant: -LC.cardPadding),

            confusionLogRow.topAnchor.constraint(equalTo: d1.bottomAnchor),
            confusionLogRow.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor),
            confusionLogRow.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor),

            d2.topAnchor.constraint(equalTo: confusionLogRow.bottomAnchor),
            d2.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor, constant: LC.cardPadding),
            d2.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor, constant: -LC.cardPadding),

            readingAloudRow.topAnchor.constraint(equalTo: d2.bottomAnchor),
            readingAloudRow.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor),
            readingAloudRow.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor),

            d3.topAnchor.constraint(equalTo: readingAloudRow.bottomAnchor),
            d3.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor, constant: LC.cardPadding),
            d3.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor, constant: -LC.cardPadding),

            reportRow.topAnchor.constraint(equalTo: d3.bottomAnchor),
            reportRow.leadingAnchor.constraint(equalTo: moreCard.leadingAnchor),
            reportRow.trailingAnchor.constraint(equalTo: moreCard.trailingAnchor),
            reportRow.bottomAnchor.constraint(equalTo: moreCard.bottomAnchor, constant: -4)
        ])
        contentStack.addArrangedSubview(sectionBlock(title: "More", card: moreCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Focus card

    private func buildFocusCard() {
        focusScrollView.translatesAutoresizingMaskIntoConstraints = false
        focusScrollView.showsHorizontalScrollIndicator = false
        focusScrollView.alwaysBounceHorizontal = true

        focusStack.axis = .horizontal
        focusStack.spacing = 10
        focusStack.alignment = .center
        focusStack.translatesAutoresizingMaskIntoConstraints = false
        focusScrollView.addSubview(focusStack)

        focusEmptyLabel.text = "No active targets. Add one from the Sound Wall."
        focusEmptyLabel.font = UIFont.lcBody()
        focusEmptyLabel.textColor = .tertiaryLabel
        focusEmptyLabel.numberOfLines = 0
        focusEmptyLabel.textAlignment = .center
        focusEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        focusEmptyLabel.isHidden = true

        focusCard.addSubview(focusScrollView)
        focusCard.addSubview(focusEmptyLabel)

        NSLayoutConstraint.activate([
            focusScrollView.topAnchor.constraint(equalTo: focusCard.topAnchor, constant: 14),
            focusScrollView.leadingAnchor.constraint(equalTo: focusCard.leadingAnchor),
            focusScrollView.trailingAnchor.constraint(equalTo: focusCard.trailingAnchor),
            focusScrollView.bottomAnchor.constraint(equalTo: focusCard.bottomAnchor, constant: -14),
            focusScrollView.heightAnchor.constraint(equalToConstant: 72),

            focusStack.topAnchor.constraint(equalTo: focusScrollView.topAnchor),
            focusStack.bottomAnchor.constraint(equalTo: focusScrollView.bottomAnchor),
            focusStack.leadingAnchor.constraint(equalTo: focusScrollView.leadingAnchor, constant: LC.cardPadding),
            focusStack.trailingAnchor.constraint(equalTo: focusScrollView.trailingAnchor, constant: -LC.cardPadding),
            focusStack.heightAnchor.constraint(equalTo: focusScrollView.heightAnchor),

            focusEmptyLabel.centerXAnchor.constraint(equalTo: focusCard.centerXAnchor),
            focusEmptyLabel.centerYAnchor.constraint(equalTo: focusCard.centerYAnchor),
            focusEmptyLabel.leadingAnchor.constraint(equalTo: focusCard.leadingAnchor, constant: LC.cardPadding),
            focusEmptyLabel.trailingAnchor.constraint(equalTo: focusCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateFocusCard() {
        focusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if activeTargets.isEmpty {
            focusEmptyLabel.isHidden = false
            focusScrollView.isHidden = true
            return
        }
        focusEmptyLabel.isHidden = true
        focusScrollView.isHidden = false

        for target in activeTargets {
            let chip = SoundChipButton(target: target)
            chip.tag = target.id
            chip.addTarget(self, action: #selector(didTapSoundChip(_:)), for: .touchUpInside)
            focusStack.addArrangedSubview(chip)
        }
    }

    // MARK: - Progress card

    private func buildProgressCard() {
        progressContentStack.axis = .vertical
        progressContentStack.spacing = 14
        progressContentStack.translatesAutoresizingMaskIntoConstraints = false

        progressCard.addSubview(progressContentStack)
        NSLayoutConstraint.activate([
            progressContentStack.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: LC.cardPadding),
            progressContentStack.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: LC.cardPadding),
            progressContentStack.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -LC.cardPadding),
            progressContentStack.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateProgressCard() {
        progressContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let levels: [(emoji: String, name: String, level: ListeningHierarchy)] = [
            ("👂", "Detection", .detection),
            ("🎯", "Discrimination", .discrimination),
            ("🔤", "Identification", .identification),
            ("💭", "Comprehension", .comprehension)
        ]

        for (emoji, name, level) in levels {
            let row = makeProgressRow(emoji: emoji, name: name, level: level)
            progressContentStack.addArrangedSubview(row)
        }
    }

    private func makeProgressRow(emoji: String, name: String, level: ListeningHierarchy) -> UIView {
        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = UIFont.systemFont(ofSize: 20)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont.lcBodyBold()
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let targetsAtLevel = activeTargets.filter { $0.currentLevel.rawValue >= level.rawValue }.count
        let fraction = activeTargets.isEmpty ? 0 : CGFloat(targetsAtLevel) / CGFloat(activeTargets.count)

        let progressBar = ProgressBarView()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.setProgress(fraction)

        let percentLabel = UILabel()
        percentLabel.text = "\(Int(fraction * 100))%"
        percentLabel.font = UIFont.lcCaption()
        percentLabel.textColor = .secondaryLabel
        percentLabel.textAlignment = .right
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, UIView(), percentLabel])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [topRow, progressBar])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressBar.heightAnchor.constraint(equalToConstant: 6)
        ])
        return stack
    }

    // MARK: - Recent sessions card

    private func buildRecentCard() {
        recentContentStack.axis = .vertical
        recentContentStack.spacing = 0
        recentContentStack.translatesAutoresizingMaskIntoConstraints = false

        recentCard.addSubview(recentContentStack)
        NSLayoutConstraint.activate([
            recentContentStack.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 4),
            recentContentStack.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor),
            recentContentStack.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor),
            recentContentStack.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -4)
        ])
    }

    private func updateRecentCard() {
        recentContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if recentSessions.isEmpty {
            let empty = UILabel()
            empty.text = "No sessions yet. Run a drill to see them here."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.numberOfLines = 0
            empty.textAlignment = .center
            empty.translatesAutoresizingMaskIntoConstraints = false
            let wrap = UIView()
            wrap.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 20),
                empty.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -20),
                empty.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
                empty.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
            ])
            recentContentStack.addArrangedSubview(wrap)
            return
        }

        for (index, session) in recentSessions.enumerated() {
            let row = RecentSessionRowView(session: session)
            recentContentStack.addArrangedSubview(row)
            if index < recentSessions.count - 1 {
                recentContentStack.addArrangedSubview(LCDivider())
            }
        }
    }

    // MARK: - Note card

    private func buildNoteCard() {
        noteContentStack.axis = .vertical
        noteContentStack.spacing = 10
        noteContentStack.translatesAutoresizingMaskIntoConstraints = false

        noteCard.addSubview(noteContentStack)
        NSLayoutConstraint.activate([
            noteContentStack.topAnchor.constraint(equalTo: noteCard.topAnchor, constant: LC.cardPadding),
            noteContentStack.leadingAnchor.constraint(equalTo: noteCard.leadingAnchor, constant: LC.cardPadding),
            noteContentStack.trailingAnchor.constraint(equalTo: noteCard.trailingAnchor, constant: -LC.cardPadding),
            noteContentStack.bottomAnchor.constraint(equalTo: noteCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateNoteCard() {
        noteContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let note = latestNote {
            let soundsLabel = UILabel()
            soundsLabel.text = "Targets: " + note.targetSoundList.joined(separator: ", ")
            soundsLabel.font = UIFont.lcCaption()
            soundsLabel.textColor = .secondaryLabel
            soundsLabel.numberOfLines = 2
            noteContentStack.addArrangedSubview(soundsLabel)

            let previewLabel = UILabel()
            let preview = String(note.notes.prefix(140)) + (note.notes.count > 140 ? "…" : "")
            previewLabel.text = preview
            previewLabel.font = UIFont.lcBody()
            previewLabel.textColor = .label
            previewLabel.numberOfLines = 3
            noteContentStack.addArrangedSubview(previewLabel)

            let dateLabel = UILabel()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            dateLabel.text = formatter.string(from: note.notedAt)
            dateLabel.font = UIFont.lcCaption()
            dateLabel.textColor = .tertiaryLabel
            noteContentStack.addArrangedSubview(dateLabel)
        } else {
            let empty = UILabel()
            empty.text = "No notes yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            noteContentStack.addArrangedSubview(empty)
        }

        let addNoteButton = LCButton(title: "Add Note", color: .lcPurple)
        addNoteButton.translatesAutoresizingMaskIntoConstraints = false
        addNoteButton.addTarget(self, action: #selector(didTapAddNote), for: .touchUpInside)
        addNoteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        noteContentStack.addArrangedSubview(addNoteButton)
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                async let targetsTask = ServiceLocator.shared.avtService.getActiveTargets()
                async let sessionsTask = ServiceLocator.shared.avtService.getRecentSessions(count: 5)
                async let noteTask = ServiceLocator.shared.avtService.getLatestNote()
                async let statsTask = ServiceLocator.shared.avtService.getHomeStats()

                let (targets, sessions, note, stats) = try await (targetsTask, sessionsTask, noteTask, statsTask)

                await MainActor.run {
                    self.activeTargets = targets
                    self.recentSessions = sessions
                    self.latestNote = note
                    self.homeStats = stats
                    self.updateFocusCard()
                    self.updateProgressCard()
                    self.updateRecentCard()
                    self.updateNoteCard()
                }
            } catch {
                // Silently fail — cards show empty states
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapSoundChip(_ sender: UIButton) {
        lcHaptic(.light)
        guard let target = activeTargets.first(where: { $0.id == sender.tag }) else { return }
        let drillVC = AVTDrillViewController(
            sound: target.sound,
            level: target.currentLevel,
            targetId: target.id
        )
        navigationController?.pushViewController(drillVC, animated: true)
    }

    @objc private func didTapQuickDrill() {
        lcHaptic(.light)
        guard let target = activeTargets.first else {
            lcShowToast("No active targets", icon: "exclamationmark.triangle.fill", tint: .lcAmber)
            return
        }
        let drillVC = AVTDrillViewController(
            sound: target.sound,
            level: target.currentLevel,
            targetId: target.id
        )
        navigationController?.pushViewController(drillVC, animated: true)
    }

    @objc private func didTapSoundWall() {
        lcHaptic(.light)
        navigationController?.pushViewController(AVTSoundWallViewController(), animated: true)
    }

    @objc private func didTapConfusionLog() {
        lcHaptic(.light)
        navigationController?.pushViewController(ConfusionLogViewController(), animated: true)
    }

    @objc private func didTapReadingAloud() {
        lcHaptic(.light)
        navigationController?.pushViewController(ReadingAloudHomeViewController(), animated: true)
    }

    @objc private func didTapReport() {
        lcHaptic(.light)
        navigationController?.pushViewController(AVTAudiologyReportViewController(), animated: true)
    }

    @objc private func didTapAddNote() {
        lcHaptic(.light)
        navigationController?.pushViewController(AVTAudiologistNoteViewController(), animated: true)
    }
}

// MARK: - SoundChipButton

final class SoundChipButton: UIControl {

    private let soundLabel = UILabel()
    private let ipaLabel = UILabel()
    private let levelColor: UIColor

    init(target: AVTTarget) {
        self.levelColor = target.currentLevel.color
        super.init(frame: .zero)
        buildUI(sound: target.sound, ipa: target.phonemeIpa)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(sound: String, ipa: String) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = levelColor.withAlphaComponent(0.14)
        layer.cornerRadius = 14
        layer.borderColor = levelColor.withAlphaComponent(0.4).cgColor
        layer.borderWidth = 1

        soundLabel.text = sound
        soundLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        soundLabel.textColor = levelColor
        soundLabel.textAlignment = .center
        soundLabel.translatesAutoresizingMaskIntoConstraints = false

        ipaLabel.text = "/\(ipa)/"
        ipaLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        ipaLabel.textColor = .secondaryLabel
        ipaLabel.textAlignment = .center
        ipaLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [soundLabel, ipaLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

// MARK: - RecentSessionRowView

final class RecentSessionRowView: UIView {

    init(session: AVTSession) {
        super.init(frame: .zero)
        buildUI(with: session)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(with session: AVTSession) {
        translatesAutoresizingMaskIntoConstraints = false

        // Sound badge
        let badge = UILabel()
        badge.text = String(session.targetSound.uppercased().prefix(2))
        badge.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = session.hierarchyLevel.color
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        // Title: level label
        let titleLabel = UILabel()
        titleLabel.text = session.hierarchyLevel.label
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle: date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateLabel = UILabel()
        dateLabel.text = formatter.string(from: session.startedAt)
        dateLabel.font = UIFont.lcCaption()
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        // Accuracy
        let accuracyLabel = UILabel()
        accuracyLabel.text = String(format: "%.0f%%", session.accuracy)
        accuracyLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        accuracyLabel.textColor = session.hierarchyLevel.color
        accuracyLabel.textAlignment = .right
        accuracyLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [badge, titleStack, UIView(), accuracyLabel])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40),

            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding)
        ])
    }
}
