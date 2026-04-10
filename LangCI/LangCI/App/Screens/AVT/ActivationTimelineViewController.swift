// ActivationTimelineViewController.swift
// LangCI
//
// Shows the user's progress since their cochlear implant was activated.
// Features:
//   • Hero card: hearing age (days / weeks / months since activation)
//   • Week-by-week AVT session count + accuracy
//   • Per-sound accuracy trend (most practiced sounds first)
//   • Confusion-pair count trend (did "said X, heard Y" moments drop?)
//   • Reading Aloud WPM trend (if any sessions exist)
//
// If no activation date is set, the screen shows a friendly CTA pointing
// the user back to Settings to set it.

import UIKit

final class ActivationTimelineViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Empty state
    private let emptyCard = LCCard()
    private let emptyStack = UIStackView()

    // Hero
    private let heroCard = LCCard()
    private let heroEmojiLabel = UILabel()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    private let heroDateLabel = UILabel()

    // Overall summary
    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?

    // Per-sound card
    private let perSoundCard = LCCard()
    private let perSoundStack = UIStackView()

    // Confusion trend
    private let confusionCard = LCCard()
    private let confusionContentStack = UIStackView()

    // Reading trend
    private let readingCard = LCCard()
    private let readingContentStack = UIStackView()

    // MARK: - State

    private var activation: MilestoneEntry?
    private var avtSessions: [AVTSession] = []
    private var confusionPairs: [ConfusionPair] = []
    private var readingSessions: [ReadingSession] = []

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
        title = "Activation Timeline"
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

        buildEmptyCard()
        contentStack.addArrangedSubview(emptyCard)
        emptyCard.isHidden = true

        buildHeroCard()
        contentStack.addArrangedSubview(heroCard)

        buildSummaryCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Since Activation", card: summaryCard))

        buildPerSoundCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Per-Sound Accuracy", card: perSoundCard))

        buildConfusionCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Confusions", card: confusionCard))

        buildReadingCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Reading Aloud", card: readingCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Empty card

    private func buildEmptyCard() {
        emptyStack.axis = .vertical
        emptyStack.spacing = 12
        emptyStack.alignment = .center
        emptyStack.translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.text = "👂"
        emoji.font = UIFont.systemFont(ofSize: 56)
        emoji.textAlignment = .center

        let title = UILabel()
        title.text = "Set Your Activation Date"
        title.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = .label
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Go to Settings → My Journey → CI Activation Date to start tracking your progress from day one."
        subtitle.font = UIFont.lcBody()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        emptyStack.addArrangedSubview(emoji)
        emptyStack.addArrangedSubview(title)
        emptyStack.addArrangedSubview(subtitle)

        emptyCard.addSubview(emptyStack)
        NSLayoutConstraint.activate([
            emptyStack.topAnchor.constraint(equalTo: emptyCard.topAnchor, constant: 32),
            emptyStack.bottomAnchor.constraint(equalTo: emptyCard.bottomAnchor, constant: -32),
            emptyStack.leadingAnchor.constraint(equalTo: emptyCard.leadingAnchor, constant: LC.cardPadding),
            emptyStack.trailingAnchor.constraint(equalTo: emptyCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - Hero card

    private func buildHeroCard() {
        heroEmojiLabel.text = "🎉"
        heroEmojiLabel.font = UIFont.systemFont(ofSize: 44)
        heroEmojiLabel.textAlignment = .center

        heroTitleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        heroTitleLabel.textColor = .lcPurple
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.numberOfLines = 0

        heroSubtitleLabel.font = UIFont.lcBodyBold()
        heroSubtitleLabel.textColor = .label
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.numberOfLines = 0

        heroDateLabel.font = UIFont.lcCaption()
        heroDateLabel.textColor = .secondaryLabel
        heroDateLabel.textAlignment = .center
        heroDateLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [heroEmojiLabel, heroTitleLabel, heroSubtitleLabel, heroDateLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        heroCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateHeroCard() {
        guard let activation = activation else { return }
        let days = daysSince(activation.achievedAt)
        heroTitleLabel.text = "Day \(days)"
        heroSubtitleLabel.text = hearingAgeDescription(days: days)

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        heroDateLabel.text = "Activated \(formatter.string(from: activation.achievedAt))"
    }

    private func hearingAgeDescription(days: Int) -> String {
        if days == 0 { return "Activation day 🎉" }
        if days < 7 { return "\(days) day\(days == 1 ? "" : "s") of hearing" }
        if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s") of hearing"
        }
        if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s") of hearing"
        }
        let years = days / 365
        let extraMonths = (days % 365) / 30
        if extraMonths == 0 {
            return "\(years) year\(years == 1 ? "" : "s") of hearing"
        }
        return "\(years)y \(extraMonths)m of hearing"
    }

    // MARK: - Summary card

    private func buildSummaryCard() {
        // Empty by default
    }

    private func updateSummaryCard() {
        summaryRow?.removeFromSuperview()
        summaryRow = nil
        summaryCard.subviews.forEach { $0.removeFromSuperview() }

        let sessionCount = avtSessions.count
        let totalAttempts = avtSessions.reduce(0) { $0 + $1.totalAttempts }
        let totalCorrect = avtSessions.reduce(0) { $0 + $1.correctAttempts }
        let overallAccuracy = totalAttempts > 0
            ? Double(totalCorrect) / Double(totalAttempts) * 100
            : 0
        let confusionCount = confusionPairs.count

        let row = LCStatRow(items: [
            .init(label: "Sessions",    value: "\(sessionCount)",               tint: .lcBlue),
            .init(label: "Accuracy",    value: String(format: "%.0f%%", overallAccuracy), tint: .lcGreen),
            .init(label: "Confusions",  value: "\(confusionCount)",             tint: .lcOrange),
            .init(label: "Reads",       value: "\(readingSessions.count)",      tint: .lcPurple)
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

    // MARK: - Per-sound card

    private func buildPerSoundCard() {
        perSoundStack.axis = .vertical
        perSoundStack.spacing = 14
        perSoundStack.translatesAutoresizingMaskIntoConstraints = false
        perSoundCard.addSubview(perSoundStack)
        NSLayoutConstraint.activate([
            perSoundStack.topAnchor.constraint(equalTo: perSoundCard.topAnchor, constant: LC.cardPadding),
            perSoundStack.leadingAnchor.constraint(equalTo: perSoundCard.leadingAnchor, constant: LC.cardPadding),
            perSoundStack.trailingAnchor.constraint(equalTo: perSoundCard.trailingAnchor, constant: -LC.cardPadding),
            perSoundStack.bottomAnchor.constraint(equalTo: perSoundCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updatePerSoundCard() {
        perSoundStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        struct SoundStat {
            var sound: String
            var totalAttempts: Int
            var correct: Int
            var sessionCount: Int
            var accuracy: Double {
                totalAttempts > 0
                    ? Double(correct) / Double(totalAttempts) * 100
                    : 0
            }
        }

        var dict: [String: SoundStat] = [:]
        for session in avtSessions {
            let key = session.targetSound
            var stat = dict[key] ?? SoundStat(
                sound: key,
                totalAttempts: 0,
                correct: 0,
                sessionCount: 0
            )
            stat.totalAttempts += session.totalAttempts
            stat.correct       += session.correctAttempts
            stat.sessionCount  += 1
            dict[key] = stat
        }

        let stats = dict.values
            .sorted { $0.sessionCount > $1.sessionCount }
            .prefix(8)

        if stats.isEmpty {
            let empty = UILabel()
            empty.text = "No AVT drill sessions yet. Start a drill from the AVT screen."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.numberOfLines = 0
            empty.textAlignment = .center
            perSoundStack.addArrangedSubview(empty)
            return
        }

        for stat in stats {
            perSoundStack.addArrangedSubview(makeSoundRow(
                sound: stat.sound,
                accuracy: stat.accuracy,
                sessionCount: stat.sessionCount
            ))
        }
    }

    private func makeSoundRow(sound: String, accuracy: Double, sessionCount: Int) -> UIView {
        let soundLabel = UILabel()
        soundLabel.text = sound
        soundLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        soundLabel.textColor = .label
        soundLabel.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let countLabel = UILabel()
        countLabel.text = "\(sessionCount) session\(sessionCount == 1 ? "" : "s")"
        countLabel.font = UIFont.lcCaption()
        countLabel.textColor = .secondaryLabel

        let percentLabel = UILabel()
        percentLabel.text = String(format: "%.0f%%", accuracy)
        percentLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        percentLabel.textColor = colorForAccuracy(accuracy)
        percentLabel.textAlignment = .right

        let topRow = UIStackView(arrangedSubviews: [soundLabel, countLabel, UIView(), percentLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let bar = ProgressBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.heightAnchor.constraint(equalToConstant: 6).isActive = true
        bar.setProgress(CGFloat(accuracy / 100.0))

        let stack = UIStackView(arrangedSubviews: [topRow, bar])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    private func colorForAccuracy(_ acc: Double) -> UIColor {
        if acc >= 80 { return .lcGreen }
        if acc >= 60 { return .lcBlue }
        if acc >= 40 { return .lcAmber }
        return .lcOrange
    }

    // MARK: - Confusion card

    private func buildConfusionCard() {
        confusionContentStack.axis = .vertical
        confusionContentStack.spacing = 10
        confusionContentStack.translatesAutoresizingMaskIntoConstraints = false
        confusionCard.addSubview(confusionContentStack)
        NSLayoutConstraint.activate([
            confusionContentStack.topAnchor.constraint(equalTo: confusionCard.topAnchor, constant: LC.cardPadding),
            confusionContentStack.leadingAnchor.constraint(equalTo: confusionCard.leadingAnchor, constant: LC.cardPadding),
            confusionContentStack.trailingAnchor.constraint(equalTo: confusionCard.trailingAnchor, constant: -LC.cardPadding),
            confusionContentStack.bottomAnchor.constraint(equalTo: confusionCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateConfusionCard() {
        confusionContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if confusionPairs.isEmpty {
            let empty = UILabel()
            empty.text = "No confusion pairs logged yet. Track moments when you hear something different from what was said."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.numberOfLines = 0
            empty.textAlignment = .center
            confusionContentStack.addArrangedSubview(empty)
            return
        }

        // Compute pairs-per-week since activation
        guard let activation = activation else { return }
        let weeks = max(1, (daysSince(activation.achievedAt) + 6) / 7)
        let weekBuckets = bucketConfusions(weeks: weeks, activation: activation.achievedAt)

        let total = UILabel()
        total.text = "\(confusionPairs.count) confusion\(confusionPairs.count == 1 ? "" : "s") logged"
        total.font = UIFont.lcBodyBold()
        total.textColor = .label
        confusionContentStack.addArrangedSubview(total)

        let subtitle = UILabel()
        subtitle.text = weeks == 1
            ? "This week"
            : "Across \(weeks) weeks since activation"
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        confusionContentStack.addArrangedSubview(subtitle)

        let chart = MiniBarChartView(values: weekBuckets.map { Double($0) },
                                     tint: .lcOrange)
        chart.heightAnchor.constraint(equalToConstant: 80).isActive = true
        confusionContentStack.addArrangedSubview(chart)

        let hint = UILabel()
        let current = weekBuckets.last ?? 0
        let previous = weekBuckets.dropLast().last ?? 0
        if weeks >= 2 && current < previous {
            hint.text = "Trending down — nice progress!"
            hint.textColor = .lcGreen
        } else if weeks >= 2 && current > previous {
            hint.text = "This week has more entries than last — keep logging so you notice patterns."
            hint.textColor = .lcAmber
        } else {
            hint.text = "Each week shows the number of confusions you logged."
            hint.textColor = .secondaryLabel
        }
        hint.font = UIFont.lcCaption()
        hint.numberOfLines = 0
        confusionContentStack.addArrangedSubview(hint)
    }

    private func bucketConfusions(weeks: Int, activation: Date) -> [Int] {
        var buckets = Array(repeating: 0, count: weeks)
        let calendar = Calendar.current
        for pair in confusionPairs {
            let days = calendar.dateComponents([.day], from: activation, to: pair.loggedAt).day ?? 0
            guard days >= 0 else { continue }
            let week = min(weeks - 1, days / 7)
            buckets[week] += 1
        }
        return buckets
    }

    // MARK: - Reading card

    private func buildReadingCard() {
        readingContentStack.axis = .vertical
        readingContentStack.spacing = 10
        readingContentStack.translatesAutoresizingMaskIntoConstraints = false
        readingCard.addSubview(readingContentStack)
        NSLayoutConstraint.activate([
            readingContentStack.topAnchor.constraint(equalTo: readingCard.topAnchor, constant: LC.cardPadding),
            readingContentStack.leadingAnchor.constraint(equalTo: readingCard.leadingAnchor, constant: LC.cardPadding),
            readingContentStack.trailingAnchor.constraint(equalTo: readingCard.trailingAnchor, constant: -LC.cardPadding),
            readingContentStack.bottomAnchor.constraint(equalTo: readingCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateReadingCard() {
        readingContentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if readingSessions.isEmpty {
            let empty = UILabel()
            empty.text = "No reading-aloud sessions yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.numberOfLines = 0
            empty.textAlignment = .center
            readingContentStack.addArrangedSubview(empty)
            return
        }

        let sorted = readingSessions.sorted { $0.recordedAt < $1.recordedAt }
        let wpmValues = sorted.map { $0.wordsPerMinute }

        let title = UILabel()
        let best = wpmValues.max() ?? 0
        let latest = wpmValues.last ?? 0
        title.text = "Latest \(Int(latest.rounded())) WPM • Best \(Int(best.rounded())) WPM"
        title.font = UIFont.lcBodyBold()
        title.textColor = .label
        readingContentStack.addArrangedSubview(title)

        let chart = MiniLineChartView(values: wpmValues, tint: .lcPurple)
        chart.heightAnchor.constraint(equalToConstant: 80).isActive = true
        readingContentStack.addArrangedSubview(chart)

        let hint = UILabel()
        if wpmValues.count >= 2 {
            let first = wpmValues.first ?? 0
            let diff = latest - first
            if diff > 5 {
                hint.text = String(format: "You're \(Int(diff)) WPM faster than your first read. Great progress!")
                hint.textColor = .lcGreen
            } else if diff < -5 {
                hint.text = "Your WPM has dropped slightly — try a lighter passage to rebuild confidence."
                hint.textColor = .lcAmber
            } else {
                hint.text = "Your pace is steady — try a harder passage to stretch it."
                hint.textColor = .secondaryLabel
            }
        } else {
            hint.text = "Read more passages to see your trend."
            hint.textColor = .secondaryLabel
        }
        hint.font = UIFont.lcCaption()
        hint.numberOfLines = 0
        readingContentStack.addArrangedSubview(hint)
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                let activation = try await ServiceLocator.shared.milestoneService.getActivation()

                await MainActor.run {
                    self.activation = activation
                }

                guard let activation = activation else {
                    await MainActor.run {
                        self.emptyCard.isHidden = false
                        self.heroCard.isHidden = true
                        self.summaryCard.superview?.isHidden = true
                        self.perSoundCard.superview?.isHidden = true
                        self.confusionCard.superview?.isHidden = true
                        self.readingCard.superview?.isHidden = true
                    }
                    return
                }

                async let avtTask        = ServiceLocator.shared.avtService.getRecentSessions(count: 200)
                async let confusionTask  = ServiceLocator.shared.confusionPairService.getRecentPairs(limit: 500)
                async let readingTask    = ServiceLocator.shared.readingAloudService.getRecentSessions(limit: 100)

                let avtAll      = try await avtTask
                let confusionAll = try await confusionTask
                let readingAll  = try await readingTask

                // Filter to post-activation
                let cutoff = Calendar.current.startOfDay(for: activation.achievedAt)
                let avtFiltered       = avtAll.filter { $0.startedAt >= cutoff }
                let confusionFiltered = confusionAll.filter { $0.loggedAt >= cutoff }
                let readingFiltered   = readingAll.filter { $0.recordedAt >= cutoff }

                await MainActor.run {
                    self.emptyCard.isHidden = true
                    self.heroCard.isHidden = false
                    self.summaryCard.superview?.isHidden = false
                    self.perSoundCard.superview?.isHidden = false
                    self.confusionCard.superview?.isHidden = false
                    self.readingCard.superview?.isHidden = false

                    self.avtSessions     = avtFiltered
                    self.confusionPairs  = confusionFiltered
                    self.readingSessions = readingFiltered
                    self.updateHeroCard()
                    self.updateSummaryCard()
                    self.updatePerSoundCard()
                    self.updateConfusionCard()
                    self.updateReadingCard()
                }
            } catch {
                // Silently fail
            }
        }
    }

    // MARK: - Helpers

    private func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

// MARK: - MiniBarChartView

final class MiniBarChartView: UIView {

    private let values: [Double]
    private let tint: UIColor

    init(values: [Double], tint: UIColor) {
        self.values = values
        self.tint = tint
        super.init(frame: .zero)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard !values.isEmpty, let ctx = UIGraphicsGetCurrentContext() else { return }
        let maxValue = max(values.max() ?? 0, 1)
        let barCount = CGFloat(values.count)
        let spacing: CGFloat = 4
        let totalSpacing = spacing * (barCount - 1)
        let availableWidth = rect.width - totalSpacing
        let barWidth = max(2, availableWidth / barCount)

        ctx.setFillColor(tint.cgColor)
        for (index, value) in values.enumerated() {
            let h = CGFloat(value / maxValue) * rect.height
            let x = CGFloat(index) * (barWidth + spacing)
            let y = rect.height - h
            let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: min(3, barWidth / 2))
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }
}

// MARK: - MiniLineChartView

final class MiniLineChartView: UIView {

    private let values: [Double]
    private let tint: UIColor

    init(values: [Double], tint: UIColor) {
        self.values = values
        self.tint = tint
        super.init(frame: .zero)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard values.count >= 2, let ctx = UIGraphicsGetCurrentContext() else {
            drawSinglePoint(in: rect, ctx: UIGraphicsGetCurrentContext())
            return
        }
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        let range = max(maxValue - minValue, 1)

        let step = rect.width / CGFloat(values.count - 1)

        ctx.setStrokeColor(tint.cgColor)
        ctx.setLineWidth(2.5)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        let path = UIBezierPath()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / range
            let y = rect.height - (CGFloat(normalized) * (rect.height - 8)) - 4
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.addPath(path.cgPath)
        ctx.strokePath()

        // Points
        ctx.setFillColor(tint.cgColor)
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / range
            let y = rect.height - (CGFloat(normalized) * (rect.height - 8)) - 4
            let circle = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            ctx.fillEllipse(in: circle)
        }
    }

    private func drawSinglePoint(in rect: CGRect, ctx: CGContext?) {
        guard let ctx = ctx, let value = values.first else { return }
        _ = value
        ctx.setFillColor(tint.cgColor)
        let midX = rect.width / 2
        let midY = rect.height / 2
        ctx.fillEllipse(in: CGRect(x: midX - 4, y: midY - 4, width: 8, height: 8))
    }
}
