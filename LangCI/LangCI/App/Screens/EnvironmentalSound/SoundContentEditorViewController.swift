// SoundContentEditorViewController.swift
// LangCI — Edit built-in and custom environmental sounds
//
// Lists all sounds (built-in + custom) grouped by environment.
// Users can tap to edit TTS text, descriptions, difficulty of built-in sounds,
// or fully edit/delete their custom sounds.

import UIKit
import AVFoundation

final class SoundContentEditorViewController: UIViewController,
    UITableViewDataSource, UITableViewDelegate {

    // MARK: - Data

    private struct SoundRow {
        let id: String
        let name: String
        let environment: SoundEnvironment
        let description: String
        let speechDescription: String
        let ciDifficulty: Int
        let isCustom: Bool
        let override: SoundEditOverride?
    }

    private var sections: [(env: SoundEnvironment, rows: [SoundRow])] = []
    private let service = ServiceLocator.shared.environmentalSoundService!
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sound Editor"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain, target: self, action: #selector(addCustomSound))

        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadData()
    }

    // MARK: - Setup

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data Loading

    private func loadData() {
        Task {
            let overrides = try await service.getAllOverrides()
            let customSounds = try await service.getAllCustomSounds()
            let overrideMap = Dictionary(uniqueKeysWithValues: overrides.map { ($0.soundId, $0) })

            var grouped: [SoundEnvironment: [SoundRow]] = [:]

            // Built-in sounds
            for sound in EnvironmentalSoundContent.allSounds {
                let ovr = overrideMap[sound.id]
                let row = SoundRow(
                    id: sound.id,
                    name: ovr?.name ?? sound.name,
                    environment: sound.environment,
                    description: ovr?.description ?? sound.description,
                    speechDescription: ovr?.speechDescription ?? sound.speechDescription,
                    ciDifficulty: ovr?.ciDifficulty ?? sound.ciDifficulty,
                    isCustom: false,
                    override: ovr)
                grouped[sound.environment, default: []].append(row)
            }

            // Custom sounds
            for cs in customSounds {
                let env = SoundEnvironment(rawValue: cs.environment) ?? .home
                let row = SoundRow(
                    id: cs.soundId,
                    name: cs.name,
                    environment: env,
                    description: cs.description,
                    speechDescription: cs.speechDescription,
                    ciDifficulty: cs.ciDifficulty,
                    isCustom: true,
                    override: nil)
                grouped[env, default: []].append(row)
            }

            await MainActor.run {
                self.sections = SoundEnvironment.allCases
                    .compactMap { env in
                        guard let rows = grouped[env], !rows.isEmpty else { return nil }
                        return (env: env, rows: rows)
                    }
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - TableView DataSource

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let env = sections[section].env
        return "\(env.label)"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]

        var config = cell.defaultContentConfiguration()
        let prefix = row.isCustom ? "* " : ""
        config.text = "\(prefix)\(row.name)"
        config.secondaryText = "TTS: \"\(row.speechDescription)\"  |  Difficulty: \(row.ciDifficulty)"
        config.secondaryTextProperties.color = .secondaryLabel
        config.secondaryTextProperties.font = .systemFont(ofSize: 12)

        let envIcon = row.environment.icon
        config.image = UIImage(systemName: envIcon)
        config.imageProperties.tintColor = .lcTeal

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - TableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]

        if row.isCustom {
            editCustomSound(row)
        } else {
            editBuiltInSound(row)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let row = sections[indexPath.section].rows[indexPath.row]

        // Preview action — available for all
        let preview = UIContextualAction(style: .normal, title: "Play") { [weak self] _, _, done in
            self?.playSoundTTS(row.speechDescription)
            done(true)
        }
        preview.backgroundColor = .lcTeal

        var actions = [preview]

        if row.isCustom {
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
                self?.deleteCustomSound(row.id)
                done(true)
            }
            actions.append(delete)
        } else if row.override != nil {
            // Allow resetting to default
            let reset = UIContextualAction(style: .destructive, title: "Reset") { [weak self] _, _, done in
                self?.resetOverride(row.id)
                done(true)
            }
            reset.backgroundColor = .lcOrange
            actions.append(reset)
        }

        return UISwipeActionsConfiguration(actions: actions)
    }

    // MARK: - Edit Built-In Sound

    private func editBuiltInSound(_ row: SoundRow) {
        let alert = UIAlertController(
            title: "Edit \(row.name)",
            message: "Customise this built-in sound's TTS text and description.",
            preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "Display name"
            tf.text = row.name
        }
        alert.addTextField { tf in
            tf.placeholder = "Description"
            tf.text = row.description
        }
        alert.addTextField { tf in
            tf.placeholder = "TTS sound text (e.g. knock knock knock)"
            tf.text = row.speechDescription
        }

        alert.addAction(UIAlertAction(title: "Preview", style: .default) { [weak self] _ in
            let tts = alert.textFields?[2].text ?? row.speechDescription
            self?.playSoundTTS(tts)
            // Re-show the alert
            self?.present(alert, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            let newName = alert.textFields?[0].text
            let newDesc = alert.textFields?[1].text
            let newTTS = alert.textFields?[2].text

            let override = SoundEditOverride(
                id: row.override?.id ?? 0,
                soundId: row.id,
                name: newName,
                description: newDesc,
                speechDescription: newTTS,
                ciDifficulty: row.ciDifficulty,
                updatedAt: Date())

            Task {
                try? await self?.service.saveOverride(override)
                await MainActor.run { self?.loadData() }
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Edit Custom Sound

    private func editCustomSound(_ row: SoundRow) {
        let vc = AddCustomSoundViewController()
        vc.existingSound = CustomEnvironmentalSound(
            id: 0, soundId: row.id, name: row.name,
            environment: row.environment.rawValue,
            description: row.description,
            speechDescription: row.speechDescription,
            ciDifficulty: row.ciDifficulty,
            isActive: true,
            createdAt: Date(), updatedAt: Date())
        vc.onSave = { [weak self] _ in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Delete / Reset

    private func deleteCustomSound(_ soundId: String) {
        Task {
            try? await service.deleteCustomSound(soundId: soundId)
            await MainActor.run { loadData() }
        }
    }

    private func resetOverride(_ soundId: String) {
        Task {
            try? await service.deleteOverride(soundId: soundId)
            await MainActor.run { loadData() }
        }
    }

    // MARK: - Add Custom Sound

    @objc private func addCustomSound() {
        let vc = AddCustomSoundViewController()
        vc.onSave = { [weak self] _ in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - TTS Preview

    private func playSoundTTS(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
