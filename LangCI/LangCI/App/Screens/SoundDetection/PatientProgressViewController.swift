// PatientProgressViewController.swift
// LangCI — Longitudinal view of one patient's sound detection history
//
// Shows:
//   • Patient header (name + identifier + notes)
//   • All sessions for this patient (most recent first)
//   • Per-sound trend: "ee went from 44% → 67% → 89% over last 3 visits"
//   • Tap a session to open its full grid
//   • Edit patient details (name / identifier / notes)

import UIKit

final class PatientProgressViewController: UIViewController {

    private let patientService = ServiceLocator.shared.patientService!
    private let sessionService = ServiceLocator.shared.soundDetectionService!

    private var patient: Patient
    private var sessions: [DetectionTestSession] = []
    private var sounds: [TestSound] = []
    private var progressBySound: [Int: [(date: Date, percentage: Int)]] = [:]

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Init

    init(patient: Patient) {
        self.patient = patient
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = patient.name
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        let edit = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain, target: self, action: #selector(editTapped))
        edit.tintColor = .lcTeal
        navigationItem.rightBarButtonItem = edit

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
        contentStack.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 40, trailing: 16)
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
            sessions = (try? await patientService.sessions(forPatient: patient.id)) ?? []
            sounds = (try? await sessionService.getActiveSounds()) ?? []

            progressBySound = [:]
            for sound in sounds {
                let prog = (try? await patientService.progressOverTime(patientId: patient.id, soundId: sound.id)) ?? []
                progressBySound[sound.id] = prog
            }

            await MainActor.run { self.rebuild() }
        }
    }

    private func rebuild() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(buildHeader())
        contentStack.addArrangedSubview(sectionLabel("Sessions"))

        if sessions.isEmpty {
            let empty = UILabel()
            empty.text = "No sessions yet for this patient."
            empty.font = UIFont.lcCaption()
            empty.textColor = .secondaryLabel
            empty.textAlignment = .center
            contentStack.addArrangedSubview(empty)
        } else {
            for s in sessions {
                contentStack.addArrangedSubview(buildSessionRow(s))
            }
        }

        // Per-sound trend
        if !sessions.isEmpty {
            contentStack.addArrangedSubview(sectionLabel("Progress by Sound"))
            contentStack.addArrangedSubview(buildTrendCard())
        }
    }

    // MARK: - Header

    private func buildHeader() -> LCCard {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        let name = UILabel()
        name.text = patient.name
        name.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        name.textColor = .label
        stack.addArrangedSubview(name)

        if let identifier = patient.identifier, !identifier.isEmpty {
            let id = UILabel()
            id.text = identifier
            id.font = UIFont.lcBody()
            id.textColor = .secondaryLabel
            stack.addArrangedSubview(id)
        }

        let stats = UILabel()
        stats.text = "\(sessions.count) session\(sessions.count == 1 ? "" : "s")"
        stats.font = UIFont.lcCaption()
        stats.textColor = .tertiaryLabel
        stack.addArrangedSubview(stats)

        if let notes = patient.notes, !notes.isEmpty {
            let n = UILabel()
            n.text = notes
            n.font = UIFont.lcCaption()
            n.textColor = .label
            n.numberOfLines = 0
            stack.addArrangedSubview(n)
        }
        return card
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        lbl.textColor = .label
        return lbl
    }

    // MARK: - Session row

    private func buildSessionRow(_ session: DetectionTestSession) -> LCCard {
        let card = LCCard()
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        let dateLabel = UILabel()
        dateLabel.text = df.string(from: session.testedAt)
        dateLabel.font = UIFont.lcBodyBold()
        dateLabel.textColor = .label

        let modeText = session.mode == .audiologist ? "Audiologist" : "Self-Test"
        let testerText = session.testerName.map { " • \($0)" } ?? ""
        let sub = UILabel()
        sub.text = "\(modeText)\(testerText) • \(session.trialsPerSound) trials"
        sub.font = UIFont.lcCaption()
        sub.textColor = .secondaryLabel

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let txt = UIStackView(arrangedSubviews: [dateLabel, sub])
        txt.axis = .vertical
        txt.spacing = 2

        let row = UIStackView(arrangedSubviews: [txt, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        let tap = SessionTapGesture(target: self, action: #selector(sessionTapped(_:)))
        tap.sessionId = session.id
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    // MARK: - Trend card

    private func buildTrendCard() -> LCCard {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])

        for sound in sounds {
            guard let data = progressBySound[sound.id], !data.isEmpty else { continue }

            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center

            let symbol = UILabel()
            symbol.text = sound.symbol
            symbol.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            symbol.textColor = .label
            symbol.textAlignment = .center
            symbol.translatesAutoresizingMaskIntoConstraints = false
            symbol.widthAnchor.constraint(equalToConstant: 40).isActive = true

            let trend = UILabel()
            trend.text = data.map { "\($0.percentage)%" }.joined(separator: " → ")
            trend.font = UIFont.lcBody()
            trend.textColor = .secondaryLabel
            trend.adjustsFontSizeToFitWidth = true
            trend.minimumScaleFactor = 0.7

            let delta = UILabel()
            if data.count >= 2 {
                let diff = data.last!.percentage - data.first!.percentage
                delta.text = diff > 0 ? "+\(diff)%" : "\(diff)%"
                delta.textColor = diff > 0 ? .lcGreen : (diff < 0 ? .lcRed : .secondaryLabel)
            } else {
                delta.text = "—"
                delta.textColor = .tertiaryLabel
            }
            delta.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            delta.textAlignment = .right
            delta.translatesAutoresizingMaskIntoConstraints = false
            delta.widthAnchor.constraint(equalToConstant: 60).isActive = true

            row.addArrangedSubview(symbol)
            row.addArrangedSubview(trend)
            row.addArrangedSubview(delta)
            stack.addArrangedSubview(row)
        }

        return card
    }

    // MARK: - Actions

    @objc private func sessionTapped(_ sender: SessionTapGesture) {
        lcHaptic(.light)
        let vc = DetectionResultsGridViewController(sessionId: sender.sessionId)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func editTapped() {
        let alert = UIAlertController(title: "Edit Patient", message: "Update the patient's details.", preferredStyle: .alert)
        alert.addTextField { $0.text = self.patient.name; $0.placeholder = "Name"; $0.autocapitalizationType = .words }
        alert.addTextField { $0.text = self.patient.identifier; $0.placeholder = "DOB / phone / note" }
        alert.addTextField { $0.text = self.patient.notes; $0.placeholder = "Clinical notes (optional)" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? self.patient.name
            let identifier = alert.textFields?[1].text?.trimmingCharacters(in: .whitespaces)
            let notes = alert.textFields?[2].text?.trimmingCharacters(in: .whitespaces)
            self.patient.name = name.isEmpty ? self.patient.name : name
            self.patient.identifier = identifier?.isEmpty == true ? nil : identifier
            self.patient.notes = notes?.isEmpty == true ? nil : notes

            Task {
                try? await self.patientService.updatePatient(self.patient)
                await MainActor.run {
                    self.title = self.patient.name
                    self.rebuild()
                }
            }
        })
        present(alert, animated: true)
    }
}

private class SessionTapGesture: UITapGestureRecognizer {
    var sessionId: Int = 0
}
