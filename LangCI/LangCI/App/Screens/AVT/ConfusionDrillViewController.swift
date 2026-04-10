// ConfusionDrillViewController.swift
// LangCI
//
// Dedicated drill built from the user's own logged confusion pairs.
// Presents each "said → heard" pair as an identification item: the audio
// speaks the "said" word, and the user picks between it and the word they
// previously misheard it as.
//
// Entry point: a card on the Home screen. Falls back to an empty state
// when the user has logged fewer than 3 confusion pairs.

import UIKit

final class ConfusionDrillViewController: UIViewController {

    // MARK: - State

    private var items: [AVTDrillItem] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var isComplete = false

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let taskCard = LCCard()
    private var taskContainer: UIStackView?
    private let scoreContainer = UIView()
    private let progressDotsStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Confusion Drill"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8, leading: 16, bottom: 24, trailing: 16
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

        buildProgressDots()
        let progressWrap = UIView()
        progressWrap.translatesAutoresizingMaskIntoConstraints = false
        progressWrap.addSubview(progressDotsStack)
        NSLayoutConstraint.activate([
            progressDotsStack.centerXAnchor.constraint(equalTo: progressWrap.centerXAnchor),
            progressDotsStack.topAnchor.constraint(equalTo: progressWrap.topAnchor),
            progressDotsStack.bottomAnchor.constraint(equalTo: progressWrap.bottomAnchor)
        ])
        contentStack.addArrangedSubview(progressWrap)

        contentStack.addArrangedSubview(taskCard)
        taskCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true

        let scoreCard = LCCard()
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.contentView.addSubview(scoreContainer)
        NSLayoutConstraint.activate([
            scoreContainer.topAnchor.constraint(equalTo: scoreCard.contentView.topAnchor, constant: 12),
            scoreContainer.leadingAnchor.constraint(equalTo: scoreCard.contentView.leadingAnchor, constant: 12),
            scoreContainer.trailingAnchor.constraint(equalTo: scoreCard.contentView.trailingAnchor, constant: -12),
            scoreContainer.bottomAnchor.constraint(equalTo: scoreCard.contentView.bottomAnchor, constant: -12)
        ])
        contentStack.addArrangedSubview(scoreCard)

        refreshScore()
        renderLoading()
    }

    private func buildProgressDots() {
        progressDotsStack.axis = .horizontal
        progressDotsStack.spacing = 8
        progressDotsStack.alignment = .center
        progressDotsStack.translatesAutoresizingMaskIntoConstraints = false
        progressDotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for i in 0..<10 {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 5
            dot.backgroundColor = i == 0 ? .lcPurple : UIColor.systemGray4
            dot.tag = 200 + i
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10)
            ])
            progressDotsStack.addArrangedSubview(dot)
        }
    }

    private func updateProgressDots() {
        for i in 0..<10 {
            guard let dot = progressDotsStack.viewWithTag(200 + i) else { continue }
            dot.backgroundColor = i <= currentIndex ? .lcPurple : UIColor.systemGray4
        }
    }

    // MARK: - Data

    private func loadItems() {
        Task {
            let fetched = await ConfusionDrillService.shared.buildDrillItems(
                limit: 10,
                level: .identification
            )
            await MainActor.run {
                self.items = fetched.shuffled()
                if self.items.count < 3 {
                    self.renderEmptyState()
                } else {
                    self.currentIndex = 0
                    self.correctCount = 0
                    self.isComplete = false
                    self.refreshScore()
                    self.renderCurrentItem()
                }
            }
        }
    }

    // MARK: - Rendering

    private func resetTaskContainer() -> UIStackView {
        taskCard.contentView.subviews.forEach { $0.removeFromSuperview() }

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 20
        container.alignment = .fill
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isLayoutMarginsRelativeArrangement = true
        container.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 20, leading: 20, bottom: 20, trailing: 20
        )

        taskCard.contentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: taskCard.contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: taskCard.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: taskCard.contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: taskCard.contentView.bottomAnchor)
        ])
        taskContainer = container
        return container
    }

    private func renderLoading() {
        let container = resetTaskContainer()
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Loading your confusions…"
        label.font = UIFont.lcBody()
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        let wrap = UIStackView(arrangedSubviews: [spinner, label])
        wrap.axis = .vertical
        wrap.spacing = 12
        wrap.alignment = .center
        container.addArrangedSubview(UIView())
        container.addArrangedSubview(wrap)
        container.addArrangedSubview(UIView())
    }

    private func renderEmptyState() {
        let container = resetTaskContainer()
        container.alignment = .center

        let icon = UILabel()
        icon.text = "🎯"
        icon.font = UIFont.systemFont(ofSize: 64)

        let title = UILabel()
        title.text = "Log some confusions first"
        title.font = UIFont.lcSectionTitle()
        title.textAlignment = .center
        title.numberOfLines = 0

        let hint = UILabel()
        hint.text = "During any AVT drill, tap Log it when you miss a word. Once you have 3+ logged pairs, Confusion Drill will build a custom session from your personal mistakes."
        hint.font = UIFont.lcBody()
        hint.textColor = .secondaryLabel
        hint.textAlignment = .center
        hint.numberOfLines = 0

        container.addArrangedSubview(UIView())
        container.addArrangedSubview(icon)
        container.addArrangedSubview(title)
        container.addArrangedSubview(hint)
        container.addArrangedSubview(UIView())
    }

    private func renderCurrentItem() {
        guard currentIndex < items.count else {
            renderComplete()
            return
        }

        let item = items[currentIndex]
        let container = resetTaskContainer()

        let prompt = UILabel()
        prompt.text = "Which word did you hear?"
        prompt.font = UIFont.lcSectionTitle()
        prompt.textAlignment = .center
        prompt.numberOfLines = 0
        container.addArrangedSubview(prompt)

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .lcPurple
        config.baseForegroundColor = .white
        config.image = UIImage(
            systemName: "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        )
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 22, leading: 26, bottom: 22, trailing: 26)
        let playButton = UIButton(configuration: config)
        playButton.addTarget(self, action: #selector(playAudio), for: .touchUpInside)
        let playWrap = UIStackView(arrangedSubviews: [playButton])
        playWrap.alignment = .center
        playWrap.axis = .vertical
        container.addArrangedSubview(playWrap)

        let choices = ([item.displayText] + item.distractors.filter { !$0.isCorrect }.map { $0.text })
            .prefix(4)
            .shuffled()

        let answers = UIStackView()
        answers.axis = .vertical
        answers.spacing = 10
        for choice in choices {
            var cfg = UIButton.Configuration.filled()
            cfg.baseBackgroundColor = UIColor.lcPurple.withAlphaComponent(0.14)
            cfg.baseForegroundColor = .lcPurple
            cfg.cornerStyle = .large
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
            var titleAttr = AttributedString(choice)
            titleAttr.font = UIFont.lcBodyBold()
            cfg.attributedTitle = titleAttr
            let button = UIButton(configuration: cfg)
            button.accessibilityIdentifier = choice
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            button.addTarget(self, action: #selector(answerTapped(sender:)), for: .touchUpInside)
            answers.addArrangedSubview(button)
        }
        container.addArrangedSubview(answers)
    }

    private func renderComplete() {
        isComplete = true
        refreshScore()
        let container = resetTaskContainer()
        container.alignment = .center
        container.spacing = 18

        let trophy = UILabel()
        trophy.text = "🎯"
        trophy.font = UIFont.systemFont(ofSize: 72)

        let pct = items.isEmpty ? 0 : Int(Double(correctCount) / Double(items.count) * 100)
        let label = UILabel()
        label.text = "\(pct)%"
        label.font = UIFont.lcHeroTitle()
        label.textColor = .lcPurple

        let subtitle = UILabel()
        subtitle.font = UIFont.lcBody()
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        if pct >= 80 {
            subtitle.text = "You're untangling your confusions — great work!"
        } else {
            subtitle.text = "These are tricky. Keep drilling; you'll get there."
        }

        let done = LCButton(title: "Done", color: .lcGreen)
        done.addTarget(self, action: #selector(dismissDrill), for: .touchUpInside)
        done.heightAnchor.constraint(equalToConstant: 52).isActive = true

        container.addArrangedSubview(UIView())
        container.addArrangedSubview(trophy)
        container.addArrangedSubview(label)
        container.addArrangedSubview(subtitle)
        container.addArrangedSubview(done)
        container.addArrangedSubview(UIView())

        lcHapticSuccess()
    }

    // MARK: - Score

    private func refreshScore() {
        scoreContainer.subviews.forEach { $0.removeFromSuperview() }
        let denom = items.isEmpty ? 10 : items.count
        let round = isComplete ? denom : min(currentIndex + 1, denom)
        let attempts = currentIndex
        let pct = attempts > 0 ? Int(Double(correctCount) / Double(attempts) * 100) : 0
        let row = LCStatRow(items: [
            .init(label: "Correct", value: "\(correctCount)", tint: .lcGreen),
            .init(label: "Round", value: "\(round)/\(denom)", tint: .lcPurple),
            .init(label: "Accuracy", value: "\(pct)%", tint: .lcBlue)
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        scoreContainer.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scoreContainer.topAnchor),
            row.leadingAnchor.constraint(equalTo: scoreContainer.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scoreContainer.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scoreContainer.bottomAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func playAudio() {
        guard currentIndex < items.count else { return }
        lcHaptic(.light)
        AVTAudioPlayer.shared.play(item: items[currentIndex])
    }

    @objc private func answerTapped(sender: UIButton) {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        let userResponse = sender.accessibilityIdentifier ?? ""
        let isCorrect = userResponse == item.displayText
        if isCorrect { correctCount += 1 }
        lcHaptic(isCorrect ? .medium : .light)

        let message = isCorrect ? "Correct!" : "Heard: \(item.displayText)"
        let icon = isCorrect ? "checkmark.circle.fill" : "xmark.octagon.fill"
        let tint: UIColor = isCorrect ? .lcGreen : .lcRed
        lcShowToast(message, icon: icon, tint: tint, duration: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.currentIndex += 1
            self.updateProgressDots()
            self.refreshScore()
            self.renderCurrentItem()
        }
    }

    @objc private func dismissDrill() {
        lcHaptic(.medium)
        navigationController?.popViewController(animated: true)
    }
}
