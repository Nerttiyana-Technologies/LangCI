// MilestonesViewController.swift
// LangCI
//
// Dedicated screen for browsing every milestone the user has reached
// (CI activation, first AVT drill, first reading aloud, custom moments,
// auto-detected hearing-age checks, etc.). Lives under Settings →
// MY JOURNEY. Even though most events are also captured in their own
// journal/drill tables, this view gives the user a single chronological
// timeline of "firsts" and special moments to celebrate.

import UIKit

final class MilestonesViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let heroCard = LCCard()
    private let heroEmoji = UILabel()
    private let heroCountLabel = UILabel()
    private let heroSubtitleLabel = UILabel()

    private var statRow: LCStatRow?
    private let statCard = LCCard()

    private let timelineCard = LCCard()
    private let timelineStack = UIStackView()
    private let emptyTimelineLabel = UILabel()

    private let addButton = LCButton(title: "Add Milestone", color: .lcPurple)

    // MARK: - State

    private var milestones: [MilestoneEntry] = []
    private var activation: MilestoneEntry?

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
        title = "Milestones"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let add = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(didTapAdd)
        )
        add.tintColor = .lcPurple
        navigationItem.rightBarButtonItem = add
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(
            top: 16, leading: LC.cardPadding,
            bottom: 24, trailing: LC.cardPadding
        )
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

        buildHeroCard()
        contentStack.addArrangedSubview(heroCard)

        contentStack.addArrangedSubview(statCard)
        updateStatRow(total: 0, autoCount: 0, manualCount: 0)

        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        addButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(addButton)

        buildTimelineCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Timeline", card: timelineCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        return wrap
    }

    private func buildHeroCard() {
        heroEmoji.text = "🎉"
        heroEmoji.font = .systemFont(ofSize: 44)
        heroEmoji.translatesAutoresizingMaskIntoConstraints = false
        heroEmoji.setContentHuggingPriority(.required, for: .horizontal)

        heroCountLabel.text = "0 milestones"
        heroCountLabel.font = .lcHeroTitle()
        heroCountLabel.textColor = .label
        heroCountLabel.translatesAutoresizingMaskIntoConstraints = false

        heroSubtitleLabel.text = "Set your activation date to start tracking."
        heroSubtitleLabel.font = .lcCaption()
        heroSubtitleLabel.textColor = .secondaryLabel
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [heroCountLabel, heroSubtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [heroEmoji, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        heroCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildTimelineCard() {
        timelineStack.axis = .vertical
        timelineStack.spacing = 0
        timelineStack.translatesAutoresizingMaskIntoConstraints = false

        emptyTimelineLabel.text =
            "No milestones yet.\nTap 'Add Milestone' or just keep practising — firsts are auto-detected."
        emptyTimelineLabel.font = .lcBody()
        emptyTimelineLabel.textColor = .tertiaryLabel
        emptyTimelineLabel.numberOfLines = 0
        emptyTimelineLabel.textAlignment = .center
        emptyTimelineLabel.translatesAutoresizingMaskIntoConstraints = false

        timelineCard.addSubview(timelineStack)
        timelineCard.addSubview(emptyTimelineLabel)

        NSLayoutConstraint.activate([
            timelineStack.topAnchor.constraint(equalTo: timelineCard.topAnchor, constant: 4),
            timelineStack.leadingAnchor.constraint(equalTo: timelineCard.leadingAnchor),
            timelineStack.trailingAnchor.constraint(equalTo: timelineCard.trailingAnchor),
            timelineStack.bottomAnchor.constraint(equalTo: timelineCard.bottomAnchor, constant: -4),

            emptyTimelineLabel.topAnchor.constraint(equalTo: timelineCard.topAnchor, constant: 24),
            emptyTimelineLabel.bottomAnchor.constraint(equalTo: timelineCard.bottomAnchor, constant: -24),
            emptyTimelineLabel.leadingAnchor.constraint(equalTo: timelineCard.leadingAnchor, constant: LC.cardPadding),
            emptyTimelineLabel.trailingAnchor.constraint(equalTo: timelineCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - Stat row

    private func updateStatRow(total: Int, autoCount: Int, manualCount: Int) {
        statCard.subviews.forEach { $0.removeFromSuperview() }
        let row = LCStatRow(items: [
            .init(label: "Total",      value: "\(total)",       tint: .lcPurple),
            .init(label: "Auto",       value: "\(autoCount)",   tint: .lcBlue),
            .init(label: "Manual",     value: "\(manualCount)", tint: .lcGreen)
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        statCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: statCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: statCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: statCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: statCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        statRow = row
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                // Make sure auto-detection has had a chance to run
                // before we re-render. Cheap if nothing has changed.
                try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                try? await ServiceLocator.shared.milestoneService.autoCheck()

                async let allTask        = ServiceLocator.shared.milestoneService.getAll()
                async let activationTask = ServiceLocator.shared.milestoneService.getActivation()
                let all     = try await allTask
                let act     = try await activationTask

                await MainActor.run {
                    self.milestones = all.sorted(by: { $0.achievedAt > $1.achievedAt })
                    self.activation = act
                    self.render()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Failed to load milestones",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                }
            }
        }
    }

    // MARK: - Render

    private func render() {
        // Hero
        let total = milestones.count
        heroCountLabel.text = total == 1 ? "1 milestone" : "\(total) milestones"

        if let activation {
            let days = ServiceLocator.shared.milestoneService.getDaysSinceActivation(activation)
            let df = DateFormatter()
            df.dateStyle = .medium
            heroSubtitleLabel.text = "Day \(max(days, 0)) of hearing  •  activated \(df.string(from: activation.achievedAt))"
            heroEmoji.text = total > 0 ? (milestones.first?.emoji ?? "🎉") : "👂"
        } else {
            heroSubtitleLabel.text = "Set your activation date in Settings → My Journey to start the timeline."
            heroEmoji.text = "👂"
        }

        // Stats
        let autoCount = milestones.filter { $0.type.isAutoDetectable }.count
        let manualCount = total - autoCount
        updateStatRow(total: total, autoCount: autoCount, manualCount: manualCount)

        // Timeline
        timelineStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if milestones.isEmpty {
            emptyTimelineLabel.isHidden = false
            return
        }
        emptyTimelineLabel.isHidden = true

        // Group by month-year for headers, newest first.
        let cal = Calendar.current
        let groups = Dictionary(grouping: milestones) { entry -> Date in
            let comps = cal.dateComponents([.year, .month], from: entry.achievedAt)
            return cal.date(from: comps) ?? entry.achievedAt
        }
        let orderedKeys = groups.keys.sorted(by: >)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for (i, key) in orderedKeys.enumerated() {
            let group = groups[key]?.sorted(by: { $0.achievedAt > $1.achievedAt }) ?? []

            let header = MilestoneMonthHeader(text: monthFormatter.string(from: key).uppercased())
            timelineStack.addArrangedSubview(header)

            for (j, milestone) in group.enumerated() {
                let row = MilestoneTimelineRow(
                    milestone: milestone,
                    activation: activation
                )
                row.tapHandler = { [weak self] in self?.didTapMilestone(milestone) }
                timelineStack.addArrangedSubview(row)

                if j < group.count - 1 {
                    timelineStack.addArrangedSubview(LCDivider())
                }
            }

            if i < orderedKeys.count - 1 {
                let spacer = UIView()
                spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
                timelineStack.addArrangedSubview(spacer)
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapAdd() {
        lcHaptic(.light)
        presentEditor(for: nil)
    }

    private func didTapMilestone(_ entry: MilestoneEntry) {
        lcHaptic(.light)
        let alert = UIAlertController(
            title: "\(entry.emoji)  \(entry.typeLabel)",
            message: detailMessage(for: entry),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.presentEditor(for: entry)
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDelete(entry)
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    private func detailMessage(for entry: MilestoneEntry) -> String {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short
        var lines = [df.string(from: entry.achievedAt)]
        if let act = activation {
            let days = Int(entry.achievedAt.timeIntervalSince(act.achievedAt) / 86_400)
            if days >= 0 {
                lines.append("Day \(days) of hearing")
            }
        }
        if let acc = entry.accuracyAtMilestone {
            lines.append("Accuracy: \(Int(acc * 100))%")
        }
        if let notes = entry.notes, !notes.isEmpty {
            lines.append("\n\(notes)")
        }
        return lines.joined(separator: "\n")
    }

    private func confirmDelete(_ entry: MilestoneEntry) {
        let alert = UIAlertController(
            title: "Delete milestone?",
            message: "“\(entry.typeLabel)” will be removed. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteMilestone(entry)
        })
        present(alert, animated: true)
    }

    private func deleteMilestone(_ entry: MilestoneEntry) {
        Task {
            do {
                try await ServiceLocator.shared.milestoneService.delete(id: entry.id)
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.lcShowToast("Deleted",
                                     icon: "trash.fill",
                                     tint: .lcRed)
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
    }

    private func presentEditor(for entry: MilestoneEntry?) {
        let editor = EditMilestoneViewController(existing: entry)
        editor.onSave = { [weak self] in self?.loadData() }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .formSheet
        if let sheetCtrl = nav.sheetPresentationController {
            sheetCtrl.detents = [.medium(), .large()]
            sheetCtrl.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}

// MARK: - MilestoneMonthHeader

private final class MilestoneMonthHeader: UIView {
    init(text: String) {
        super.init(frame: .zero)
        let label = UILabel()
        label.text = text
        label.font = .lcCaption()
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - MilestoneTimelineRow

private final class MilestoneTimelineRow: UIControl {

    var tapHandler: (() -> Void)?

    init(milestone: MilestoneEntry, activation: MilestoneEntry?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.text = milestone.emoji
        emoji.font = .systemFont(ofSize: 30)
        emoji.translatesAutoresizingMaskIntoConstraints = false
        emoji.setContentHuggingPriority(.required, for: .horizontal)

        let title = UILabel()
        title.text = milestone.typeLabel
        title.font = .lcBodyBold()
        title.textColor = .label
        title.numberOfLines = 1

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        var subtitleParts: [String] = [df.string(from: milestone.achievedAt)]
        if let activation {
            let days = Int(milestone.achievedAt.timeIntervalSince(activation.achievedAt) / 86_400)
            if days >= 0 {
                subtitleParts.append("Day \(days)")
            }
        }
        if let notes = milestone.notes, !notes.isEmpty {
            subtitleParts.append(notes)
        }
        let subtitle = UILabel()
        subtitle.text = subtitleParts.joined(separator: "  •  ")
        subtitle.font = .lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let chevron = UIImageView(
            image: UIImage(systemName: "chevron.right",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        )
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [emoji, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])

        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func didTap() { tapHandler?() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.backgroundColor = self.isHighlighted
                    ? UIColor.systemFill.withAlphaComponent(0.4)
                    : .clear
            }
        }
    }
}
