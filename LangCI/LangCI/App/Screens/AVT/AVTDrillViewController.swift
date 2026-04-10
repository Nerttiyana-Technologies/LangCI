// AVTDrillViewController.swift
// LangCI
//
// Redesigned AVT Drill. Clean iOS-native layout:
//   • Large title nav showing "SOUND — Level" with Switch Level bar button
//   • Level chip row (4 levels, active one tinted)
//   • 10 progress dots
//   • Main task card (mode-specific: detection / discrimination / identification / comprehension)
//   • Score summary (Correct / Round / Accuracy)
//   • Clean completion card with trophy, accuracy, level-up message, actions
//
// Service/data behaviour is preserved verbatim.

import UIKit

final class AVTDrillViewController: UIViewController {

    // MARK: - Dependencies

    let sound: String
    var level: ListeningHierarchy
    let targetId: Int

    // MARK: - Session state

    private var drillItems: [AVTDrillItem] = []
    private var currentIndex = 0
    private var sessionId: Int?
    private var correctCount = 0
    private var isSessionComplete = false

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let levelChipsStack = UIStackView()
    private let progressDotsStack = UIStackView()

    private let taskCard = LCCard()
    private var taskContainer: UIStackView?

    private let scoreContainer = UIView()

    // Completion state UI lives inside taskCard, so nothing extra here.

    // MARK: - Init

    init(sound: String, level: ListeningHierarchy, targetId: Int) {
        self.sound = sound
        self.level = level
        self.targetId = targetId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadDrillItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "/\(sound)/ — \(level.label)"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let switchItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.left.arrow.right"),
            style: .plain,
            target: self,
            action: #selector(switchLevel)
        )
        switchItem.tintColor = level.color
        navigationItem.rightBarButtonItem = switchItem
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.alignment = .fill
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

        // Level chips
        buildLevelChips()
        contentStack.addArrangedSubview(levelChipsStack)

        // Progress dots
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

        // Task card
        contentStack.addArrangedSubview(taskCard)
        taskCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        // Score card
        let scoreCard = LCCard()
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.contentView.addSubview(scoreContainer)
        NSLayoutConstraint.activate([
            scoreContainer.topAnchor.constraint(equalTo: scoreCard.contentView.topAnchor, constant: 12),
            scoreContainer.leadingAnchor.constraint(equalTo: scoreCard.contentView.leadingAnchor, constant: 12),
            scoreContainer.trailingAnchor.constraint(equalTo: scoreCard.contentView.trailingAnchor, constant: -12),
            scoreContainer.bottomAnchor.constraint(equalTo: scoreCard.contentView.bottomAnchor, constant: -12)
        ])
        contentStack.addArrangedSubview(sectionBlock(title: "Progress", card: scoreCard))

        refreshScore()
        renderLoadingState()
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let block = UIStackView(arrangedSubviews: [header, card])
        block.axis = .vertical
        block.spacing = 8
        return block
    }

    private func buildLevelChips() {
        levelChipsStack.axis = .horizontal
        levelChipsStack.spacing = 8
        levelChipsStack.distribution = .fillEqually
        levelChipsStack.alignment = .center
        levelChipsStack.translatesAutoresizingMaskIntoConstraints = false

        levelChipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let levels: [ListeningHierarchy] = [.detection, .discrimination, .identification, .comprehension]
        for lvl in levels {
            let chip = LevelChipView(level: lvl, isActive: lvl == level)
            levelChipsStack.addArrangedSubview(chip)
        }
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
            dot.backgroundColor = i == 0 ? level.color : UIColor.systemGray4
            dot.tag = 100 + i
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10)
            ])
            progressDotsStack.addArrangedSubview(dot)
        }
        applyPulseToCurrentDot()
    }

    private func applyPulseToCurrentDot() {
        guard currentIndex < 10,
              let dot = progressDotsStack.viewWithTag(100 + currentIndex) else { return }
        dot.layer.removeAllAnimations()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.35
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dot.layer.add(pulse, forKey: "pulse")
    }

    private func updateProgressDots() {
        for i in 0..<10 {
            guard let dot = progressDotsStack.viewWithTag(100 + i) else { continue }
            dot.layer.removeAllAnimations()
            if i < currentIndex {
                dot.backgroundColor = level.color
            } else if i == currentIndex {
                dot.backgroundColor = level.color
            } else {
                dot.backgroundColor = UIColor.systemGray4
            }
        }
        applyPulseToCurrentDot()
    }

    // MARK: - Loading / Session

    private func loadDrillItems() {
        isSessionComplete = false
        renderLoadingState()

        // Prime the confusion cache first so the drill round can mix in
        // personal confusion items on the next call.
        Task {
            await ConfusionDrillService.shared.primeCache()
            await MainActor.run {
                let items = ServiceLocator.shared.avtService.getDrillItems(
                    sound: self.sound,
                    level: self.level
                )
                self.drillItems = Array(items.shuffled().prefix(10))
                self.startSession()
            }
        }
    }

    private func startSession() {
        Task {
            do {
                let session = try await ServiceLocator.shared.avtService.startSession(
                    targetSound: sound,
                    level: level
                )
                await MainActor.run {
                    self.sessionId = session.id
                    self.currentIndex = 0
                    self.correctCount = 0
                    self.updateProgressDots()
                    self.refreshScore()
                    self.renderCurrentItem()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to start session", error: error)
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

    private func renderLoadingState() {
        let container = resetTaskContainer()
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Loading drill…"
        label.font = UIFont.lcBody()
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        let wrap = UIStackView(arrangedSubviews: [spinner, label])
        wrap.axis = .vertical
        wrap.spacing = 12
        wrap.alignment = .center
        container.addArrangedSubview(UIView())  // top spacer
        container.addArrangedSubview(wrap)
        container.addArrangedSubview(UIView())  // bottom spacer
    }

    private func renderCurrentItem() {
        guard currentIndex < drillItems.count else {
            renderSessionComplete()
            return
        }

        let item = drillItems[currentIndex]
        let container = resetTaskContainer()

        switch level {
        case .detection:
            renderDetection(item: item, in: container)
        case .discrimination:
            renderDiscrimination(item: item, in: container)
        case .identification:
            renderIdentification(item: item, in: container)
        case .comprehension:
            renderComprehension(item: item, in: container)
        }
    }

    private func makePromptLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.lcSectionTitle()
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private func makePlayButton(tag: Int = 0) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = level.color
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "play.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold))
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 22, leading: 26, bottom: 22, trailing: 26)

        let button = UIButton(configuration: config)
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(playAudio(sender:)), for: .touchUpInside)
        return button
    }

    private func renderDetection(item: AVTDrillItem, in container: UIStackView) {
        container.addArrangedSubview(makePromptLabel("Did you hear a sound?"))

        let ear = UILabel()
        ear.text = "👂"
        ear.font = UIFont.systemFont(ofSize: 70)
        ear.textAlignment = .center

        let playButton = makePlayButton()
        let playWrap = UIStackView(arrangedSubviews: [playButton])
        playWrap.alignment = .center
        playWrap.axis = .vertical

        container.addArrangedSubview(ear)
        container.addArrangedSubview(playWrap)

        let yes = LCButton(title: "Yes, I heard it", color: .lcGreen)
        yes.tag = 1
        yes.addTarget(self, action: #selector(answerDetection(sender:)), for: .touchUpInside)
        yes.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let no = LCButton(title: "No sound", color: .lcRed)
        no.tag = 0
        no.addTarget(self, action: #selector(answerDetection(sender:)), for: .touchUpInside)
        no.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let answers = UIStackView(arrangedSubviews: [yes, no])
        answers.axis = .vertical
        answers.spacing = 10
        answers.distribution = .fillEqually
        container.addArrangedSubview(answers)
    }

    private func renderDiscrimination(item: AVTDrillItem, in container: UIStackView) {
        container.addArrangedSubview(makePromptLabel("Are these the same or different?"))

        let playA = makeSecondaryPlayButton(title: "Play A", tag: currentIndex * 10)
        let playB = makeSecondaryPlayButton(title: "Play B", tag: currentIndex * 10 + 1)

        let playRow = UIStackView(arrangedSubviews: [playA, playB])
        playRow.axis = .horizontal
        playRow.spacing = 12
        playRow.distribution = .fillEqually
        container.addArrangedSubview(playRow)

        let same = LCButton(title: "Same", color: .lcBlue)
        same.tag = 1
        same.addTarget(self, action: #selector(answerDiscrimination(sender:)), for: .touchUpInside)
        same.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let diff = LCButton(title: "Different", color: .lcOrange)
        diff.tag = 0
        diff.addTarget(self, action: #selector(answerDiscrimination(sender:)), for: .touchUpInside)
        diff.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let answers = UIStackView(arrangedSubviews: [same, diff])
        answers.axis = .vertical
        answers.spacing = 10
        answers.distribution = .fillEqually
        container.addArrangedSubview(answers)
    }

    private func makeSecondaryPlayButton(title: String, tag: Int) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = level.color.withAlphaComponent(0.15)
        config.baseForegroundColor = level.color
        config.image = UIImage(systemName: "play.circle.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold))
        config.imagePlacement = .top
        config.imagePadding = 6
        config.cornerStyle = .large

        var titleAttr = AttributedString(title)
        titleAttr.font = UIFont.lcBodyBold()
        config.attributedTitle = titleAttr
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 12)

        let button = UIButton(configuration: config)
        button.tag = tag
        button.addTarget(self, action: #selector(playAudio(sender:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 84).isActive = true
        return button
    }

    private func renderIdentification(item: AVTDrillItem, in container: UIStackView) {
        container.addArrangedSubview(makePromptLabel("Which word did you hear?"))

        let playWrap = UIStackView(arrangedSubviews: [makePlayButton()])
        playWrap.alignment = .center
        playWrap.axis = .vertical
        container.addArrangedSubview(playWrap)

        let choices = ([item.displayText] + item.distractors.prefix(3).map { $0.text }).shuffled()
        let answers = UIStackView()
        answers.axis = .vertical
        answers.spacing = 10

        for choice in choices {
            let button = makeChoiceButton(title: choice)
            button.accessibilityIdentifier = choice
            button.addTarget(self, action: #selector(answerIdentification(sender:)), for: .touchUpInside)
            answers.addArrangedSubview(button)
        }
        container.addArrangedSubview(answers)
    }

    private func renderComprehension(item: AVTDrillItem, in container: UIStackView) {
        container.addArrangedSubview(makePromptLabel("What does this word mean?"))

        let playWrap = UIStackView(arrangedSubviews: [makePlayButton()])
        playWrap.alignment = .center
        playWrap.axis = .vertical
        container.addArrangedSubview(playWrap)

        let meanings = ([item.displayText] + item.distractors.prefix(3).map { $0.text }).shuffled()
        let answers = UIStackView()
        answers.axis = .vertical
        answers.spacing = 10

        for meaning in meanings {
            let button = makeChoiceButton(title: meaning)
            button.accessibilityIdentifier = meaning
            button.titleLabel?.numberOfLines = 2
            button.addTarget(self, action: #selector(answerComprehension(sender:)), for: .touchUpInside)
            answers.addArrangedSubview(button)
        }
        container.addArrangedSubview(answers)
    }

    private func makeChoiceButton(title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = level.color.withAlphaComponent(0.14)
        config.baseForegroundColor = level.color
        config.background.strokeColor = level.color.withAlphaComponent(0.35)
        config.background.strokeWidth = 1
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)

        var titleAttr = AttributedString(title)
        titleAttr.font = UIFont.lcBodyBold()
        config.attributedTitle = titleAttr

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        return button
    }

    // MARK: - Score / stats

    private func refreshScore() {
        scoreContainer.subviews.forEach { $0.removeFromSuperview() }

        let denom = drillItems.isEmpty ? 10 : drillItems.count
        let round = isSessionComplete
            ? denom
            : min(currentIndex + 1, denom)

        let attempts = currentIndex
        let pct: Int = attempts > 0
            ? Int((Double(correctCount) / Double(attempts)) * 100.0)
            : 0

        let row = LCStatRow(items: [
            .init(label: "Correct", value: "\(correctCount)", tint: .lcGreen),
            .init(label: "Round", value: "\(round)/\(denom)", tint: level.color),
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

    // MARK: - Audio / answers

    @objc private func playAudio(sender: UIButton) {
        guard currentIndex < drillItems.count else { return }
        lcHaptic(.light)
        let item = drillItems[currentIndex]

        // Discrimination mode has two play buttons (Play A / Play B). Their
        // tags are `currentIndex * 10` (even) and `currentIndex * 10 + 1`
        // (odd), so the parity picks which distractor to present.
        if level == .discrimination {
            let distractorIndex = sender.tag % 2
            AVTAudioPlayer.shared.play(item: item, distractorIndex: distractorIndex)
        } else {
            AVTAudioPlayer.shared.play(item: item)
        }
    }

    @objc private func answerDetection(sender: UIButton) {
        guard currentIndex < drillItems.count else { return }
        let item = drillItems[currentIndex]
        let userResponse = sender.tag == 1 ? "heard" : "silent"
        let isCorrect = (userResponse == "heard") == (arc4random_uniform(2) == 0)
        recordAnswer(userResponse: userResponse, isCorrect: isCorrect, item: item)
    }

    @objc private func answerDiscrimination(sender: UIButton) {
        guard currentIndex < drillItems.count else { return }
        let item = drillItems[currentIndex]
        let userResponse = sender.tag == 1 ? "same" : "different"
        let isCorrect = (userResponse == "same") == (arc4random_uniform(2) == 0)
        recordAnswer(userResponse: userResponse, isCorrect: isCorrect, item: item)
    }

    @objc private func answerIdentification(sender: UIButton) {
        guard currentIndex < drillItems.count else { return }
        let item = drillItems[currentIndex]
        let userResponse = sender.accessibilityIdentifier ?? ""
        let isCorrect = userResponse == item.displayText
        recordAnswer(userResponse: userResponse, isCorrect: isCorrect, item: item)
    }

    @objc private func answerComprehension(sender: UIButton) {
        guard currentIndex < drillItems.count else { return }
        let item = drillItems[currentIndex]
        let userResponse = sender.accessibilityIdentifier ?? ""
        let isCorrect = userResponse == item.displayText
        recordAnswer(userResponse: userResponse, isCorrect: isCorrect, item: item)
    }

    private func recordAnswer(userResponse: String, isCorrect: Bool, item: AVTDrillItem) {
        guard let sessionId else { return }

        if isCorrect { correctCount += 1 }
        lcHaptic(isCorrect ? .medium : .light)

        Task {
            do {
                _ = try await ServiceLocator.shared.avtService.recordAttempt(
                    sessionId: sessionId,
                    targetSound: sound,
                    presentedSound: item.sound,
                    userResponse: userResponse,
                    isCorrect: isCorrect,
                    level: level
                )
                await MainActor.run {
                    self.showFeedback(isCorrect: isCorrect, item: item, userResponse: userResponse)
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to record answer", error: error)
                }
            }
        }
    }

    private func showFeedback(isCorrect: Bool, item: AVTDrillItem, userResponse: String) {
        let message = isCorrect ? "Correct!" : "Try again — /\(item.sound)/"
        let icon = isCorrect ? "checkmark.circle.fill" : "xmark.octagon.fill"
        let tint: UIColor = isCorrect ? .lcGreen : .lcRed
        lcShowToast(message, icon: icon, tint: tint, duration: 1.0)

        // On wrong answers, offer inline confusion capture before advancing.
        if !isCorrect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.offerConfusionCapture(item: item, userResponse: userResponse)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.advanceToNext()
        }
    }

    private func advanceToNext() {
        currentIndex += 1
        updateProgressDots()
        refreshScore()
        renderCurrentItem()
    }

    private func offerConfusionCapture(item: AVTDrillItem, userResponse: String) {
        let said  = item.displayText.isEmpty ? item.sound : item.displayText
        let heard = userResponse

        let alert = UIAlertController(
            title: "Log this confusion?",
            message: "You heard \"\(heard)\" instead of \"\(said)\". Save it to your Confusion Log so you can review patterns later.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { [weak self] _ in
            self?.advanceToNext()
        })
        alert.addAction(UIAlertAction(title: "Log it", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let pair = ConfusionPair(
                saidWord: said,
                heardWord: heard,
                targetSound: item.sound,
                source: .avtDrill,
                avtSessionId: self.sessionId,
                loggedAt: Date()
            )
            Task {
                do {
                    _ = try await ServiceLocator.shared.confusionPairService.logPair(pair)
                    try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                    await MainActor.run {
                        self.lcHapticSuccess()
                        self.lcShowToast("Logged", icon: "checkmark.circle.fill", tint: .lcGreen)
                        self.advanceToNext()
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Save failed", icon: "exclamationmark.triangle.fill", tint: .lcRed)
                        self.advanceToNext()
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Session complete

    private func renderSessionComplete() {
        isSessionComplete = true
        refreshScore()
        let container = resetTaskContainer()
        container.alignment = .center
        container.spacing = 18

        let trophy = UILabel()
        trophy.text = "🏆"
        trophy.font = UIFont.systemFont(ofSize: 72)
        trophy.textAlignment = .center

        let accuracy = drillItems.isEmpty ? 0 : Double(correctCount) / Double(drillItems.count)
        let pctLabel = UILabel()
        pctLabel.text = String(format: "%.0f%%", accuracy * 100)
        pctLabel.font = UIFont.lcHeroTitle()
        pctLabel.textColor = level.color
        pctLabel.textAlignment = .center

        let subtitle = UILabel()
        subtitle.font = UIFont.lcBody()
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        if accuracy >= 0.8, let next = level.nextLevel {
            subtitle.text = "Great job — you're ready for \(next.label)!"
        } else if accuracy >= 0.8 {
            subtitle.text = "Top marks — you've mastered this level."
        } else {
            subtitle.text = "Keep practicing — you can do it!"
        }

        container.addArrangedSubview(UIView())
        container.addArrangedSubview(trophy)
        container.addArrangedSubview(pctLabel)
        container.addArrangedSubview(subtitle)

        let again = LCButton(title: "Practice Again", color: level.color)
        again.addTarget(self, action: #selector(practiceAgain), for: .touchUpInside)
        again.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let done = LCButton(title: "Done", color: .lcGreen)
        done.addTarget(self, action: #selector(completeSession), for: .touchUpInside)
        done.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let actions = UIStackView(arrangedSubviews: [again, done])
        actions.axis = .horizontal
        actions.spacing = 10
        actions.distribution = .fillEqually
        actions.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(actions)
        container.addArrangedSubview(UIView())
        actions.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16).isActive = true
        actions.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16).isActive = true

        // Trophy pop-in
        let pop = CABasicAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.2
        pop.toValue = 1.0
        pop.duration = 0.55
        pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
        trophy.layer.add(pop, forKey: "pop")

        lcHapticSuccess()
    }

    // MARK: - Actions

    @objc private func switchLevel() {
        lcHaptic(.light)
        let alert = UIAlertController(title: "Switch Level", message: nil, preferredStyle: .actionSheet)
        for lvl in [ListeningHierarchy.detection, .discrimination, .identification, .comprehension] {
            let prefix = lvl == level ? "✓  " : "    "
            alert.addAction(UIAlertAction(title: prefix + lvl.label, style: .default) { [weak self] _ in
                guard let self else { return }
                self.level = lvl
                self.setupNavigation()
                self.buildLevelChips()
                self.currentIndex = 0
                self.correctCount = 0
                self.buildProgressDots()
                self.refreshScore()
                self.loadDrillItems()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    @objc private func practiceAgain() {
        lcHaptic(.light)
        currentIndex = 0
        correctCount = 0
        isSessionComplete = false
        buildProgressDots()
        refreshScore()
        loadDrillItems()
    }

    @objc private func completeSession() {
        lcHaptic(.medium)
        Task {
            do {
                guard let sessionId else { return }
                _ = try await ServiceLocator.shared.avtService.completeSession(id: sessionId)

                let accuracy = drillItems.isEmpty ? 0 : Double(correctCount) / Double(drillItems.count)
                if accuracy >= 0.8 {
                    try await ServiceLocator.shared.avtService.setTargetLevel(
                        level.nextLevel ?? level,
                        targetId: targetId
                    )
                }
                // Auto-detect "first AVT drill" milestone (and any
                // other firsts that became true since last scan).
                try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                await MainActor.run {
                    _ = self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to complete session", error: error)
                }
            }
        }
    }

    private func showError(_ title: String, error: Error?) {
        let alert = UIAlertController(
            title: title,
            message: error?.localizedDescription ?? "An unknown error occurred",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - LevelChipView

private final class LevelChipView: UIView {

    init(level: ListeningHierarchy, isActive: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let bg: UIColor = isActive ? level.color.withAlphaComponent(0.15) : .lcCard
        let border: UIColor = isActive ? level.color.withAlphaComponent(0.55) : UIColor.separator.withAlphaComponent(0.4)
        let fg: UIColor = isActive ? level.color : .secondaryLabel

        backgroundColor = bg
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = border.cgColor

        let emoji = UILabel()
        emoji.text = level.emoji
        emoji.font = UIFont.systemFont(ofSize: 18)
        emoji.textAlignment = .center

        let label = UILabel()
        label.text = level.label
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = fg
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8

        let stack = UIStackView(arrangedSubviews: [emoji, label])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Helper Extensions
//
// `label` and `emoji` are already declared on `ListeningHierarchy` in
// `Domain/Models/AVTModels.swift`. Only the UI-specific helpers
// (`color`, `nextLevel`) live here — they don't belong in the Domain
// layer because they import UIKit colours.
extension ListeningHierarchy {
    var color: UIColor {
        switch self {
        case .detection: return .systemGray
        case .discrimination: return .lcOrange
        case .identification: return .lcBlue
        case .comprehension: return .lcGreen
        }
    }

    var nextLevel: ListeningHierarchy? {
        switch self {
        case .detection: return .discrimination
        case .discrimination: return .identification
        case .identification: return .comprehension
        case .comprehension: return nil
        }
    }
}
