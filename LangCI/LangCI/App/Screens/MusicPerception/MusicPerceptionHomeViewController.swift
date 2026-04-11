// MusicPerceptionHomeViewController.swift
// LangCI — Music Perception Training hub
//
// Music is one of the hardest things for CI users to enjoy again.
// This hub offers three training modes:
//   1. Rhythm — identify beat patterns (slow waltz vs fast march)
//   2. Instrument — which instrument is playing (piano, violin, flute)
//   3. Melody — recognise familiar tunes (Twinkle Twinkle, Happy Birthday)
//
// Each mode uses TTS descriptions + available audio files so the brain
// can learn to map the electrical stimulation to musical concepts.

import UIKit

final class MusicPerceptionHomeViewController: UIViewController {

    // MARK: - State

    private let service = ServiceLocator.shared.musicService!
    private var stats: [MusicStatsDto] = []
    private var overallAccuracy: Double = 0

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Music"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        // Custom title view with icon
        let titleIcon = UIImageView(image: UIImage(systemName: "music.note.list"))
        titleIcon.tintColor = .lcPurple
        titleIcon.contentMode = .scaleAspectFit
        let titleLabel = UILabel()
        titleLabel.text = "Music"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        let titleStack = UIStackView(arrangedSubviews: [titleIcon, titleLabel])
        titleStack.spacing = 6
        titleStack.alignment = .center
        navigationItem.titleView = titleStack

        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadData()
    }

    // MARK: - Data

    private func loadData() {
        Task {
            stats = (try? await service.getStatsByType()) ?? []
            overallAccuracy = (try? await service.getOverallAccuracy()) ?? 0
            await MainActor.run { rebuildCards() }
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8, leading: 16, bottom: 32, trailing: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

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
        ])
    }

    private func rebuildCards() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Intro card
        contentStack.addArrangedSubview(buildIntroCard())

        // Overall stats (if any attempts)
        let totalAttempts = stats.reduce(0) { $0 + $1.attempts }
        if totalAttempts > 0 {
            contentStack.addArrangedSubview(buildStatsCard(totalAttempts: totalAttempts))
        }

        // Training modes
        contentStack.addArrangedSubview(buildSectionLabel("TRAINING MODES"))

        contentStack.addArrangedSubview(buildModeCard(
            type: .rhythm,
            title: "Rhythm Training",
            subtitle: "Identify beat patterns — waltz, march, bossa nova, tango",
            icon: "metronome.fill",
            colors: [UIColor.lcOrange.withAlphaComponent(0.15),
                     UIColor.lcAmber.withAlphaComponent(0.08)],
            tint: .lcOrange,
            emoji: "🥁"))

        contentStack.addArrangedSubview(buildModeCard(
            type: .instrument,
            title: "Instrument Recognition",
            subtitle: "Piano, violin, trumpet, guitar, flute, tabla, veena & more",
            icon: "pianokeys",
            colors: [UIColor.lcPurple.withAlphaComponent(0.15),
                     UIColor.lcBlue.withAlphaComponent(0.08)],
            tint: .lcPurple,
            emoji: "🎹"))

        contentStack.addArrangedSubview(buildModeCard(
            type: .melody,
            title: "Melody Recognition",
            subtitle: "Recognise familiar tunes — Twinkle Twinkle, Happy Birthday & more",
            icon: "music.note.list",
            colors: [UIColor.lcGreen.withAlphaComponent(0.15),
                     UIColor.lcTeal.withAlphaComponent(0.08)],
            tint: .lcGreen,
            emoji: "🎵"))

        // Tip
        contentStack.addArrangedSubview(buildTipCard())
    }

    // MARK: - Intro Card

    private func buildIntroCard() -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 26
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "music.quarternote.3"))
        icon.tintColor = .lcPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let title = UILabel()
        title.text = "Train Your Musical Brain"
        title.font = .systemFont(ofSize: 18, weight: .bold)

        let subtitle = UILabel()
        subtitle.text = "Music sounds different through a CI. These exercises help your brain learn to enjoy rhythm, instruments, and melodies again."
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    // MARK: - Stats Card

    private func buildStatsCard(totalAttempts: Int) -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Overall
        stack.addArrangedSubview(buildStatPill(
            value: String(format: "%.0f%%", overallAccuracy),
            label: "Overall", color: .lcPurple))

        // Per-type stats
        for stat in stats {
            let emoji: String
            switch stat.trainingType {
            case .rhythm:     emoji = "🥁"
            case .instrument: emoji = "🎹"
            case .melody:     emoji = "🎵"
            }
            stack.addArrangedSubview(buildStatPill(
                value: "\(emoji) \(String(format: "%.0f%%", stat.accuracyPct))",
                label: stat.typeLabel, color: .lcTeal))
        }

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        return card
    }

    private func buildStatPill(value: String, label: String, color: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center

        let valLabel = UILabel()
        valLabel.text = value
        valLabel.font = .systemFont(ofSize: 16, weight: .heavy)
        valLabel.textColor = color

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabel

        stack.addArrangedSubview(valLabel)
        stack.addArrangedSubview(nameLabel)
        return stack
    }

    // MARK: - Mode Card

    private func buildModeCard(type: MusicTrainingType, title: String,
                                subtitle: String, icon: String,
                                colors: [UIColor], tint: UIColor,
                                emoji: String) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.clipsToBounds = true

        let gradient = CAGradientLayer()
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = tint.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 26
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
        ])

        // Text
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .bold)

        // Stats for this mode
        let stat = stats.first { $0.trainingType == type }
        let subText: String
        if let s = stat, s.attempts > 0 {
            subText = "\(subtitle)\n\(String(format: "%.0f%% accuracy", s.accuracyPct)) • \(s.attempts) attempts"
        } else {
            subText = subtitle
        }

        let subLbl = UILabel()
        subLbl.text = subText
        subLbl.font = UIFont.lcCaption()
        subLbl.textColor = .secondaryLabel
        subLbl.numberOfLines = 3

        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(subLbl)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        DispatchQueue.main.async { gradient.frame = card.bounds }

        let tap = ModeTapGesture(target: self, action: #selector(modeTapped(_:)))
        tap.mode = type
        card.addGestureRecognizer(tap)

        return card
    }

    // MARK: - Tip

    private func buildTipCard() -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false

        let bulb = UIImageView(image: UIImage(systemName: "lightbulb.fill"))
        bulb.tintColor = .lcAmber
        bulb.contentMode = .scaleAspectFit
        bulb.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let tip = UILabel()
        tip.text = "Start with rhythm — it's the easiest for CI users since beat patterns come through the implant more clearly than pitch. Work up to instruments, then melodies. Many CI users report enjoying music again after 3-6 months of practice!"
        tip.font = .systemFont(ofSize: 13, weight: .medium)
        tip.textColor = .secondaryLabel
        tip.numberOfLines = 0

        stack.addArrangedSubview(bulb)
        stack.addArrangedSubview(tip)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - Section Label

    private func buildSectionLabel(_ text: String) -> UIView {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .tertiaryLabel
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: 1.2, range: NSRange(location: 0, length: text.count))
        lbl.attributedText = attr
        return lbl
    }

    // MARK: - Actions

    @objc private func modeTapped(_ gesture: ModeTapGesture) {
        guard let mode = gesture.mode else { return }
        let vc = MusicTrainingViewController()
        vc.trainingMode = mode
        vc.title = {
            switch mode {
            case .rhythm:     return "Rhythm Training"
            case .instrument: return "Instruments"
            case .melody:     return "Melody Recognition"
            }
        }()
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Gesture subclass

private class ModeTapGesture: UITapGestureRecognizer {
    var mode: MusicTrainingType?
}
