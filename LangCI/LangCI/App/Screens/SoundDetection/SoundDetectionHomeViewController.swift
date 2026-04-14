// SoundDetectionHomeViewController.swift
// LangCI — Sound Detection Test home screen
//
// Entry point for the Sound Detection feature. Shows:
//   • "Start Test" cards for Audiologist Mode & Self-Test Mode
//   • Recent test sessions with score summary
//   • "Manage Sounds" button to customise the sound list
//
// Navigation: pushed from CI Hub or Home screen

import UIKit

final class SoundDetectionHomeViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let service = ServiceLocator.shared.soundDetectionService!

    private var recentSessions: [DetectionTestSession] = []

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
        title = "Sound Detection"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        let manageBtn = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain, target: self, action: #selector(manageSoundsTapped))
        manageBtn.tintColor = .lcTeal
        navigationItem.rightBarButtonItem = manageBtn
    }

    private func loadData() {
        Task {
            recentSessions = (try? await service.getRecentSessions(count: 10)) ?? []
            await MainActor.run { rebuildContent() }
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 16, leading: LC.cardPadding, bottom: 40, trailing: LC.cardPadding)
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

        rebuildContent()
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Mode selection cards
        contentStack.addArrangedSubview(buildSectionHeader("Start a Test"))
        contentStack.addArrangedSubview(buildModeCard(
            title: "Audiologist Mode",
            subtitle: "Your audiologist plays sounds & marks your responses",
            icon: "stethoscope",
            color: .lcTeal,
            action: #selector(startAudiologistMode)))
        contentStack.addArrangedSubview(buildModeCard(
            title: "Self-Test Mode",
            subtitle: "App plays sounds — you identify what you heard",
            icon: "ear.fill",
            color: .lcBlue,
            action: #selector(startSelfTestMode)))

        // Recent sessions
        if !recentSessions.isEmpty {
            contentStack.addArrangedSubview(buildSectionHeader("Recent Sessions"))
            for session in recentSessions.prefix(5) {
                contentStack.addArrangedSubview(buildSessionRow(session))
            }

            if recentSessions.count > 5 {
                let seeAll = UIButton(type: .system)
                seeAll.setTitle("See All Sessions →", for: .normal)
                seeAll.titleLabel?.font = UIFont.lcBody()
                seeAll.tintColor = .lcTeal
                seeAll.addTarget(self, action: #selector(seeAllSessionsTapped), for: .touchUpInside)
                contentStack.addArrangedSubview(seeAll)
            }
        }
    }

    // MARK: - Build Helpers

    private func buildSectionHeader(_ title: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        lbl.textColor = .label
        return lbl
    }

    private func buildModeCard(title: String, subtitle: String, icon: String, color: UIColor, action: Selector) -> LCCard {
        let card = LCCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.lcCaption()
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let row = UIStackView(arrangedSubviews: [iconView, textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        let tap = UITapGestureRecognizer(target: self, action: action)
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    private func buildSessionRow(_ session: DetectionTestSession) -> LCCard {
        let card = LCCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let modeIcon = UIImageView()
        let iconName = session.mode == .audiologist ? "stethoscope" : "ear.fill"
        let iconColor: UIColor = session.mode == .audiologist ? .lcTeal : .lcBlue
        modeIcon.image = UIImage(systemName: iconName)
        modeIcon.tintColor = iconColor
        modeIcon.contentMode = .scaleAspectFit
        modeIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            modeIcon.widthAnchor.constraint(equalToConstant: 24),
            modeIcon.heightAnchor.constraint(equalToConstant: 24)
        ])

        let dateLabel = UILabel()
        dateLabel.text = dateFormatter.string(from: session.testedAt)
        dateLabel.font = UIFont.lcBody()
        dateLabel.textColor = .label

        let detailLabel = UILabel()
        let modeText = session.mode == .audiologist ? "Audiologist" : "Self-test"
        let testerText = session.testerName.map { " • \($0)" } ?? ""
        detailLabel.text = "\(modeText)\(testerText) • \(session.trialsPerSound) trials"
        detailLabel.font = UIFont.lcCaption()
        detailLabel.textColor = .secondaryLabel

        let statusBadge = UILabel()
        statusBadge.text = session.isComplete ? "Complete" : "In Progress"
        statusBadge.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        statusBadge.textColor = .white
        statusBadge.backgroundColor = session.isComplete ? .lcGreen : .lcAmber
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 8
        statusBadge.clipsToBounds = true
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusBadge.widthAnchor.constraint(equalToConstant: 80),
            statusBadge.heightAnchor.constraint(equalToConstant: 20)
        ])

        let textStack = UIStackView(arrangedSubviews: [dateLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [modeIcon, textStack, statusBadge])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
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

    // MARK: - Actions

    @objc private func startAudiologistMode() {
        lcHaptic(.light)
        let vc = AudiologistTestViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func startSelfTestMode() {
        lcHaptic(.light)
        let vc = SelfTestViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func manageSoundsTapped() {
        lcHaptic(.light)
        let vc = ManageSoundsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func seeAllSessionsTapped() {
        // Could push a full session list — for now show all in the list
    }

    @objc private func sessionTapped(_ sender: SessionTapGesture) {
        lcHaptic(.light)
        let vc = DetectionResultsGridViewController(sessionId: sender.sessionId)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Gesture helper

private class SessionTapGesture: UITapGestureRecognizer {
    var sessionId: Int = 0
}
