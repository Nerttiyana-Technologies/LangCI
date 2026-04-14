// MoreViewController.swift
// LangCI
//
// Beautiful card-based "More" hub replacing iOS's default More list.
// Groups secondary features (Reports, CI Hub, Settings, AVT, Sound Therapy)
// into visually rich, tappable cards with gradients and icons.

import UIKit

final class MoreViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "More"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
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
            top: 8, leading: 16, bottom: 32, trailing: 16
        )
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

        // ── Therapy & Training ──────────────────────────────────

        contentStack.addArrangedSubview(buildSectionLabel("THERAPY & TRAINING"))

        // Sound Therapy — large featured card
        contentStack.addArrangedSubview(buildFeaturedCard(
            title: "Sound Therapy",
            subtitle: "Train sh, mm, ush sounds with minimal pairs & progressive exercises",
            icon: "ear.fill",
            gradientColors: [UIColor.lcPurple.withAlphaComponent(0.15),
                             UIColor.lcTeal.withAlphaComponent(0.10)],
            tint: .lcPurple,
            action: #selector(openSoundTherapy)
        ))

        // Environmental Sound Training — large featured card
        contentStack.addArrangedSubview(buildFeaturedCard(
            title: "Environmental Sounds",
            subtitle: "Learn to identify everyday sounds — door knocks, alarms, birds & more",
            icon: "waveform.badge.magnifyingglass",
            gradientColors: [UIColor.lcGreen.withAlphaComponent(0.15),
                             UIColor.lcAmber.withAlphaComponent(0.10)],
            tint: .lcGreen,
            action: #selector(openEnvironmentalSounds)
        ))

        // AVT — large featured card
        contentStack.addArrangedSubview(buildFeaturedCard(
            title: "Auditory Verbal Therapy",
            subtitle: "Structured listening hierarchy: Detection → Discrimination → Identification → Comprehension",
            icon: "ear.and.waveform",
            gradientColors: [UIColor.lcTeal.withAlphaComponent(0.15),
                             UIColor.lcBlue.withAlphaComponent(0.10)],
            tint: .lcTeal,
            action: #selector(openAVT)
        ))

        // Music Perception — large featured card
        contentStack.addArrangedSubview(buildFeaturedCard(
            title: "Music Perception",
            subtitle: "Train rhythm, instrument recognition & melody — enjoy music through your CI",
            icon: "music.quarternote.3",
            gradientColors: [UIColor.lcAmber.withAlphaComponent(0.15),
                             UIColor.lcPurple.withAlphaComponent(0.10)],
            tint: .lcAmber,
            action: #selector(openMusicPerception)
        ))

        // ── My CI Journey ───────────────────────────────────────

        contentStack.addArrangedSubview(buildSectionLabel("MY CI JOURNEY"))

        // Two cards side by side
        let journeyRow = UIStackView()
        journeyRow.axis = .horizontal
        journeyRow.spacing = 12
        journeyRow.distribution = .fillEqually

        journeyRow.addArrangedSubview(buildCompactCard(
            title: "CI Hub",
            subtitle: "Activation timeline, mapping & milestones",
            icon: "waveform.path.ecg",
            tint: .lcOrange,
            action: #selector(openCIHub)
        ))

        journeyRow.addArrangedSubview(buildCompactCard(
            title: "Reports",
            subtitle: "Progress charts & audiologist summaries",
            icon: "chart.bar.fill",
            tint: .lcBlue,
            action: #selector(openReports)
        ))

        contentStack.addArrangedSubview(journeyRow)

        // ── App ─────────────────────────────────────────────────

        contentStack.addArrangedSubview(buildSectionLabel("APP"))

        contentStack.addArrangedSubview(buildListCard(
            title: "Settings",
            subtitle: "Language, Whisper API, appearance",
            icon: "gearshape.fill",
            tint: .secondaryLabel,
            action: #selector(openSettings)
        ))

        contentStack.addArrangedSubview(buildListCard(
            title: "About LangCI",
            subtitle: "The story behind the app",
            icon: "heart.text.square.fill",
            tint: .lcTeal,
            action: #selector(openAbout)
        ))
    }

    @objc private func openAbout() {
        lcHaptic(.light)
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }

    // MARK: - Card Builders

    /// Large featured card with gradient background
    private func buildFeaturedCard(title: String, subtitle: String,
                                    icon: String,
                                    gradientColors: [UIColor],
                                    tint: UIColor,
                                    action: Selector) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        // Gradient
        let gradient = CAGradientLayer()
        gradient.colors = gradientColors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 14
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        // Icon circle
        let iconBg = UIView()
        iconBg.backgroundColor = tint.withAlphaComponent(0.15)
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
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Text
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 18, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel
        subtitleLbl.numberOfLines = 2

        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(subtitleLbl)

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        hStack.addArrangedSubview(iconBg)
        hStack.addArrangedSubview(textStack)
        hStack.addArrangedSubview(chevron)

        card.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            hStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            hStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])

        DispatchQueue.main.async { gradient.frame = card.bounds }

        return card
    }

    /// Compact square-ish card for side-by-side layout
    private func buildCompactCard(title: String, subtitle: String,
                                   icon: String, tint: UIColor,
                                   action: Selector) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = tint.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 20
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLbl.textColor = .secondaryLabel
        subtitleLbl.numberOfLines = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),
        ])

        stack.addArrangedSubview(iconBg)
        stack.alignment = .leading
        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(subtitleLbl)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
        ])

        return card
    }

    /// Simple list-style card (for Settings)
    private func buildListCard(title: String, subtitle: String,
                                icon: String, tint: UIColor,
                                action: Selector) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(subtitleLbl)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        hStack.addArrangedSubview(iconView)
        hStack.addArrangedSubview(textStack)
        hStack.addArrangedSubview(chevron)

        card.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            hStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            hStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])

        return card
    }

    private func buildSectionLabel(_ text: String) -> UIView {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .tertiaryLabel
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.kern, value: 1.2, range: NSRange(location: 0, length: text.count))
        lbl.attributedText = attributed
        return lbl
    }

    // MARK: - Navigation Actions

    @objc private func openEnvironmentalSounds() {
        navigationController?.pushViewController(EnvironmentalSoundHomeViewController(), animated: true)
    }

    @objc private func openSoundTherapy() {
        navigationController?.pushViewController(SoundTherapyHomeViewController(), animated: true)
    }

    @objc private func openAVT() {
        navigationController?.pushViewController(AVTViewController(), animated: true)
    }

    @objc private func openMusicPerception() {
        navigationController?.pushViewController(MusicPerceptionHomeViewController(), animated: true)
    }

    @objc private func openCIHub() {
        navigationController?.pushViewController(CIHubViewController(), animated: true)
    }

    @objc private func openReports() {
        navigationController?.pushViewController(ReportsViewController(), animated: true)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
}
