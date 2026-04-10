// TrainViewController.swift
// LangCI
//
// Redesigned Train setup screen — clean iOS-native layout with large title,
// stats header, menu-based language/dialect pickers, and prominent start button.

import UIKit

final class TrainViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    // Stats row (Due / Mode / Source)
    private let statsCard = LCCard()
    private var statsRow: LCStatRow?

    // Mode card
    private let modeCard    = LCCard()
    private let modeSegment = UISegmentedControl()

    // Selectors card (language + dialect rows stacked with divider)
    private let selectorsCard = LCCard()
    private let languageRow   = LCListRow(icon: "globe",
                                          title: "Language",
                                          subtitle: "Tap to choose",
                                          tint: .lcGreen)
    private let dialectRow    = LCListRow(icon: "character.bubble",
                                          title: "Dialect",
                                          subtitle: "Tap to choose",
                                          tint: .lcGreen)

    // Start button
    private let startButton = LCButton(title: "Start Training", color: .lcGreen)

    // Loading overlay
    private let loadingView = LCLoadingView(message: "Loading languages…")

    // MARK: - State

    private var languages: [Language] = []
    private var dialects:  [Dialect]  = []
    private var selectedLanguage: Language?
    private var selectedDialect:  Dialect?
    private var dueWordsCount: Int = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadLanguages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDueWordsCount()
    }

    // MARK: - Navigation

    private func setupNavigation() {
        navigationItem.title = "Train"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground
    }

    // MARK: - UI Setup

    private func buildUI() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Stats card
        buildStatsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Today", card: statsCard))

        // Mode card
        buildModeCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Mode", card: modeCard))

        // Selectors
        buildSelectorsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Source", card: selectorsCard))

        // Start button
        startButton.addTarget(self, action: #selector(handleStartSession), for: .touchUpInside)
        startButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        contentStack.addArrangedSubview(startButton)

        // Loading overlay
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: LC.cardPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -LC.cardPadding),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * LC.cardPadding),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 200),
            loadingView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func sectionBlock(title: String, card: UIView) -> UIStackView {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 6
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let header = SectionHeaderView(title: title)
        header.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addArrangedSubview(header)
        wrapper.addArrangedSubview(card)
        return wrapper
    }

    private func buildStatsCard() {
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        rebuildStatsRow(due: 0, mode: "Std", source: "—")
    }

    private func rebuildStatsRow(due: Int, mode: String, source: String) {
        statsCard.subviews.forEach { $0.removeFromSuperview() }
        let row = LCStatRow(items: [
            .init(label: "Due",    value: "\(due)",  tint: .lcGreen),
            .init(label: "Mode",   value: mode,      tint: .lcBlue),
            .init(label: "Source", value: source,    tint: .lcOrange)
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -18),
            row.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -12)
        ])
        statsRow = row
    }

    private func buildModeCard() {
        modeCard.translatesAutoresizingMaskIntoConstraints = false

        modeSegment.insertSegment(withTitle: "Standard",  at: 0, animated: false)
        modeSegment.insertSegment(withTitle: "Noisy",     at: 1, animated: false)
        modeSegment.insertSegment(withTitle: "Min Pairs", at: 2, animated: false)
        modeSegment.selectedSegmentIndex = 0
        modeSegment.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeSegment.translatesAutoresizingMaskIntoConstraints = false

        modeCard.addSubview(modeSegment)
        NSLayoutConstraint.activate([
            modeSegment.topAnchor.constraint(equalTo: modeCard.topAnchor, constant: 16),
            modeSegment.bottomAnchor.constraint(equalTo: modeCard.bottomAnchor, constant: -16),
            modeSegment.leadingAnchor.constraint(equalTo: modeCard.leadingAnchor, constant: LC.cardPadding),
            modeSegment.trailingAnchor.constraint(equalTo: modeCard.trailingAnchor, constant: -LC.cardPadding),
            modeSegment.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func buildSelectorsCard() {
        selectorsCard.translatesAutoresizingMaskIntoConstraints = false

        languageRow.addTarget(self, action: #selector(handleLanguageTap), for: .touchUpInside)
        dialectRow.addTarget(self, action: #selector(handleDialectTap), for: .touchUpInside)

        let divider = LCDivider()

        let stack = UIStackView(arrangedSubviews: [languageRow, divider, dialectRow])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        selectorsCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: selectorsCard.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: selectorsCard.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: selectorsCard.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: selectorsCard.trailingAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadLanguages() {
        showLoading(true)
        Task {
            do {
                let langs = try await ServiceLocator.shared.languageService.getActiveLanguages()
                await MainActor.run {
                    self.languages = langs
                    if let first = langs.first {
                        self.selectedLanguage = first
                        self.languageRow.accessoryText = first.name
                    } else {
                        self.languageRow.accessoryText = "None"
                    }
                    self.showLoading(false)
                }
                if let first = langs.first {
                    await loadDialects(for: first.id)
                }
            } catch {
                await MainActor.run {
                    self.showLoading(false)
                    self.showErrorAlert(title: "Error",
                                        message: "Failed to load languages: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadDialects(for languageId: Int) async {
        do {
            let d = try await ServiceLocator.shared.languageService.getActiveDialects(for: languageId)
            await MainActor.run {
                self.dialects = d
                if let first = d.first {
                    self.selectedDialect = first
                    self.dialectRow.accessoryText = first.name
                } else {
                    self.selectedDialect = nil
                    self.dialectRow.accessoryText = "None"
                }
            }
            await refreshDueWordsCountAsync()
        } catch {
            await MainActor.run {
                self.showErrorAlert(title: "Error",
                                    message: "Failed to load dialects: \(error.localizedDescription)")
            }
        }
    }

    private func refreshDueWordsCount() {
        Task { await refreshDueWordsCountAsync() }
    }

    private func refreshDueWordsCountAsync() async {
        guard let dialect = selectedDialect else {
            await MainActor.run {
                self.dueWordsCount = 0
                self.updateStatsRow()
                self.updateStartButtonState()
            }
            return
        }
        do {
            let words = try await ServiceLocator.shared.trainingService.getDueWords(
                dialectId: dialect.id, limit: 200)
            await MainActor.run {
                self.dueWordsCount = words.count
                self.updateStatsRow()
                self.updateStartButtonState()
            }
        } catch {
            await MainActor.run {
                self.dueWordsCount = 0
                self.updateStatsRow()
                self.updateStartButtonState()
            }
        }
    }

    private func updateStatsRow() {
        let modeName: String
        switch modeSegment.selectedSegmentIndex {
        case 1: modeName = "Noisy"
        case 2: modeName = "Pairs"
        default: modeName = "Std"
        }
        let sourceName: String
        if let code = selectedLanguage?.code, !code.isEmpty {
            sourceName = code.uppercased()
        } else if let name = selectedLanguage?.name, !name.isEmpty {
            sourceName = String(name.prefix(3)).uppercased()
        } else {
            sourceName = "—"
        }
        rebuildStatsRow(due: dueWordsCount, mode: modeName, source: sourceName)
    }

    private func updateStartButtonState() {
        let canStart = dueWordsCount > 0 && selectedDialect != nil
        startButton.isEnabled = canStart
        startButton.alpha = canStart ? 1.0 : 0.5
    }

    private func showLoading(_ loading: Bool) {
        loadingView.isHidden = !loading
        scrollView.isHidden = loading
        if loading { loadingView.start() } else { loadingView.stop() }
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        lcHaptic(.light)
        updateStatsRow()
    }

    @objc private func handleLanguageTap() {
        lcHaptic(.light)
        guard !languages.isEmpty else {
            lcShowToast("No languages available", icon: "exclamationmark.triangle.fill", tint: .lcOrange)
            return
        }
        let alert = UIAlertController(title: "Select Language", message: nil, preferredStyle: .actionSheet)
        for lang in languages {
            let marker = (lang.id == selectedLanguage?.id) ? "✓  " : "    "
            let action = UIAlertAction(title: marker + lang.name, style: .default) { [weak self] _ in
                self?.selectLanguage(lang)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAsSheet(alert, sourceView: languageRow)
    }

    @objc private func handleDialectTap() {
        lcHaptic(.light)
        guard !dialects.isEmpty else {
            lcShowToast("No dialects available", icon: "exclamationmark.triangle.fill", tint: .lcOrange)
            return
        }
        let alert = UIAlertController(title: "Select Dialect", message: nil, preferredStyle: .actionSheet)
        for d in dialects {
            let marker = (d.id == selectedDialect?.id) ? "✓  " : "    "
            let action = UIAlertAction(title: marker + d.name, style: .default) { [weak self] _ in
                self?.selectDialect(d)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAsSheet(alert, sourceView: dialectRow)
    }

    private func presentAsSheet(_ alert: UIAlertController, sourceView: UIView) {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = [.up, .down]
        }
        present(alert, animated: true)
    }

    private func selectLanguage(_ lang: Language) {
        selectedLanguage = lang
        languageRow.accessoryText = lang.name
        Task { await loadDialects(for: lang.id) }
    }

    private func selectDialect(_ d: Dialect) {
        selectedDialect = d
        dialectRow.accessoryText = d.name
        refreshDueWordsCount()
    }

    @objc private func handleStartSession() {
        guard let dialect = selectedDialect else {
            showErrorAlert(title: "Selection Required", message: "Please select a dialect.")
            return
        }
        guard dueWordsCount > 0 else {
            lcShowToast("No words due today", icon: "checkmark.seal.fill", tint: .lcGreen)
            return
        }

        lcHaptic(.medium)

        let mode: TrainingMode = switch modeSegment.selectedSegmentIndex {
        case 1: .noisyEnvironment
        case 2: .minimalPairs
        default: .standard
        }

        Task {
            do {
                let session = try await ServiceLocator.shared.trainingService.startSession(
                    dialectId: dialect.id,
                    categoryCode: "all",
                    mode: mode,
                    wordLimit: 20
                )
                await MainActor.run {
                    let trainingVC = TrainingSessionViewController(session: session)
                    self.navigationController?.pushViewController(trainingVC, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.showErrorAlert(title: "Session Error",
                                        message: "Failed to start session: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
