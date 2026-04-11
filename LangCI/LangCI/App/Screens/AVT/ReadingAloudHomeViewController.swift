// ReadingAloudHomeViewController.swift
// LangCI
//
// Home screen for the Reading Aloud drill. Shows:
//   • Summary stats card (sessions, avg WPM, avg loudness)
//   • "Paste your own passage" quick action
//   • Bundled passages grouped by difficulty
//   • User's custom (non-bundled) passages
//   • Recent reading sessions
//
// Tapping a passage pushes ReadingAloudDrillViewController which records
// the user reading aloud and computes WPM + loudness stats.

import UIKit

final class ReadingAloudHomeViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Summary
    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?
    private let summaryEmptyLabel = UILabel()

    // Quick action
    private let pasteButton = LCButton(title: "Paste Your Own Passage", color: .lcBlue)

    // Bundled passages
    private let bundledCard = LCCard()
    private let bundledStack = UIStackView()

    // Custom passages
    private let customCard = LCCard()
    private let customStack = UIStackView()
    private var customSectionWrap: UIView?

    // Recent sessions
    private let recentCard = LCCard()
    private let recentStack = UIStackView()

    // MARK: - State

    private var bundledPassages: [ReadingPassage] = []
    private var customPassages: [ReadingPassage] = []
    private var recentSessions: [ReadingSession] = []
    private var stats: ReadingStatsDto?

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
        title = "Reading Aloud"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let progressButton = UIBarButtonItem(
            image: UIImage(systemName: "chart.line.uptrend.xyaxis"),
            style: .plain,
            target: self,
            action: #selector(didTapProgress))
        progressButton.accessibilityLabel = "View Progress"
        navigationItem.rightBarButtonItem = progressButton
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

        buildSummaryCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Your Reading", card: summaryCard))

        pasteButton.addTarget(self, action: #selector(didTapPaste), for: .touchUpInside)
        pasteButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(pasteButton)

        buildBundledCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Bundled Passages", card: bundledCard))

        buildCustomCard()
        let customWrap = sectionBlock(title: "My Passages", card: customCard)
        customWrap.isHidden = true
        customSectionWrap = customWrap
        contentStack.addArrangedSubview(customWrap)

        buildRecentCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Recent Sessions", card: recentCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Summary card

    private func buildSummaryCard() {
        summaryEmptyLabel.text = "Read a passage to see your speed and loudness stats here."
        summaryEmptyLabel.font = UIFont.lcBody()
        summaryEmptyLabel.textColor = .tertiaryLabel
        summaryEmptyLabel.numberOfLines = 0
        summaryEmptyLabel.textAlignment = .center
        summaryEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(summaryEmptyLabel)
        NSLayoutConstraint.activate([
            summaryEmptyLabel.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 24),
            summaryEmptyLabel.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -24),
            summaryEmptyLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: LC.cardPadding),
            summaryEmptyLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateSummaryCard() {
        // Remove any existing row
        summaryRow?.removeFromSuperview()
        summaryRow = nil

        guard let s = stats, s.sessionCount > 0 else {
            summaryEmptyLabel.isHidden = false
            return
        }
        summaryEmptyLabel.isHidden = true

        let wpmText   = String(format: "%.0f", s.avgWordsPerMinute)
        let dbText    = String(format: "%.0f", s.avgLoudnessDb)
        let pitchText = s.avgPitchHz > 0 ? String(format: "%.0f Hz", s.avgPitchHz) : "—"

        let row = LCStatRow(items: [
            .init(label: "Done",   value: "\(s.sessionCount)", tint: .lcBlue),
            .init(label: "WPM",    value: wpmText,             tint: .lcPurple),
            .init(label: "dB",     value: dbText,              tint: .lcTeal),
            .init(label: "Pitch",  value: pitchText,           tint: .lcGreen)
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        summaryRow = row
    }

    // MARK: - Bundled card

    private func buildBundledCard() {
        bundledStack.axis = .vertical
        bundledStack.spacing = 0
        bundledStack.translatesAutoresizingMaskIntoConstraints = false
        bundledCard.addSubview(bundledStack)
        NSLayoutConstraint.activate([
            bundledStack.topAnchor.constraint(equalTo: bundledCard.topAnchor, constant: 4),
            bundledStack.leadingAnchor.constraint(equalTo: bundledCard.leadingAnchor),
            bundledStack.trailingAnchor.constraint(equalTo: bundledCard.trailingAnchor),
            bundledStack.bottomAnchor.constraint(equalTo: bundledCard.bottomAnchor, constant: -4)
        ])
    }

    private func updateBundledCard() {
        bundledStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if bundledPassages.isEmpty {
            let empty = emptyLabel("No bundled passages available.")
            bundledStack.addArrangedSubview(empty)
            return
        }

        for (index, passage) in bundledPassages.enumerated() {
            let row = PassageRowView(passage: passage) { [weak self] in
                self?.presentDrill(for: passage)
            }
            bundledStack.addArrangedSubview(row)
            if index < bundledPassages.count - 1 {
                bundledStack.addArrangedSubview(indentedDivider())
            }
        }
    }

    // MARK: - Custom card

    private func buildCustomCard() {
        customStack.axis = .vertical
        customStack.spacing = 0
        customStack.translatesAutoresizingMaskIntoConstraints = false
        customCard.addSubview(customStack)
        NSLayoutConstraint.activate([
            customStack.topAnchor.constraint(equalTo: customCard.topAnchor, constant: 4),
            customStack.leadingAnchor.constraint(equalTo: customCard.leadingAnchor),
            customStack.trailingAnchor.constraint(equalTo: customCard.trailingAnchor),
            customStack.bottomAnchor.constraint(equalTo: customCard.bottomAnchor, constant: -4)
        ])
    }

    private func updateCustomCard() {
        customStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        customSectionWrap?.isHidden = customPassages.isEmpty
        if customPassages.isEmpty { return }

        for (index, passage) in customPassages.enumerated() {
            let row = PassageRowView(passage: passage,
                                     onTap: { [weak self] in self?.presentDrill(for: passage) },
                                     onLongPress: { [weak self] in self?.showPassageActions(passage) })
            customStack.addArrangedSubview(row)
            if index < customPassages.count - 1 {
                customStack.addArrangedSubview(indentedDivider())
            }
        }
    }

    // MARK: - Recent card

    private func buildRecentCard() {
        recentStack.axis = .vertical
        recentStack.spacing = 0
        recentStack.translatesAutoresizingMaskIntoConstraints = false
        recentCard.addSubview(recentStack)
        NSLayoutConstraint.activate([
            recentStack.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 4),
            recentStack.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor),
            recentStack.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor),
            recentStack.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -4)
        ])
    }

    private func updateRecentCard() {
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if recentSessions.isEmpty {
            recentStack.addArrangedSubview(emptyLabel("No reading sessions yet."))
            return
        }

        for (index, session) in recentSessions.enumerated() {
            let row = ReadingSessionRowView(session: session)
            recentStack.addArrangedSubview(row)
            if index < recentSessions.count - 1 {
                recentStack.addArrangedSubview(indentedDivider())
            }
        }
    }

    // MARK: - Helpers

    private func emptyLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = UIFont.lcBody()
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let wrap = UIView()
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -20),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
        ])
        return wrap
    }

    private func indentedDivider() -> UIView {
        let wrap = UIView()
        let div = LCDivider()
        div.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(div)
        NSLayoutConstraint.activate([
            div.topAnchor.constraint(equalTo: wrap.topAnchor),
            div.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            div.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
            div.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
        ])
        return wrap
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                async let bundledTask = ServiceLocator.shared.readingAloudService.getBundledPassages()
                async let allTask     = ServiceLocator.shared.readingAloudService.getAllPassages()
                async let recentTask  = ServiceLocator.shared.readingAloudService.getRecentSessions(limit: 6)
                async let statsTask   = ServiceLocator.shared.readingAloudService.getStats(days: nil)

                let bundled = try await bundledTask
                let all     = try await allTask
                let recent  = try await recentTask
                let s       = try await statsTask

                await MainActor.run {
                    self.bundledPassages = bundled
                    self.customPassages  = all.filter { !$0.isBundled }
                    self.recentSessions  = recent
                    self.stats           = s
                    self.updateSummaryCard()
                    self.updateBundledCard()
                    self.updateCustomCard()
                    self.updateRecentCard()
                }
            } catch {
                // Silently fail — cards show empty states
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapProgress() {
        lcHaptic(.light)
        let progress = ReadingProgressViewController()
        navigationController?.pushViewController(progress, animated: true)
    }

    @objc private func didTapPaste() {
        lcHaptic(.light)
        let paste = PassagePasteViewController { [weak self] passage in
            guard let self = self else { return }
            Task {
                do {
                    let saved = try await ServiceLocator.shared.readingAloudService.savePassage(passage)
                    await MainActor.run {
                        self.lcHapticSuccess()
                        self.loadData()
                        self.presentDrill(for: saved)
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Save failed",
                                         icon: "exclamationmark.triangle.fill",
                                         tint: .lcRed)
                    }
                }
            }
        }
        let nav = UINavigationController(rootViewController: paste)
        nav.modalPresentationStyle = .formSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    private func presentDrill(for passage: ReadingPassage) {
        let drill = ReadingAloudDrillViewController(passage: passage)
        navigationController?.pushViewController(drill, animated: true)
    }

    private func showPassageActions(_ passage: ReadingPassage) {
        let sheet = UIAlertController(
            title: passage.title,
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "Edit Passage", style: .default) { [weak self] _ in
            self?.presentEdit(for: passage)
        })
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDelete(passage)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func presentEdit(for passage: ReadingPassage) {
        let editor = PassagePasteViewController(editing: passage) { [weak self] updated in
            guard let self = self else { return }
            Task {
                do {
                    let saved = try await ServiceLocator.shared.readingAloudService.savePassage(updated)
                    await MainActor.run {
                        self.lcHapticSuccess()
                        self.lcShowToast("Passage updated",
                                         icon: "checkmark.circle.fill",
                                         tint: .lcGreen)
                        self.loadData()
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Save failed",
                                         icon: "exclamationmark.triangle.fill",
                                         tint: .lcRed)
                    }
                }
            }
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .formSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    private func confirmDelete(_ passage: ReadingPassage) {
        let alert = UIAlertController(
            title: "Delete passage?",
            message: "\"\(passage.title)\" will be removed. Saved sessions keep their own copy of the text.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await ServiceLocator.shared.readingAloudService.deletePassage(id: passage.id)
                    await MainActor.run {
                        self.lcHapticSuccess()
                        self.loadData()
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Delete failed",
                                         icon: "exclamationmark.triangle.fill",
                                         tint: .lcRed)
                    }
                }
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - PassageRowView

final class PassageRowView: UIControl {

    private let onTap: () -> Void
    private let onLongPress: (() -> Void)?

    init(passage: ReadingPassage,
         onTap: @escaping () -> Void,
         onLongPress: (() -> Void)? = nil)
    {
        self.onTap = onTap
        self.onLongPress = onLongPress
        super.init(frame: .zero)
        buildUI(with: passage)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(with passage: ReadingPassage) {
        translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.text = passage.category.emoji
        emoji.font = UIFont.systemFont(ofSize: 22)
        emoji.translatesAutoresizingMaskIntoConstraints = false
        emoji.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.text = passage.title
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        let subtitleLabel = UILabel()
        subtitleLabel.text = "\(passage.category.label) • \(passage.difficultyLabel) • \(passage.wordCount) words"
        subtitleLabel.font = UIFont.lcCaption()
        subtitleLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [emoji, textStack, UIView(), chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])

        // Long press → edit/delete action sheet
        if onLongPress != nil {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            addGestureRecognizer(longPress)
        }
    }

    @objc private func didTap() { onTap() }

    @objc private func didLongPress(_ gr: UILongPressGestureRecognizer) {
        if gr.state == .began { onLongPress?() }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.backgroundColor = self.isHighlighted
                    ? UIColor.systemFill.withAlphaComponent(0.3)
                    : .clear
            }
        }
    }
}

// MARK: - ReadingSessionRowView

final class ReadingSessionRowView: UIView {

    init(session: ReadingSession) {
        super.init(frame: .zero)
        buildUI(with: session)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(with session: ReadingSession) {
        translatesAutoresizingMaskIntoConstraints = false

        // WPM badge
        let badge = UILabel()
        badge.text = String(format: "%.0f", session.wordsPerMinute)
        badge.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = tintFor(band: session.wpmBand)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = session.passageTitle
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let subtitleLabel = UILabel()
        let wpmBand   = session.wpmBand.label
        let dbBand    = session.loudnessBand.label
        let duration  = formatDuration(session.durationSeconds)
        subtitleLabel.text = "\(wpmBand) • \(dbBand) • \(duration) • \(formatter.string(from: session.recordedAt))"
        subtitleLabel.font = UIFont.lcCaption()
        subtitleLabel.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [badge, titleStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 44),
            badge.heightAnchor.constraint(equalToConstant: 44),

            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func tintFor(band: WPMBand) -> UIColor {
        switch band {
        case .slow:       return .lcOrange
        case .developing: return .lcAmber
        case .natural:    return .lcGreen
        case .fast:       return .lcBlue
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
