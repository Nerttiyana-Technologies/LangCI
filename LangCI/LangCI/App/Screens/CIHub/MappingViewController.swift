// MappingViewController.swift
// LangCI
//
// Redesigned Electrode Mapping screen. Clean iOS-native look:
//   • Large title nav
//   • Session card: date picker, audiologist text field, program segmented
//   • 22 electrode rows with T/C steppers inside an LCCard
//   • Notes card with placeholder
//   • Save button

import UIKit

final class MappingViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Session info
    private let sessionCard = LCCard()
    private let datePicker = UIDatePicker()
    private let audiologistTextField = UITextField()
    private let programSegmented = UISegmentedControl()

    // Electrodes
    private let electrodesCard = LCCard()
    private var electrodeRows: [ElectrodeRowView] = []

    // Notes
    private let notesCard = LCCard()
    private let notesTextView = UITextView()
    private let notesPlaceholder = UILabel()

    // Save
    private let saveButton = LCButton(title: "Save Mapping", color: .lcPurple)

    // MARK: - State

    private var electrodeLevels: [ElectrodeLevel] = []
    private var selectedDate = Date()
    private var selectedProgram: ProcessorProgram = .everyday
    private let electrodeCount = 22

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        initializeElectrodeLevels()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Mapping"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground
    }

    private func initializeElectrodeLevels() {
        electrodeLevels = (1...electrodeCount).map { number in
            ElectrodeLevel(
                id: number - 1,
                mappingSessionId: 0,
                electrodeNumber: number,
                tLevel: 0,
                cLevel: 0,
                isActive: true,
                notes: nil
            )
        }
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

        buildSessionCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Session", card: sessionCard))

        buildElectrodesCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Electrode Levels", card: electrodesCard))

        buildNotesCard()
        contentStack.addArrangedSubview(sectionBlock(title: "Notes", card: notesCard))

        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(saveButton)

        // Dismiss keyboard on tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let wrap = UIStackView(arrangedSubviews: [header, card])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.translatesAutoresizingMaskIntoConstraints = false
        return wrap
    }

    // MARK: - Session card

    private func buildSessionCard() {
        // Date row
        let dateLabel = makeFieldLabel("Session Date")
        datePicker.preferredDatePickerStyle = .compact
        datePicker.datePickerMode = .date
        datePicker.date = selectedDate
        datePicker.tintColor = .lcPurple
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(didChangeDate), for: .valueChanged)

        let dateRow = UIStackView(arrangedSubviews: [dateLabel, UIView(), datePicker])
        dateRow.axis = .horizontal
        dateRow.alignment = .center
        dateRow.spacing = 8

        // Audiologist row
        let audiologistLabel = makeFieldLabel("Audiologist")
        audiologistTextField.placeholder = "Name"
        audiologistTextField.font = UIFont.lcBody()
        audiologistTextField.textColor = .label
        audiologistTextField.backgroundColor = .systemGray6
        audiologistTextField.layer.cornerRadius = 8
        audiologistTextField.translatesAutoresizingMaskIntoConstraints = false
        // Add horizontal padding
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        audiologistTextField.leftView = leftPadding
        audiologistTextField.leftViewMode = .always
        audiologistTextField.returnKeyType = .done
        audiologistTextField.delegate = self
        audiologistTextField.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let audiologistStack = UIStackView(arrangedSubviews: [audiologistLabel, audiologistTextField])
        audiologistStack.axis = .vertical
        audiologistStack.spacing = 6

        // Program row
        let programLabel = makeFieldLabel("Processor Program")
        programSegmented.insertSegment(withTitle: "Every", at: 0, animated: false)
        programSegmented.insertSegment(withTitle: "Noise", at: 1, animated: false)
        programSegmented.insertSegment(withTitle: "Music", at: 2, animated: false)
        programSegmented.insertSegment(withTitle: "Focus", at: 3, animated: false)
        programSegmented.insertSegment(withTitle: "Tcoil", at: 4, animated: false)
        programSegmented.selectedSegmentIndex = 0
        programSegmented.translatesAutoresizingMaskIntoConstraints = false
        programSegmented.heightAnchor.constraint(equalToConstant: 34).isActive = true
        programSegmented.addTarget(self, action: #selector(didChangeProgram), for: .valueChanged)

        let programStack = UIStackView(arrangedSubviews: [programLabel, programSegmented])
        programStack.axis = .vertical
        programStack.spacing = 6

        let mainStack = UIStackView(arrangedSubviews: [dateRow, audiologistStack, programStack])
        mainStack.axis = .vertical
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        sessionCard.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: sessionCard.topAnchor, constant: LC.cardPadding),
            mainStack.leadingAnchor.constraint(equalTo: sessionCard.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: sessionCard.trailingAnchor, constant: -LC.cardPadding),
            mainStack.bottomAnchor.constraint(equalTo: sessionCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.lcBodyBold()
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @objc private func didChangeDate() {
        selectedDate = datePicker.date
    }

    @objc private func didChangeProgram() {
        let programs: [ProcessorProgram] = [.everyday, .noise, .music, .focus, .telecoil]
        let idx = programSegmented.selectedSegmentIndex
        if idx >= 0 && idx < programs.count {
            selectedProgram = programs[idx]
        }
    }

    // MARK: - Electrodes card

    private func buildElectrodesCard() {
        // Header row for T/C columns
        let headerE = UILabel()
        headerE.text = "Electrode"
        headerE.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        headerE.textColor = .tertiaryLabel

        let headerT = UILabel()
        headerT.text = "T-Level"
        headerT.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        headerT.textColor = .tertiaryLabel
        headerT.textAlignment = .center

        let headerC = UILabel()
        headerC.text = "C-Level"
        headerC.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        headerC.textColor = .tertiaryLabel
        headerC.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [headerE, headerT, headerC])
        headerStack.axis = .horizontal
        headerStack.distribution = .fill
        headerStack.spacing = 8
        headerE.widthAnchor.constraint(equalToConstant: 60).isActive = true
        headerT.widthAnchor.constraint(equalTo: headerC.widthAnchor).isActive = true
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // All 22 rows in a vertical stack (no inner scroll — outer scroll handles it)
        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 6
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        electrodeRows.removeAll()
        for i in 0..<electrodeCount {
            let row = ElectrodeRowView(number: i + 1)
            row.onTChange = { [weak self] value in
                self?.electrodeLevels[i].tLevel = Double(value)
            }
            row.onCChange = { [weak self] value in
                self?.electrodeLevels[i].cLevel = Double(value)
            }
            electrodeRows.append(row)
            rowsStack.addArrangedSubview(row)

            if i < electrodeCount - 1 {
                rowsStack.addArrangedSubview(LCDivider())
            }
        }

        let inner = UIStackView(arrangedSubviews: [headerStack, rowsStack])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false

        electrodesCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: electrodesCard.topAnchor, constant: LC.cardPadding),
            inner.leadingAnchor.constraint(equalTo: electrodesCard.leadingAnchor, constant: LC.cardPadding),
            inner.trailingAnchor.constraint(equalTo: electrodesCard.trailingAnchor, constant: -LC.cardPadding),
            inner.bottomAnchor.constraint(equalTo: electrodesCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - Notes card

    private func buildNotesCard() {
        notesTextView.font = UIFont.lcBody()
        notesTextView.textColor = .label
        notesTextView.backgroundColor = .systemGray6
        notesTextView.layer.cornerRadius = 10
        notesTextView.clipsToBounds = true
        notesTextView.textContainerInset = .init(top: 10, left: 8, bottom: 10, right: 8)
        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        notesTextView.delegate = self
        notesTextView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        notesPlaceholder.text = "Session notes, observations, next steps…"
        notesPlaceholder.font = UIFont.lcBody()
        notesPlaceholder.textColor = .tertiaryLabel
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        notesCard.addSubview(notesTextView)
        notesCard.addSubview(notesPlaceholder)

        NSLayoutConstraint.activate([
            notesTextView.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: LC.cardPadding),
            notesTextView.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: LC.cardPadding),
            notesTextView.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -LC.cardPadding),
            notesTextView.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -LC.cardPadding),

            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor, constant: 16),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor, constant: 14)
        ])
    }

    // MARK: - Save

    @objc private func didTapSave() {
        view.endEditing(true)
        saveButton.isEnabled = false
        Task {
            do {
                let trimmed = (audiologistTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                var session = MappingSession(
                    id: 0,
                    sessionDate: selectedDate,
                    audiologistName: trimmed,
                    clinicName: "",
                    notes: notesTextView.text.isEmpty ? nil : notesTextView.text,
                    nextAppointmentDate: nil
                )
                session = try await ServiceLocator.shared.mappingService.saveSession(session)

                await MainActor.run {
                    self.saveButton.isEnabled = true
                    self.lcHapticSuccess()
                    self.lcShowToast("Mapping saved", icon: "checkmark.circle.fill", tint: .lcPurple)
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.saveButton.isEnabled = true
                    self.lcShowToast("Save failed", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension MappingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITextViewDelegate (notes placeholder)

extension MappingViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
    }
}

// MARK: - ElectrodeRowView

final class ElectrodeRowView: UIView {

    private let badgeLabel = UILabel()
    private let tValueLabel = UILabel()
    private let cValueLabel = UILabel()
    private let tStepper = UIStepper()
    private let cStepper = UIStepper()

    var onTChange: ((Int) -> Void)?
    var onCChange: ((Int) -> Void)?

    init(number: Int) {
        super.init(frame: .zero)
        buildUI(number: number)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(number: Int) {
        translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.text = "E\(number)"
        badgeLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textColor = .lcPurple
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.12)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        // T column
        tValueLabel.text = "0"
        tValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        tValueLabel.textColor = .label
        tValueLabel.textAlignment = .right
        tValueLabel.translatesAutoresizingMaskIntoConstraints = false
        tValueLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        tStepper.minimumValue = 0
        tStepper.maximumValue = 255
        tStepper.stepValue = 1
        tStepper.autorepeat = true
        tStepper.tintColor = .lcPurple
        tStepper.translatesAutoresizingMaskIntoConstraints = false
        tStepper.addTarget(self, action: #selector(didChangeT), for: .valueChanged)

        let tStack = UIStackView(arrangedSubviews: [tValueLabel, tStepper])
        tStack.axis = .horizontal
        tStack.spacing = 6
        tStack.alignment = .center

        // C column
        cValueLabel.text = "0"
        cValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        cValueLabel.textColor = .label
        cValueLabel.textAlignment = .right
        cValueLabel.translatesAutoresizingMaskIntoConstraints = false
        cValueLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        cStepper.minimumValue = 0
        cStepper.maximumValue = 255
        cStepper.stepValue = 1
        cStepper.autorepeat = true
        cStepper.tintColor = .lcPurple
        cStepper.translatesAutoresizingMaskIntoConstraints = false
        cStepper.addTarget(self, action: #selector(didChangeC), for: .valueChanged)

        let cStack = UIStackView(arrangedSubviews: [cValueLabel, cStepper])
        cStack.axis = .horizontal
        cStack.spacing = 6
        cStack.alignment = .center

        let mainStack = UIStackView(arrangedSubviews: [badgeLabel, tStack, cStack])
        mainStack.axis = .horizontal
        mainStack.distribution = .fill
        mainStack.alignment = .center
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        badgeLabel.heightAnchor.constraint(equalToConstant: 26).isActive = true
        tStack.widthAnchor.constraint(equalTo: cStack.widthAnchor).isActive = true

        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }

    @objc private func didChangeT() {
        let v = Int(tStepper.value)
        tValueLabel.text = "\(v)"
        onTChange?(v)
    }

    @objc private func didChangeC() {
        let v = Int(cStepper.value)
        cValueLabel.text = "\(v)"
        onCChange?(v)
    }
}
