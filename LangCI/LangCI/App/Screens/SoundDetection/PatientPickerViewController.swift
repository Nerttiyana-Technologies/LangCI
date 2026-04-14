// PatientPickerViewController.swift
// LangCI — Pick an existing patient or create a new one
//
// Presented before starting an audiologist test:
//   • Search existing patients by name or identifier
//   • Tap a result to select them (with their DOB/phone/etc.)
//   • Or fill the bottom form to add a NEW patient
//   • If the typed name matches existing patient(s), the UI asks
//     "Did you mean one of these?" to prevent accidental duplicates
//
// Also shows a privacy disclaimer so the audiologist confirms consent.

import UIKit

final class PatientPickerViewController: UIViewController {

    // MARK: - Services

    private let patientService = ServiceLocator.shared.patientService!

    // MARK: - Output

    /// Called with the chosen patient + session date/tester
    var onConfirm: ((_ patient: Patient, _ testerName: String?, _ testedAt: Date) -> Void)?

    // MARK: - State

    private var searchResults: [Patient] = []
    private var recentPatients: [Patient] = []
    /// Non-nil when the typed name matches existing patients — shown as warning
    private var duplicateMatches: [Patient] = []

    // MARK: - UI

    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let footerContainer = UIView()
    private let footerStack = UIStackView()

    // New patient form
    private let newPatientHeaderLabel = UILabel()
    private let nameField = UITextField()
    private let identifierField = UITextField()
    private let duplicateWarningLabel = UILabel()

    // Session info
    private let testerField = UITextField()
    private let datePicker = UIDatePicker()
    private let nowButton = UIButton(type: .system)

    // Consent
    private let consentSwitch = UISwitch()
    private let consentLabel = UILabel()
    private let privacyLabel = UILabel()

    private let primaryButton = LCButton(title: "Start Test", color: .lcTeal)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Patient"
        view.backgroundColor = .lcBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        buildUI()
        loadRecent()
    }

    // MARK: - Build UI

    private func buildUI() {
        // Search bar
        searchBar.placeholder = "Search patients…"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        // Table
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PatientCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)

        // Footer (new patient form + session info + consent + CTA)
        buildFooter()
        // Seed with a non-zero initial frame so the table accepts it; real
        // size is computed in viewDidLayoutSubviews → resizeFooter().
        footerContainer.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        tableView.tableFooterView = footerContainer

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildFooter() {
        // Table footer views must use frame-based sizing. The footer container's
        // width will be set to the table's width in viewDidLayoutSubviews; here
        // we only build auto-layout inside it, pinned to its edges.
        footerContainer.translatesAutoresizingMaskIntoConstraints = true
        footerContainer.autoresizingMask = [.flexibleWidth]

        footerStack.axis = .vertical
        footerStack.spacing = 12
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.isLayoutMarginsRelativeArrangement = true
        footerStack.directionalLayoutMargins = .init(top: 16, leading: 20, bottom: 24, trailing: 20)
        footerContainer.addSubview(footerStack)

        // New patient section header
        newPatientHeaderLabel.text = "Or add a new patient"
        newPatientHeaderLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        newPatientHeaderLabel.textColor = .secondaryLabel
        footerStack.addArrangedSubview(newPatientHeaderLabel)

        configureField(nameField, placeholder: "Patient name (e.g. Suresh S)", icon: "person.fill")
        nameField.addTarget(self, action: #selector(nameDidChange), for: .editingChanged)
        footerStack.addArrangedSubview(nameField)

        configureField(identifierField, placeholder: "DOB, phone, or note (optional)", icon: "number")
        footerStack.addArrangedSubview(identifierField)

        // Duplicate warning
        duplicateWarningLabel.font = UIFont.systemFont(ofSize: 13)
        duplicateWarningLabel.textColor = .lcAmber
        duplicateWarningLabel.numberOfLines = 0
        duplicateWarningLabel.text = ""
        duplicateWarningLabel.isHidden = true
        footerStack.addArrangedSubview(duplicateWarningLabel)

        // Session info header
        let sessionHeader = UILabel()
        sessionHeader.text = "Session Info"
        sessionHeader.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sessionHeader.textColor = .secondaryLabel
        footerStack.addArrangedSubview(sessionHeader)

        configureField(testerField, placeholder: "Tester / Audiologist (optional)", icon: "stethoscope")
        footerStack.addArrangedSubview(testerField)

        // Date row
        let dateHeaderRow = UIStackView()
        dateHeaderRow.axis = .horizontal
        dateHeaderRow.distribution = .equalSpacing
        dateHeaderRow.alignment = .center

        let dateLabel = UILabel()
        dateLabel.text = "Test Date & Time"
        dateLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .label
        dateHeaderRow.addArrangedSubview(dateLabel)

        nowButton.setTitle("Set to Now", for: .normal)
        nowButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        nowButton.tintColor = .lcTeal
        nowButton.addTarget(self, action: #selector(setToNowTapped), for: .touchUpInside)
        dateHeaderRow.addArrangedSubview(nowButton)
        footerStack.addArrangedSubview(dateHeaderRow)

        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        footerStack.addArrangedSubview(datePicker)

        let backdateHint = UILabel()
        backdateHint.text = "Use past dates for sessions captured on paper earlier."
        backdateHint.font = UIFont.systemFont(ofSize: 12)
        backdateHint.textColor = .tertiaryLabel
        backdateHint.numberOfLines = 0
        footerStack.addArrangedSubview(backdateHint)

        // Consent
        consentSwitch.isOn = false
        consentSwitch.onTintColor = .lcTeal
        consentSwitch.addTarget(self, action: #selector(consentChanged), for: .valueChanged)
        consentSwitch.translatesAutoresizingMaskIntoConstraints = false
        // Lock the switch to its intrinsic size so the label cannot squeeze it
        consentSwitch.setContentHuggingPriority(.required, for: .horizontal)
        consentSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)

        consentLabel.text = "I confirm the patient has consented to their information being recorded on this device."
        consentLabel.font = UIFont.systemFont(ofSize: 13)
        consentLabel.textColor = .label
        consentLabel.numberOfLines = 0
        consentLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        consentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let consentRow = UIStackView(arrangedSubviews: [consentSwitch, consentLabel])
        consentRow.axis = .horizontal
        consentRow.spacing = 14
        consentRow.alignment = .center
        consentRow.distribution = .fill
        footerStack.addArrangedSubview(consentRow)

        privacyLabel.text = "All patient data stays on this device and is never uploaded. You can delete it anytime from Settings."
        privacyLabel.font = UIFont.systemFont(ofSize: 11)
        privacyLabel.textColor = .tertiaryLabel
        privacyLabel.numberOfLines = 0
        footerStack.addArrangedSubview(privacyLabel)

        // Primary
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        primaryButton.isEnabled = false
        primaryButton.alpha = 0.5
        footerStack.addArrangedSubview(primaryButton)

        NSLayoutConstraint.activate([
            footerStack.topAnchor.constraint(equalTo: footerContainer.topAnchor),
            footerStack.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor),
            footerStack.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor),
        ])
    }

    /// Size the table footer to fit its contents at the current table width.
    /// Must be called from viewDidLayoutSubviews because the table's width is
    /// only known after the sheet presentation has computed its own bounds.
    private func resizeFooter() {
        let targetWidth = tableView.bounds.width
        guard targetWidth > 0 else { return }

        // If width changed, update the frame first so auto-layout inside
        // can compute against the new width
        if footerContainer.frame.width != targetWidth {
            footerContainer.frame = CGRect(x: 0, y: 0, width: targetWidth, height: footerContainer.frame.height)
        }

        let size = footerContainer.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)

        if footerContainer.frame.height != size.height {
            footerContainer.frame = CGRect(x: 0, y: 0, width: targetWidth, height: size.height)
            // Re-assign to force the table view to pick up the new footer height
            tableView.tableFooterView = footerContainer
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizeFooter()
    }

    private func configureField(_ field: UITextField, placeholder: String, icon: String) {
        field.placeholder = placeholder
        field.font = UIFont.lcBody()
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .words
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .center
        iconView.frame = CGRect(x: 0, y: 0, width: 32, height: 20)
        field.leftView = iconView
        field.leftViewMode = .always
    }

    // MARK: - Data

    private func loadRecent() {
        Task {
            recentPatients = (try? await patientService.recentPatients(limit: 20)) ?? []
            searchResults = recentPatients
            await MainActor.run { self.tableView.reloadData() }
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func setToNowTapped() {
        datePicker.setDate(Date(), animated: true)
        lcHaptic(.light)
    }

    @objc private func consentChanged() {
        updatePrimaryEnabled()
    }

    @objc private func nameDidChange() {
        updatePrimaryEnabled()
        checkForDuplicates()
    }

    private func updatePrimaryEnabled() {
        let hasName = !(nameField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        let hasConsent = consentSwitch.isOn
        primaryButton.isEnabled = hasName && hasConsent
        primaryButton.alpha = primaryButton.isEnabled ? 1.0 : 0.5
    }

    private func checkForDuplicates() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else {
            duplicateWarningLabel.isHidden = true
            duplicateMatches = []
            resizeFooter()
            return
        }

        Task {
            let matches = (try? await patientService.patientsMatching(name: name)) ?? []
            await MainActor.run {
                self.duplicateMatches = matches
                if matches.isEmpty {
                    self.duplicateWarningLabel.isHidden = true
                } else {
                    let examples = matches.prefix(3).map { $0.shortDisplay }.joined(separator: ", ")
                    self.duplicateWarningLabel.text = "⚠️ A patient named \"\(name)\" already exists (\(examples)). Scroll up to select, or add an identifier below to keep them distinct."
                    self.duplicateWarningLabel.isHidden = false
                }
                self.resizeFooter()
            }
        }
    }

    @objc private func primaryTapped() {
        lcHaptic(.medium)

        guard consentSwitch.isOn else { return }
        let nameText = (nameField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !nameText.isEmpty else { return }

        let identifierText = (identifierField.text ?? "").trimmingCharacters(in: .whitespaces)
        let tester = (testerField.text ?? "").trimmingCharacters(in: .whitespaces)

        // If duplicates exist and no identifier provided, warn once
        if !duplicateMatches.isEmpty && identifierText.isEmpty {
            let alert = UIAlertController(
                title: "Duplicate Name?",
                message: "A patient named \"\(nameText)\" already exists. Do you want to create a NEW patient with the same name, or select the existing one from the list above?",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Create New Anyway", style: .default) { _ in
                self.createAndConfirm(name: nameText, identifier: nil, tester: tester.isEmpty ? nil : tester)
            })
            present(alert, animated: true)
            return
        }

        createAndConfirm(
            name: nameText,
            identifier: identifierText.isEmpty ? nil : identifierText,
            tester: tester.isEmpty ? nil : tester)
    }

    private func createAndConfirm(name: String, identifier: String?, tester: String?) {
        let newPatient = Patient(
            id: 0, name: name, identifier: identifier, notes: nil,
            createdAt: Date(), updatedAt: Date())
        let date = datePicker.date

        Task {
            if let saved = try? await patientService.addPatient(newPatient) {
                await MainActor.run {
                    self.dismiss(animated: true) {
                        self.onConfirm?(saved, tester, date)
                    }
                }
            }
        }
    }

    private func selectExisting(_ patient: Patient) {
        guard consentSwitch.isOn else {
            let alert = UIAlertController(
                title: "Consent Required",
                message: "Please confirm the patient has consented before starting the test.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let tester = (testerField.text ?? "").trimmingCharacters(in: .whitespaces)
        let date = datePicker.date
        dismiss(animated: true) {
            self.onConfirm?(patient, tester.isEmpty ? nil : tester, date)
        }
    }
}

// MARK: - UISearchBarDelegate

extension PatientPickerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        Task {
            let results: [Patient]
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                results = recentPatients
            } else {
                results = (try? await patientService.searchPatients(query: searchText)) ?? []
            }
            await MainActor.run {
                self.searchResults = results
                self.tableView.reloadData()
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableView

extension PatientPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(searchResults.count, 1)  // always show at least the empty placeholder
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        searchBar.text?.isEmpty == false ? "Results" : "Recent Patients"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PatientCell", for: indexPath)

        if searchResults.isEmpty {
            var config = cell.defaultContentConfiguration()
            config.text = searchBar.text?.isEmpty == false
                ? "No matches found. Add a new patient below."
                : "No patients yet. Add one below."
            config.textProperties.color = .secondaryLabel
            config.textProperties.font = UIFont.italicSystemFont(ofSize: 14)
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }

        let patient = searchResults[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = patient.name
        config.secondaryText = patient.identifier
        config.textProperties.font = UIFont.lcBodyBold()
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !searchResults.isEmpty, indexPath.row < searchResults.count else { return }
        lcHaptic(.light)
        selectExisting(searchResults[indexPath.row])
    }
}
