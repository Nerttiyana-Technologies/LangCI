// CIHubViewController.swift
// LangCI
//
// Redesigned CI Hub hub screen. Clean iOS-native look:
//   • Large title nav
//   • Stat row card (Ling6 today • Streak • Last mapping)
//   • Tools list — rows with icons + trailing chevron, grouped in LCCard
//   • Fatigue snapshot card with avg effort & fatigue
//   • Quick-action start button for a new Ling 6 test

import UIKit

final class CIHubViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Summary stat row
    private let summaryCard = LCCard()
    private var summaryRow: LCStatRow?

    // Tool rows container
    private let toolsCard = LCCard()

    // Fatigue snapshot
    private let fatigueCard = LCCard()
    private let fatigueTitleLabel = UILabel()
    private var fatigueStatRow: LCStatRow?
    private let fatigueSubtitleLabel = UILabel()

    // Quick action
    private let quickStartButton = LCButton(title: "Start a Ling 6 Test", color: .lcTeal)

    // MARK: - State

    private var ling6Stats: Ling6StatsDto?
    private var mappingSessions: [MappingSession] = []
    private var fatigueStats: FatigueStatsDto?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadCIHubData()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "CI Hub"
        navigationController?.navigationBar.prefersLargeTitles = true
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

        // 1. Summary card
        buildSummaryCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Today", card: summaryCard))

        // 2. Tools
        buildToolsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Audiological Tools", card: toolsCard))

        // 3. Fatigue snapshot
        buildFatigueCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Listening Fatigue (7 days)", card: fatigueCard))

        // 4. Quick start
        quickStartButton.addTarget(self, action: #selector(didTapLing6), for: .touchUpInside)
        quickStartButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(quickStartButton)
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
        rebuildSummaryRow(ling6Today: false, streak: 0, lastMappingDesc: "—")
    }

    private func rebuildSummaryRow(ling6Today: Bool, streak: Int, lastMappingDesc: String) {
        summaryRow?.removeFromSuperview()
        let row = LCStatRow(items: [
            .init(label: "Ling 6", value: ling6Today ? "Done" : "Todo", tint: ling6Today ? .lcGreen : .lcOrange),
            .init(label: "Streak", value: "\(streak)d", tint: .lcTeal),
            .init(label: "Last Map", value: lastMappingDesc, tint: .lcPurple)
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

    // MARK: - Tools card

    private func buildToolsCard() {
        let ling6Row = makeToolRow(icon: "waveform",
                                   title: "Ling 6 Test",
                                   subtitle: "Quick 6-sound listening check",
                                   tint: .lcTeal,
                                   action: #selector(didTapLing6))

        let mappingRow = makeToolRow(icon: "slider.horizontal.3",
                                     title: "Electrode Mapping",
                                     subtitle: "Record T/C levels & notes",
                                     tint: .lcPurple,
                                     action: #selector(didTapMapping))

        let fatigueRow = makeToolRow(icon: "bolt.heart",
                                     title: "Fatigue Journal",
                                     subtitle: "Log listening effort & fatigue",
                                     tint: .lcAmber,
                                     action: #selector(didTapFatigue))

        let minimalRow = makeToolRow(icon: "waveform.and.magnifyingglass",
                                     title: "Minimal Pairs",
                                     subtitle: "Fine-tune sound discrimination",
                                     tint: .lcBlue,
                                     action: #selector(didTapMinimalPairs))

        let musicRow = makeToolRow(icon: "music.note",
                                   title: "Music Perception",
                                   subtitle: "Rhythm, melody & pitch",
                                   tint: .lcRed,
                                   action: #selector(didTapMusic))

        let detectionRow = makeToolRow(icon: "ear.trianglebadge.exclamationmark",
                                       title: "Sound Detection Test",
                                       subtitle: "Audiologist grid & self-test",
                                       tint: .lcOrange,
                                       action: #selector(didTapSoundDetection))

        let inner = UIStackView(arrangedSubviews: [
            ling6Row, LCDivider(),
            detectionRow, LCDivider(),
            mappingRow, LCDivider(),
            fatigueRow, LCDivider(),
            minimalRow, LCDivider(),
            musicRow
        ])
        inner.axis = .vertical
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false

        toolsCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: toolsCard.topAnchor, constant: 4),
            inner.leadingAnchor.constraint(equalTo: toolsCard.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: toolsCard.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: toolsCard.bottomAnchor, constant: -4)
        ])
    }

    private func makeToolRow(icon: String,
                             title: String,
                             subtitle: String,
                             tint: UIColor,
                             action: Selector) -> LCListRow {
        let row = LCListRow(icon: icon, title: title, subtitle: subtitle, tint: tint)
        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    // MARK: - Fatigue card

    private func buildFatigueCard() {
        fatigueTitleLabel.text = "No entries yet"
        fatigueTitleLabel.font = UIFont.lcBodyBold()
        fatigueTitleLabel.textColor = .label
        fatigueTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        fatigueSubtitleLabel.text = "Log a day in the Fatigue Journal to see your trend."
        fatigueSubtitleLabel.font = UIFont.lcCaption()
        fatigueSubtitleLabel.textColor = .secondaryLabel
        fatigueSubtitleLabel.numberOfLines = 0
        fatigueSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView(arrangedSubviews: [fatigueTitleLabel, fatigueSubtitleLabel])
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false

        fatigueCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: fatigueCard.topAnchor, constant: LC.cardPadding),
            inner.leadingAnchor.constraint(equalTo: fatigueCard.leadingAnchor, constant: LC.cardPadding),
            inner.trailingAnchor.constraint(equalTo: fatigueCard.trailingAnchor, constant: -LC.cardPadding),
            inner.bottomAnchor.constraint(equalTo: fatigueCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateFatigueCard() {
        guard let stats = fatigueStats, stats.totalEntries > 0 else {
            fatigueTitleLabel.text = "No entries yet"
            fatigueSubtitleLabel.text = "Log a day in the Fatigue Journal to see your trend."
            fatigueStatRow?.removeFromSuperview()
            fatigueStatRow = nil
            return
        }

        // Replace labels with stat row
        fatigueTitleLabel.isHidden = true
        fatigueSubtitleLabel.isHidden = true

        fatigueStatRow?.removeFromSuperview()
        let effortStr = String(format: "%.1f", stats.avgEffort)
        let fatigueStr = String(format: "%.1f", stats.avgFatigue)
        let row = LCStatRow(items: [
            .init(label: "Avg Effort", value: effortStr, tint: .lcOrange),
            .init(label: "Avg Fatigue", value: fatigueStr, tint: .lcRed),
            .init(label: "Entries", value: "\(stats.totalEntries)", tint: .lcTeal)
        ])
        fatigueCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: fatigueCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: fatigueCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: fatigueCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: fatigueCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        fatigueStatRow = row
    }

    // MARK: - Data

    private func loadCIHubData() {
        Task {
            do {
                async let ling6 = ServiceLocator.shared.ling6Service.getStats()
                async let mappings = ServiceLocator.shared.mappingService.getAllSessions()
                async let fatigue = ServiceLocator.shared.fatigueService.getStats(days: 7)

                let (l, m, f) = try await (ling6, mappings, fatigue)

                await MainActor.run {
                    self.ling6Stats = l
                    self.mappingSessions = m
                    self.fatigueStats = f
                    self.updateSummaryUI()
                    self.updateFatigueCard()
                }
            } catch {
                // Silently fail — we still show blank cards
            }
        }
    }

    private func updateSummaryUI() {
        let ling6Today = ling6Stats?.testedToday ?? false
        let streak = ling6Stats?.currentStreak ?? 0

        let lastDesc: String
        if let last = mappingSessions.first?.sessionDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if days == 0 { lastDesc = "Today" }
            else if days == 1 { lastDesc = "1d" }
            else if days < 30 { lastDesc = "\(days)d" }
            else { lastDesc = "\(days / 30)mo" }
        } else {
            lastDesc = "—"
        }

        rebuildSummaryRow(ling6Today: ling6Today, streak: streak, lastMappingDesc: lastDesc)
    }

    // MARK: - Navigation

    @objc private func didTapLing6() {
        lcHaptic(.light)
        navigationController?.pushViewController(Ling6TestViewController(), animated: true)
    }

    @objc private func didTapMapping() {
        lcHaptic(.light)
        navigationController?.pushViewController(MappingViewController(), animated: true)
    }

    @objc private func didTapFatigue() {
        lcHaptic(.light)
        navigationController?.pushViewController(FatigueJournalViewController(), animated: true)
    }

    @objc private func didTapMinimalPairs() {
        lcHaptic(.light)
        navigationController?.pushViewController(MinimalPairsViewController(), animated: true)
    }

    @objc private func didTapSoundDetection() {
        lcHaptic(.light)
        navigationController?.pushViewController(SoundDetectionHomeViewController(), animated: true)
    }

    @objc private func didTapMusic() {
        lcHaptic(.light)
        let alert = UIAlertController(
            title: "Music Perception",
            message: "This feature is on the way. Stay tuned!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
