// ManageSoundsViewController.swift
// LangCI — Manage test sounds for Sound Detection
//
// Lets the audiologist or user add/remove/reorder sounds in the test grid.
// Default sounds (Ling 6 + extras) can be hidden but not deleted.

import UIKit

final class ManageSoundsViewController: UIViewController {

    private let service = ServiceLocator.shared.soundDetectionService!
    private var sounds: [TestSound] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manage Sounds"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        let addBtn = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addSoundTapped))
        addBtn.tintColor = .lcTeal
        navigationItem.rightBarButtonItem = addBtn

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SoundCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        loadSounds()
    }

    private func loadSounds() {
        Task {
            sounds = (try? await service.getAllSounds()) ?? []
            await MainActor.run { tableView.reloadData() }
        }
    }

    // MARK: - Actions

    @objc private func addSoundTapped() {
        let alert = UIAlertController(
            title: "Add Sound",
            message: "Enter the sound symbol and how TTS should pronounce it",
            preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Symbol (e.g. 'ch', 'ng', 'கா')" }
        alert.addTextField {
            $0.placeholder = "TTS pronunciation (e.g. 'church' for 'ch')"
            // Pre-populate caption so audiologist understands this is key
        }
        alert.addTextField { $0.placeholder = "Tamil label (optional)" }
        alert.addTextField { $0.placeholder = "IPA symbol (optional, e.g. /tʃ/)" }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let symbol = alert.textFields?[0].text, !symbol.isEmpty else { return }
            let ttsHint = alert.textFields?[1].text
            let tamil = alert.textFields?[2].text
            let ipa = alert.textFields?[3].text

            let sound = TestSound(
                id: 0, symbol: symbol,
                tamilLabel: tamil?.isEmpty == true ? nil : tamil,
                ipaSymbol: ipa?.isEmpty == true ? nil : ipa,
                ttsHint: ttsHint?.isEmpty == true ? nil : ttsHint,
                audioFileName: nil,
                sortOrder: self.sounds.count,
                isActive: true, isDefault: false,
                createdAt: Date())

            Task {
                _ = try? await self.service.addSound(sound)
                self.loadSounds()
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension ManageSoundsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sounds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SoundCell", for: indexPath)
        let sound = sounds[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = sound.symbol
        if let tamil = sound.tamilLabel {
            config.text = "\(sound.symbol)  (\(tamil))"
        }
        // Show IPA + pronunciation hint so audiologist can verify
        var detail = sound.ipaSymbol ?? ""
        if let hint = sound.ttsHint, !hint.isEmpty {
            detail += detail.isEmpty ? "Says: \"\(hint)\"" : "  •  Says: \"\(hint)\""
        } else {
            let auto = sound.speakableText
            if auto != sound.symbol {
                detail += detail.isEmpty ? "Says: \"\(auto)\"" : "  •  Says: \"\(auto)\""
            }
        }
        config.secondaryText = detail.isEmpty ? nil : detail
        config.textProperties.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        if !sound.isActive {
            config.textProperties.color = .tertiaryLabel
            config.secondaryTextProperties.color = .tertiaryLabel
        }

        cell.contentConfiguration = config

        // Toggle active/inactive
        let toggle = UISwitch()
        toggle.isOn = sound.isActive
        toggle.tag = indexPath.row
        toggle.onTintColor = .lcTeal
        toggle.addTarget(self, action: #selector(toggleSound(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func toggleSound(_ sender: UISwitch) {
        let idx = sender.tag
        guard idx < sounds.count else { return }
        sounds[idx].isActive = sender.isOn
        let sound = sounds[idx]
        Task {
            try? await service.updateSound(sound)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        !sounds[indexPath.row].isDefault  // Can't delete defaults
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let sound = sounds[indexPath.row]
            sounds.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            Task {
                try? await service.deleteSound(id: sound.id)
            }
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Toggle sounds on/off. Swipe to delete custom sounds."
    }
}
