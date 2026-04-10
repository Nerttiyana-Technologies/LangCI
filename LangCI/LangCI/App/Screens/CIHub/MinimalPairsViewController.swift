// MinimalPairsViewController.swift
// LangCI
//
// Redesigned Minimal Pairs game. Clean iOS-native look:
//   • Large title nav
//   • Progress dots row showing round state
//   • Big centered play card (circular play button)
//   • Two choice buttons stacked vertically (or horizontal if room)
//   • Live score LCStatRow
//   • Completion overlay with score + Try Again / Done buttons

import UIKit

final class MinimalPairsViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Progress
    private let progressCard = LCCard()
    private let roundLabel = UILabel()
    private var progressDots: [UIView] = []

    // Play card
    private let playCard = LCCard()
    private let promptLabel = UILabel()
    private let playButton = UIButton(type: .system)

    // Choice buttons
    private let choicesCard = LCCard()
    private let choiceButton1 = UIButton(type: .system)
    private let choiceButton2 = UIButton(type: .system)

    // Score
    private let scoreCard = LCCard()
    private var scoreRow: LCStatRow?

    // Completion overlay
    private let overlayView = UIView()
    private let overlayCard = LCCard()
    private let overlayTitleLabel = UILabel()
    private let overlayScoreLabel = UILabel()
    private let overlayMessageLabel = UILabel()
    private let tryAgainButton = LCButton(title: "Try Again", color: .lcBlue)
    private let doneButton = LCButton(title: "Done", color: .lcGreen)

    // MARK: - State

    private let viewModel = MinimalPairsViewModel()
    private var pairs: [MinimalPairDto] = []
    private var currentPairIndex = 0
    private var correctCount = 0
    private let totalRounds = 10
    private var currentPairId: Int?
    private var playedWord: MinimalPairWordDto?
    private var otherWord: MinimalPairWordDto?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        updateScoreRow()
        loadPairs()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Minimal Pairs"
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

        buildProgressCard()
        contentStack.addArrangedSubview(progressCard)

        buildPlayCard()
        contentStack.addArrangedSubview(playCard)

        buildChoicesCard()
        contentStack.addArrangedSubview(choicesCard)

        buildScoreCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Score", card: scoreCard))

        buildOverlay()
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Progress card

    private func buildProgressCard() {
        roundLabel.text = "Round 1 of \(totalRounds)"
        roundLabel.font = UIFont.lcBodyBold()
        roundLabel.textColor = .label
        roundLabel.textAlignment = .center
        roundLabel.translatesAutoresizingMaskIntoConstraints = false

        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .center
        dotsStack.distribution = .fillEqually
        dotsStack.translatesAutoresizingMaskIntoConstraints = false

        progressDots.removeAll()
        for _ in 0..<totalRounds {
            let dot = UIView()
            dot.backgroundColor = .systemGray5
            dot.layer.cornerRadius = 5
            dot.clipsToBounds = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
            progressDots.append(dot)
            dotsStack.addArrangedSubview(dot)
        }

        let inner = UIStackView(arrangedSubviews: [roundLabel, dotsStack])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false

        progressCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: LC.cardPadding),
            inner.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: LC.cardPadding),
            inner.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -LC.cardPadding),
            inner.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func updateProgressDots() {
        for (index, dot) in progressDots.enumerated() {
            if index < currentPairIndex {
                dot.backgroundColor = .lcGreen
            } else if index == currentPairIndex {
                dot.backgroundColor = .lcBlue
            } else {
                dot.backgroundColor = .systemGray5
            }
        }
    }

    // MARK: - Play card

    private func buildPlayCard() {
        promptLabel.text = "Tap play, then choose the word you heard"
        promptLabel.font = UIFont.lcBody()
        promptLabel.textColor = .secondaryLabel
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.translatesAutoresizingMaskIntoConstraints = false

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = .lcBlue
        cfg.baseForegroundColor = .white
        cfg.image = UIImage(
            systemName: "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        )
        cfg.cornerStyle = .capsule
        playButton.configuration = cfg
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)

        let inner = UIStackView(arrangedSubviews: [promptLabel, playButton])
        inner.axis = .vertical
        inner.spacing = 16
        inner.alignment = .center
        inner.translatesAutoresizingMaskIntoConstraints = false

        playCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: playCard.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: playCard.leadingAnchor, constant: LC.cardPadding),
            inner.trailingAnchor.constraint(equalTo: playCard.trailingAnchor, constant: -LC.cardPadding),
            inner.bottomAnchor.constraint(equalTo: playCard.bottomAnchor, constant: -20),
            playButton.widthAnchor.constraint(equalToConstant: 84),
            playButton.heightAnchor.constraint(equalToConstant: 84)
        ])
    }

    @objc private func didTapPlay() {
        lcHaptic(.light)
        // In a real app, play audio of `playedWord`.
        // For now we pulse the button to give feedback.
        UIView.animate(withDuration: 0.1, animations: {
            self.playButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.playButton.transform = .identity
            }
        }
    }

    // MARK: - Choices card

    private func buildChoicesCard() {
        configureChoiceButton(choiceButton1)
        configureChoiceButton(choiceButton2)
        choiceButton1.addTarget(self, action: #selector(didTapAnswer1), for: .touchUpInside)
        choiceButton2.addTarget(self, action: #selector(didTapAnswer2), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [choiceButton1, choiceButton2])
        stack.axis = .vertical
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        choicesCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: choicesCard.topAnchor, constant: LC.cardPadding),
            stack.leadingAnchor.constraint(equalTo: choicesCard.leadingAnchor, constant: LC.cardPadding),
            stack.trailingAnchor.constraint(equalTo: choicesCard.trailingAnchor, constant: -LC.cardPadding),
            stack.bottomAnchor.constraint(equalTo: choicesCard.bottomAnchor, constant: -LC.cardPadding),
            choiceButton1.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func configureChoiceButton(_ button: UIButton) {
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = UIColor.lcBlue.withAlphaComponent(0.12)
        cfg.baseForegroundColor = .label
        cfg.cornerStyle = .large
        cfg.titleAlignment = .center
        cfg.titlePadding = 4
        var titleAttr = AttributedString("—")
        titleAttr.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        cfg.attributedTitle = titleAttr
        button.configuration = cfg
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setChoiceTitle(_ button: UIButton, native: String, translit: String?) {
        var cfg = button.configuration ?? UIButton.Configuration.filled()
        var titleAttr = AttributedString(native)
        titleAttr.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        cfg.attributedTitle = titleAttr
        if let t = translit, !t.isEmpty {
            var sub = AttributedString(t)
            sub.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            sub.foregroundColor = .secondaryLabel
            cfg.attributedSubtitle = sub
        } else {
            cfg.attributedSubtitle = nil
        }
        button.configuration = cfg
    }

    private func setChoiceColor(_ button: UIButton, tint: UIColor) {
        var cfg = button.configuration
        cfg?.baseBackgroundColor = tint.withAlphaComponent(0.2)
        cfg?.baseForegroundColor = .label
        button.configuration = cfg
    }

    // MARK: - Score card

    private func buildScoreCard() {
        updateScoreRow()
    }

    private func updateScoreRow() {
        scoreRow?.removeFromSuperview()
        let accuracy: Int
        if currentPairIndex > 0 {
            accuracy = Int(Double(correctCount) / Double(currentPairIndex) * 100)
        } else {
            accuracy = 0
        }
        let row = LCStatRow(items: [
            .init(label: "Correct", value: "\(correctCount)", tint: .lcGreen),
            .init(label: "Round", value: "\(min(currentPairIndex + 1, totalRounds))", tint: .lcBlue),
            .init(label: "Accuracy", value: "\(accuracy)%", tint: .lcOrange)
        ])
        scoreCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scoreCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: scoreCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: scoreCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: scoreCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        scoreRow = row
    }

    // MARK: - Completion overlay

    private func buildOverlay() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.isHidden = true
        view.addSubview(overlayView)

        overlayCard.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(overlayCard)

        overlayTitleLabel.text = "Session Complete"
        overlayTitleLabel.font = UIFont.lcHeroTitle()
        overlayTitleLabel.textColor = .label
        overlayTitleLabel.textAlignment = .center
        overlayTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        overlayScoreLabel.text = "0/\(totalRounds)"
        overlayScoreLabel.font = UIFont.systemFont(ofSize: 54, weight: .bold)
        overlayScoreLabel.textColor = .lcBlue
        overlayScoreLabel.textAlignment = .center
        overlayScoreLabel.translatesAutoresizingMaskIntoConstraints = false

        overlayMessageLabel.text = ""
        overlayMessageLabel.font = UIFont.lcBody()
        overlayMessageLabel.textColor = .secondaryLabel
        overlayMessageLabel.textAlignment = .center
        overlayMessageLabel.numberOfLines = 0
        overlayMessageLabel.translatesAutoresizingMaskIntoConstraints = false

        tryAgainButton.addTarget(self, action: #selector(didTapTryAgain), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [tryAgainButton, doneButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView(arrangedSubviews: [
            overlayTitleLabel,
            overlayScoreLabel,
            overlayMessageLabel,
            buttonStack
        ])
        inner.axis = .vertical
        inner.spacing = 14
        inner.alignment = .fill
        inner.translatesAutoresizingMaskIntoConstraints = false

        overlayCard.addSubview(inner)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayCard.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            overlayCard.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            overlayCard.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 24),
            overlayCard.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -24),

            inner.topAnchor.constraint(equalTo: overlayCard.topAnchor, constant: 24),
            inner.leadingAnchor.constraint(equalTo: overlayCard.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: overlayCard.trailingAnchor, constant: -20),
            inner.bottomAnchor.constraint(equalTo: overlayCard.bottomAnchor, constant: -20),

            tryAgainButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Data

    private func loadPairs() {
        Task {
            do {
                let loaded = try await viewModel.loadPairs(count: totalRounds)
                await MainActor.run {
                    self.pairs = loaded
                    if !loaded.isEmpty {
                        self.displayPair(index: 0)
                    } else {
                        self.promptLabel.text = "No minimal pairs available."
                    }
                }
            } catch {
                await MainActor.run {
                    self.promptLabel.text = "Couldn't load minimal pairs."
                }
            }
        }
    }

    private func displayPair(index: Int) {
        guard index < pairs.count else {
            endGame()
            return
        }
        currentPairIndex = index
        let pair = pairs[index]
        currentPairId = pair.id

        let playFirst = Bool.random()
        playedWord = playFirst ? pair.word1 : pair.word2
        otherWord  = playFirst ? pair.word2 : pair.word1

        roundLabel.text = "Round \(index + 1) of \(totalRounds)"
        updateProgressDots()

        setChoiceTitle(choiceButton1, native: pair.word1.nativeScript, translit: pair.word1.transliteration)
        setChoiceTitle(choiceButton2, native: pair.word2.nativeScript, translit: pair.word2.transliteration)
        setChoiceColor(choiceButton1, tint: .lcBlue)
        setChoiceColor(choiceButton2, tint: .lcBlue)
        choiceButton1.isEnabled = true
        choiceButton2.isEnabled = true

        updateScoreRow()
    }

    @objc private func didTapAnswer1() {
        let selectedId = pairs[safe: currentPairIndex]?.word1.wordEntryId
        handleAnswer(selectedWordEntryId: selectedId, tappedButton: choiceButton1)
    }

    @objc private func didTapAnswer2() {
        let selectedId = pairs[safe: currentPairIndex]?.word2.wordEntryId
        handleAnswer(selectedWordEntryId: selectedId, tappedButton: choiceButton2)
    }

    private func handleAnswer(selectedWordEntryId: Int?, tappedButton: UIButton) {
        choiceButton1.isEnabled = false
        choiceButton2.isEnabled = false

        let isCorrect = (selectedWordEntryId != nil) && (selectedWordEntryId == playedWord?.wordEntryId)
        if isCorrect {
            correctCount += 1
            setChoiceColor(tappedButton, tint: .lcGreen)
            lcHapticSuccess()
        } else {
            setChoiceColor(tappedButton, tint: .lcRed)
            // Highlight the correct one
            let correctButton = (pairs[safe: currentPairIndex]?.word1.wordEntryId == playedWord?.wordEntryId)
                ? choiceButton1 : choiceButton2
            setChoiceColor(correctButton, tint: .lcGreen)
            lcHaptic(.heavy)
        }
        updateScoreRow()

        if let pairId = currentPairId,
           let playedId = playedWord?.wordEntryId,
           let selectedId = selectedWordEntryId {
            Task {
                _ = try? await viewModel.recordAttempt(
                    minimalPairId: pairId,
                    playedWordEntryId: playedId,
                    selectedWordEntryId: selectedId
                )
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.displayPair(index: self.currentPairIndex + 1)
        }
    }

    private func endGame() {
        // Mark the last dot green
        if let lastDot = progressDots.last { lastDot.backgroundColor = .lcGreen }

        overlayScoreLabel.text = "\(correctCount)/\(totalRounds)"
        let accuracy = totalRounds > 0 ? Int(Double(correctCount) / Double(totalRounds) * 100) : 0
        if accuracy >= 80 {
            overlayMessageLabel.text = "Excellent work! \(accuracy)% accuracy."
            overlayScoreLabel.textColor = .lcGreen
        } else if accuracy >= 60 {
            overlayMessageLabel.text = "Good job. Keep practising to improve."
            overlayScoreLabel.textColor = .lcOrange
        } else {
            overlayMessageLabel.text = "Keep going — you'll improve with practice."
            overlayScoreLabel.textColor = .lcRed
        }

        overlayView.isHidden = false
        overlayView.alpha = 0
        UIView.animate(withDuration: 0.25) { self.overlayView.alpha = 1 }
    }

    @objc private func didTapTryAgain() {
        correctCount = 0
        currentPairIndex = 0
        updateScoreRow()
        for dot in progressDots { dot.backgroundColor = .systemGray5 }
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayView.alpha = 0
        }) { _ in
            self.overlayView.isHidden = true
            self.loadPairs()
        }
    }

    @objc private func didTapDone() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
