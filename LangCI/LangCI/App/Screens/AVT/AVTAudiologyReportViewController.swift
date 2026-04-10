// AVTAudiologyReportViewController.swift
// LangCI
//
// Clinician-facing Audiology Report. Aggregates everything an audiologist
// needs in one clean scroll:
//
//   • Header summary: client snapshot + report date + share button
//   • Listening hierarchy overview (counts at each level)
//   • AVT progress per sound (level + accuracy + trend)
//   • Ling 6 performance summary + per-sound breakdown
//   • Recent AVT session history
//   • Fatigue trend summary
//   • Mapping snapshot (latest appointment + active electrodes)
//   • Audiologist notes timeline
//   • Export action uses UIActivityViewController with a formatted text dump.
//
// Visually follows the LangCI clean iOS-native design language: large title
// navigation, LCCard-based sections, SectionHeaderView, LCStatRow summaries,
// and consistent colour tinting via UIColor.lc* tokens.

import UIKit

final class AVTAudiologyReportViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingView = LCLoadingView()

    // Section containers we rebuild after data load
    private let headerCard = LCCard()
    private let headerStack = UIStackView()

    private let hierarchyCard = LCCard()
    private let hierarchyStack = UIStackView()

    private let progressCard = LCCard()
    private let progressStack = UIStackView()

    private let ling6Card = LCCard()
    private let ling6Stack = UIStackView()

    private let sessionsCard = LCCard()
    private let sessionsStack = UIStackView()

    private let fatigueCard = LCCard()
    private let fatigueStack = UIStackView()

    private let mappingCard = LCCard()
    private let mappingStack = UIStackView()

    private let notesCard = LCCard()
    private let notesStack = UIStackView()

    // MARK: - Data

    private var targets: [AVTTarget] = []
    private var progress: [AVTProgressDto] = []
    private var homeStats: AVTHomeStats?
    private var recentSessions: [AVTSession] = []
    private var notes: [AVTAudiologistNote] = []
    private var ling6Stats: Ling6StatsDto?
    private var recentLing6: [Ling6Session] = []
    private var fatigueStats: FatigueStatsDto?
    private var latestMapping: MappingSession?

    // MARK: - Formatters

    private lazy var reportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    private lazy var shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Audiology Report"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let share = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(didTapShare)
        )
        share.tintColor = .lcPurple
        navigationItem.rightBarButtonItem = share
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

        // Wire loading indicator into the view hierarchy
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Create every card up-front so the scroll layout is stable.
        prepareStack(headerStack, inside: headerCard)
        prepareStack(hierarchyStack, inside: hierarchyCard)
        prepareStack(progressStack, inside: progressCard)
        prepareStack(ling6Stack, inside: ling6Card)
        prepareStack(sessionsStack, inside: sessionsCard)
        prepareStack(fatigueStack, inside: fatigueCard)
        prepareStack(mappingStack, inside: mappingCard)
        prepareStack(notesStack, inside: notesCard)

        contentStack.addArrangedSubview(headerCard)
        contentStack.addArrangedSubview(sectionBlock(title: "Listening Hierarchy", card: hierarchyCard))
        contentStack.addArrangedSubview(sectionBlock(title: "Sound Progress", card: progressCard))
        contentStack.addArrangedSubview(sectionBlock(title: "Ling 6 Performance", card: ling6Card))
        contentStack.addArrangedSubview(sectionBlock(title: "Recent AVT Sessions", card: sessionsCard))
        contentStack.addArrangedSubview(sectionBlock(title: "Fatigue Trend", card: fatigueCard))
        contentStack.addArrangedSubview(sectionBlock(title: "Mapping Snapshot", card: mappingCard))
        contentStack.addArrangedSubview(sectionBlock(title: "Audiologist Notes", card: notesCard))

        // Hide the scroll content until data is ready.
        contentStack.alpha = 0
    }

    private func prepareStack(_ stack: UIStackView, inside card: LCCard) {
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Data load

    private func loadData() {
        loadingView.isHidden = false
        let svc = ServiceLocator.shared

        Task {
            async let targetsTask = svc.avtService.getAllTargets()
            async let progressTask = svc.avtService.getProgress()
            async let statsTask = svc.avtService.getHomeStats()
            async let sessionsTask = svc.avtService.getRecentSessions(count: 10)
            async let notesTask = svc.avtService.getNotes()
            async let ling6StatsTask = svc.ling6Service.getStats()
            async let ling6SessionsTask = svc.ling6Service.getRecentSessions(count: 5)
            async let fatigueStatsTask = svc.fatigueService.getStats(days: 14)
            async let mappingTask = svc.mappingService.getLatestSession()

            do {
                let t   = try await targetsTask
                let p   = try await progressTask
                let hs  = try await statsTask
                let rs  = try await sessionsTask
                let ns  = try await notesTask
                let l6s = try await ling6StatsTask
                let l6r = try await ling6SessionsTask
                let ft  = try await fatigueStatsTask
                let ms  = try await mappingTask

                await MainActor.run {
                    self.targets = t
                    self.progress = p
                    self.homeStats = hs
                    self.recentSessions = rs
                    self.notes = ns
                    self.ling6Stats = l6s
                    self.recentLing6 = l6r
                    self.fatigueStats = ft
                    self.latestMapping = ms
                    self.populate()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.isHidden = true
                    self.lcShowToast(
                        "Couldn't build report",
                        icon: "xmark.octagon.fill",
                        tint: .lcRed
                    )
                }
            }
        }
    }

    // MARK: - Populate sections

    private func populate() {
        populateHeader()
        populateHierarchy()
        populateProgress()
        populateLing6()
        populateSessions()
        populateFatigue()
        populateMapping()
        populateNotes()

        loadingView.isHidden = true
        UIView.animate(withDuration: 0.25) {
            self.contentStack.alpha = 1
        }
    }

    // MARK: Header

    private func populateHeader() {
        headerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Top row: icon + titles
        let icon = UIImageView(image: UIImage(
            systemName: "doc.text.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        ))
        icon.tintColor = .lcPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let title = UILabel()
        title.text = "Progress Summary"
        title.font = UIFont.lcHeroTitle()
        title.textColor = .label
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7

        let subtitle = UILabel()
        subtitle.text = reportDateFormatter.string(from: Date())
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel

        let titleColumn = UIStackView(arrangedSubviews: [title, subtitle])
        titleColumn.axis = .vertical
        titleColumn.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [icon, titleColumn])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12
        headerStack.addArrangedSubview(topRow)

        headerStack.addArrangedSubview(LCDivider())

        // Summary stat row
        let active = homeStats?.activeTargets ?? targets.filter { $0.isActive }.count
        let accuracy = homeStats?.overallAccuracy ?? 0
        let streak = homeStats?.streakDays ?? 0

        let stats = LCStatRow(items: [
            .init(label: "Targets", value: "\(active)", tint: .lcPurple),
            .init(label: "Accuracy", value: String(format: "%.0f%%", accuracy), tint: .lcGreen),
            .init(label: "Streak", value: "\(streak)d", tint: .lcOrange)
        ])
        headerStack.addArrangedSubview(stats)

        if let focus = homeStats?.currentFocusSound, !focus.isEmpty {
            let focusLabel = UILabel()
            focusLabel.text = "Current focus: \(focus)"
            focusLabel.font = UIFont.lcCaption()
            focusLabel.textColor = .tertiaryLabel
            focusLabel.textAlignment = .center
            headerStack.addArrangedSubview(focusLabel)
        }
    }

    // MARK: Hierarchy

    private func populateHierarchy() {
        hierarchyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let levels: [ListeningHierarchy] = [.detection, .discrimination, .identification, .comprehension]

        for level in levels {
            let count = targets.filter { $0.isActive && $0.currentLevel == level }.count
            let row = HierarchyRowView(level: level, count: count, total: max(targets.count, 1))
            hierarchyStack.addArrangedSubview(row)
        }

        if targets.isEmpty {
            let empty = UILabel()
            empty.text = "No active targets on file."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            hierarchyStack.addArrangedSubview(empty)
        }
    }

    // MARK: Per-sound progress

    private func populateProgress() {
        progressStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if progress.isEmpty {
            let empty = UILabel()
            empty.text = "No progress data yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            progressStack.addArrangedSubview(empty)
            return
        }

        for (index, item) in progress.enumerated() {
            progressStack.addArrangedSubview(SoundProgressRowView(dto: item))
            if index < progress.count - 1 {
                progressStack.addArrangedSubview(LCDivider())
            }
        }
    }

    // MARK: Ling 6

    private func populateLing6() {
        ling6Stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let stats = ling6Stats, stats.totalSessions > 0 else {
            let empty = UILabel()
            empty.text = "No Ling 6 sessions recorded."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            ling6Stack.addArrangedSubview(empty)
            return
        }

        let row = LCStatRow(items: [
            .init(label: "Sessions", value: "\(stats.totalSessions)", tint: .lcBlue),
            .init(label: "Detection", value: String(format: "%.0f%%", stats.avgDetectionRate), tint: .lcTeal),
            .init(label: "Recognition", value: String(format: "%.0f%%", stats.avgRecognitionRate), tint: .lcGreen)
        ])
        ling6Stack.addArrangedSubview(row)

        if !stats.perSoundAccuracy.isEmpty {
            ling6Stack.addArrangedSubview(LCDivider())

            let header = UILabel()
            header.text = "Per-sound accuracy"
            header.font = UIFont.lcBodyBold()
            header.textColor = .secondaryLabel
            ling6Stack.addArrangedSubview(header)

            for sound in stats.perSoundAccuracy {
                ling6Stack.addArrangedSubview(Ling6SoundRowView(sound: sound))
            }
        }

        if let last = recentLing6.first {
            let footer = UILabel()
            footer.text = "Last session: \(shortDateFormatter.string(from: last.testedAt))"
            footer.font = UIFont.lcCaption()
            footer.textColor = .tertiaryLabel
            footer.textAlignment = .center
            ling6Stack.addArrangedSubview(footer)
        }
    }

    // MARK: Sessions

    private func populateSessions() {
        sessionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if recentSessions.isEmpty {
            let empty = UILabel()
            empty.text = "No AVT sessions yet."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            sessionsStack.addArrangedSubview(empty)
            return
        }

        for (index, session) in recentSessions.enumerated() {
            sessionsStack.addArrangedSubview(SessionHistoryRowView(
                session: session,
                dateFormatter: shortDateFormatter
            ))
            if index < recentSessions.count - 1 {
                sessionsStack.addArrangedSubview(LCDivider())
            }
        }
    }

    // MARK: Fatigue

    private func populateFatigue() {
        fatigueStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let stats = fatigueStats, stats.totalEntries > 0 else {
            let empty = UILabel()
            empty.text = "No fatigue data logged."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            fatigueStack.addArrangedSubview(empty)
            return
        }

        let row = LCStatRow(items: [
            .init(label: "Entries", value: "\(stats.totalEntries)", tint: .lcBlue),
            .init(label: "Avg Effort", value: String(format: "%.1f", stats.avgEffort), tint: .lcOrange),
            .init(label: "Avg Fatigue", value: String(format: "%.1f", stats.avgFatigue), tint: .lcRed)
        ])
        fatigueStack.addArrangedSubview(row)

        if !stats.hardestEnv.isEmpty || !stats.easiestEnv.isEmpty {
            fatigueStack.addArrangedSubview(LCDivider())

            if !stats.hardestEnv.isEmpty {
                fatigueStack.addArrangedSubview(bulletRow(
                    icon: "exclamationmark.triangle.fill",
                    tint: .lcRed,
                    title: "Hardest environment",
                    value: stats.hardestEnv
                ))
            }
            if !stats.easiestEnv.isEmpty {
                fatigueStack.addArrangedSubview(bulletRow(
                    icon: "leaf.fill",
                    tint: .lcGreen,
                    title: "Easiest environment",
                    value: stats.easiestEnv
                ))
            }
        }
    }

    // MARK: Mapping

    private func populateMapping() {
        mappingStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let mapping = latestMapping else {
            let empty = UILabel()
            empty.text = "No mapping session recorded."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            mappingStack.addArrangedSubview(empty)
            return
        }

        let top = LCStatRow(items: [
            .init(label: "Active", value: "\(mapping.activeElectrodes)", tint: .lcGreen),
            .init(label: "Inactive", value: "\(mapping.inactiveElectrodes)", tint: .lcRed),
            .init(
                label: "Next",
                value: mapping.hasNextAppointment ? "\(mapping.daysUntilNext)d" : "—",
                tint: .lcOrange
            )
        ])
        mappingStack.addArrangedSubview(top)
        mappingStack.addArrangedSubview(LCDivider())

        if !mapping.audiologistName.isEmpty {
            mappingStack.addArrangedSubview(bulletRow(
                icon: "person.fill",
                tint: .lcPurple,
                title: "Audiologist",
                value: mapping.audiologistName
            ))
        }
        if !mapping.clinicName.isEmpty {
            mappingStack.addArrangedSubview(bulletRow(
                icon: "building.2.fill",
                tint: .lcBlue,
                title: "Clinic",
                value: mapping.clinicName
            ))
        }
        mappingStack.addArrangedSubview(bulletRow(
            icon: "calendar",
            tint: .lcTeal,
            title: "Session date",
            value: shortDateFormatter.string(from: mapping.sessionDate)
        ))
        if let next = mapping.nextAppointmentDate {
            mappingStack.addArrangedSubview(bulletRow(
                icon: "calendar.badge.clock",
                tint: .lcOrange,
                title: "Next appointment",
                value: shortDateFormatter.string(from: next)
            ))
        }
    }

    // MARK: Notes

    private func populateNotes() {
        notesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if notes.isEmpty {
            let empty = UILabel()
            empty.text = "No audiologist notes on file."
            empty.font = UIFont.lcBody()
            empty.textColor = .tertiaryLabel
            empty.textAlignment = .center
            notesStack.addArrangedSubview(empty)
            return
        }

        // Show up to 5 most recent
        let shown = Array(notes.prefix(5))
        for (index, note) in shown.enumerated() {
            notesStack.addArrangedSubview(NoteTimelineRowView(
                note: note,
                dateFormatter: shortDateFormatter
            ))
            if index < shown.count - 1 {
                notesStack.addArrangedSubview(LCDivider())
            }
        }
    }

    // MARK: - Helpers

    private func bulletRow(icon: String, tint: UIColor, title: String, value: String) -> UIView {
        let iconView = UIImageView(image: UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        ))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.lcCaption()
        titleLabel.textColor = .secondaryLabel
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.lcBodyBold()
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), valueLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }

    // MARK: - Share

    @objc private func didTapShare() {
        lcHaptic(.light)
        let text = buildShareText()
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activity, animated: true)
    }

    private func buildShareText() -> String {
        var lines: [String] = []
        lines.append("LangCI — Audiology Report")
        lines.append("Generated: \(reportDateFormatter.string(from: Date()))")
        lines.append(String(repeating: "─", count: 36))

        if let hs = homeStats {
            lines.append("")
            lines.append("SUMMARY")
            lines.append("• Active targets: \(hs.activeTargets)")
            lines.append("• Sessions today: \(hs.sessionsToday)")
            lines.append("• Overall accuracy: \(String(format: "%.0f%%", hs.overallAccuracy))")
            lines.append("• Streak: \(hs.streakDays) day(s)")
            if !hs.currentFocusSound.isEmpty {
                lines.append("• Current focus: \(hs.currentFocusSound)")
            }
        }

        if !targets.isEmpty {
            lines.append("")
            lines.append("LISTENING HIERARCHY")
            for level in [ListeningHierarchy.detection, .discrimination, .identification, .comprehension] {
                let count = targets.filter { $0.isActive && $0.currentLevel == level }.count
                lines.append("• \(level.label): \(count)")
            }
        }

        if !progress.isEmpty {
            lines.append("")
            lines.append("SOUND PROGRESS")
            for p in progress {
                let trend: String
                switch p.trend {
                case .improving:  trend = "↑"
                case .stable:     trend = "→"
                case .needsWork:  trend = "↓"
                }
                lines.append(
                    "• /\(p.phonemeIpa)/ \(p.sound) — \(p.currentLevel.label) — "
                    + "\(p.totalSessions) sessions — \(String(format: "%.0f%%", p.recentAccuracy)) \(trend)"
                )
            }
        }

        if let l6 = ling6Stats, l6.totalSessions > 0 {
            lines.append("")
            lines.append("LING 6")
            lines.append("• Total sessions: \(l6.totalSessions)")
            lines.append("• Avg detection: \(String(format: "%.0f%%", l6.avgDetectionRate))")
            lines.append("• Avg recognition: \(String(format: "%.0f%%", l6.avgRecognitionRate))")
            for s in l6.perSoundAccuracy {
                lines.append(
                    "   – \(s.sound) (\(s.freqHz) Hz): "
                    + "det \(String(format: "%.0f%%", s.detectionPct)) · "
                    + "rec \(String(format: "%.0f%%", s.recognitionPct))"
                )
            }
        }

        if !recentSessions.isEmpty {
            lines.append("")
            lines.append("RECENT AVT SESSIONS")
            for s in recentSessions {
                lines.append(
                    "• \(shortDateFormatter.string(from: s.startedAt)) — "
                    + "\(s.targetSound) (\(s.hierarchyLevel.label)) — "
                    + "\(s.correctAttempts)/\(s.totalAttempts) (\(String(format: "%.0f%%", s.accuracy)))"
                )
            }
        }

        if let f = fatigueStats, f.totalEntries > 0 {
            lines.append("")
            lines.append("FATIGUE (last 14 days)")
            lines.append("• Entries: \(f.totalEntries)")
            lines.append("• Avg effort: \(String(format: "%.1f", f.avgEffort))")
            lines.append("• Avg fatigue: \(String(format: "%.1f", f.avgFatigue))")
            if !f.hardestEnv.isEmpty { lines.append("• Hardest env: \(f.hardestEnv)") }
            if !f.easiestEnv.isEmpty { lines.append("• Easiest env: \(f.easiestEnv)") }
        }

        if let m = latestMapping {
            lines.append("")
            lines.append("MAPPING")
            lines.append("• Session date: \(shortDateFormatter.string(from: m.sessionDate))")
            if !m.audiologistName.isEmpty { lines.append("• Audiologist: \(m.audiologistName)") }
            if !m.clinicName.isEmpty { lines.append("• Clinic: \(m.clinicName)") }
            lines.append("• Active electrodes: \(m.activeElectrodes)")
            lines.append("• Inactive electrodes: \(m.inactiveElectrodes)")
            if let next = m.nextAppointmentDate {
                lines.append("• Next appointment: \(shortDateFormatter.string(from: next))")
            }
        }

        if !notes.isEmpty {
            lines.append("")
            lines.append("AUDIOLOGIST NOTES")
            for n in notes.prefix(5) {
                lines.append("• \(shortDateFormatter.string(from: n.notedAt)) — [\(n.targetSoundList.joined(separator: ", "))]")
                let body = n.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    lines.append("   \(body)")
                }
            }
        }

        lines.append("")
        lines.append(String(repeating: "─", count: 36))
        lines.append("Generated by LangCI")

        return lines.joined(separator: "\n")
    }
}

// MARK: - HierarchyRowView

private final class HierarchyRowView: UIView {
    init(level: ListeningHierarchy, count: Int, total: Int) {
        super.init(frame: .zero)
        build(level: level, count: count, total: total)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(level: ListeningHierarchy, count: Int, total: Int) {
        translatesAutoresizingMaskIntoConstraints = false

        let emoji = UILabel()
        emoji.text = level.emoji
        emoji.font = UIFont.systemFont(ofSize: 22)
        emoji.translatesAutoresizingMaskIntoConstraints = false
        emoji.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let name = UILabel()
        name.text = level.label
        name.font = UIFont.lcBodyBold()
        name.textColor = .label

        let countLabel = UILabel()
        countLabel.text = "\(count)"
        countLabel.font = UIFont.lcCardValue()
        countLabel.textColor = level.color
        countLabel.textAlignment = .right

        let progress = ProgressBarView()
        progress.color = level.color
        progress.setProgress(total > 0 ? Double(count) / Double(total) : 0, animated: false)
        progress.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [emoji, name, UIView(), countLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [topRow, progress])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            progress.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
}

// MARK: - SoundProgressRowView

private final class SoundProgressRowView: UIView {
    init(dto: AVTProgressDto) {
        super.init(frame: .zero)
        build(dto: dto)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(dto: AVTProgressDto) {
        translatesAutoresizingMaskIntoConstraints = false

        // Colour-coded sound badge
        let badge = UILabel()
        badge.text = "/\(dto.phonemeIpa)/"
        badge.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = dto.currentLevel.color
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        let name = UILabel()
        name.text = dto.sound.uppercased()
        name.font = UIFont.lcBodyBold()
        name.textColor = .label

        let meta = UILabel()
        meta.text = "\(dto.currentLevel.label) · \(dto.totalSessions) sessions"
        meta.font = UIFont.lcCaption()
        meta.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [name, meta])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let accuracy = UILabel()
        accuracy.text = String(format: "%.0f%%", dto.recentAccuracy)
        accuracy.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        accuracy.textColor = dto.currentLevel.color
        accuracy.textAlignment = .right

        let trend = UILabel()
        switch dto.trend {
        case .improving:
            trend.text = "↑"
            trend.textColor = .lcGreen
        case .stable:
            trend.text = "→"
            trend.textColor = .lcAmber
        case .needsWork:
            trend.text = "↓"
            trend.textColor = .lcRed
        }
        trend.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        trend.textAlignment = .center
        trend.translatesAutoresizingMaskIntoConstraints = false
        trend.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let row = UIStackView(arrangedSubviews: [badge, titleStack, UIView(), accuracy, trend])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 46),
            badge.heightAnchor.constraint(equalToConstant: 32),

            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
}

// MARK: - Ling6SoundRowView

private final class Ling6SoundRowView: UIView {
    init(sound: Ling6SoundAccuracy) {
        super.init(frame: .zero)
        build(sound: sound)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(sound: Ling6SoundAccuracy) {
        translatesAutoresizingMaskIntoConstraints = false

        let soundLabel = UILabel()
        soundLabel.text = "\(sound.sound)  /\(sound.ipaSymbol)/"
        soundLabel.font = UIFont.lcBodyBold()
        soundLabel.textColor = .label

        let freq = UILabel()
        freq.text = "\(sound.freqHz) Hz"
        freq.font = UIFont.lcCaption()
        freq.textColor = .secondaryLabel

        let left = UIStackView(arrangedSubviews: [soundLabel, freq])
        left.axis = .vertical
        left.spacing = 2

        let detection = UILabel()
        detection.text = "det \(Int(sound.detectionPct))%"
        detection.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        detection.textColor = .lcTeal

        let recognition = UILabel()
        recognition.text = "rec \(Int(sound.recognitionPct))%"
        recognition.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        recognition.textColor = .lcGreen

        let right = UIStackView(arrangedSubviews: [detection, recognition])
        right.axis = .vertical
        right.alignment = .trailing
        right.spacing = 2

        let row = UIStackView(arrangedSubviews: [left, UIView(), right])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}

// MARK: - SessionHistoryRowView

private final class SessionHistoryRowView: UIView {
    init(session: AVTSession, dateFormatter: DateFormatter) {
        super.init(frame: .zero)
        build(session: session, dateFormatter: dateFormatter)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(session: AVTSession, dateFormatter: DateFormatter) {
        translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.backgroundColor = session.hierarchyLevel.color
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let title = UILabel()
        title.text = "\(session.targetSound.uppercased()) · \(session.hierarchyLevel.label)"
        title.font = UIFont.lcBodyBold()
        title.textColor = .label

        let meta = UILabel()
        meta.text = "\(dateFormatter.string(from: session.startedAt)) · \(session.correctAttempts)/\(session.totalAttempts)"
        meta.font = UIFont.lcCaption()
        meta.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [title, meta])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let accuracy = UILabel()
        accuracy.text = String(format: "%.0f%%", session.accuracy)
        accuracy.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        accuracy.textColor = session.hierarchyLevel.color
        accuracy.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [dot, titleStack, UIView(), accuracy])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
}

// MARK: - NoteTimelineRowView

private final class NoteTimelineRowView: UIView {
    init(note: AVTAudiologistNote, dateFormatter: DateFormatter) {
        super.init(frame: .zero)
        build(note: note, dateFormatter: dateFormatter)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(note: AVTAudiologistNote, dateFormatter: DateFormatter) {
        translatesAutoresizingMaskIntoConstraints = false

        let date = UILabel()
        date.text = dateFormatter.string(from: note.notedAt)
        date.font = UIFont.lcCaption()
        date.textColor = .secondaryLabel

        let sounds = UILabel()
        sounds.text = note.targetSoundList.isEmpty
            ? "—"
            : note.targetSoundList.joined(separator: ", ")
        sounds.font = UIFont.lcBodyBold()
        sounds.textColor = .lcPurple
        sounds.numberOfLines = 1

        let topRow = UIStackView(arrangedSubviews: [sounds, UIView(), date])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let body = UILabel()
        let preview = note.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        body.text = preview.isEmpty ? "(no notes)" : preview
        body.font = UIFont.lcBody()
        body.textColor = .label
        body.numberOfLines = 0

        var arranged: [UIView] = [topRow, body]
        if let next = note.nextAppointment {
            let nextLabel = UILabel()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            nextLabel.text = "Next: \(formatter.string(from: next))"
            nextLabel.font = UIFont.lcCaption()
            nextLabel.textColor = .tertiaryLabel
            arranged.append(nextLabel)
        }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}
