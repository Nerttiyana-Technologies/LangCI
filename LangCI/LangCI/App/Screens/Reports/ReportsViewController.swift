// ReportsViewController.swift
// LangCI
//
// Redesigned Reports. Clean iOS-native layout:
//   • Large title nav
//   • Overall progress card with accuracy ring + 3 stat columns
//   • Level journey card with progress bar
//   • Badges horizontal scroll (or empty state)
//   • Training history as stack of LCCard rows
//   • Ling 6 trend as bar chart
//   • Fatigue trend as dot row
//   • Milestones as stack of LCCard rows
//
// Data layer (`ReportsViewModel`) is preserved verbatim.

import UIKit

final class ReportsViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingView = LCLoadingView(message: "Loading your reports…")

    // MARK: - Data

    private var viewModel = ReportsViewModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildScaffold()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Reports"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground
    }

    private func buildScaffold() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.alignment = .fill
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8, leading: 16, bottom: 32, trailing: 16
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)

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

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data

    private func loadData() {
        loadingView.isHidden = false
        scrollView.isHidden = true

        Task {
            do {
                try await viewModel.loadData()
                await MainActor.run {
                    self.loadingView.isHidden = true
                    self.scrollView.isHidden = false
                    self.renderSections()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.isHidden = true
                    self.scrollView.isHidden = false
                    self.lcShowToast("Couldn't load reports", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }

    // MARK: - Section rendering

    private func renderSections() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        contentStack.addArrangedSubview(buildOverviewSection())
        contentStack.addArrangedSubview(buildLevelJourneySection())
        contentStack.addArrangedSubview(buildBadgesSection())
        contentStack.addArrangedSubview(buildTrainingHistorySection())
        contentStack.addArrangedSubview(buildLing6TrendSection())
        contentStack.addArrangedSubview(buildFatigueTrendSection())
        contentStack.addArrangedSubview(buildMilestonesSection())
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let block = UIStackView(arrangedSubviews: [header, card])
        block.axis = .vertical
        block.spacing = 8
        return block
    }

    // MARK: - Overview

    private func buildOverviewSection() -> UIView {
        let card = LCCard()

        let ring = ProgressRingView(percentage: viewModel.overallAccuracy, color: .lcPurple)
        ring.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ring.widthAnchor.constraint(equalToConstant: 120),
            ring.heightAnchor.constraint(equalToConstant: 120)
        ])

        let ringWrap = UIStackView(arrangedSubviews: [ring])
        ringWrap.alignment = .center
        ringWrap.axis = .vertical

        let sessionsStat = StatCardView(
            icon: "square.stack.3d.up.fill",
            value: "\(viewModel.totalSessions)",
            label: "Sessions",
            tint: .lcBlue
        )
        let wordsStat = StatCardView(
            icon: "book.fill",
            value: "\(viewModel.totalWords)",
            label: "Words",
            tint: .lcGreen
        )
        let streakStat = StatCardView(
            icon: "flame.fill",
            value: "\(viewModel.currentStreak)",
            label: "Day Streak",
            tint: .lcOrange
        )
        let statsRow = UIStackView(arrangedSubviews: [sessionsStat, wordsStat, streakStat])
        statsRow.axis = .horizontal
        statsRow.spacing = 10
        statsRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [ringWrap, statsRow])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -LC.cardPadding)
        ])

        return sectionBlock(title: "Overall Accuracy", card: card)
    }

    // MARK: - Level journey

    private func buildLevelJourneySection() -> UIView {
        let card = LCCard()

        let currentLabel = UILabel()
        currentLabel.text = "Level \(viewModel.currentLevel)"
        currentLabel.font = UIFont.lcBodyBold()
        currentLabel.textColor = .lcPurple

        let nextLabel = UILabel()
        nextLabel.text = "Level \(viewModel.currentLevel + 1)"
        nextLabel.font = UIFont.lcBodyBold()
        nextLabel.textColor = .tertiaryLabel
        nextLabel.textAlignment = .right

        let labelsRow = UIStackView(arrangedSubviews: [currentLabel, nextLabel])
        labelsRow.axis = .horizontal
        labelsRow.distribution = .fillEqually

        let bar = ProgressBarView()
        bar.color = .lcPurple
        bar.setProgress(viewModel.levelProgress, animated: false)
        bar.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let pointsLabel = UILabel()
        pointsLabel.text = "\(viewModel.levelPoints) / \(viewModel.levelPointsNeeded) points"
        pointsLabel.font = UIFont.lcCaption()
        pointsLabel.textColor = .secondaryLabel
        pointsLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [labelsRow, bar, pointsLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -LC.cardPadding)
        ])

        return sectionBlock(title: "Level Journey", card: card)
    }

    // MARK: - Badges

    private func buildBadgesSection() -> UIView {
        let card = LCCard()

        if viewModel.badges.isEmpty {
            let empty = EmptyStateView(
                icon: "star.fill",
                title: "No Badges Yet",
                message: "Keep training to unlock badges!",
                tint: .lcGold
            )
            empty.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
                empty.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
                empty.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
                empty.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
                empty.heightAnchor.constraint(equalToConstant: 120)
            ])
        } else {
            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            scroll.translatesAutoresizingMaskIntoConstraints = false

            let hstack = UIStackView()
            hstack.axis = .horizontal
            hstack.spacing = 12
            hstack.alignment = .top
            hstack.translatesAutoresizingMaskIntoConstraints = false

            for badge in viewModel.badges {
                hstack.addArrangedSubview(BadgeTileView(badge: badge))
            }

            scroll.addSubview(hstack)
            card.contentView.addSubview(scroll)

            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
                scroll.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
                scroll.heightAnchor.constraint(equalToConstant: 130),

                hstack.topAnchor.constraint(equalTo: scroll.topAnchor),
                hstack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                hstack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
                hstack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
                hstack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
            ])
        }

        return sectionBlock(title: "Badges", card: card)
    }

    // MARK: - Training history

    private func buildTrainingHistorySection() -> UIView {
        if viewModel.recentSessions.isEmpty {
            let empty = EmptyStateView(
                icon: "list.clipboard.fill",
                title: "No Sessions Yet",
                message: "Start training to see your history",
                tint: .lcBlue
            )
            empty.heightAnchor.constraint(equalToConstant: 140).isActive = true
            return sectionBlock(title: "Training History", card: empty)
        }

        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (i, session) in viewModel.recentSessions.enumerated() {
            stack.addArrangedSubview(TrainingSessionRowView(session: session))
            if i < viewModel.recentSessions.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
        }

        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -4)
        ])

        return sectionBlock(title: "Training History", card: card)
    }

    // MARK: - Ling 6 trend

    private func buildLing6TrendSection() -> UIView {
        let card = LCCard()

        if viewModel.ling6Sessions.isEmpty {
            let empty = UILabel()
            empty.text = "No Ling 6 tests yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .secondaryLabel
            empty.textAlignment = .center
            empty.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 20),
                empty.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
                empty.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
                empty.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -20)
            ])
        } else {
            let chart = Ling6BarChartView(sessions: viewModel.ling6Sessions)
            chart.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(chart)
            NSLayoutConstraint.activate([
                chart.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
                chart.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 12),
                chart.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -12),
                chart.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
                chart.heightAnchor.constraint(equalToConstant: 140)
            ])
        }

        return sectionBlock(title: "Ling 6 Trend", card: card)
    }

    // MARK: - Fatigue trend

    private func buildFatigueTrendSection() -> UIView {
        let card = LCCard()

        if viewModel.fatigueEntries.isEmpty {
            let empty = UILabel()
            empty.text = "No fatigue entries yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .secondaryLabel
            empty.textAlignment = .center
            empty.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 20),
                empty.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
                empty.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
                empty.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -20)
            ])
        } else {
            let dots = FatigueDotRowView(entries: viewModel.fatigueEntries)
            dots.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(dots)
            NSLayoutConstraint.activate([
                dots.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
                dots.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
                dots.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
                dots.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
                dots.heightAnchor.constraint(equalToConstant: 46)
            ])
        }

        return sectionBlock(title: "Fatigue Trend (Last 7 Days)", card: card)
    }

    // MARK: - Milestones

    private func buildMilestonesSection() -> UIView {
        if viewModel.milestones.isEmpty {
            let empty = EmptyStateView(
                icon: "flag.fill",
                title: "No Milestones",
                message: "Keep learning to achieve milestones",
                tint: .lcPurple
            )
            empty.heightAnchor.constraint(equalToConstant: 140).isActive = true
            return sectionBlock(title: "Milestones", card: empty)
        }

        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (i, milestone) in viewModel.milestones.enumerated() {
            stack.addArrangedSubview(MilestoneRowView(milestone: milestone))
            if i < viewModel.milestones.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
        }

        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -4)
        ])

        return sectionBlock(title: "Milestones", card: card)
    }
}

// MARK: - ProgressRingView

private final class ProgressRingView: UIView {
    private let backgroundLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let percentLabel = UILabel()

    init(percentage: Double, color: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundLayer.strokeColor = UIColor.systemFill.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 10
        layer.addSublayer(backgroundLayer)

        progressLayer.strokeColor = color.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 10
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)

        percentLabel.text = "\(Int(percentage))%"
        percentLabel.font = UIFont.lcHeroTitle()
        percentLabel.textColor = color
        percentLabel.textAlignment = .center
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(percentLabel)

        NSLayoutConstraint.activate([
            percentLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        self.percentage = percentage
    }

    required init?(coder: NSCoder) { fatalError() }

    private var percentage: Double = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.width, bounds.height) / 2 - 8
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        let bgPath = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        )
        backgroundLayer.path = bgPath.cgPath

        let progPath = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: -.pi / 2,
            endAngle: -.pi / 2 + .pi * 2 * CGFloat(percentage / 100),
            clockwise: true
        )
        progressLayer.path = progPath.cgPath
    }
}

// MARK: - BadgeTileView

private final class BadgeTileView: UIView {
    init(badge: BadgeDto) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .lcCard
        layer.cornerRadius = LC.cornerRadius
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor

        let emoji = UILabel()
        emoji.text = badge.emoji
        emoji.font = UIFont.systemFont(ofSize: 40)
        emoji.textAlignment = .center
        emoji.alpha = badge.isEarned ? 1.0 : 0.35

        let title = UILabel()
        title.text = badge.title
        title.font = UIFont.lcCaption()
        title.textColor = badge.isEarned ? .label : .tertiaryLabel
        title.textAlignment = .center
        title.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [emoji, title])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            widthAnchor.constraint(equalToConstant: 92),
            heightAnchor.constraint(equalToConstant: 110)
        ])

        if badge.isEarned {
            let check = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
            check.tintColor = .lcGreen
            check.translatesAutoresizingMaskIntoConstraints = false
            addSubview(check)
            NSLayoutConstraint.activate([
                check.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                check.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                check.widthAnchor.constraint(equalToConstant: 16),
                check.heightAnchor.constraint(equalToConstant: 16)
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - TrainingSessionRowView

private final class TrainingSessionRowView: UIView {
    init(session: TrainingSession) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        let icon = UILabel()
        icon.text = Self.modeIcon(session.trainingMode)
        icon.font = UIFont.systemFont(ofSize: 22)
        icon.textAlignment = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let df = DateFormatter()
        df.dateStyle = .medium

        let title = UILabel()
        title.text = df.string(from: session.startedAt)
        title.font = UIFont.lcBodyBold()
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "\(session.completedWords)/\(session.totalWords) words"
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let accuracy = session.totalWords > 0
            ? Double(session.completedWords) / Double(session.totalWords) * 100
            : 0
        let accLabel = UILabel()
        accLabel.text = "\(Int(accuracy))%"
        accLabel.font = UIFont.lcBodyBold()
        accLabel.textColor = accuracy >= 80 ? .lcGreen : (accuracy >= 50 ? .lcAmber : .lcRed)
        accLabel.textAlignment = .right

        let duration = session.completedAt.map { Int($0.timeIntervalSince(session.startedAt)) } ?? 0
        let durLabel = UILabel()
        durLabel.text = "\(duration)s"
        durLabel.font = UIFont.lcCaption()
        durLabel.textColor = .tertiaryLabel
        durLabel.textAlignment = .right

        let trailingStack = UIStackView(arrangedSubviews: [accLabel, durLabel])
        trailingStack.axis = .vertical
        trailingStack.alignment = .trailing
        trailingStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, titleStack, trailingStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func modeIcon(_ mode: TrainingMode) -> String {
        switch mode {
        case .standard: return "📚"
        case .noisyEnvironment: return "🔊"
        case .minimalPairs: return "👂"
        }
    }
}

// MARK: - Ling6BarChartView

private final class Ling6BarChartView: UIView {
    private let sessions: [Ling6Session]

    init(sessions: [Ling6Session]) {
        self.sessions = sessions
        super.init(frame: .zero)
        backgroundColor = .clear

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let hstack = UIStackView()
        hstack.axis = .horizontal
        hstack.spacing = 10
        hstack.alignment = .bottom
        hstack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(hstack)

        NSLayoutConstraint.activate([
            hstack.topAnchor.constraint(equalTo: scroll.topAnchor),
            hstack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            hstack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 8),
            hstack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -8),
            hstack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        let maxValue: Double = 6
        for session in sessions {
            let col = Self.makeColumn(for: session, maxValue: maxValue)
            hstack.addArrangedSubview(col)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeColumn(for session: Ling6Session, maxValue: Double) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false

        let value = Double(session.detectedCount)
        let tint: UIColor = value >= 6 ? .lcGreen : (value >= 4 ? .lcAmber : .lcRed)

        let bar = UIView()
        bar.backgroundColor = tint
        bar.layer.cornerRadius = 5
        bar.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = "\(session.detectedCount)"
        valueLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        valueLabel.textColor = tint
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let df = DateFormatter()
        df.dateFormat = "M/d"
        let dateLabel = UILabel()
        dateLabel.text = df.string(from: session.testedAt)
        dateLabel.font = UIFont.systemFont(ofSize: 10)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.textAlignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        wrap.addSubview(valueLabel)
        wrap.addSubview(bar)
        wrap.addSubview(dateLabel)

        let heightRatio = CGFloat(value / maxValue)
        NSLayoutConstraint.activate([
            wrap.widthAnchor.constraint(equalToConstant: 32),

            valueLabel.topAnchor.constraint(equalTo: wrap.topAnchor),
            valueLabel.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),

            bar.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            bar.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            bar.widthAnchor.constraint(equalToConstant: 24),

            dateLabel.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 4),
            dateLabel.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),

            bar.heightAnchor.constraint(equalTo: wrap.heightAnchor, multiplier: max(0.05, heightRatio * 0.72))
        ])

        return wrap
    }
}

// MARK: - FatigueDotRowView

private final class FatigueDotRowView: UIView {
    init(entries: [FatigueEntry]) {
        super.init(frame: .zero)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        for entry in entries {
            let dot = UIView()
            dot.backgroundColor = Self.color(for: entry.fatigueLevel)
            dot.layer.cornerRadius = 14
            dot.layer.borderWidth = 2
            dot.layer.borderColor = UIColor.lcCard.cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.heightAnchor.constraint(equalToConstant: 28).isActive = true
            dot.widthAnchor.constraint(equalToConstant: 28).isActive = true
            stack.addArrangedSubview(dot)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func color(for level: Int) -> UIColor {
        switch level {
        case 1: return .lcGreen
        case 2: return .lcTeal
        case 3: return .lcAmber
        case 4, 5: return .lcRed
        default: return .systemGray3
        }
    }
}

// MARK: - MilestoneRowView

private final class MilestoneRowView: UIView {
    init(milestone: MilestoneEntry) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        let emoji = UILabel()
        emoji.text = milestone.emoji
        emoji.font = UIFont.systemFont(ofSize: 26)
        emoji.textAlignment = .center
        emoji.translatesAutoresizingMaskIntoConstraints = false
        emoji.widthAnchor.constraint(equalToConstant: 40).isActive = true

        let title = UILabel()
        title.text = milestone.typeLabel
        title.font = UIFont.lcBodyBold()
        title.textColor = .label
        title.numberOfLines = 2

        let df = DateFormatter()
        df.dateStyle = .medium
        let date = UILabel()
        date.text = df.string(from: milestone.achievedAt)
        date.font = UIFont.lcCaption()
        date.textColor = .lcGreen
        date.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [emoji, title, date])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - View Model (unchanged data loading contract)

final class ReportsViewModel {

    var overallAccuracy: Double = 0
    var totalSessions: Int = 0
    var totalWords: Int = 0
    var currentStreak: Int = 0
    var currentLevel: Int = 1
    var levelProgress: Double = 0
    var levelPoints: Int = 0
    var levelPointsNeeded: Int = 100

    var badges: [BadgeDto] = []
    var recentSessions: [TrainingSession] = []
    var ling6Sessions: [Ling6Session] = []
    var fatigueEntries: [FatigueEntry] = []
    var milestones: [MilestoneEntry] = []

    func loadData() async throws {
        let sl = ServiceLocator.shared
        async let badgesResult     = sl.progressService.getAllBadges()
        async let sessionsResult   = sl.trainingService.getRecentSessions(count: 10)
        async let ling6Result      = sl.ling6Service.getRecentSessions(count: 7)
        async let fatigueResult    = sl.fatigueService.getEntries(days: 7)
        async let milestonesResult = sl.milestoneService.getAll()
        async let statsResult      = sl.progressService.getHomeStats()

        self.badges          = try await badgesResult
        self.recentSessions  = try await sessionsResult
        self.ling6Sessions   = try await ling6Result
        self.fatigueEntries  = try await fatigueResult
        self.milestones      = try await milestonesResult

        let stats            = try await statsResult
        self.totalSessions   = stats.totalSessions
        self.totalWords      = stats.wordsLearned
        self.overallAccuracy = stats.overallAccuracy
        self.currentStreak   = stats.currentStreak
        self.currentLevel    = stats.currentLevel
        self.levelPoints     = stats.pointsForCurrentLevel
        self.levelPointsNeeded = stats.pointsForNextLevel
        self.levelProgress   = stats.pointsForNextLevel > 0
            ? Double(stats.totalPoints - stats.pointsForCurrentLevel) /
              Double(stats.pointsForNextLevel - stats.pointsForCurrentLevel)
            : 1.0
    }
}
