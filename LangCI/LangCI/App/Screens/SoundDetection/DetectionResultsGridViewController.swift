// DetectionResultsGridViewController.swift
// LangCI — Results grid view for Sound Detection Test
//
// Shows the full tracking matrix exactly like the audiologist's paper:
//   Columns = sounds (a, e, mm, o, sh, ush, ...)
//   Rows    = trials (1, 2, 3, ... 9)
//   Cells   = ✓ (green), ✗ (red), ~ (amber), — (not tested)
//
// Plus a summary row at bottom showing per-sound accuracy percentages.

import UIKit

final class DetectionResultsGridViewController: UIViewController {

    // MARK: - Data

    private let sessionId: Int
    private let service = ServiceLocator.shared.soundDetectionService!

    private var session: DetectionTestSession?
    private var sounds: [TestSound] = []
    private var trials: [DetectionTrial] = []
    private var scores: [SoundScore] = []

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(sessionId: Int) {
        self.sessionId = sessionId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Results"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        buildShell()
        loadData()
    }

    private func buildShell() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 12, leading: 12, bottom: 40, trailing: 12)
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func loadData() {
        Task {
            session = try? await service.getSession(id: sessionId)
            sounds = (try? await service.getActiveSounds()) ?? []
            trials = (try? await service.getTrials(forSession: sessionId)) ?? []
            scores = (try? await service.getSessionScores(sessionId: sessionId)) ?? []

            await MainActor.run { self.buildResults() }
        }
    }

    // MARK: - Build Results

    private func buildResults() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let session = session else { return }

        // Session info header
        contentStack.addArrangedSubview(buildSessionHeader(session))

        // The Grid
        contentStack.addArrangedSubview(buildGrid(session))

        // Per-sound accuracy summary
        contentStack.addArrangedSubview(buildScoreSummary())

        // Notes
        if let notes = session.notes, !notes.isEmpty {
            let notesCard = LCCard()
            let lbl = UILabel()
            lbl.text = "Notes: \(notes)"
            lbl.font = UIFont.lcBody()
            lbl.textColor = .secondaryLabel
            lbl.numberOfLines = 0
            lbl.translatesAutoresizingMaskIntoConstraints = false
            notesCard.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: 12),
                lbl.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -12),
                lbl.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 12),
                lbl.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -12),
            ])
            contentStack.addArrangedSubview(notesCard)
        }

        // Done button
        let done = LCButton(title: "Done", color: .lcTeal)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(done)
    }

    private func buildSessionHeader(_ session: DetectionTestSession) -> LCCard {
        let card = LCCard()

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short

        // Patient name as the main title (if present), else the date
        let titleLabel = UILabel()
        if let patient = session.patientName, !patient.isEmpty {
            titleLabel.text = patient
            titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        } else {
            titleLabel.text = formatter.string(from: session.testedAt)
            titleLabel.font = UIFont.lcBodyBold()
        }
        titleLabel.textColor = .label

        // Date + mode + tester combined
        let modeText = session.mode == .audiologist ? "Audiologist Mode" : "Self-Test"
        let testerText = session.testerName.map { " • \($0)" } ?? ""
        let dateText = session.patientName?.isEmpty == false
            ? formatter.string(from: session.testedAt) + "  •  "
            : ""
        let detailLabel = UILabel()
        detailLabel.text = "\(dateText)\(modeText)\(testerText) • \(session.trialsPerSound) trials per sound"
        detailLabel.font = UIFont.lcCaption()
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        // Overall accuracy
        let totalCorrect = trials.filter { $0.isCorrect }.count
        let totalTrials = trials.count
        let pct = totalTrials > 0 ? Int(Double(totalCorrect) / Double(totalTrials) * 100) : 0

        let accuracyLabel = UILabel()
        accuracyLabel.text = "Overall: \(totalCorrect)/\(totalTrials) (\(pct)%)"
        accuracyLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        accuracyLabel.textColor = pct >= 80 ? .lcGreen : (pct >= 50 ? .lcAmber : .lcRed)
        accuracyLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, accuracyLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    private func buildGrid(_ session: DetectionTestSession) -> UIView {
        let gridScroll = UIScrollView()
        gridScroll.showsHorizontalScrollIndicator = true
        gridScroll.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        gridScroll.addSubview(container)

        let cellSize: CGFloat = 44
        let headerWidth: CGFloat = 44
        let numTrials = session.trialsPerSound
        let gridWidth = headerWidth + CGFloat(sounds.count) * cellSize
        let gridHeight = CGFloat(numTrials + 2) * cellSize // header + trials + summary

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: gridScroll.topAnchor),
            container.leadingAnchor.constraint(equalTo: gridScroll.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: gridScroll.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: gridScroll.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: gridWidth),
            container.heightAnchor.constraint(equalToConstant: gridHeight),
            gridScroll.heightAnchor.constraint(equalToConstant: gridHeight + 8),
        ])

        // Column headers (sound symbols)
        for (col, sound) in sounds.enumerated() {
            let lbl = makeGridLabel(sound.symbol, bold: true)
            lbl.frame = CGRect(x: headerWidth + CGFloat(col) * cellSize, y: 0, width: cellSize, height: cellSize)
            container.addSubview(lbl)
        }

        // Build trial→sound lookup
        var trialMap: [Int: [Int: DetectionTrial]] = [:] // [soundId: [trialNum: trial]]
        for t in trials {
            trialMap[t.soundId, default: [:]][t.trialNumber] = t
        }

        // Data rows
        for row in 0..<numTrials {
            let rowLabel = makeGridLabel("\(row + 1)", bold: false)
            rowLabel.textColor = .secondaryLabel
            rowLabel.frame = CGRect(x: 0, y: CGFloat(row + 1) * cellSize, width: headerWidth, height: cellSize)
            container.addSubview(rowLabel)

            for (col, sound) in sounds.enumerated() {
                let cell = UILabel()
                cell.textAlignment = .center
                cell.layer.cornerRadius = 4
                cell.clipsToBounds = true
                cell.frame = CGRect(
                    x: headerWidth + CGFloat(col) * cellSize + 2,
                    y: CGFloat(row + 1) * cellSize + 2,
                    width: cellSize - 4,
                    height: cellSize - 4)

                if let trial = trialMap[sound.id]?[row + 1] {
                    if trial.isCorrect {
                        cell.text = "✓"
                        cell.font = UIFont.systemFont(ofSize: 20, weight: .bold)
                        cell.textColor = .lcGreen
                        cell.backgroundColor = .lcGreen.withAlphaComponent(0.15)
                    } else if trial.isDetected {
                        cell.text = "~"
                        cell.font = UIFont.systemFont(ofSize: 20, weight: .bold)
                        cell.textColor = .lcAmber
                        cell.backgroundColor = .lcAmber.withAlphaComponent(0.15)
                    } else {
                        cell.text = "✗"
                        cell.font = UIFont.systemFont(ofSize: 20, weight: .bold)
                        cell.textColor = .lcRed
                        cell.backgroundColor = .lcRed.withAlphaComponent(0.15)
                    }
                } else {
                    cell.text = "—"
                    cell.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    cell.textColor = .tertiaryLabel
                    cell.backgroundColor = .secondarySystemFill
                }

                container.addSubview(cell)
            }
        }

        // Summary row — percentages
        let summaryY = CGFloat(numTrials + 1) * cellSize
        let summaryHeader = makeGridLabel("%", bold: true)
        summaryHeader.textColor = .lcTeal
        summaryHeader.frame = CGRect(x: 0, y: summaryY, width: headerWidth, height: cellSize)
        container.addSubview(summaryHeader)

        for (col, score) in scores.enumerated() {
            let pctLabel = UILabel()
            pctLabel.text = "\(score.percentage)%"
            pctLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            pctLabel.textAlignment = .center
            pctLabel.textColor = score.percentage >= 80 ? .lcGreen : (score.percentage >= 50 ? .lcAmber : .lcRed)
            pctLabel.backgroundColor = pctLabel.textColor.withAlphaComponent(0.1)
            pctLabel.layer.cornerRadius = 4
            pctLabel.clipsToBounds = true
            pctLabel.frame = CGRect(
                x: headerWidth + CGFloat(col) * cellSize + 2,
                y: summaryY + 2,
                width: cellSize - 4,
                height: cellSize - 4)
            container.addSubview(pctLabel)
        }

        let card = LCCard()
        card.addSubview(gridScroll)
        NSLayoutConstraint.activate([
            gridScroll.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            gridScroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            gridScroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            gridScroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
        ])
        return card
    }

    private func buildScoreSummary() -> LCCard {
        let card = LCCard()

        let title = UILabel()
        title.text = "Per-Sound Accuracy"
        title.font = UIFont.lcBodyBold()
        title.textColor = .label

        let barsStack = UIStackView()
        barsStack.axis = .vertical
        barsStack.spacing = 6

        for score in scores {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center

            let symbolLabel = UILabel()
            symbolLabel.text = score.sound.symbol
            symbolLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
            symbolLabel.textColor = .label
            symbolLabel.translatesAutoresizingMaskIntoConstraints = false
            symbolLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true

            let barBg = UIView()
            barBg.backgroundColor = .secondarySystemFill
            barBg.layer.cornerRadius = 6
            barBg.clipsToBounds = true
            barBg.translatesAutoresizingMaskIntoConstraints = false
            barBg.heightAnchor.constraint(equalToConstant: 16).isActive = true

            let barFill = UIView()
            let barColor: UIColor = score.percentage >= 80 ? .lcGreen : (score.percentage >= 50 ? .lcAmber : .lcRed)
            barFill.backgroundColor = barColor
            barFill.layer.cornerRadius = 6
            barFill.translatesAutoresizingMaskIntoConstraints = false
            barBg.addSubview(barFill)
            NSLayoutConstraint.activate([
                barFill.topAnchor.constraint(equalTo: barBg.topAnchor),
                barFill.bottomAnchor.constraint(equalTo: barBg.bottomAnchor),
                barFill.leadingAnchor.constraint(equalTo: barBg.leadingAnchor),
                barFill.widthAnchor.constraint(equalTo: barBg.widthAnchor, multiplier: CGFloat(score.percentage) / 100.0)
            ])

            let pctLabel = UILabel()
            pctLabel.text = "\(score.percentage)%"
            pctLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            pctLabel.textColor = barColor
            pctLabel.translatesAutoresizingMaskIntoConstraints = false
            pctLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true

            row.addArrangedSubview(symbolLabel)
            row.addArrangedSubview(barBg)
            row.addArrangedSubview(pctLabel)
            barsStack.addArrangedSubview(row)
        }

        let stack = UIStackView(arrangedSubviews: [title, barsStack])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    // MARK: - Helpers

    private func makeGridLabel(_ text: String, bold: Bool) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 13, weight: bold ? .bold : .medium)
        lbl.textAlignment = .center
        lbl.textColor = .label
        return lbl
    }

    @objc private func doneTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
}
