// AddCustomSoundViewController.swift
// LangCI — Add / edit a custom environmental sound
//
// Allows users to create their own sounds (e.g. "my dog's bark",
// "my doorbell") with a TTS description and difficulty rating.
// Also used for editing existing custom sounds.

import UIKit
import AVFoundation

final class AddCustomSoundViewController: UIViewController {

    // MARK: - Edit mode

    /// Pass an existing sound to edit; nil for new
    var existingSound: CustomEnvironmentalSound?

    // MARK: - Callback

    var onSave: ((CustomEnvironmentalSound) -> Void)?

    // MARK: - Service

    private let service = ServiceLocator.shared.environmentalSoundService!
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let nameField = UITextField()
    private let descriptionField = UITextField()
    private let ttsField = UITextField()
    private let environmentPicker = UISegmentedControl()
    private let difficultySlider = UISlider()
    private let difficultyLabel = UILabel()
    private let previewButton = LCButton(title: "Preview Sound", color: .lcTeal)
    private let saveButton = LCButton(title: "Save Sound", color: .lcGreen)

    private let environments: [SoundEnvironment] = [.home, .kitchen, .outdoors,
                                                      .people, .animals, .transport,
                                                      .alerts, .music]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingSound != nil ? "Edit Sound" : "Add Custom Sound"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        buildUI()
        populateIfEditing()
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 16, leading: 20, bottom: 40, trailing: 20)
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // Sound Name
        contentStack.addArrangedSubview(makeFieldSection(
            title: "Sound Name",
            subtitle: "What is this sound? e.g. \"My doorbell\", \"Amma calling\"",
            field: nameField,
            placeholder: "Door Knock"))

        // Description
        contentStack.addArrangedSubview(makeFieldSection(
            title: "Description",
            subtitle: "A short description of the sound",
            field: descriptionField,
            placeholder: "Someone knocking on my front door"))

        // TTS Text
        contentStack.addArrangedSubview(makeFieldSection(
            title: "Sound Effect Text (TTS)",
            subtitle: "Type what this sound sounds like — the app will speak it aloud.\nE.g. \"knock knock knock\" or \"ding dong\"",
            field: ttsField,
            placeholder: "knock knock knock"))

        // Environment category
        let envSection = makeSection(title: "Category",
            subtitle: "Which environment does this sound belong to?")
        for (i, env) in environments.enumerated() {
            environmentPicker.insertSegment(withTitle: env.label, at: i, animated: false)
        }
        environmentPicker.selectedSegmentIndex = 0
        environmentPicker.translatesAutoresizingMaskIntoConstraints = false
        envSection.addArrangedSubview(environmentPicker)
        contentStack.addArrangedSubview(envSection)

        // Difficulty
        let diffSection = makeSection(title: "CI Difficulty (1-5)",
            subtitle: "1 = easy (low-freq, simple) → 5 = hard (high-freq, complex)")
        difficultySlider.minimumValue = 1
        difficultySlider.maximumValue = 5
        difficultySlider.value = 2
        difficultySlider.tintColor = .lcTeal
        difficultySlider.addTarget(self, action: #selector(difficultyChanged), for: .valueChanged)

        difficultyLabel.text = "Difficulty: 2"
        difficultyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        difficultyLabel.textColor = .secondaryLabel

        let diffRow = UIStackView(arrangedSubviews: [difficultySlider, difficultyLabel])
        diffRow.spacing = 12
        diffRow.alignment = .center
        difficultyLabel.setContentHuggingPriority(.required, for: .horizontal)

        diffSection.addArrangedSubview(diffRow)
        contentStack.addArrangedSubview(diffSection)

        // Preview
        previewButton.addTarget(self, action: #selector(previewTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(previewButton)

        // Save
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(saveButton)

        // Dismiss keyboard on tap
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func populateIfEditing() {
        guard let s = existingSound else { return }
        nameField.text = s.name
        descriptionField.text = s.description
        ttsField.text = s.speechDescription
        if let idx = environments.firstIndex(where: { $0.rawValue == s.environment }) {
            environmentPicker.selectedSegmentIndex = idx
        }
        difficultySlider.value = Float(s.ciDifficulty)
        difficultyLabel.text = "Difficulty: \(s.ciDifficulty)"
        saveButton.setTitle("Update Sound", for: .normal)
    }

    // MARK: - Helpers

    private func makeFieldSection(title: String, subtitle: String,
                                   field: UITextField, placeholder: String) -> UIStackView {
        let section = makeSection(title: title, subtitle: subtitle)

        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .roundedRect
        field.backgroundColor = .lcCard
        field.autocorrectionType = .no
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true

        section.addArrangedSubview(field)
        return section
    }

    private func makeSection(title: String, subtitle: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .tertiaryLabel
        subtitleLbl.numberOfLines = 0

        stack.addArrangedSubview(titleLbl)
        stack.addArrangedSubview(subtitleLbl)
        return stack
    }

    // MARK: - Actions

    @objc private func difficultyChanged() {
        let val = Int(difficultySlider.value.rounded())
        difficultyLabel.text = "Difficulty: \(val)"
    }

    @objc private func previewTapped() {
        guard let tts = ttsField.text, !tts.isEmpty else {
            showAlert(title: "No TTS text", message: "Enter the sound effect text first, then tap preview to hear it.")
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: tts)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    @objc private func saveTapped() {
        guard let name = nameField.text, !name.isEmpty else {
            showAlert(title: "Name required", message: "Please enter a name for the sound.")
            return
        }
        guard let tts = ttsField.text, !tts.isEmpty else {
            showAlert(title: "TTS text required", message: "Enter what this sound sounds like so the app can play it.")
            return
        }

        let envIdx = environmentPicker.selectedSegmentIndex
        let env = environments[envIdx]
        let difficulty = Int(difficultySlider.value.rounded())
        let desc = descriptionField.text ?? name

        // Generate a unique ID from name
        let soundId: String
        if let existing = existingSound {
            soundId = existing.soundId
        } else {
            soundId = "custom_" + name.lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        }

        let sound = CustomEnvironmentalSound(
            id: existingSound?.id ?? 0,
            soundId: soundId,
            name: name,
            environment: env.rawValue,
            description: desc,
            speechDescription: tts,
            ciDifficulty: difficulty,
            isActive: true,
            createdAt: existingSound?.createdAt ?? Date(),
            updatedAt: Date())

        Task {
            do {
                if existingSound != nil {
                    try await service.updateCustomSound(sound)
                    onSave?(sound)
                } else {
                    let saved = try await service.addCustomSound(sound)
                    onSave?(saved)
                }
                await MainActor.run {
                    navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Save failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
