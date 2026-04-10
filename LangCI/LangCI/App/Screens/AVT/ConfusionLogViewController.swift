// ConfusionLogViewController.swift
// LangCI
//
// Standalone "said X, I heard Y" confusion log. Users can:
//   • See a summary of the most frequent confusions (all-time & 7-day)
//   • Quick-log a new pair via a modal sheet
//   • Browse recent entries grouped by day
//   • Delete an entry from a row swipe
//
// Complements the inline confusion capture inside AVTDrillViewController.

import UIKit

final class ConfusionLogViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?
    private let topPatternsCard = LCCard()
    private let topPatternsStack = UIStackView()
    private let emptyTopPatternsLabel = UILabel()

    private let recentCard = LCCard()
    private let recentStack = UIStackView()
    private let emptyRecentLabel = UILabel()

    private let logButton = LCButton(title: "Log New Confusion", color: .lcPurple)

    // MARK: - State

    private var recentPairs: [ConfusionPair] = []
    private var topAllTime: [ConfusionStatDto] = []
    private var topLastWeek: [ConfusionStatDto] = []
    private var totalAllTime: Int = 0
    private var totalLastWeek: Int = 0

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
        title = "Confusion Log"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(didTapLog)
        )
        addButton.tintColor = .lcPurple
        navigationItem.rightBarButtonItem = addButton
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 16, leading: LC.cardPadding,
                                                      bottom: 24, trailing: LC.cardPadding)
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Summary
        contentStack.addArrangedSubview(summaryCard)
        updateSummary() // seed with zeros so the card has height

        // Log button
        logButton.addTarget(self, action: #selector(didTapLog), for: .touchUpInside)
        logButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(logButton)

        // Top patterns
        buildTopPatternsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Most Frequent", card: topPatternsCard))

        // Recent
        buildRecentCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Recent Entries", card: recentCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        return wrap
    }

    private func buildTopPatternsCard() {
        topPatternsStack.axis = .vertical
        topPatternsStack.spacing = 0
        topPatternsStack.translatesAutoresizingMaskIntoConstraints = false

        emptyTopPatternsLabel.text = "Nothing logged yet.\nTap 'Log New Confusion' to start."
        emptyTopPatternsLabel.font = UIFont.lcBody()
        emptyTopPatternsLabel.textColor = .tertiaryLabel
        emptyTopPatternsLabel.numberOfLines = 0
        emptyTopPatternsLabel.textAlignment = .center
        emptyTopPatternsLabel.translatesAutoresizingMaskIntoConstraints = false

        topPatternsCard.addSubview(topPatternsStack)
        topPatternsCard.addSubview(emptyTopPatternsLabel)

        NSLayoutConstraint.activate([
            topPatternsStack.topAnchor.constraint(equalTo: topPatternsCard.topAnchor, constant: 4),
            topPatternsStack.leadingAnchor.constraint(equalTo: topPatternsCard.leadingAnchor),
            topPatternsStack.trailingAnchor.constraint(equalTo: topPatternsCard.trailingAnchor),
            topPatternsStack.bottomAnchor.constraint(equalTo: topPatternsCard.bottomAnchor, constant: -4),

            emptyTopPatternsLabel.topAnchor.constraint(equalTo: topPatternsCard.topAnchor, constant: 24),
            emptyTopPatternsLabel.bottomAnchor.constraint(equalTo: topPatternsCard.bottomAnchor, constant: -24),
            emptyTopPatternsLabel.leadingAnchor.constraint(equalTo: topPatternsCard.leadingAnchor, constant: LC.cardPadding),
            emptyTopPatternsLabel.trailingAnchor.constraint(equalTo: topPatternsCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildRecentCard() {
        recentStack.axis = .vertical
        recentStack.spacing = 0
        recentStack.translatesAutoresizingMaskIntoConstraints = false

        emptyRecentLabel.text = "No recent entries yet."
        emptyRecentLabel.font = UIFont.lcBody()
        emptyRecentLabel.textColor = .tertiaryLabel
        emptyRecentLabel.numberOfLines = 0
        emptyRecentLabel.textAlignment = .center
        emptyRecentLabel.translatesAutoresizingMaskIntoConstraints = false

        recentCard.addSubview(recentStack)
        recentCard.addSubview(emptyRecentLabel)

        NSLayoutConstraint.activate([
            recentStack.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 4),
            recentStack.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor),
            recentStack.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor),
            recentStack.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -4),

            emptyRecentLabel.topAnchor.constraint(equalTo: recentCard.topAnchor, constant: 24),
            emptyRecentLabel.bottomAnchor.constraint(equalTo: recentCard.bottomAnchor, constant: -24),
            emptyRecentLabel.leadingAnchor.constraint(equalTo: recentCard.leadingAnchor, constant: LC.cardPadding),
            emptyRecentLabel.trailingAnchor.constraint(equalTo: recentCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - Data

    private func loadData() {
        let svc: ConfusionPairService = ServiceLocator.shared.confusionPairService
        Task {
            async let recentTask    = svc.getRecentPairs(limit: 30)
            async let topAllTask    = svc.getTopConfusions(limit: 5, days: nil)
            async let topWeekTask   = svc.getTopConfusions(limit: 5, days: 7)
            async let countAllTask  = svc.getCount(days: nil)
            async let countWeekTask = svc.getCount(days: 7)
            do {
                let recent    = try await recentTask
                let topAll    = try await topAllTask
                let topWeek   = try await topWeekTask
                let countAll  = try await countAllTask
                let countWeek = try await countWeekTask

                await MainActor.run {
                    self.recentPairs    = recent
                    self.topAllTime     = topAll
                    self.topLastWeek    = topWeek
                    self.totalAllTime   = countAll
                    self.totalLastWeek  = countWeek
                    self.updateSummary()
                    self.updateTopPatterns()
                    self.updateRecent()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Couldn't load confusion log",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                }
            }
        }
    }

    private func updateSummary() {
        summaryRow?.removeFromSuperview()
        let topEntry = topAllTime.first
        let topText: String
        if let t = topEntry, !t.saidWord.isEmpty {
            topText = "\(t.saidWord)→\(t.heardWord)"
        } else {
            topText = "—"
        }
        let row = LCStatRow(items: [
            .init(label: "Total",     value: "\(totalAllTime)",  tint: .lcPurple),
            .init(label: "This Week", value: "\(totalLastWeek)", tint: .lcBlue),
            .init(label: "Top Pair",  value: topText,            tint: .lcOrange)
        ])
        summaryCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -LC.cardPadding)
        ])
        summaryRow = row
    }

    private func updateTopPatterns() {
        topPatternsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if topAllTime.isEmpty {
            emptyTopPatternsLabel.isHidden = false
            topPatternsStack.isHidden = true
            return
        }
        emptyTopPatternsLabel.isHidden = true
        topPatternsStack.isHidden = false

        for (i, stat) in topAllTime.enumerated() {
            let row = ConfusionPatternRowView(stat: stat, rank: i + 1)
            topPatternsStack.addArrangedSubview(row)
            if i < topAllTime.count - 1 {
                topPatternsStack.addArrangedSubview(LCDivider())
            }
        }
    }

    private func updateRecent() {
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if recentPairs.isEmpty {
            emptyRecentLabel.isHidden = false
            recentStack.isHidden = true
            return
        }
        emptyRecentLabel.isHidden = true
        recentStack.isHidden = false

        // Group by day
        let grouped = Dictionary(grouping: recentPairs) { pair -> Date in
            Calendar.current.startOfDay(for: pair.loggedAt)
        }
        let sortedDays = grouped.keys.sorted(by: >)
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .medium

        for (dayIndex, day) in sortedDays.enumerated() {
            let dayLabel = UILabel()
            dayLabel.text = dayFormatter.string(from: day).uppercased()
            dayLabel.font = UIFont.lcCaption()
            dayLabel.textColor = .secondaryLabel
            dayLabel.translatesAutoresizingMaskIntoConstraints = false

            let dayWrap = UIView()
            dayWrap.addSubview(dayLabel)
            dayLabel.topAnchor.constraint(equalTo: dayWrap.topAnchor, constant: 10).isActive = true
            dayLabel.bottomAnchor.constraint(equalTo: dayWrap.bottomAnchor, constant: -4).isActive = true
            dayLabel.leadingAnchor.constraint(equalTo: dayWrap.leadingAnchor, constant: LC.cardPadding).isActive = true
            dayLabel.trailingAnchor.constraint(equalTo: dayWrap.trailingAnchor, constant: -LC.cardPadding).isActive = true
            recentStack.addArrangedSubview(dayWrap)

            let pairs = grouped[day] ?? []
            for (i, pair) in pairs.enumerated() {
                let row = ConfusionEntryRowView(pair: pair)
                row.onDelete = { [weak self] in self?.promptDelete(pair) }
                recentStack.addArrangedSubview(row)
                if i < pairs.count - 1 {
                    recentStack.addArrangedSubview(LCDivider())
                }
            }
            if dayIndex < sortedDays.count - 1 {
                let spacer = UIView()
                spacer.heightAnchor.constraint(equalToConstant: 6).isActive = true
                recentStack.addArrangedSubview(spacer)
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapLog() {
        lcHaptic(.light)
        presentLogSheet()
    }

    private func presentLogSheet() {
        let sheet = ConfusionQuickLogSheet { [weak self] pair in
            guard let self = self else { return }
            Task {
                do {
                    _ = try await ServiceLocator.shared.confusionPairService.logPair(pair)
                    try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                    await MainActor.run {
                        self.lcHapticSuccess()
                        self.lcShowToast("Logged", icon: "checkmark.circle.fill", tint: .lcGreen)
                        self.loadData()
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Save failed", icon: "exclamationmark.triangle.fill", tint: .lcRed)
                    }
                }
            }
        }
        let nav = UINavigationController(rootViewController: sheet)
        nav.modalPresentationStyle = .formSheet
        if let sheetCtrl = nav.sheetPresentationController {
            sheetCtrl.detents = [.medium(), .large()]
            sheetCtrl.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func promptDelete(_ pair: ConfusionPair) {
        let alert = UIAlertController(
            title: "Delete this entry?",
            message: "\(pair.saidWord) → \(pair.heardWord)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await ServiceLocator.shared.confusionPairService.deletePair(id: pair.id)
                    await MainActor.run { self.loadData() }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Delete failed", icon: "exclamationmark.triangle.fill", tint: .lcRed)
                    }
                }
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - ConfusionPatternRowView

private final class ConfusionPatternRowView: UIView {

    init(stat: ConfusionStatDto, rank: Int) {
        super.init(frame: .zero)
        buildUI(with: stat, rank: rank)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(with stat: ConfusionStatDto, rank: Int) {
        translatesAutoresizingMaskIntoConstraints = false

        let rankLabel = UILabel()
        rankLabel.text = "#\(rank)"
        rankLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        rankLabel.textColor = .lcPurple
        rankLabel.textAlignment = .center
        rankLabel.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.14)
        rankLabel.layer.cornerRadius = 10
        rankLabel.clipsToBounds = true
        rankLabel.translatesAutoresizingMaskIntoConstraints = false

        let pairLabel = UILabel()
        pairLabel.text = "\(stat.saidWord)  →  \(stat.heardWord)"
        pairLabel.font = UIFont.lcBodyBold()
        pairLabel.textColor = .label
        pairLabel.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = UILabel()
        countLabel.text = "\(stat.count)×"
        countLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        countLabel.textColor = .lcOrange
        countLabel.textAlignment = .right
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [rankLabel, pairLabel, UIView(), countLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            rankLabel.widthAnchor.constraint(equalToConstant: 36),
            rankLabel.heightAnchor.constraint(equalToConstant: 22),

            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding)
        ])
    }
}

// MARK: - ConfusionEntryRowView

private final class ConfusionEntryRowView: UIView {

    var onDelete: (() -> Void)?

    init(pair: ConfusionPair) {
        super.init(frame: .zero)
        buildUI(with: pair)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(with pair: ConfusionPair) {
        translatesAutoresizingMaskIntoConstraints = false

        let sourceBadge = UILabel()
        sourceBadge.text = pair.source.emoji
        sourceBadge.font = UIFont.systemFont(ofSize: 18)
        sourceBadge.textAlignment = .center
        sourceBadge.backgroundColor = UIColor.secondarySystemFill
        sourceBadge.layer.cornerRadius = 18
        sourceBadge.clipsToBounds = true
        sourceBadge.translatesAutoresizingMaskIntoConstraints = false

        let pairLabel = UILabel()
        pairLabel.text = "\(pair.saidWord)  →  \(pair.heardWord)"
        pairLabel.font = UIFont.lcBodyBold()
        pairLabel.textColor = .label
        pairLabel.numberOfLines = 2
        pairLabel.translatesAutoresizingMaskIntoConstraints = false

        let subLabel = UILabel()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        var subParts = [timeFormatter.string(from: pair.loggedAt)]
        if !pair.targetSound.isEmpty {
            subParts.append("/" + pair.targetSound + "/")
        }
        subParts.append(pair.source.label)
        subLabel.text = subParts.joined(separator: " · ")
        subLabel.font = UIFont.lcCaption()
        subLabel.textColor = .secondaryLabel
        subLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [pairLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .tertiaryLabel
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [sourceBadge, textStack, deleteButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            sourceBadge.widthAnchor.constraint(equalToConstant: 36),
            sourceBadge.heightAnchor.constraint(equalToConstant: 36),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    @objc private func didTapDelete() { onDelete?() }
}
