// FatigueJournalViewController.swift
// LangCI
//
// Redesigned fatigue journal — clean iOS-native layout with:
//   • Large-title nav
//   • Today card with slider-based effort/fatigue + menu pickers for env/program
//   • Week dots row (clickable, colored by fatigue level)
//   • Weekly stats card
//   • Prominent "Log Entry" primary action

import UIKit

final class FatigueJournalViewController: UIViewController {

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Input card
    private let inputCard = LCCard()
    private let effortHeaderLabel = UILabel()
    private let effortValueLabel = UILabel()
    private let effortSlider = UISlider()
    private let fatigueHeaderLabel = UILabel()
    private let fatigueValueLabel = UILabel()
    private let fatigueSlider = UISlider()
    private let hoursHeaderLabel = UILabel()
    private let hoursValueLabel = UILabel()
    private let hoursStepper = UIStepper()
    private let environmentRow = LCListRow(icon: "speaker.wave.2",
                                           title: "Environment",
                                           subtitle: "Where were you listening?",
                                           tint: .lcAmber)
    private let programRow = LCListRow(icon: "cpu",
                                       title: "Processor Program",
                                       subtitle: "Which program?",
                                       tint: .lcAmber)
    private let notesTextView = UITextView()
    private let notesPlaceholder = UILabel()
    private let saveButton = LCButton(title: "Log Entry", color: .lcAmber)

    // Week card
    private let weekCard = LCCard()
    private let weekDotsStack = UIStackView()

    // Stats card
    private let statsCard = LCCard()
    private var statsRow: LCStatRow?

    // MARK: - State
    private var selectedEffort: Int = 3
    private var selectedFatigue: Int = 3
    private var selectedHours: Double = 8.0
    private var selectedEnvironment: FatigueEnvironment = .quiet
    private var selectedProgram: ProcessorProgram = .everyday
    private var weekEntries: [FatigueEntry] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadWeekData()
    }

    // MARK: - Setup
    private func setupNavigation() {
        title = "Fatigue Journal"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .lcBackground
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
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

        buildInputCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Today", card: inputCard))

        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(saveButton)

        buildWeekCard()
        contentStack.addArrangedSubview(sectionBlock(title: "This Week", card: weekCard))

        buildStatsCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Weekly Summary", card: statsCard))
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    private func buildInputCard() {
        // Effort
        effortHeaderLabel.text = "Listening Effort"
        effortHeaderLabel.font = UIFont.lcBodyBold()
        effortHeaderLabel.textColor = .label

        effortValueLabel.text = "3"
        effortValueLabel.font = UIFont.lcCardValue()
        effortValueLabel.textColor = .lcAmber
        effortValueLabel.textAlignment = .right

        let effortHeader = UIStackView(arrangedSubviews: [effortHeaderLabel, effortValueLabel])
        effortHeader.axis = .horizontal

        effortSlider.minimumValue = 1
        effortSlider.maximumValue = 5
        effortSlider.value = 3
        effortSlider.tintColor = .lcAmber
        effortSlider.isContinuous = true
        effortSlider.addTarget(self, action: #selector(effortSliderChanged), for: .valueChanged)

        let effortHint = UILabel()
        effortHint.text = "1 = effortless   •   5 = exhausting"
        effortHint.font = UIFont.lcCaption()
        effortHint.textColor = .secondaryLabel

        let effortSection = UIStackView(arrangedSubviews: [effortHeader, effortSlider, effortHint])
        effortSection.axis = .vertical
        effortSection.spacing = 6

        // Fatigue
        fatigueHeaderLabel.text = "Fatigue Level"
        fatigueHeaderLabel.font = UIFont.lcBodyBold()
        fatigueHeaderLabel.textColor = .label

        fatigueValueLabel.text = "3"
        fatigueValueLabel.font = UIFont.lcCardValue()
        fatigueValueLabel.textColor = .lcRed
        fatigueValueLabel.textAlignment = .right

        let fatigueHeader = UIStackView(arrangedSubviews: [fatigueHeaderLabel, fatigueValueLabel])
        fatigueHeader.axis = .horizontal

        fatigueSlider.minimumValue = 1
        fatigueSlider.maximumValue = 5
        fatigueSlider.value = 3
        fatigueSlider.tintColor = .lcRed
        fatigueSlider.isContinuous = true
        fatigueSlider.addTarget(self, action: #selector(fatigueSliderChanged), for: .valueChanged)

        let fatigueHint = UILabel()
        fatigueHint.text = "1 = fresh   •   5 = completely drained"
        fatigueHint.font = UIFont.lcCaption()
        fatigueHint.textColor = .secondaryLabel

        let fatigueSection = UIStackView(arrangedSubviews: [fatigueHeader, fatigueSlider, fatigueHint])
        fatigueSection.axis = .vertical
        fatigueSection.spacing = 6

        // Hours worn
        hoursHeaderLabel.text = "Hours Worn"
        hoursHeaderLabel.font = UIFont.lcBodyBold()
        hoursHeaderLabel.textColor = .label

        hoursValueLabel.text = "8 h"
        hoursValueLabel.font = UIFont.lcCardValue()
        hoursValueLabel.textColor = .lcTeal
        hoursValueLabel.textAlignment = .right

        hoursStepper.minimumValue = 0
        hoursStepper.maximumValue = 24
        hoursStepper.stepValue = 1
        hoursStepper.value = 8
        hoursStepper.tintColor = .lcTeal
        hoursStepper.addTarget(self, action: #selector(hoursStepperChanged), for: .valueChanged)

        let hoursHeader = UIStackView(arrangedSubviews: [hoursHeaderLabel, hoursValueLabel, hoursStepper])
        hoursHeader.axis = .horizontal
        hoursHeader.alignment = .center
        hoursHeader.spacing = 12

        // Environment row
        environmentRow.accessoryText = displayName(for: selectedEnvironment)
        environmentRow.addTarget(self, action: #selector(didTapEnvironment), for: .touchUpInside)

        // Program row
        programRow.accessoryText = displayName(for: selectedProgram)
        programRow.addTarget(self, action: #selector(didTapProgram), for: .touchUpInside)

        let selectorStack = UIStackView(arrangedSubviews: [environmentRow, LCDivider(), programRow])
        selectorStack.axis = .vertical
        selectorStack.spacing = 0

        // Notes
        let notesHeader = UILabel()
        notesHeader.text = "Notes"
        notesHeader.font = UIFont.lcBodyBold()
        notesHeader.textColor = .label

        notesTextView.font = UIFont.lcBody()
        notesTextView.textColor = .label
        notesTextView.backgroundColor = .systemGray6
        notesTextView.layer.cornerRadius = 10
        notesTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        notesTextView.delegate = self
        notesTextView.heightAnchor.constraint(equalToConstant: 90).isActive = true
        notesTextView.translatesAutoresizingMaskIntoConstraints = false

        notesPlaceholder.text = "Anything notable about today?"
        notesPlaceholder.font = UIFont.lcBody()
        notesPlaceholder.textColor = .tertiaryLabel
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        notesTextView.addSubview(notesPlaceholder)
        NSLayoutConstraint.activate([
            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor, constant: 14),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor, constant: 14)
        ])

        let notesSection = UIStackView(arrangedSubviews: [notesHeader, notesTextView])
        notesSection.axis = .vertical
        notesSection.spacing = 6

        // Combine all sections
        let mainStack = UIStackView(arrangedSubviews: [
            effortSection,
            fatigueSection,
            hoursHeader,
            selectorStack,
            notesSection
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 18
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // Add some internal padding
        inputCard.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: inputCard.topAnchor, constant: LC.cardPadding),
            mainStack.leadingAnchor.constraint(equalTo: inputCard.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: inputCard.trailingAnchor, constant: -LC.cardPadding),
            mainStack.bottomAnchor.constraint(equalTo: inputCard.bottomAnchor, constant: -LC.cardPadding)
        ])

        // The LCListRow's internal padding already aligns with card padding,
        // so we override the leading here to reach inside the card edge.
        // Make row use the full card width by nesting selectorStack in a wrapper.
    }

    private func buildWeekCard() {
        weekDotsStack.axis = .horizontal
        weekDotsStack.alignment = .center
        weekDotsStack.distribution = .fillEqually
        weekDotsStack.spacing = 6
        weekDotsStack.translatesAutoresizingMaskIntoConstraints = false

        weekCard.addSubview(weekDotsStack)
        NSLayoutConstraint.activate([
            weekDotsStack.topAnchor.constraint(equalTo: weekCard.topAnchor, constant: LC.cardPadding),
            weekDotsStack.leadingAnchor.constraint(equalTo: weekCard.leadingAnchor, constant: LC.cardPadding),
            weekDotsStack.trailingAnchor.constraint(equalTo: weekCard.trailingAnchor, constant: -LC.cardPadding),
            weekDotsStack.bottomAnchor.constraint(equalTo: weekCard.bottomAnchor, constant: -LC.cardPadding)
        ])

        rebuildWeekDots()
    }

    private func buildStatsCard() {
        let placeholder = UILabel()
        placeholder.text = "No entries yet"
        placeholder.font = UIFont.lcBody()
        placeholder.textColor = .secondaryLabel
        placeholder.textAlignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        statsCard.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: LC.cardPadding),
            placeholder.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: LC.cardPadding),
            placeholder.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -LC.cardPadding),
            placeholder.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - Week Dots
    private func rebuildWeekDots() {
        weekDotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let calendar = Calendar.current
        let today = Date()
        let fmt = DateFormatter(); fmt.dateFormat = "EEEEE"

        for offset in (0...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let entry = weekEntries.first { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd }
            let color = color(forFatigue: entry?.fatigueLevel)

            let dotContainer = UIView()
            dotContainer.translatesAutoresizingMaskIntoConstraints = false

            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 18
            dot.translatesAutoresizingMaskIntoConstraints = false

            let dayLabel = UILabel()
            dayLabel.text = fmt.string(from: date)
            dayLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            dayLabel.textColor = .secondaryLabel
            dayLabel.textAlignment = .center
            dayLabel.translatesAutoresizingMaskIntoConstraints = false

            let valueLabel = UILabel()
            valueLabel.text = entry.map { "\($0.fatigueLevel)" } ?? "–"
            valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            valueLabel.textColor = entry != nil ? .white : .secondaryLabel
            valueLabel.textAlignment = .center
            valueLabel.translatesAutoresizingMaskIntoConstraints = false

            dotContainer.addSubview(dayLabel)
            dotContainer.addSubview(dot)
            dot.addSubview(valueLabel)

            NSLayoutConstraint.activate([
                dayLabel.topAnchor.constraint(equalTo: dotContainer.topAnchor),
                dayLabel.centerXAnchor.constraint(equalTo: dotContainer.centerXAnchor),
                dayLabel.leadingAnchor.constraint(greaterThanOrEqualTo: dotContainer.leadingAnchor),
                dayLabel.trailingAnchor.constraint(lessThanOrEqualTo: dotContainer.trailingAnchor),

                dot.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 6),
                dot.centerXAnchor.constraint(equalTo: dotContainer.centerXAnchor),
                dot.widthAnchor.constraint(equalToConstant: 36),
                dot.heightAnchor.constraint(equalToConstant: 36),
                dot.bottomAnchor.constraint(equalTo: dotContainer.bottomAnchor),

                valueLabel.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: dot.centerYAnchor)
            ])

            weekDotsStack.addArrangedSubview(dotContainer)
        }
    }

    private func color(forFatigue level: Int?) -> UIColor {
        guard let lvl = level else { return UIColor.systemGray5 }
        switch lvl {
        case 1, 2: return .lcGreen
        case 3: return .lcAmber
        default: return .lcRed
        }
    }

    // MARK: - Stats card
    private func updateStatsCard() {
        statsCard.subviews.forEach { $0.removeFromSuperview() }

        if weekEntries.isEmpty {
            let placeholder = UILabel()
            placeholder.text = "No entries yet"
            placeholder.font = UIFont.lcBody()
            placeholder.textColor = .secondaryLabel
            placeholder.textAlignment = .center
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            statsCard.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: LC.cardPadding),
                placeholder.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: LC.cardPadding),
                placeholder.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -LC.cardPadding),
                placeholder.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -LC.cardPadding)
            ])
            return
        }

        let count = weekEntries.count
        let avgEffort = Double(weekEntries.map { $0.effortLevel }.reduce(0, +)) / Double(count)
        let avgFatigue = Double(weekEntries.map { $0.fatigueLevel }.reduce(0, +)) / Double(count)

        let row = LCStatRow(items: [
            .init(label: "Effort", value: String(format: "%.1f", avgEffort), tint: .lcAmber),
            .init(label: "Fatigue", value: String(format: "%.1f", avgFatigue), tint: .lcRed),
            .init(label: "Logged", value: "\(count)", tint: .lcTeal)
        ])
        statsCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: LC.cardPadding),
            row.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: LC.cardPadding),
            row.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -LC.cardPadding),
            row.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -LC.cardPadding)
        ])
        statsRow = row
    }

    // MARK: - Actions
    @objc private func effortSliderChanged() {
        let rounded = Int(effortSlider.value.rounded())
        effortSlider.value = Float(rounded)
        selectedEffort = rounded
        effortValueLabel.text = "\(rounded)"
    }

    @objc private func fatigueSliderChanged() {
        let rounded = Int(fatigueSlider.value.rounded())
        fatigueSlider.value = Float(rounded)
        selectedFatigue = rounded
        fatigueValueLabel.text = "\(rounded)"
    }

    @objc private func hoursStepperChanged() {
        selectedHours = hoursStepper.value
        hoursValueLabel.text = "\(Int(selectedHours)) h"
    }

    @objc private func didTapEnvironment() {
        let options: [FatigueEnvironment] = [
            .quiet, .homeTV, .office, .restaurant, .outdoors, .phone, .shopping, .transport
        ]
        let alert = UIAlertController(title: "Environment", message: nil, preferredStyle: .actionSheet)
        for env in options {
            let prefix = env == selectedEnvironment ? "✓  " : ""
            alert.addAction(UIAlertAction(title: prefix + displayName(for: env), style: .default) { [weak self] _ in
                self?.selectedEnvironment = env
                self?.environmentRow.accessoryText = self?.displayName(for: env)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAsSheet(alert, sourceView: environmentRow)
    }

    @objc private func didTapProgram() {
        let options: [ProcessorProgram] = [.everyday, .noise, .music, .focus, .telecoil, .custom1, .custom2]
        let alert = UIAlertController(title: "Processor Program", message: nil, preferredStyle: .actionSheet)
        for program in options {
            let prefix = program == selectedProgram ? "✓  " : ""
            alert.addAction(UIAlertAction(title: prefix + displayName(for: program), style: .default) { [weak self] _ in
                self?.selectedProgram = program
                self?.programRow.accessoryText = self?.displayName(for: program)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAsSheet(alert, sourceView: programRow)
    }

    private func presentAsSheet(_ alert: UIAlertController, sourceView: UIView) {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = [.up, .down]
        }
        present(alert, animated: true)
    }

    @objc private func didTapSave() {
        lcHaptic(.medium)
        let entry = FatigueEntry(
            id: 0,
            loggedAt: Date(),
            effortLevel: selectedEffort,
            fatigueLevel: selectedFatigue,
            environment: selectedEnvironment,
            programUsed: selectedProgram,
            hoursWorn: Int(selectedHours.rounded()),
            notes: notesTextView.text.isEmpty ? nil : notesTextView.text
        )

        Task {
            do {
                _ = try await ServiceLocator.shared.fatigueService.log(entry)
                try? await ServiceLocator.shared.milestoneService.autoDetectFirsts()
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.lcShowToast("Entry logged", icon: "checkmark.circle.fill", tint: .lcAmber)
                    self.resetForm()
                    self.loadWeekData()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to log entry. Please try again.")
                }
            }
        }
    }

    private func resetForm() {
        selectedEffort = 3
        selectedFatigue = 3
        selectedHours = 8.0
        selectedEnvironment = .quiet
        selectedProgram = .everyday
        effortSlider.value = 3
        fatigueSlider.value = 3
        hoursStepper.value = 8
        effortValueLabel.text = "3"
        fatigueValueLabel.text = "3"
        hoursValueLabel.text = "8 h"
        environmentRow.accessoryText = displayName(for: .quiet)
        programRow.accessoryText = displayName(for: .everyday)
        notesTextView.text = ""
        notesPlaceholder.isHidden = false
    }

    // MARK: - Display helpers
    private func displayName(for env: FatigueEnvironment) -> String {
        switch env {
        case .quiet: return "Quiet"
        case .homeTV: return "Home / TV"
        case .office: return "Office"
        case .restaurant: return "Restaurant"
        case .outdoors: return "Outdoors"
        case .phone: return "Phone"
        case .shopping: return "Shopping"
        case .transport: return "Transport"
        }
    }

    private func displayName(for program: ProcessorProgram) -> String {
        switch program {
        case .everyday: return "Everyday"
        case .noise: return "Noise"
        case .music: return "Music"
        case .focus: return "Focus"
        case .telecoil: return "Telecoil"
        case .custom1: return "Custom 1"
        case .custom2: return "Custom 2"
        }
    }

    // MARK: - Data
    private func loadWeekData() {
        Task {
            do {
                let entries = try await ServiceLocator.shared.fatigueService.getEntries(days: 7)
                await MainActor.run {
                    self.weekEntries = entries
                    self.rebuildWeekDots()
                    self.updateStatsCard()
                }
            } catch {
                // silent
            }
        }
    }

    // MARK: - Error
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension FatigueJournalViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
    }
}
