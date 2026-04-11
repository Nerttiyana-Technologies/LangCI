// EnvironmentalSoundHomeViewController.swift
// LangCI — Hub for Environmental Sound Training
//
// Shows weekly sound packs with progressive unlocking,
// custom sounds section, quick start, and settings access.

import UIKit

final class EnvironmentalSoundHomeViewController: UIViewController {

    // MARK: - State

    private var packs: [WeeklySoundPack] = []
    private var customSounds: [CustomEnvironmentalSound] = []
    private let service = ServiceLocator.shared.environmentalSoundService!

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sounds"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        // Custom title view with icon for when large title collapses
        let titleIcon = UIImageView(image: UIImage(systemName: "waveform.badge.magnifyingglass"))
        titleIcon.tintColor = .lcGreen
        titleIcon.contentMode = .scaleAspectFit
        let titleLabel = UILabel()
        titleLabel.text = "Sounds"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        let titleStack = UIStackView(arrangedSubviews: [titleIcon, titleLabel])
        titleStack.spacing = 6
        titleStack.alignment = .center
        navigationItem.titleView = titleStack

        // Nav bar buttons
        let editBtn = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain, target: self, action: #selector(openEditor))
        let addBtn = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain, target: self, action: #selector(addCustom))
        navigationItem.rightBarButtonItems = [addBtn, editBtn]

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
            let packProgress = (try? await service.getPackProgress()) ?? []
            let unlockedIds = Set(packProgress.filter { $0.isUnlocked }.map { $0.packId })
            packs = EnvironmentalSoundContent.buildPacks(unlockedIds: unlockedIds)

            // Mark completed packs
            let completedIds = Set(packProgress.filter { $0.completed }.map { $0.packId })
            for i in packs.indices {
                packs[i].isCompleted = completedIds.contains(packs[i].id)
            }

            customSounds = (try? await service.getAllCustomSounds()) ?? []

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

        // Learning Mode CTA (for early CI users)
        contentStack.addArrangedSubview(buildLearningModeCard())

        // Quick Start CTA
        contentStack.addArrangedSubview(buildQuickStartCard())

        // Voice Library
        contentStack.addArrangedSubview(buildVoiceLibraryCard())

        // Browse by Category
        contentStack.addArrangedSubview(buildSectionLabel("BROWSE BY CATEGORY"))
        contentStack.addArrangedSubview(buildCategoryScroll())

        // Weekly Packs
        contentStack.addArrangedSubview(buildSectionLabel("WEEKLY SOUND PACKS"))

        for pack in packs {
            contentStack.addArrangedSubview(buildPackCard(pack))
        }

        // Custom Sounds
        if !customSounds.isEmpty {
            contentStack.addArrangedSubview(buildSectionLabel("MY CUSTOM SOUNDS"))
            for sound in customSounds {
                contentStack.addArrangedSubview(buildCustomSoundRow(sound))
            }
        }

        // Tip
        contentStack.addArrangedSubview(buildTipCard())
    }

    // MARK: - Category Scroll

    private func buildCategoryScroll() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 90),
        ])

        for env in SoundEnvironment.allCases {
            let soundCount = EnvironmentalSoundContent.sounds(for: env).count
            let customCount = customSounds.filter { $0.environment == env.rawValue }.count
            let total = soundCount + customCount
            let chip = buildCategoryChip(env: env, count: total)
            row.addArrangedSubview(chip)
        }

        return scroll
    }

    private func buildCategoryChip(env: SoundEnvironment, count: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .lcCard
        card.layer.cornerRadius = 14
        card.lcApplyShadow(radius: 4, opacity: 0.10)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: 100).isActive = true
        card.isUserInteractionEnabled = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        card.addSubview(stack)

        let color: UIColor = {
            switch env.color {
            case "lcBlue":   return .lcBlue
            case "lcOrange": return .lcOrange
            case "lcGreen":  return .lcGreen
            case "lcPurple": return .lcPurple
            case "lcAmber":  return .lcAmber
            case "lcRed":    return .lcRed
            case "lcTeal":   return .lcTeal
            case "lcGold":   return .lcGold
            default:         return .lcTeal
            }
        }()

        let iconView = UIImageView(image: UIImage(systemName: env.icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let label = UILabel()
        label.text = env.label
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .label

        let countLbl = UILabel()
        countLbl.text = "\(count) sounds"
        countLbl.font = .systemFont(ofSize: 10, weight: .medium)
        countLbl.textColor = .secondaryLabel

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(countLbl)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        let tap = CategoryTapGesture(target: self, action: #selector(categoryTapped(_:)))
        tap.environment = env
        card.addGestureRecognizer(tap)

        return card
    }

    @objc private func categoryTapped(_ gesture: CategoryTapGesture) {
        guard let env = gesture.environment else { return }
        let vc = EnvironmentalSoundTrainingViewController()
        vc.environment = env
        vc.title = env.label
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Learning Mode Card

    private func buildLearningModeCard() -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(startLearningMode)))

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcAmber.withAlphaComponent(0.18).cgColor,
                           UIColor.lcOrange.withAlphaComponent(0.10).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcAmber.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 26
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "brain.head.profile"))
        icon.tintColor = .lcAmber
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let title = UILabel()
        title.text = "Learning Mode"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .label

        let badge = UILabel()
        badge.text = "  RECOMMENDED FOR EARLY CI  "
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = .lcAmber
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        badge.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "No quiz — just see the name, hear the sound, and replay. Your brain maps static to meaning through repetition."
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 3

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(badge)
        textStack.addArrangedSubview(subtitle)

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

        return card
    }

    // MARK: - Voice Library Card

    private func buildVoiceLibraryCard() -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(openVoiceLibrary)))

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcPurple.withAlphaComponent(0.15).cgColor,
                           UIColor.lcTeal.withAlphaComponent(0.08).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 26
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "mic.fill"))
        icon.tintColor = .lcPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let title = UILabel()
        title.text = "Voice Library"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "Record your wife, audiologist, or family. Train with familiar voices for faster progress."
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 3

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

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

        return card
    }

    @objc private func openVoiceLibrary() {
        let vc = VoiceLibraryViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func startLearningMode() {
        let vc = EnvironmentalSoundTrainingViewController()
        vc.learningMode = true
        vc.title = "Learning Mode"
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Quick Start

    private func buildQuickStartCard() -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(quickStart)))

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcGreen.withAlphaComponent(0.15).cgColor,
                           UIColor.lcTeal.withAlphaComponent(0.10).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 26
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "play.fill"))
        icon.tintColor = .lcGreen
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let title = UILabel()
        title.text = "Quick Start"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "Mixed sounds at your current level — includes your custom sounds"
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

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

        return card
    }

    // MARK: - Pack Card

    private func buildPackCard(_ pack: WeeklySoundPack) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.alpha = pack.isUnlocked ? 1.0 : 0.5

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = pack.color.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 22
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: pack.icon))
        iconView.tintColor = pack.color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        // Text
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3

        let title = UILabel()
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = .label

        if pack.isCompleted {
            title.text = "\(pack.title)  \u{2705}"
        } else if !pack.isUnlocked {
            title.text = "\(pack.title)  \u{1F512}"
        } else {
            title.text = pack.title
        }

        let subtitle = UILabel()
        subtitle.text = "\(pack.soundCount) sounds \u{2022} \(pack.subtitle)"
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        if pack.isUnlocked {
            let tap = PackTapGesture(target: self, action: #selector(packTapped(_:)))
            tap.packId = pack.id
            tap.soundIds = pack.soundIds
            card.addGestureRecognizer(tap)
        }

        return card
    }

    // MARK: - Custom Sound Row

    private func buildCustomSoundRow(_ sound: CustomEnvironmentalSound) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let env = SoundEnvironment(rawValue: sound.environment) ?? .home
        let iconView = UIImageView(image: UIImage(systemName: env.icon))
        iconView.tintColor = .lcAmber
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let title = UILabel()
        title.text = sound.name
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .label

        let sub = UILabel()
        sub.text = "TTS: \"\(sound.speechDescription)\""
        sub.font = UIFont.lcCaption()
        sub.textColor = .secondaryLabel

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(sub)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        let tap = CustomSoundTapGesture(target: self, action: #selector(customSoundTapped(_:)))
        tap.sound = sound
        card.addGestureRecognizer(tap)

        return card
    }

    // MARK: - Tip Card

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

        let tipText = UILabel()
        tipText.text = "Add your own sounds! Your specific doorbell, your dog's bark, or your family member's voice will help your brain learn faster because you hear them every day."
        tipText.font = .systemFont(ofSize: 13, weight: .medium)
        tipText.textColor = .secondaryLabel
        tipText.numberOfLines = 0

        stack.addArrangedSubview(bulb)
        stack.addArrangedSubview(tipText)

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
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.kern, value: 1.2,
            range: NSRange(location: 0, length: text.count))
        lbl.attributedText = attributed
        return lbl
    }

    // MARK: - Actions

    @objc private func quickStart() {
        let vc = EnvironmentalSoundTrainingViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func packTapped(_ gesture: PackTapGesture) {
        let vc = EnvironmentalSoundTrainingViewController()
        vc.packSoundIds = gesture.soundIds
        vc.title = gesture.packId.replacingOccurrences(of: "week", with: "Week ")
            .capitalized
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func customSoundTapped(_ gesture: CustomSoundTapGesture) {
        guard let sound = gesture.sound else { return }
        let vc = AddCustomSoundViewController()
        vc.existingSound = sound
        vc.onSave = { [weak self] _ in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openEditor() {
        let vc = SoundContentEditorViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func addCustom() {
        let vc = AddCustomSoundViewController()
        vc.onSave = { [weak self] _ in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Gesture subclasses for passing data

private class PackTapGesture: UITapGestureRecognizer {
    var packId = ""
    var soundIds: [String] = []
}

private class CustomSoundTapGesture: UITapGestureRecognizer {
    var sound: CustomEnvironmentalSound?
}

private class CategoryTapGesture: UITapGestureRecognizer {
    var environment: SoundEnvironment?
}
