// SoundTherapyHomeViewController.swift
// LangCI — Sound Therapy hub
//
// Beautiful card-based UI for sound therapy training.
// Shows progress overview, target sounds as animated cards,
// and quick-start actions for drills.

import UIKit
import AVFoundation

final class SoundTherapyHomeViewController: UIViewController {

    // MARK: - State

    private var allProgress: [SoundProgress] = []
    private var stats: SoundTherapyHomeStats?
    private var selectedVoiceGender: VoiceGender = .female
    private var isKidMode = false   // toggle for child-friendly UI

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        isKidMode = UserDefaults.standard.bool(forKey: "sound_therapy_kid_mode")
        setupNavigation()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadData()
    }

    // MARK: - Navigation Setup

    private func setupNavigation() {
        title = "Sound Therapy"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        // Voice gender toggle in nav bar
        let voiceMenu = UIMenu(title: "Voice", children: [
            UIAction(title: "Female Voice (Easier)", image: UIImage(systemName: "person.fill"),
                     state: selectedVoiceGender == .female ? .on : .off) { [weak self] _ in
                self?.selectedVoiceGender = .female
                self?.setupNavigation()
            },
            UIAction(title: "Male Voice (Harder)", image: UIImage(systemName: "person.fill"),
                     state: selectedVoiceGender == .male ? .on : .off) { [weak self] _ in
                self?.selectedVoiceGender = .male
                self?.setupNavigation()
            }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: selectedVoiceGender == .female ? "person.wave.2" : "person.wave.2.fill"),
            menu: voiceMenu
        )

        // Kid mode toggle
        let kidItem = UIBarButtonItem(
            image: UIImage(systemName: isKidMode ? "star.fill" : "star"),
            style: .plain, target: self, action: #selector(toggleKidMode)
        )
        navigationItem.leftBarButtonItem = kidItem
    }

    @objc private func toggleKidMode() {
        isKidMode.toggle()
        UserDefaults.standard.set(isKidMode, forKey: "sound_therapy_kid_mode")
        setupNavigation()
        rebuildContent()
    }

    // MARK: - Data Loading

    private func loadData() {
        Task {
            do {
                let service = ServiceLocator.shared.soundTherapyService!
                async let progressResult = service.getAllProgress()
                async let statsResult = service.getHomeStats()

                let (progress, homeStats) = try await (progressResult, statsResult)
                await MainActor.run {
                    self.allProgress = progress
                    self.stats = homeStats
                    self.rebuildContent()
                }
            } catch {
                print("[SoundTherapy] Load error: \(error)")
            }
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // MARK: - Rebuild Content

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1. Stats Overview Cards
        if let stats = stats {
            contentStack.addArrangedSubview(buildStatsRow(stats))
        }

        // 2. Quick Start CTA
        contentStack.addArrangedSubview(buildQuickStartCard())

        // 3. Sound Categories (cards, not list!)
        contentStack.addArrangedSubview(buildSectionLabel("YOUR SOUNDS"))
        let categorizedSounds = Dictionary(grouping: allProgress.filter(\.isUnlocked)) {
            SoundTherapyContent.sound(named: $0.sound)?.category ?? .fricatives
        }
        for category in SoundCategory.allCases {
            guard let sounds = categorizedSounds[category], !sounds.isEmpty else { continue }
            contentStack.addArrangedSubview(buildCategorySection(category, sounds: sounds))
        }

        // 4. Minimal Pairs Quick Access
        contentStack.addArrangedSubview(buildSectionLabel("MINIMAL PAIR DRILLS"))
        contentStack.addArrangedSubview(buildMinimalPairsGrid())

        // 5. Voice Training Tip
        contentStack.addArrangedSubview(buildVoiceTipCard())
    }

    // MARK: - Stats Row

    private func buildStatsRow(_ stats: SoundTherapyHomeStats) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually

        let items: [(String, String, UIColor)] = [
            ("\(stats.totalSoundsUnlocked)", "Sounds", .lcTeal),
            ("\(stats.soundsMastered)", "Mastered", .lcGreen),
            (String(format: "%.0f%%", stats.overallAccuracy), "Accuracy", .lcOrange),
            ("\(stats.currentStreak)d", "Streak", .lcPurple),
        ]

        for (value, label, color) in items {
            let card = LCCard()
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false

            let valueLbl = UILabel()
            valueLbl.text = value
            valueLbl.font = UIFont.lcCardValue()
            valueLbl.textColor = color
            valueLbl.textAlignment = .center

            let labelLbl = UILabel()
            labelLbl.text = label
            labelLbl.font = UIFont.lcCaption()
            labelLbl.textColor = .secondaryLabel
            labelLbl.textAlignment = .center

            stack.addArrangedSubview(valueLbl)
            stack.addArrangedSubview(labelLbl)
            card.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            ])
            row.addArrangedSubview(card)
        }

        return row
    }

    // MARK: - Quick Start CTA

    private func buildQuickStartCard() -> UIView {
        let card = LCCard()

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcTeal.withAlphaComponent(0.15).cgColor,
                           UIColor.lcPurple.withAlphaComponent(0.10).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = isKidMode ? "Ready to Train Your Ears?" : "Quick Start"
        titleLbl.font = .systemFont(ofSize: 20, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        if let weakest = stats?.weakestSound {
            subtitleLbl.text = isKidMode
                ? "Let's practice the '\(weakest)' sound today!"
                : "Focus: '\(weakest)' — your weakest sound. \(selectedVoiceGender.label) voice."
        } else {
            subtitleLbl.text = isKidMode
                ? "Pick a sound and start listening!"
                : "Start practising to build your sound skills."
        }
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel
        subtitleLbl.numberOfLines = 0

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 16
        buttonRow.distribution = .fillEqually

        let pairBtn = makeIconTile(
            icon: "arrow.left.arrow.right",
            label: isKidMode ? "Same or\nDifferent?" : "Minimal\nPairs",
            tint: .lcTeal,
            action: #selector(startMinimalPairDrill)
        )
        let isoBtn = makeIconTile(
            icon: "speaker.wave.3.fill",
            label: isKidMode ? "Listen &\nLearn" : "Sound\nPractice",
            tint: .lcPurple,
            action: #selector(startSoundIsolation)
        )

        buttonRow.addArrangedSubview(pairBtn)
        buttonRow.addArrangedSubview(isoBtn)

        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(subtitleLbl)
        stack.addArrangedSubview(buttonRow)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        // Resize gradient on layout
        card.layoutIfNeeded()
        DispatchQueue.main.async { gradient.frame = card.bounds }

        return card
    }

    // MARK: - Category Section (cards for each sound)

    private func buildCategorySection(_ category: SoundCategory, sounds: [SoundProgress]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        // Category header
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center

        let iconView = UIImageView(image: UIImage(systemName: category.icon))
        iconView.tintColor = UIColor(named: category.color) ?? .lcTeal
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let catLabel = UILabel()
        catLabel.text = category.label
        catLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        catLabel.textColor = .secondaryLabel

        header.addArrangedSubview(iconView)
        header.addArrangedSubview(catLabel)
        header.addArrangedSubview(UIView()) // spacer
        container.addArrangedSubview(header)

        // Sound cards in a horizontal scroll
        let scrollContainer = UIScrollView()
        scrollContainer.showsHorizontalScrollIndicator = false
        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.heightAnchor.constraint(equalToConstant: 130).isActive = true

        let cardRow = UIStackView()
        cardRow.axis = .horizontal
        cardRow.spacing = 12
        cardRow.translatesAutoresizingMaskIntoConstraints = false
        scrollContainer.addSubview(cardRow)

        NSLayoutConstraint.activate([
            cardRow.topAnchor.constraint(equalTo: scrollContainer.contentLayoutGuide.topAnchor),
            cardRow.leadingAnchor.constraint(equalTo: scrollContainer.contentLayoutGuide.leadingAnchor),
            cardRow.trailingAnchor.constraint(equalTo: scrollContainer.contentLayoutGuide.trailingAnchor),
            cardRow.bottomAnchor.constraint(equalTo: scrollContainer.contentLayoutGuide.bottomAnchor),
            cardRow.heightAnchor.constraint(equalTo: scrollContainer.frameLayoutGuide.heightAnchor),
        ])

        for progress in sounds {
            cardRow.addArrangedSubview(buildSoundCard(progress, category: category))
        }

        container.addArrangedSubview(scrollContainer)
        return container
    }

    private func buildSoundCard(_ progress: SoundProgress, category: SoundCategory) -> UIView {
        let card = LCCard()
        card.widthAnchor.constraint(equalToConstant: 120).isActive = true
        card.isUserInteractionEnabled = true

        let tap = SoundCardTapGesture(target: self, action: #selector(didTapSoundCard(_:)))
        tap.soundName = progress.sound
        card.addGestureRecognizer(tap)

        let color = UIColor(named: category.color) ?? .lcTeal

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Sound label (big)
        let soundLbl = UILabel()
        soundLbl.text = isKidMode ? progress.sound.uppercased() : progress.sound
        soundLbl.font = .systemFont(ofSize: isKidMode ? 28 : 24, weight: .bold)
        soundLbl.textColor = color

        // IPA
        let ipaLbl = UILabel()
        let soundDef = SoundTherapyContent.sound(named: progress.sound)
        ipaLbl.text = soundDef?.ipa ?? ""
        ipaLbl.font = .systemFont(ofSize: 12, weight: .medium)
        ipaLbl.textColor = .tertiaryLabel

        // Level badge
        let levelLbl = UILabel()
        levelLbl.text = progress.currentLevel.label
        levelLbl.font = .systemFont(ofSize: 10, weight: .semibold)
        levelLbl.textColor = .white
        levelLbl.backgroundColor = color.withAlphaComponent(0.8)
        levelLbl.textAlignment = .center
        levelLbl.layer.cornerRadius = 8
        levelLbl.clipsToBounds = true
        levelLbl.heightAnchor.constraint(equalToConstant: 16).isActive = true
        levelLbl.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true

        // Accuracy bar
        let barBg = UIView()
        barBg.backgroundColor = color.withAlphaComponent(0.15)
        barBg.layer.cornerRadius = 3
        barBg.translatesAutoresizingMaskIntoConstraints = false
        barBg.heightAnchor.constraint(equalToConstant: 6).isActive = true
        barBg.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let barFill = UIView()
        barFill.backgroundColor = color
        barFill.layer.cornerRadius = 3
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barBg.addSubview(barFill)

        let fillWidth = min(90, 90 * CGFloat(progress.overallAccuracy / 100))
        NSLayoutConstraint.activate([
            barFill.topAnchor.constraint(equalTo: barBg.topAnchor),
            barFill.leadingAnchor.constraint(equalTo: barBg.leadingAnchor),
            barFill.bottomAnchor.constraint(equalTo: barBg.bottomAnchor),
            barFill.widthAnchor.constraint(equalToConstant: fillWidth),
        ])

        // Accuracy label
        let accLbl = UILabel()
        accLbl.text = progress.totalAttempts > 0
            ? String(format: "%.0f%%", progress.overallAccuracy) : "New"
        accLbl.font = UIFont.lcCaption()
        accLbl.textColor = .tertiaryLabel

        stack.addArrangedSubview(soundLbl)
        stack.addArrangedSubview(ipaLbl)
        stack.addArrangedSubview(levelLbl)
        stack.addArrangedSubview(barBg)
        stack.addArrangedSubview(accLbl)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
        ])

        // Mastered star
        if progress.isMastered {
            let star = UIImageView(image: UIImage(systemName: "star.fill"))
            star.tintColor = .lcGold
            star.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(star)
            NSLayoutConstraint.activate([
                star.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
                star.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
                star.widthAnchor.constraint(equalToConstant: 16),
                star.heightAnchor.constraint(equalToConstant: 16),
            ])
        }

        return card
    }

    // MARK: - Minimal Pairs Grid

    private func buildMinimalPairsGrid() -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10

        // Show available contrasts as tappable cards, 2 per row
        let contrasts = SoundTherapyContent.allContrasts
        for i in stride(from: 0, to: contrasts.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually

            for j in i..<min(i + 2, contrasts.count) {
                row.addArrangedSubview(buildContrastCard(contrasts[j]))
            }
            // Pad with spacer if odd
            if i + 1 >= contrasts.count {
                row.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(row)
        }

        return grid
    }

    private func buildContrastCard(_ contrast: String) -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true

        let tap = ContrastTapGesture(target: self, action: #selector(didTapContrastCard(_:)))
        tap.contrast = contrast
        card.addGestureRecognizer(tap)

        let parts = contrast.components(separatedBy: " vs ")
        let sound1 = parts.first ?? ""
        let sound2 = parts.last ?? ""

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let lbl1 = UILabel()
        lbl1.text = sound1
        lbl1.font = .systemFont(ofSize: 20, weight: .bold)
        lbl1.textColor = .lcTeal
        lbl1.textAlignment = .center

        let vsLbl = UILabel()
        vsLbl.text = "vs"
        vsLbl.font = .systemFont(ofSize: 12, weight: .medium)
        vsLbl.textColor = .tertiaryLabel

        let lbl2 = UILabel()
        lbl2.text = sound2
        lbl2.font = .systemFont(ofSize: 20, weight: .bold)
        lbl2.textColor = .lcOrange
        lbl2.textAlignment = .center

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true

        stack.addArrangedSubview(lbl1)
        stack.addArrangedSubview(vsLbl)
        stack.addArrangedSubview(lbl2)
        stack.addArrangedSubview(UIView()) // spacer
        stack.addArrangedSubview(chevron)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        return card
    }

    // MARK: - Voice Tip Card

    private func buildVoiceTipCard() -> UIView {
        let card = LCCard()
        card.backgroundColor = UIColor.lcAmber.withAlphaComponent(0.08)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false

        let bulb = UIImageView(image: UIImage(systemName: "lightbulb.fill"))
        bulb.tintColor = .lcAmber
        bulb.contentMode = .scaleAspectFit
        bulb.widthAnchor.constraint(equalToConstant: 24).isActive = true
        bulb.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let tipStack = UIStackView()
        tipStack.axis = .vertical
        tipStack.spacing = 4

        let tipTitle = UILabel()
        tipTitle.text = "Why Female Voices Are Easier"
        tipTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        tipTitle.textColor = .label

        let tipBody = UILabel()
        tipBody.text = "Female voices have higher pitch (~220 Hz) with sharper formant peaks, making sounds like 'ee' and 'sh' more distinct through your CI processor. Male voices (~120 Hz) compress these cues into a flatter range. Start with female voice, then challenge yourself with male!"
        tipBody.font = UIFont.lcCaption()
        tipBody.textColor = .secondaryLabel
        tipBody.numberOfLines = 0

        tipStack.addArrangedSubview(tipTitle)
        tipStack.addArrangedSubview(tipBody)
        stack.addArrangedSubview(bulb)
        stack.addArrangedSubview(tipStack)

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
        lbl.text = text
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .tertiaryLabel
        lbl.letterSpacing(1.2)
        return lbl
    }

    // MARK: - Icon Tile Builder

    private func makeIconTile(icon: String, label: String,
                               tint: UIColor, action: Selector) -> UIView {
        let tile = UIView()
        tile.backgroundColor = tint.withAlphaComponent(0.10)
        tile.layer.cornerRadius = LC.cornerRadius
        tile.isUserInteractionEnabled = true
        tile.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon circle
        let circleBg = UIView()
        circleBg.backgroundColor = tint.withAlphaComponent(0.18)
        circleBg.layer.cornerRadius = 26
        circleBg.translatesAutoresizingMaskIntoConstraints = false
        circleBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        circleBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        circleBg.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: circleBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circleBg.centerYAnchor),
        ])

        // Label
        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 13, weight: .semibold)
        lbl.textColor = tint
        lbl.textAlignment = .center
        lbl.numberOfLines = 2

        stack.addArrangedSubview(circleBg)
        stack.addArrangedSubview(lbl)

        tile.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tile.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -12),
            stack.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: tile.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: tile.trailingAnchor, constant: -8),
        ])

        return tile
    }

    // MARK: - Actions

    @objc private func startMinimalPairDrill() {
        let vc = MinimalPairDrillViewController()
        vc.voiceGender = selectedVoiceGender
        vc.isKidMode = isKidMode
        if let weakest = stats?.weakestSound {
            vc.focusSound = weakest
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func startSoundIsolation() {
        let vc = SoundIsolationViewController()
        vc.voiceGender = selectedVoiceGender
        vc.isKidMode = isKidMode
        if let weakest = stats?.weakestSound {
            vc.targetSound = weakest
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func didTapSoundCard(_ gesture: SoundCardTapGesture) {
        let vc = SoundIsolationViewController()
        vc.voiceGender = selectedVoiceGender
        vc.isKidMode = isKidMode
        vc.targetSound = gesture.soundName
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func didTapContrastCard(_ gesture: ContrastTapGesture) {
        let vc = MinimalPairDrillViewController()
        vc.voiceGender = selectedVoiceGender
        vc.isKidMode = isKidMode
        vc.contrastFilter = gesture.contrast
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Tap Gesture Subclasses (carry data)

private class SoundCardTapGesture: UITapGestureRecognizer {
    var soundName: String = ""
}

private class ContrastTapGesture: UITapGestureRecognizer {
    var contrast: String = ""
}

// MARK: - UILabel helper

private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = text else { return }
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.kern, value: spacing,
                                range: NSRange(location: 0, length: text.count))
        self.attributedText = attributed
    }
}
