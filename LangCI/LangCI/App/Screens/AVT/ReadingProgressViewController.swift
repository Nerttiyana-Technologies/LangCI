// ReadingProgressViewController.swift
// LangCI
//
// Dashboard showing reading-aloud progress over time.
// Groups sessions by day, shows trend stats for 7-day / 30-day / all-time
// windows, and a scrollable day-by-day breakdown with individual session rows.

import UIKit

final class ReadingProgressViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Period picker
    private let periodControl = UISegmentedControl(items: ["7 Days", "30 Days", "All Time"])

    // Summary stats card
    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?
    private let summaryEmptyLabel = UILabel()

    // Trend card (best / worst / streak)
    private let trendCard = LCCard()
    private let trendStack = UIStackView()

    // Day-by-day breakdown
    private let dailyCard = LCCard()
    private let dailyStack = UIStackView()

    // MARK: - State

    private var allSessions: [ReadingSession] = []
    private var filteredSessions: [ReadingSession] = []

    /// Grouped by calendar day, most recent first.
    private var dayGroups: [(date: Date, sessions: [ReadingSession])] = []

    private enum Period: Int {
        case week = 0, month, all
        var days: Int? {
            switch self {
            case .week:  return 7
            case .month: return 30
            case .all:   return nil
            }
        }
    }
    private var period: Period = .week

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reading Progress"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .lcBackground
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Build UI

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

        // Period picker
        periodControl.selectedSegmentIndex = 0
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        contentStack.addArrangedSubview(periodControl)

        // Summary card
        buildSummaryCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Overview", card: summaryCard))

        // Trend card
        buildTrendCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Highlights", card: trendCard))

        // Daily breakdown
        buildDailyCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Day by Day", card: dailyCard))
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
        summaryEmptyLabel.text = "No sessions in this period."
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
        summaryRow?.removeFromSuperview()
        summaryRow = nil

        guard !filteredSessions.isEmpty else {
            summaryEmptyLabel.isHidden = false
            return
        }
        summaryEmptyLabel.isHidden = true

        let count = filteredSessions.count
        let avgWPM = filteredSessions.map(\.wordsPerMinute).reduce(0, +) / Double(count)
        let avgDb  = filteredSessions.map(\.avgLoudnessDb).reduce(0, +) / Double(count)
        let pitchSamples = filteredSessions.filter { $0.avgPitchHz > 0 }
        let avgPitch = pitchSamples.isEmpty ? 0
            : pitchSamples.map(\.avgPitchHz).reduce(0, +) / Double(pitchSamples.count)

        let row = LCStatRow(items: [
            .init(label: "Sessions",  value: "\(count)",                          tint: .lcBlue),
            .init(label: "Avg WPM",   value: String(format: "%.0f", avgWPM),      tint: .lcPurple),
            .init(label: "Avg dB",    value: String(format: "%.0f", avgDb),        tint: .lcTeal),
            .init(label: "Avg Pitch", value: avgPitch > 0 ? String(format: "%.0f Hz", avgPitch) : "—", tint: .lcGreen)
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

    // MARK: - Trend card

    private func buildTrendCard() {
        trendStack.axis = .vertical
        trendStack.spacing = 10
        trendStack.translatesAutoresizingMaskIntoConstraints = false
        trendCard.addSubview(trendStack)
        NSLayoutConstraint.activate([
            trendStack.topAnchor.constraint(equalTo: trendCard.topAnchor, constant: LC.cardPadding),
            trendStack.leadingAnchor.constraint(equalTo: trendCard.leadingAnchor, constant: LC.cardPadding),
            trendStack.trailingAnchor.constraint(equalTo: trendCard.trailingAnchor, constant: -LC.cardPadding),
            trendStack.bottomAnchor.constraint(equalTo: trendCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateTrendCard() {
        trendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !filteredSessions.isEmpty else {
            let empty = UILabel()
            empty.text = "Read more passages to see trends."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            trendStack.addArrangedSubview(empty)
            return
        }

        let bestWPM = filteredSessions.max(by: { $0.wordsPerMinute < $1.wordsPerMinute })
        let totalTime = filteredSessions.map(\.durationSeconds).reduce(0, +)
        let totalWords = filteredSessions.map(\.wordCount).reduce(0, +)
        let uniqueDays = Set(filteredSessions.map { Calendar.current.startOfDay(for: $0.recordedAt) }).count

        if let best = bestWPM {
            addTrendRow(icon: "trophy.fill", color: .lcGold,
                        text: String(format: "Best speed: %.0f WPM — \"%@\"",
                                     best.wordsPerMinute, best.passageTitle))
        }

        addTrendRow(icon: "clock.fill", color: .lcBlue,
                    text: String(format: "Total practice: %@ across %d session%@",
                                 formatDuration(totalTime), filteredSessions.count,
                                 filteredSessions.count == 1 ? "" : "s"))

        addTrendRow(icon: "text.word.spacing", color: .lcPurple,
                    text: "\(totalWords) words read over \(uniqueDays) day\(uniqueDays == 1 ? "" : "s")")

        // Show improvement if enough sessions
        if filteredSessions.count >= 3 {
            let sorted = filteredSessions.sorted { $0.recordedAt < $1.recordedAt }
            let firstThird = Array(sorted.prefix(sorted.count / 3))
            let lastThird  = Array(sorted.suffix(sorted.count / 3))
            let earlyAvg = firstThird.map(\.wordsPerMinute).reduce(0, +) / Double(firstThird.count)
            let lateAvg  = lastThird.map(\.wordsPerMinute).reduce(0, +) / Double(lastThird.count)
            let diff = lateAvg - earlyAvg

            if abs(diff) >= 1 {
                let arrow = diff > 0 ? "arrow.up.right" : "arrow.down.right"
                let color: UIColor = diff > 0 ? .lcGreen : .lcOrange
                let direction = diff > 0 ? "up" : "down"
                addTrendRow(icon: arrow, color: color,
                            text: String(format: "WPM trend: %@ %.0f (%.0f → %.0f)",
                                         direction, abs(diff), earlyAvg, lateAvg))
            }
        }
    }

    private func addTrendRow(icon: String, color: UIColor, text: String) {
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = color
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 22).isActive = true
        imageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = text
        label.font = UIFont.lcBody()
        label.textColor = .label
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [imageView, label])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        trendStack.addArrangedSubview(row)
    }

    // MARK: - Daily card

    private func buildDailyCard() {
        dailyStack.axis = .vertical
        dailyStack.spacing = 0
        dailyStack.translatesAutoresizingMaskIntoConstraints = false
        dailyCard.addSubview(dailyStack)
        NSLayoutConstraint.activate([
            dailyStack.topAnchor.constraint(equalTo: dailyCard.topAnchor, constant: 4),
            dailyStack.leadingAnchor.constraint(equalTo: dailyCard.leadingAnchor),
            dailyStack.trailingAnchor.constraint(equalTo: dailyCard.trailingAnchor),
            dailyStack.bottomAnchor.constraint(equalTo: dailyCard.bottomAnchor, constant: -4)
        ])
    }

    private func updateDailyCard() {
        dailyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !dayGroups.isEmpty else {
            let empty = UILabel()
            empty.text = "No sessions yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            empty.translatesAutoresizingMaskIntoConstraints = false
            let wrap = UIView()
            wrap.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 20),
                empty.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -20),
                empty.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
                empty.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
            ])
            dailyStack.addArrangedSubview(wrap)
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        for (groupIndex, group) in dayGroups.enumerated() {
            // Day header
            let dayHeader = makeDayHeader(
                date: group.date,
                sessions: group.sessions,
                dateFormatter: dateFormatter
            )
            dailyStack.addArrangedSubview(dayHeader)

            // Individual session rows for this day
            for (sessionIndex, session) in group.sessions.enumerated() {
                let sessionRow = makeSessionRow(session: session, timeFormatter: timeFormatter)
                dailyStack.addArrangedSubview(sessionRow)

                if sessionIndex < group.sessions.count - 1 {
                    dailyStack.addArrangedSubview(indentedDivider())
                }
            }

            // Divider between day groups
            if groupIndex < dayGroups.count - 1 {
                let thick = UIView()
                thick.backgroundColor = .separator
                thick.translatesAutoresizingMaskIntoConstraints = false
                thick.heightAnchor.constraint(equalToConstant: 1).isActive = true
                dailyStack.addArrangedSubview(thick)
            }
        }
    }

    private func makeDayHeader(date: Date, sessions: [ReadingSession],
                                dateFormatter: DateFormatter) -> UIView {
        let cal = Calendar.current
        let dayLabel: String
        if cal.isDateInToday(date) {
            dayLabel = "Today"
        } else if cal.isDateInYesterday(date) {
            dayLabel = "Yesterday"
        } else {
            dayLabel = dateFormatter.string(from: date)
        }

        let avgWPM = sessions.map(\.wordsPerMinute).reduce(0, +) / Double(sessions.count)

        let dateText = UILabel()
        dateText.text = dayLabel
        dateText.font = UIFont.lcBodyBold()
        dateText.textColor = .label

        let statsText = UILabel()
        statsText.text = String(format: "%d session%@ • Avg %.0f WPM",
                                sessions.count,
                                sessions.count == 1 ? "" : "s",
                                avgWPM)
        statsText.font = UIFont.lcCaption()
        statsText.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [dateText, UIView(), statsText])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIView()
        wrap.backgroundColor = UIColor.systemFill.withAlphaComponent(0.15)
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
        ])
        return wrap
    }

    private func makeSessionRow(session: ReadingSession,
                                 timeFormatter: DateFormatter) -> UIView {
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
        badge.widthAnchor.constraint(equalToConstant: 42).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 42).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = session.passageTitle
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        let time = timeFormatter.string(from: session.recordedAt)
        let duration = formatDuration(session.durationSeconds)
        let dbStr = String(format: "%.0f dB", session.avgLoudnessDb)
        let pitchStr = session.avgPitchHz > 0 ? String(format: " • %.0f Hz", session.avgPitchHz) : ""

        let subtitleLabel = UILabel()
        subtitleLabel.text = "\(time) • \(duration) • \(dbStr)\(pitchStr)"
        subtitleLabel.font = UIFont.lcCaption()
        subtitleLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [badge, textStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIView()
        wrap.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
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
            div.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: LC.cardPadding + 54),
            div.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -LC.cardPadding)
        ])
        return wrap
    }

    // MARK: - Actions

    @objc private func periodChanged() {
        period = Period(rawValue: periodControl.selectedSegmentIndex) ?? .week
        applyFilter()
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                let sessions = try await ServiceLocator.shared.readingAloudService.getAllSessions()
                await MainActor.run {
                    self.allSessions = sessions
                    self.applyFilter()
                }
            } catch {
                // Silently fail — empty states handle it
            }
        }
    }

    private func applyFilter() {
        let cal = Calendar.current

        if let days = period.days {
            let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
            filteredSessions = allSessions.filter { $0.recordedAt >= cutoff }
        } else {
            filteredSessions = allSessions
        }

        // Group by calendar day
        let grouped = Dictionary(grouping: filteredSessions) { session in
            cal.startOfDay(for: session.recordedAt)
        }
        dayGroups = grouped
            .sorted { $0.key > $1.key }  // most recent day first
            .map { (date: $0.key, sessions: $0.value.sorted { $0.recordedAt > $1.recordedAt }) }

        updateSummaryCard()
        updateTrendCard()
        updateDailyCard()
    }

    // MARK: - Helpers

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
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
