import UIKit

class SettingsViewController: UIViewController {

    // MARK: - UI Components

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var sections: [SettingsSection] = []

    // MARK: - Data Properties

    private var viewModel: SettingsViewModel?
    private var selectedLanguageId: Int?
    private var selectedDialectId: Int?
    private var familyMembers: [FamilyMember] = []
    private var milestones: [MilestoneEntry] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupViewModel()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor.lcBackground

        // Hero Header
        let headerView = HeroHeaderView(
            title: "Settings",
            subtitle: "LangCI preferences",
            systemIcon: "gearshape.fill",
            color: UIColor.systemGray
        )
        view.addSubview(headerView)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.lcBackground
        tableView.separatorColor = UIColor.lcCard
        tableView.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.identifier)
        tableView.register(SettingsSwitchCell.self, forCellReuseIdentifier: SettingsSwitchCell.identifier)
        tableView.register(SettingsSegmentCell.self, forCellReuseIdentifier: SettingsSegmentCell.identifier)
        tableView.register(SettingsStepperCell.self, forCellReuseIdentifier: SettingsStepperCell.identifier)

        view.addSubview(tableView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupViewModel() {
        viewModel = SettingsViewModel()
    }

    private func loadData() {
        Task {
            do {
                try await viewModel?.loadData()
                DispatchQueue.main.async {
                    self.buildSections()
                    self.tableView.reloadData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(error)
                }
            }
        }
    }

    // MARK: - Build Sections

    private func buildSections() {
        sections.removeAll()

        // Section: My Journey — activation date, timeline & milestones
        var journeyRows: [SettingsRow] = []
        let activationLabel = viewModel?.activationDateLabel ?? "Not set"
        journeyRows.append(SettingsRow(
            type: .disclosure,
            title: "CI Activation Date",
            value: activationLabel,
            action: { [weak self] in self?.showActivationDatePicker() }
        ))
        journeyRows.append(SettingsRow(
            type: .disclosure,
            title: "Activation Timeline",
            value: viewModel?.hearingAgeLabel,
            action: { [weak self] in self?.showActivationTimeline() }
        ))
        let milestoneCount = viewModel?.milestoneCount ?? 0
        let milestoneValue = milestoneCount == 0 ? "None yet" : "\(milestoneCount)"
        journeyRows.append(SettingsRow(
            type: .disclosure,
            title: "Milestones",
            value: milestoneValue,
            action: { [weak self] in self?.showMilestones() }
        ))
        sections.append(SettingsSection(header: "MY JOURNEY", footer: "Track your progress from the day your CI was switched on. Firsts are auto-detected; tap Milestones to add your own.", rows: journeyRows))

        // Section 0: Language
        var languageRows: [SettingsRow] = []
        languageRows.append(SettingsRow(
            type: .disclosure,
            title: "Language",
            value: viewModel?.selectedLanguageName,
            action: { [weak self] in self?.showLanguagePicker() }
        ))
        languageRows.append(SettingsRow(
            type: .disclosure,
            title: "Dialect",
            value: viewModel?.selectedDialectName,
            action: { [weak self] in self?.showDialectPicker() }
        ))
        sections.append(SettingsSection(header: "LEARNING LANGUAGE", footer: nil, rows: languageRows))

        // Section 1: Family
        var familyRows: [SettingsRow] = []
        let familyMemberCount = viewModel?.familyMembers.count ?? 0
        familyRows.append(SettingsRow(
            type: .disclosure,
            title: "Family Members",
            value: "\(familyMemberCount) members",
            action: { [weak self] in self?.showFamilyMemberList() }
        ))
        sections.append(SettingsSection(header: "FAMILY VOICE BANK", footer: nil, rows: familyRows))

        // Section 2: CI Processor
        var ciRows: [SettingsRow] = []
        ciRows.append(SettingsRow(
            type: .disclosure,
            title: "Default Program",
            value: viewModel?.defaultProgramName,
            action: { [weak self] in self?.showProgramPicker() }
        ))
        ciRows.append(SettingsRow(
            type: .stepper,
            title: "Preferred Distance",
            value: "\(UserDefaults.standard.integer(forKey: "preferredDistanceCm") != 0 ? UserDefaults.standard.integer(forKey: "preferredDistanceCm") : 100) cm",
            action: { [weak self] in self?.updateDistanceInSettings() }
        ))
        ciRows.append(SettingsRow(
            type: .disclosure,
            title: "AVT Drill Voice",
            value: AVTAudioPlayer.voicePreference.displayName,
            action: { [weak self] in self?.showVoicePicker() }
        ))
        ciRows.append(SettingsRow(
            type: .disclosure,
            title: "Background Noise",
            value: AVTAudioPlayer.noiseProfile.displayName,
            action: { [weak self] in self?.showNoiseProfilePicker() }
        ))
        ciRows.append(SettingsRow(
            type: .disclosure,
            title: "Noise Level (SNR)",
            value: AVTAudioPlayer.noiseLevel.displayName,
            action: { [weak self] in self?.showNoiseLevelPicker() }
        ))
        sections.append(SettingsSection(header: "CI SETTINGS", footer: "Add ambient noise behind drills to simulate real-world listening. Lower SNR = harder.", rows: ciRows))

        // Section: Practice Reminders
        var reminderRows: [SettingsRow] = []
        let morning = PracticeReminderService.shared.morning
        let evening = PracticeReminderService.shared.evening
        reminderRows.append(SettingsRow(
            type: .disclosure,
            title: "Morning reminder",
            value: morning.enabled ? morning.displayTime : "Off",
            action: { [weak self] in self?.showMorningReminderPicker() }
        ))
        reminderRows.append(SettingsRow(
            type: .disclosure,
            title: "Evening reminder",
            value: evening.enabled ? evening.displayTime : "Off",
            action: { [weak self] in self?.showEveningReminderPicker() }
        ))
        sections.append(SettingsSection(
            header: "PRACTICE REMINDERS",
            footer: "Get a gentle nudge to keep your listening streak alive.",
            rows: reminderRows
        ))

        // Section: Reports
        var reportRows: [SettingsRow] = []
        reportRows.append(SettingsRow(
            type: .disclosure,
            title: "Export audiologist report",
            value: "PDF",
            action: { [weak self] in self?.exportAudiologistReport() }
        ))
        sections.append(SettingsSection(
            header: "REPORTS",
            footer: "Generate a printable PDF to share at your next mapping appointment.",
            rows: reportRows
        ))

        // Section 3: App
        var appRows: [SettingsRow] = []
        appRows.append(SettingsRow(
            type: .toggle,
            title: "Notifications",
            value: nil,
            action: { }
        ))
        appRows.append(SettingsRow(
            type: .segment,
            title: "Dark Mode",
            value: nil,
            action: { }
        ))
        appRows.append(SettingsRow(
            type: .destructive,
            title: "Reset Progress",
            value: nil,
            action: { [weak self] in self?.showResetConfirmation() }
        ))
        sections.append(SettingsSection(header: "APP", footer: nil, rows: appRows))

        // Section: Speech (Whisper API)
        let whisperService = WhisperTranscriptionService.shared
        let keyStatus = whisperService.hasAPIKey ? "Configured ✓" : "Not set"
        var speechRows: [SettingsRow] = []
        speechRows.append(SettingsRow(
            type: .disclosure,
            title: "OpenAI API Key",
            value: keyStatus,
            action: { [weak self] in self?.showWhisperAPIKeyEntry() }
        ))
        sections.append(SettingsSection(
            header: "SPEECH RECOGNITION",
            footer: "An OpenAI API key enables accurate Tamil word counting via Whisper. Costs ~$0.006/min of audio. Get a key at platform.openai.com.",
            rows: speechRows))

        // Section: About
        var aboutRows: [SettingsRow] = []
        aboutRows.append(SettingsRow(
            type: .static,
            title: "Version",
            value: "1.0.0",
            action: { }
        ))
        aboutRows.append(SettingsRow(
            type: .disclosure,
            title: "About LangCI",
            value: nil,
            action: { [weak self] in self?.showAboutScreen() }
        ))
        sections.append(SettingsSection(header: "ABOUT", footer: nil, rows: aboutRows))
    }

    // MARK: - Actions

    private func showWhisperAPIKeyEntry() {
        let whisper = WhisperTranscriptionService.shared
        let alert = UIAlertController(
            title: "OpenAI API Key",
            message: "Enter your OpenAI API key to enable accurate word counting for Tamil and other unsupported languages via Whisper.\n\nGet a key at platform.openai.com → API Keys.",
            preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "sk-..."
            tf.text = whisper.apiKey
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
            tf.isSecureTextEntry = true
            tf.clearButtonMode = .whileEditing
        }

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            let key = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            whisper.apiKey = key.isEmpty ? nil : key
            self?.buildSections()
            self?.tableView.reloadData()
        })

        if whisper.hasAPIKey {
            alert.addAction(UIAlertAction(title: "Remove Key", style: .destructive) { [weak self] _ in
                whisper.apiKey = nil
                self?.buildSections()
                self?.tableView.reloadData()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showLanguagePicker() {
        Task {
            do {
                let languages = try await viewModel?.languageService.getActiveLanguages() ?? []
                DispatchQueue.main.async {
                    self.presentLanguagePicker(languages)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(error)
                }
            }
        }
    }

    private func presentLanguagePicker(_ languages: [Language]) {
        let alert = UIAlertController(title: "Select Language", message: nil, preferredStyle: .actionSheet)

        for language in languages {
            let action = UIAlertAction(title: language.nativeName, style: .default) { [weak self] _ in
                UserDefaults.standard.set(language.id, forKey: "selectedLanguageId")
                self?.viewModel?.selectedLanguageId = language.id
                self?.viewModel?.selectedLanguageName = language.nativeName
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    private func showDialectPicker() {
        Task {
            do {
                let languageId = viewModel?.selectedLanguageId ?? 1
                let dialects = try await viewModel?.languageService.getActiveDialects(for: languageId) ?? []
                DispatchQueue.main.async {
                    self.presentDialectPicker(dialects)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(error)
                }
            }
        }
    }

    private func presentDialectPicker(_ dialects: [Dialect]) {
        let alert = UIAlertController(title: "Select Dialect", message: nil, preferredStyle: .actionSheet)

        for dialect in dialects {
            let action = UIAlertAction(title: dialect.name, style: .default) { [weak self] _ in
                UserDefaults.standard.set(dialect.id, forKey: "selectedDialectId")
                self?.viewModel?.selectedDialectId = dialect.id
                self?.viewModel?.selectedDialectName = dialect.name
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    private func showFamilyMemberList() {
        let vc = FamilyMemberListViewController(viewModel: viewModel)
        vc.onDismiss = { [weak self] in
            self?.loadData()
        }
        let navController = UINavigationController(rootViewController: vc)
        present(navController, animated: true)
    }

    private func showProgramPicker() {
        let alert = UIAlertController(title: "Select Program", message: nil, preferredStyle: .actionSheet)

        let programs = [
            (name: "Everyday", rawValue: 0),
            (name: "Noise", rawValue: 1),
            (name: "Music", rawValue: 2),
            (name: "Focus", rawValue: 3),
            (name: "Telecoil", rawValue: 4),
            (name: "Custom 1", rawValue: 5),
            (name: "Custom 2", rawValue: 6)
        ]

        for program in programs {
            let action = UIAlertAction(title: program.name, style: .default) { [weak self] _ in
                UserDefaults.standard.set(program.rawValue, forKey: "defaultProcessorProgram")
                self?.viewModel?.defaultProgramRawValue = program.rawValue
                self?.viewModel?.defaultProgramName = program.name
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    private func showVoicePicker() {
        let alert = UIAlertController(
            title: "AVT Drill Voice",
            message: "Choose the system voice used for TTS playback of library items.",
            preferredStyle: .actionSheet
        )

        let current = AVTAudioPlayer.voicePreference
        for pref in AVTAudioPlayer.VoicePreference.allCases {
            let prefix = pref == current ? "✓  " : "    "
            let action = UIAlertAction(
                title: prefix + pref.displayName,
                style: .default
            ) { [weak self] _ in
                AVTAudioPlayer.voicePreference = pref
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showNoiseProfilePicker() {
        let alert = UIAlertController(
            title: "Background Noise",
            message: "Pick the ambient environment that will play behind drills.",
            preferredStyle: .actionSheet
        )
        let current = AVTAudioPlayer.noiseProfile
        for prof in AVTAudioPlayer.NoiseProfile.allCases {
            let prefix = prof == current ? "✓  " : "    "
            let action = UIAlertAction(
                title: prefix + prof.displayName,
                style: .default
            ) { [weak self] _ in
                AVTAudioPlayer.noiseProfile = prof
                // If user picks a real profile but level is still off, bump to +10dB.
                if prof != .off, AVTAudioPlayer.noiseLevel == .offDB {
                    AVTAudioPlayer.noiseLevel = .plus10dB
                }
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showNoiseLevelPicker() {
        let alert = UIAlertController(
            title: "Noise Level (SNR)",
            message: "Signal-to-noise ratio. +10 dB is easy; 0 dB is hard; -5 dB is expert.",
            preferredStyle: .actionSheet
        )
        let current = AVTAudioPlayer.noiseLevel
        for lvl in AVTAudioPlayer.NoiseLevel.allCases {
            let prefix = lvl == current ? "✓  " : "    "
            let action = UIAlertAction(
                title: prefix + lvl.displayName,
                style: .default
            ) { [weak self] _ in
                AVTAudioPlayer.noiseLevel = lvl
                self?.buildSections()
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Practice reminders

    private func showMorningReminderPicker() {
        showReminderPicker(
            title: "Morning reminder",
            getter: { PracticeReminderService.shared.morning },
            setter: { PracticeReminderService.shared.morning = $0 }
        )
    }

    private func showEveningReminderPicker() {
        showReminderPicker(
            title: "Evening reminder",
            getter: { PracticeReminderService.shared.evening },
            setter: { PracticeReminderService.shared.evening = $0 }
        )
    }

    /// Shared action-sheet for either reminder slot. Offers Off + a handful
    /// of common times, plus "Custom time" which spins up an inline time
    /// picker in a secondary alert.
    private func showReminderPicker(
        title: String,
        getter: @escaping () -> PracticeReminderService.Slot,
        setter: @escaping (PracticeReminderService.Slot) -> Void
    ) {
        let current = getter()
        let alert = UIAlertController(
            title: title,
            message: "Pick a time for your daily nudge, or turn it off.",
            preferredStyle: .actionSheet
        )

        // Off option
        let offMark = current.enabled ? "   " : "✓ "
        alert.addAction(UIAlertAction(title: offMark + "Off", style: .default) { [weak self] _ in
            var slot = getter()
            slot.enabled = false
            setter(slot)
            PracticeReminderService.shared.rescheduleFromPreferences()
            self?.buildSections()
            self?.tableView.reloadData()
        })

        // Common presets
        let presets: [(String, Int, Int)] = [
            ("7:00 AM",  7, 0),
            ("9:00 AM",  9, 0),
            ("12:00 PM", 12, 0),
            ("6:00 PM",  18, 0),
            ("7:30 PM",  19, 30),
            ("9:00 PM",  21, 0),
        ]
        for (label, h, m) in presets {
            let mark = (current.enabled && current.hour == h && current.minute == m) ? "✓ " : "   "
            alert.addAction(UIAlertAction(title: mark + label, style: .default) { [weak self] _ in
                self?.ensureNotificationAuthThen {
                    var slot = getter()
                    slot.enabled = true
                    slot.hour = h
                    slot.minute = m
                    setter(slot)
                    PracticeReminderService.shared.rescheduleFromPreferences()
                    self?.buildSections()
                    self?.tableView.reloadData()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Ask for notification permission if we don't have it yet; call the
    /// continuation only if authorization was granted (or already granted).
    private func ensureNotificationAuthThen(_ continuation: @escaping () -> Void) {
        PracticeReminderService.shared.checkAuthorizationStatus { status in
            switch status {
            case .authorized, .provisional, .ephemeral:
                // .ephemeral is the App Clip transient grant — treat as
                // authorized so the reminder schedules.
                continuation()
            case .denied:
                let alert = UIAlertController(
                    title: "Notifications are off",
                    message: "Turn on notifications for LangCI in iOS Settings to enable reminders.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            case .notDetermined:
                PracticeReminderService.shared.requestAuthorization { granted in
                    if granted { continuation() }
                }
            @unknown default:
                PracticeReminderService.shared.requestAuthorization { granted in
                    if granted { continuation() }
                }
            }
        }
    }

    // MARK: - Audiologist report

    private func exportAudiologistReport() {
        let hud = UIAlertController(
            title: "Generating report…",
            message: nil,
            preferredStyle: .alert
        )
        present(hud, animated: true)

        Task {
            do {
                let url = try await AudiologistReportService.shared.generateReport()
                await MainActor.run {
                    hud.dismiss(animated: true) {
                        let share = UIActivityViewController(
                            activityItems: [url],
                            applicationActivities: nil
                        )
                        // iPad popover anchor
                        if let pop = share.popoverPresentationController {
                            pop.sourceView = self.view
                            pop.sourceRect = CGRect(
                                x: self.view.bounds.midX,
                                y: self.view.bounds.midY,
                                width: 0, height: 0
                            )
                            pop.permittedArrowDirections = []
                        }
                        self.present(share, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    hud.dismiss(animated: true) {
                        let err = UIAlertController(
                            title: "Report failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        err.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err, animated: true)
                    }
                }
            }
        }
    }

    private func updateDistanceInSettings() {
        // This is handled by the stepper cell
    }

    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Reset Progress?",
            message: "This will delete all your training data and cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.resetProgress()
        })

        present(alert, animated: true)
    }

    private func resetProgress() {
        Task {
            do {
                // Reset via service (would be implemented)
                UserDefaults.standard.removeObject(forKey: "selectedLanguageId")
                UserDefaults.standard.removeObject(forKey: "selectedDialectId")
                UserDefaults.standard.removeObject(forKey: "defaultProcessorProgram")
                UserDefaults.standard.removeObject(forKey: "preferredDistanceCm")

                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Progress Reset", message: "Your progress has been cleared.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func showAboutScreen() {
        let vc = AboutViewController()
        let navController = UINavigationController(rootViewController: vc)
        present(navController, animated: true)
    }

    // MARK: - Activation date

    private func showActivationDatePicker() {
        let currentDate = viewModel?.currentActivationDate ?? Date()
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.date = currentDate
        picker.maximumDate = Date()

        let alert = UIAlertController(
            title: "CI Activation Date",
            message: "\n\n\n\n\n\n\n\n\n\n",
            preferredStyle: .alert
        )

        picker.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            picker.widthAnchor.constraint(lessThanOrEqualTo: alert.view.widthAnchor, constant: -20),
            picker.heightAnchor.constraint(equalToConstant: 180)
        ])

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            self?.saveActivationDate(picker.date)
        })

        if viewModel?.currentActivationDate != nil {
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
                self?.clearActivationDate()
            })
        }

        present(alert, animated: true)
    }

    private func saveActivationDate(_ date: Date) {
        Task {
            do {
                try await viewModel?.setActivationDate(date)
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.lcShowToast("Activation date saved",
                                     icon: "checkmark.circle.fill",
                                     tint: .lcGreen)
                    self.buildSections()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self.showErrorAlert(error) }
            }
        }
    }

    private func clearActivationDate() {
        Task {
            do {
                try await viewModel?.clearActivationDate()
                await MainActor.run {
                    self.buildSections()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self.showErrorAlert(error) }
            }
        }
    }

    private func showActivationTimeline() {
        let vc = ActivationTimelineViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showMilestones() {
        let vc = MilestonesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Error Handling

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View Data Source

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row.type {
        case .toggle:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.identifier, for: indexPath) as? SettingsSwitchCell else {
                return UITableViewCell()
            }
            cell.configure(title: row.title, isEnabled: UserDefaults.standard.bool(forKey: "notificationsEnabled"))
            cell.onToggle = { isEnabled in
                UserDefaults.standard.set(isEnabled, forKey: "notificationsEnabled")
            }
            return cell

        case .segment:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSegmentCell.identifier, for: indexPath) as? SettingsSegmentCell else {
                return UITableViewCell()
            }
            cell.configure(
                title: row.title,
                selectedIndex: ThemeManager.shared.current.segmentIndex
            )
            cell.onSegmentChange = { index in
                // index 0 = Light, 1 = Dark
                let mode: AppThemeMode = (index == 1) ? .dark : .light
                ThemeManager.shared.current = mode
            }
            return cell

        case .stepper:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsStepperCell.identifier, for: indexPath) as? SettingsStepperCell else {
                return UITableViewCell()
            }
            let currentDistance = UserDefaults.standard.integer(forKey: "preferredDistanceCm") != 0 ? UserDefaults.standard.integer(forKey: "preferredDistanceCm") : 100
            cell.configure(title: row.title, value: currentDistance)
            cell.onValueChange = { [weak self] distance in
                UserDefaults.standard.set(distance, forKey: "preferredDistanceCm")
                self?.buildSections()
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell

        case .destructive:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as? SettingsCell else {
                return UITableViewCell()
            }
            cell.configure(title: row.title, value: row.value, isDestructive: true)
            return cell

        default:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as? SettingsCell else {
                return UITableViewCell()
            }
            cell.configure(title: row.title, value: row.value, isDestructive: false)
            return cell
        }
    }
}

// MARK: - Table View Delegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].rows[indexPath.row]
        row.action()
    }
}

// MARK: - Settings Cell

class SettingsCell: UITableViewCell {
    static let identifier = "SettingsCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.lcCard
        selectionStyle = .gray

        titleLabel.font = UIFont.lcBody()
        titleLabel.textColor = UIColor.label
        contentView.addSubview(titleLabel)

        valueLabel.font = UIFont.lcBody()
        valueLabel.textColor = UIColor.secondaryLabel
        valueLabel.textAlignment = .right
        contentView.addSubview(valueLabel)

        let disclosureIndicator = UIImageView(image: UIImage(systemName: "chevron.right"))
        disclosureIndicator.tintColor = UIColor.systemGray
        disclosureIndicator.contentMode = .center
        contentView.addSubview(disclosureIndicator)

        setupConstraints(disclosureIndicator: disclosureIndicator)
    }

    private func setupConstraints(disclosureIndicator: UIImageView) {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        disclosureIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            disclosureIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            disclosureIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            disclosureIndicator.widthAnchor.constraint(equalToConstant: 20)
        ])

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.trailingAnchor.constraint(equalTo: disclosureIndicator.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, value: String?, isDestructive: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isDestructive ? UIColor.lcRed : UIColor.label
        valueLabel.text = value
    }
}

// MARK: - Switch Cell

class SettingsSwitchCell: UITableViewCell {
    static let identifier = "SettingsSwitchCell"

    private let titleLabel = UILabel()
    private let toggle = UISwitch()
    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.lcCard
        selectionStyle = .none

        titleLabel.font = UIFont.lcBody()
        titleLabel.textColor = UIColor.label
        contentView.addSubview(titleLabel)

        toggle.onTintColor = UIColor.lcGreen
        toggle.addTarget(self, action: #selector(toggleDidChange), for: .valueChanged)
        contentView.addSubview(toggle)

        setupConstraints()
    }

    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        toggle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @objc private func toggleDidChange() {
        onToggle?(toggle.isOn)
    }

    func configure(title: String, isEnabled: Bool) {
        titleLabel.text = title
        toggle.isOn = isEnabled
    }
}

// MARK: - Segment Cell

class SettingsSegmentCell: UITableViewCell {
    static let identifier = "SettingsSegmentCell"

    private let titleLabel = UILabel()
    private let segment = UISegmentedControl()
    var onSegmentChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.lcCard
        selectionStyle = .none

        titleLabel.font = UIFont.lcBody()
        titleLabel.textColor = UIColor.label
        contentView.addSubview(titleLabel)

        segment.insertSegment(withTitle: "Light", at: 0, animated: false)
        segment.insertSegment(withTitle: "Dark", at: 1, animated: false)
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segmentDidChange), for: .valueChanged)
        contentView.addSubview(segment)

        setupConstraints()
    }

    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        segment.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segment.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            segment.widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    @objc private func segmentDidChange() {
        onSegmentChange?(segment.selectedSegmentIndex)
    }

    func configure(title: String, selectedIndex: Int = 0) {
        titleLabel.text = title
        if selectedIndex >= 0 && selectedIndex < segment.numberOfSegments {
            segment.selectedSegmentIndex = selectedIndex
        }
    }
}

// MARK: - Stepper Cell

class SettingsStepperCell: UITableViewCell {
    static let identifier = "SettingsStepperCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    var onValueChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.lcCard
        selectionStyle = .none

        titleLabel.font = UIFont.lcBody()
        titleLabel.textColor = UIColor.label
        contentView.addSubview(titleLabel)

        valueLabel.font = UIFont.lcBody()
        valueLabel.textColor = UIColor.secondaryLabel
        contentView.addSubview(valueLabel)

        stepper.minimumValue = 50
        stepper.maximumValue = 300
        stepper.stepValue = 10
        stepper.addTarget(self, action: #selector(stepperDidChange), for: .valueChanged)
        contentView.addSubview(stepper)

        setupConstraints()
    }

    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        stepper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @objc private func stepperDidChange() {
        let value = Int(stepper.value)
        valueLabel.text = "\(value) cm"
        onValueChange?(value)
    }

    func configure(title: String, value: Int) {
        titleLabel.text = title
        valueLabel.text = "\(value) cm"
        stepper.value = Double(value)
    }
}

// MARK: - Family Member List View Controller

class FamilyMemberListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let viewModel: SettingsViewModel?
    var onDismiss: (() -> Void)?
    private var members: [FamilyMember] = []

    init(viewModel: SettingsViewModel?) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMembers()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.lcBackground
        title = "Family Members"

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addMember))
        navigationItem.rightBarButtonItem = addButton

        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissViewController))
        navigationItem.leftBarButtonItem = closeButton

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.lcBackground
        tableView.register(FamilyMemberCell.self, forCellReuseIdentifier: FamilyMemberCell.identifier)
        view.addSubview(tableView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    fileprivate func loadMembers() {
        Task {
            do {
                self.members = try await ServiceLocator.shared.familyMemberService.getAllMembers()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(error)
                }
            }
        }
    }

    @objc private func addMember() {
        presentEditor(for: nil)
    }

    fileprivate func presentEditor(for member: FamilyMember?) {
        let editor = FamilyMemberEditorViewController(member: member) { [weak self] in
            self?.loadMembers()
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func dismissViewController() {
        onDismiss?()
        dismiss(animated: true)
    }

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension FamilyMemberListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FamilyMemberCell.identifier, for: indexPath) as? FamilyMemberCell else {
            return UITableViewCell()
        }
        cell.configure(with: members[indexPath.row])
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < members.count else { return }
        presentEditor(for: members[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
            let member = self?.members[indexPath.row]
            Task {
                do {
                    if let memberId = member?.id {
                        try await ServiceLocator.shared.familyMemberService.deleteMember(id: memberId)
                        self?.loadMembers()
                    }
                } catch {
                    self?.showErrorAlert(error)
                }
            }
            completionHandler(true)
        }

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}

// MARK: - Family Member Cell

class FamilyMemberCell: UITableViewCell {
    static let identifier = "FamilyMemberCell"

    private let nameLabel = UILabel()
    private let relationshipLabel = UILabel()
    private let recordingCountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.lcCard
        selectionStyle = .gray

        nameLabel.font = UIFont.lcBodyBold()
        nameLabel.textColor = UIColor.label
        contentView.addSubview(nameLabel)

        relationshipLabel.font = UIFont.lcCaption()
        relationshipLabel.textColor = UIColor.secondaryLabel
        contentView.addSubview(relationshipLabel)

        recordingCountLabel.font = UIFont.lcCaption()
        recordingCountLabel.textColor = UIColor.systemGray
        recordingCountLabel.textAlignment = .right
        contentView.addSubview(recordingCountLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        ])

        relationshipLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            relationshipLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            relationshipLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            relationshipLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])

        recordingCountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recordingCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            recordingCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with member: FamilyMember) {
        nameLabel.text = member.name
        relationshipLabel.text = member.relationship
        recordingCountLabel.text = "0 recordings"
    }
}

// MARK: - Family Member Editor (Add / Edit)

/// Unified editor for adding a new family member or editing an existing one.
/// Passing `nil` as `member` enables add mode; passing an existing member
/// enables edit mode with the Save button updating in place. The dialect
/// picker is populated from `languageService` so the user can actually
/// choose which dialect (e.g. Chennai Tamil vs. Indian English) their
/// recordings should be tagged with.
final class FamilyMemberEditorViewController: UIViewController {

    private let originalMember: FamilyMember?
    private let onSaved: () -> Void

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let nameField = UITextField()
    private let relationshipField = UITextField()

    private let languageLabel = UILabel()
    private let languageSegment = UISegmentedControl(items: ["English"])

    private let dialectLabel = UILabel()
    private let dialectButton = UIButton(type: .system)

    private var languages: [Language] = []
    private var dialectsForSelectedLanguage: [Dialect] = []
    private var selectedLanguageIndex: Int = 0
    private var selectedDialectId: Int = 0

    init(member: FamilyMember?, onSaved: @escaping () -> Void) {
        self.originalMember = member
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.lcBackground
        title = originalMember == nil ? "Add Family Member" : "Edit Family Member"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self, action: #selector(saveTapped))

        setupLayout()
        populateFromMemberIfEditing()
        loadLanguagesAndDialects()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        stack.addArrangedSubview(makeLabel("Name"))
        styleTextField(nameField, placeholder: "e.g. Amma, Dad, Priya")
        stack.addArrangedSubview(nameField)

        stack.addArrangedSubview(makeLabel("Relationship"))
        styleTextField(relationshipField, placeholder: "e.g. Mother, Father, Sister")
        stack.addArrangedSubview(relationshipField)

        languageLabel.text = "Language"
        languageLabel.font = UIFont.lcCaption()
        languageLabel.textColor = UIColor.secondaryLabel
        stack.addArrangedSubview(languageLabel)

        languageSegment.addTarget(
            self, action: #selector(languageChanged), for: .valueChanged)
        stack.addArrangedSubview(languageSegment)

        dialectLabel.text = "Dialect"
        dialectLabel.font = UIFont.lcCaption()
        dialectLabel.textColor = UIColor.secondaryLabel
        stack.addArrangedSubview(dialectLabel)

        dialectButton.contentHorizontalAlignment = .leading
        dialectButton.titleLabel?.font = UIFont.lcBody()
        dialectButton.setTitleColor(UIColor.label, for: .normal)
        dialectButton.setTitle("Select a dialect…", for: .normal)
        dialectButton.backgroundColor = UIColor.lcCard
        dialectButton.layer.cornerRadius = 10
        dialectButton.contentEdgeInsets = UIEdgeInsets(
            top: 12, left: 14, bottom: 12, right: 14)
        dialectButton.addTarget(
            self, action: #selector(dialectTapped), for: .touchUpInside)
        dialectButton.heightAnchor
            .constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stack.addArrangedSubview(dialectButton)

        let helpLabel = UILabel()
        helpLabel.text = "The dialect tags every recording you capture for this family member, so the trainer can match their accent."
        helpLabel.font = UIFont.lcCaption()
        helpLabel.textColor = UIColor.secondaryLabel
        helpLabel.numberOfLines = 0
        stack.addArrangedSubview(helpLabel)
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.lcCaption()
        l.textColor = UIColor.secondaryLabel
        return l
    }

    private func styleTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = UIFont.lcBody()
        field.textColor = UIColor.label
        field.backgroundColor = UIColor.lcCard
        field.borderStyle = .none
        field.layer.cornerRadius = 10
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.leftView = pad
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.rightViewMode = .always
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
    }

    private func populateFromMemberIfEditing() {
        guard let m = originalMember else { return }
        nameField.text = m.name
        relationshipField.text = m.relationship
        selectedDialectId = m.preferredDialectId
    }

    private func loadLanguagesAndDialects() {
        Task {
            do {
                let langs = try await ServiceLocator.shared
                    .languageService.getActiveLanguages()
                await MainActor.run {
                    self.languages = langs
                    self.rebuildLanguageSegment()
                }

                // Default-select a language: (a) language of the member's
                // existing dialect if editing, else (b) first language.
                var initialLangIndex = 0
                if let m = self.originalMember, m.preferredDialectId > 0,
                   let dialect = try await ServiceLocator.shared
                    .languageService.getDialect(id: m.preferredDialectId),
                   let langId = dialect.languageId,
                   let idx = langs.firstIndex(where: { $0.id == langId }) {
                    initialLangIndex = idx
                }
                await MainActor.run {
                    self.selectedLanguageIndex = initialLangIndex
                    self.languageSegment.selectedSegmentIndex = initialLangIndex
                }
                await self.reloadDialects(for: initialLangIndex)
            } catch {
                await MainActor.run { self.showError(error) }
            }
        }
    }

    private func rebuildLanguageSegment() {
        languageSegment.removeAllSegments()
        for (i, lang) in languages.enumerated() {
            languageSegment.insertSegment(
                withTitle: lang.name, at: i, animated: false)
        }
        if !languages.isEmpty {
            languageSegment.selectedSegmentIndex = 0
        }
    }

    private func reloadDialects(for languageIndex: Int) async {
        guard languageIndex >= 0, languageIndex < languages.count else {
            await MainActor.run {
                self.dialectsForSelectedLanguage = []
                self.updateDialectButtonTitle()
            }
            return
        }
        do {
            let dialects = try await ServiceLocator.shared
                .languageService.getActiveDialects(
                    for: languages[languageIndex].id)
            await MainActor.run {
                self.dialectsForSelectedLanguage = dialects
                // If the current selectedDialectId doesn't belong to this
                // language, default to the first dialect in the list.
                if !dialects.contains(where: { $0.id == self.selectedDialectId }),
                   let first = dialects.first {
                    self.selectedDialectId = first.id
                }
                self.updateDialectButtonTitle()
            }
        } catch {
            await MainActor.run { self.showError(error) }
        }
    }

    private func updateDialectButtonTitle() {
        if let d = dialectsForSelectedLanguage
            .first(where: { $0.id == selectedDialectId }) {
            dialectButton.setTitle("  \(d.name)", for: .normal)
        } else if let first = dialectsForSelectedLanguage.first {
            selectedDialectId = first.id
            dialectButton.setTitle("  \(first.name)", for: .normal)
        } else {
            dialectButton.setTitle("  No dialects available", for: .normal)
        }
    }

    @objc private func languageChanged() {
        let idx = languageSegment.selectedSegmentIndex
        selectedLanguageIndex = idx
        // Reset selected dialect so we pick the first dialect of the new lang.
        selectedDialectId = 0
        Task { await reloadDialects(for: idx) }
    }

    @objc private func dialectTapped() {
        guard !dialectsForSelectedLanguage.isEmpty else { return }
        let sheet = UIAlertController(
            title: "Choose Dialect", message: nil, preferredStyle: .actionSheet)
        for d in dialectsForSelectedLanguage {
            sheet.addAction(UIAlertAction(title: d.name, style: .default) { [weak self] _ in
                self?.selectedDialectId = d.id
                self?.updateDialectButtonTitle()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = dialectButton
            pop.sourceRect = dialectButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let name = (nameField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let relationship = (relationshipField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            showError(message: "Please enter a name.")
            return
        }
        guard !relationship.isEmpty else {
            showError(message: "Please enter a relationship (e.g. Mother, Father).")
            return
        }

        let initials: String = {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }()

        let existing = originalMember
        let member = FamilyMember(
            id: existing?.id ?? 0,
            name: name,
            relationship: relationship,
            avatarInitials: initials,
            avatarColorHex: existing?.avatarColorHex ?? "#1D9E75",
            preferredDialectId: selectedDialectId,
            preferredDialect: nil,
            baselineFrequencyHz: existing?.baselineFrequencyHz,
            createdAt: existing?.createdAt ?? Date(),
            recordings: existing?.recordings ?? []
        )

        Task {
            do {
                _ = try await ServiceLocator.shared
                    .familyMemberService.saveMember(member)
                await MainActor.run {
                    self.onSaved()
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run { self.showError(error) }
            }
        }
    }

    private func showError(_ error: Error) {
        showError(message: error.localizedDescription)
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - About View Controller

class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.lcBackground
        title = "About LangCI"

        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissViewController))
        navigationItem.leftBarButtonItem = closeButton

        let scrollView = UIScrollView()
        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        scrollView.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        let logoLabel = UILabel()
        logoLabel.text = "🎓"
        logoLabel.font = UIFont.systemFont(ofSize: 64)
        logoLabel.textAlignment = .center
        stackView.addArrangedSubview(logoLabel)

        let titleLabel = UILabel()
        titleLabel.text = "LangCI"
        titleLabel.font = UIFont.lcHeroTitle()
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = UILabel()
        descriptionLabel.text = "LangCI is a language learning app designed specifically for cochlear implant users. Learn using family members' voices and CI-specific audiology tools."
        descriptionLabel.font = UIFont.lcBody()
        descriptionLabel.textColor = UIColor.secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        stackView.addArrangedSubview(descriptionLabel)

        let versionLabel = UILabel()
        versionLabel.text = "Version 1.0.0"
        versionLabel.font = UIFont.lcCaption()
        versionLabel.textColor = UIColor.systemGray
        versionLabel.textAlignment = .center
        stackView.addArrangedSubview(versionLabel)

        // Spacer
        stackView.addArrangedSubview(UIView())

        // MARK: Medical disclaimer (required by Apple Guideline 1.4)
        let disclaimerCard = UIView()
        disclaimerCard.backgroundColor = UIColor.secondarySystemBackground
        disclaimerCard.layer.cornerRadius = 16
        disclaimerCard.layer.borderWidth = 1
        disclaimerCard.layer.borderColor = UIColor.separator.cgColor

        let disclaimerStack = UIStackView()
        disclaimerStack.axis = .vertical
        disclaimerStack.spacing = 8
        disclaimerStack.translatesAutoresizingMaskIntoConstraints = false
        disclaimerCard.addSubview(disclaimerStack)
        NSLayoutConstraint.activate([
            disclaimerStack.topAnchor.constraint(equalTo: disclaimerCard.topAnchor, constant: 16),
            disclaimerStack.leadingAnchor.constraint(equalTo: disclaimerCard.leadingAnchor, constant: 16),
            disclaimerStack.trailingAnchor.constraint(equalTo: disclaimerCard.trailingAnchor, constant: -16),
            disclaimerStack.bottomAnchor.constraint(equalTo: disclaimerCard.bottomAnchor, constant: -16)
        ])

        let disclaimerTitle = UILabel()
        disclaimerTitle.text = "⚠️ Important — Not a Medical Device"
        disclaimerTitle.font = UIFont.lcBodyBold()
        disclaimerTitle.textColor = UIColor.label
        disclaimerTitle.numberOfLines = 0
        disclaimerStack.addArrangedSubview(disclaimerTitle)

        let disclaimerBody = UILabel()
        disclaimerBody.text = "LangCI is a general-purpose auditory training aid. It is not a medical device and is not intended to diagnose, treat, cure, or prevent hearing loss, cochlear implant malfunction, or any other medical condition.\n\nAlways consult a qualified audiologist, ENT specialist, or auditory-verbal therapist for hearing assessments, device programming, and therapy decisions. Do not rely on LangCI as a substitute for professional medical care."
        disclaimerBody.font = UIFont.lcCaption()
        disclaimerBody.textColor = UIColor.secondaryLabel
        disclaimerBody.numberOfLines = 0
        disclaimerStack.addArrangedSubview(disclaimerBody)

        stackView.addArrangedSubview(disclaimerCard)

        // MARK: Privacy policy link
        let privacyButton = UIButton(type: .system)
        privacyButton.setTitle("Privacy Policy", for: .normal)
        privacyButton.titleLabel?.font = UIFont.lcBody()
        privacyButton.addTarget(self, action: #selector(openPrivacyPolicy), for: .touchUpInside)
        stackView.addArrangedSubview(privacyButton)

        let copyrightLabel = UILabel()
        copyrightLabel.text = "© 2026 Suresh Subramanian"
        copyrightLabel.font = UIFont.lcCaption()
        copyrightLabel.textColor = UIColor.tertiaryLabel
        copyrightLabel.textAlignment = .center
        stackView.addArrangedSubview(copyrightLabel)
    }

    @objc private func dismissViewController() {
        dismiss(animated: true)
    }

    @objc private func openPrivacyPolicy() {
        if let url = URL(string: "https://github.com/isureshsubramanian/LangCI/blob/main/PRIVACY_POLICY.md") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Models

struct SettingsSection {
    let header: String?
    let footer: String?
    let rows: [SettingsRow]
}

struct SettingsRow {
    enum RowType {
        case disclosure
        case toggle
        case segment
        case stepper
        case destructive
        case `static`
    }

    let type: RowType
    let title: String
    let value: String?
    let action: () -> Void
}

// NOTE: `Language`, `Dialect`, `FamilyMember`, and `Milestone` previously
// defined here as local stubs collided with the real Domain models in
// `LangCI/Domain/Models/`, producing "is ambiguous for type lookup"
// errors. They were removed — the Domain models are used instead.
//
// `SettingsViewModel` was extracted to
// `Presentation/ViewModels/SettingsViewModel.swift`.

