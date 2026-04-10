// AVTAudiologistNoteViewController.swift
// LangCI
//
// Redesigned Audiologist Note editor. Clean iOS-native layout:
//   • Large title nav with Save bar button
//   • Date card (compact picker)
//   • Assigned Sounds card with toggleable chips + custom add row
//   • Notes card (placeholder-managed UITextView with char count)
//   • Next Appointment card (switch + disclosable picker)
//   • Past Notes section with inset LCCard rows (swipe-to-delete)
//
// Service/data behaviour is preserved verbatim.

import UIKit

final class AVTAudiologistNoteViewController: UIViewController {

    // MARK: - State

    private var selectedDate = Date()
    private var selectedTargets: Set<String> = []
    private var pastNotes: [AVTAudiologistNote] = []
    private var customSounds: [String] = []

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let datePicker = UIDatePicker()

    private let targetSoundsFlow = UIStackView()
    private let customSoundField = UITextField()

    private let notesTextView = UITextView()
    private let notesPlaceholder = UILabel()
    private let charCountLabel = UILabel()

    private let appointmentSwitch = UISwitch()
    private let appointmentPicker = UIDatePicker()

    private let pastNotesStack = UIStackView()
    private let pastNotesEmptyLabel = UILabel()

    private var saveBarButton: UIBarButtonItem!

    // Tint
    private let accent: UIColor = .lcPurple

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
        loadData()
        setupKeyboardDismiss()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Session Note"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        saveBarButton = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveNote)
        )
        saveBarButton.tintColor = accent
        navigationItem.rightBarButtonItem = saveBarButton
    }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.alignment = .fill
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8, leading: 16, bottom: 32, trailing: 16
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

        contentStack.addArrangedSubview(buildDateSection())
        contentStack.addArrangedSubview(buildTargetsSection())
        contentStack.addArrangedSubview(buildNotesSection())
        contentStack.addArrangedSubview(buildAppointmentSection())
        contentStack.addArrangedSubview(buildPastNotesSection())
    }

    private func sectionBlock(title: String, card: UIView) -> UIView {
        let header = SectionHeaderView(title: title)
        let block = UIStackView(arrangedSubviews: [header, card])
        block.axis = .vertical
        block.spacing = 8
        return block
    }

    // MARK: - Sections

    private func buildDateSection() -> UIView {
        let card = LCCard()
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14, leading: 16, bottom: 14, trailing: 16
        )

        let icon = UIImageView(image: UIImage(systemName: "calendar"))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = UILabel()
        label.text = "Session Date"
        label.font = UIFont.lcBodyBold()
        label.textColor = .label
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        datePicker.preferredDatePickerStyle = .compact
        datePicker.datePickerMode = .date
        datePicker.date = selectedDate
        datePicker.tintColor = accent
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        datePicker.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.addArrangedSubview(datePicker)

        card.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])

        return sectionBlock(title: "Date", card: card)
    }

    private func buildTargetsSection() -> UIView {
        let card = LCCard()

        targetSoundsFlow.axis = .vertical
        targetSoundsFlow.spacing = 8
        targetSoundsFlow.alignment = .fill
        targetSoundsFlow.translatesAutoresizingMaskIntoConstraints = false

        // Custom sound row
        customSoundField.placeholder = "Add a sound (e.g. 'ch')"
        customSoundField.font = UIFont.lcBody()
        customSoundField.backgroundColor = .systemGray6
        customSoundField.layer.cornerRadius = 10
        customSoundField.autocapitalizationType = .none
        customSoundField.autocorrectionType = .no
        customSoundField.returnKeyType = .done
        customSoundField.delegate = self
        customSoundField.translatesAutoresizingMaskIntoConstraints = false
        customSoundField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let leftPad = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        customSoundField.leftView = leftPad
        customSoundField.leftViewMode = .always

        let addButton = UIButton(type: .system)
        var addConfig = UIButton.Configuration.filled()
        addConfig.baseBackgroundColor = accent
        addConfig.baseForegroundColor = .white
        addConfig.title = "Add"
        addConfig.cornerStyle = .medium
        addConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        addButton.configuration = addConfig
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addCustomSound), for: .touchUpInside)
        addButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let addRow = UIStackView(arrangedSubviews: [customSoundField, addButton])
        addRow.axis = .horizontal
        addRow.spacing = 8
        addRow.alignment = .center

        let inner = UIStackView(arrangedSubviews: [targetSoundsFlow, addRow])
        inner.axis = .vertical
        inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.isLayoutMarginsRelativeArrangement = true
        inner.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 16, leading: 16, bottom: 16, trailing: 16
        )

        card.contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])

        return sectionBlock(title: "Assigned Sounds", card: card)
    }

    private func buildNotesSection() -> UIView {
        let card = LCCard()

        notesTextView.font = UIFont.lcBody()
        notesTextView.textColor = .label
        notesTextView.backgroundColor = .clear
        notesTextView.delegate = self
        notesTextView.textContainerInset = .zero
        notesTextView.textContainer.lineFragmentPadding = 0
        notesTextView.translatesAutoresizingMaskIntoConstraints = false

        notesPlaceholder.text = "Type session observations…"
        notesPlaceholder.font = UIFont.lcBody()
        notesPlaceholder.textColor = .tertiaryLabel
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        charCountLabel.text = "0 / 1000"
        charCountLabel.font = UIFont.lcCaption()
        charCountLabel.textColor = .tertiaryLabel
        charCountLabel.textAlignment = .right
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(notesTextView)
        inner.addSubview(notesPlaceholder)
        inner.addSubview(charCountLabel)

        NSLayoutConstraint.activate([
            notesTextView.topAnchor.constraint(equalTo: inner.topAnchor, constant: 16),
            notesTextView.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 16),
            notesTextView.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -16),
            notesTextView.heightAnchor.constraint(equalToConstant: 180),

            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor),
            notesPlaceholder.trailingAnchor.constraint(equalTo: notesTextView.trailingAnchor),

            charCountLabel.topAnchor.constraint(equalTo: notesTextView.bottomAnchor, constant: 8),
            charCountLabel.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -16),
            charCountLabel.bottomAnchor.constraint(equalTo: inner.bottomAnchor, constant: -14),
            charCountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: inner.leadingAnchor, constant: 16)
        ])

        card.contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])

        return sectionBlock(title: "Notes", card: card)
    }

    private func buildAppointmentSection() -> UIView {
        let card = LCCard()

        let titleLabel = UILabel()
        titleLabel.text = "Schedule next appointment"
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label

        appointmentSwitch.onTintColor = accent
        appointmentSwitch.addTarget(self, action: #selector(toggleAppointment), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), appointmentSwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12

        appointmentPicker.preferredDatePickerStyle = .compact
        appointmentPicker.datePickerMode = .dateAndTime
        appointmentPicker.tintColor = accent
        appointmentPicker.isHidden = true
        appointmentPicker.alpha = 0
        appointmentPicker.translatesAutoresizingMaskIntoConstraints = false

        let pickerRow = UIStackView(arrangedSubviews: [UIView(), appointmentPicker])
        pickerRow.axis = .horizontal
        pickerRow.alignment = .center
        pickerRow.distribution = .fill

        let inner = UIStackView(arrangedSubviews: [row, pickerRow])
        inner.axis = .vertical
        inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.isLayoutMarginsRelativeArrangement = true
        inner.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14, leading: 16, bottom: 14, trailing: 16
        )

        card.contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])

        return sectionBlock(title: "Next Appointment", card: card)
    }

    private func buildPastNotesSection() -> UIView {
        pastNotesStack.axis = .vertical
        pastNotesStack.spacing = 10
        pastNotesStack.translatesAutoresizingMaskIntoConstraints = false

        pastNotesEmptyLabel.text = "No previous notes yet."
        pastNotesEmptyLabel.font = UIFont.lcBody()
        pastNotesEmptyLabel.textColor = .secondaryLabel
        pastNotesEmptyLabel.textAlignment = .center
        pastNotesEmptyLabel.isHidden = true
        pastNotesEmptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIStackView(arrangedSubviews: [pastNotesStack, pastNotesEmptyLabel])
        wrap.axis = .vertical
        wrap.spacing = 10

        return sectionBlock(title: "Past Notes", card: wrap)
    }

    // MARK: - Data

    private func loadData() {
        Task {
            do {
                async let targets = ServiceLocator.shared.avtService.getActiveTargets()
                async let notes = ServiceLocator.shared.avtService.getNotes()

                let activeTargets = try await targets
                let allNotes = try await notes

                await MainActor.run {
                    self.selectedTargets = Set(activeTargets.map { $0.sound })
                    self.pastNotes = allNotes.sorted { $0.notedAt > $1.notedAt }
                    self.updateTargetSoundChips()
                    self.renderPastNotes()
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Couldn't load data", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }

    private func updateTargetSoundChips() {
        targetSoundsFlow.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let sounds = selectedTargets.sorted()
        if sounds.isEmpty {
            let empty = UILabel()
            empty.text = "No sounds selected yet — add one below."
            empty.font = UIFont.lcCaption()
            empty.textColor = .tertiaryLabel
            targetSoundsFlow.addArrangedSubview(empty)
            return
        }

        // Flow layout approximation: split chips into rows of up to 3
        var currentRow: UIStackView?
        var count = 0
        for sound in sounds {
            if count % 3 == 0 {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 8
                row.alignment = .center
                row.distribution = .fillEqually
                targetSoundsFlow.addArrangedSubview(row)
                currentRow = row
            }
            let chip = makeSoundChip(sound: sound)
            currentRow?.addArrangedSubview(chip)
            count += 1
        }
        // Pad last row if needed
        if let row = currentRow {
            while row.arrangedSubviews.count < 3 {
                let spacer = UIView()
                row.addArrangedSubview(spacer)
            }
        }
    }

    private func makeSoundChip(sound: String) -> UIControl {
        let chip = SoundTogglePill(sound: sound)
        chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return chip
    }

    private func renderPastNotes() {
        pastNotesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if pastNotes.isEmpty {
            pastNotesEmptyLabel.isHidden = false
            return
        }
        pastNotesEmptyLabel.isHidden = true

        for (idx, note) in pastNotes.enumerated() {
            let row = PastNoteRowView(note: note)
            row.onDelete = { [weak self] in
                self?.deleteNote(at: idx)
            }
            pastNotesStack.addArrangedSubview(row)
        }
    }

    private func deleteNote(at index: Int) {
        guard index < pastNotes.count else { return }
        let note = pastNotes[index]
        let confirm = UIAlertController(
            title: "Delete this note?",
            message: "This can't be undone.",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await ServiceLocator.shared.avtService.deleteNote(noteId: note.id)
                    await MainActor.run {
                        self.pastNotes.removeAll { $0.id == note.id }
                        self.renderPastNotes()
                        self.lcShowToast("Note deleted", icon: "trash.fill", tint: .lcRed)
                    }
                } catch {
                    await MainActor.run {
                        self.lcShowToast("Couldn't delete", icon: "xmark.octagon.fill", tint: .lcRed)
                    }
                }
            }
        })
        present(confirm, animated: true)
    }

    // MARK: - Actions

    @objc private func dateChanged() {
        selectedDate = datePicker.date
    }

    @objc private func toggleAppointment() {
        let show = appointmentSwitch.isOn
        UIView.animate(withDuration: 0.25) {
            self.appointmentPicker.isHidden = !show
            self.appointmentPicker.alpha = show ? 1 : 0
        }
    }

    @objc private func addCustomSound() {
        guard let raw = customSoundField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            lcShowToast("Enter a sound", icon: "exclamationmark.triangle.fill", tint: .lcAmber)
            return
        }
        lcHaptic(.light)
        let sound = raw.lowercased()
        selectedTargets.insert(sound)
        customSounds.append(sound)
        customSoundField.text = ""
        updateTargetSoundChips()
    }

    @objc private func chipTapped(_ sender: SoundTogglePill) {
        lcHaptic(.light)
        selectedTargets.remove(sender.sound)
        customSounds.removeAll { $0 == sender.sound }
        updateTargetSoundChips()
    }

    @objc private func saveNote() {
        view.endEditing(true)
        let note = AVTAudiologistNote(
            id: 0,
            notedAt: selectedDate,
            targetSounds: Array(selectedTargets).sorted().joined(separator: ","),
            notes: notesTextView.text ?? "",
            nextAppointment: appointmentSwitch.isOn ? appointmentPicker.date : nil
        )

        Task {
            do {
                _ = try await ServiceLocator.shared.avtService.saveNote(note)

                for customSound in customSounds {
                    _ = try await ServiceLocator.shared.avtService.saveTarget(
                        AVTTarget(
                            id: 0,
                            sound: customSound,
                            phonemeIpa: "/\(customSound.prefix(1))/",
                            frequencyRange: "",
                            soundDescription: "Added from audiologist note",
                            currentLevel: .detection,
                            isActive: true,
                            assignedAt: Date(),
                            audiologistNote: nil
                        )
                    )
                }

                await MainActor.run {
                    self.lcHapticSuccess()
                    self.lcShowToast("Note saved", icon: "checkmark.circle.fill", tint: .lcGreen)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Save failed", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension AVTAudiologistNoteViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        addCustomSound()
        return true
    }
}

// MARK: - UITextViewDelegate

extension AVTAudiologistNoteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
        charCountLabel.text = "\(textView.text.count) / 1000"
        if textView.text.count > 1000 {
            charCountLabel.textColor = .lcRed
        } else {
            charCountLabel.textColor = .tertiaryLabel
        }
    }
}

// MARK: - SoundTogglePill

private final class SoundTogglePill: UIControl {
    let sound: String
    private let label = UILabel()
    private let iconView = UIImageView()

    init(sound: String) {
        self.sound = sound
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = UIColor.lcGreen.withAlphaComponent(0.12)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.lcGreen.withAlphaComponent(0.45).cgColor

        iconView.image = UIImage(systemName: "checkmark")
        iconView.tintColor = .lcGreen
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true

        label.text = sound.uppercased()
        label.font = UIFont.lcBodyBold()
        label.textColor = .lcGreen
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

// MARK: - PastNoteRowView

private final class PastNoteRowView: UIView {
    var onDelete: (() -> Void)?

    init(note: AVTAudiologistNote) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .lcCard
        layer.cornerRadius = LC.cornerRadius
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor

        let df = DateFormatter()
        df.dateStyle = .medium

        let dateLabel = UILabel()
        dateLabel.text = df.string(from: note.notedAt)
        dateLabel.font = UIFont.lcCaption()
        dateLabel.textColor = .tertiaryLabel

        let soundsLabel = UILabel()
        let list = note.targetSoundList.map { $0.uppercased() }.joined(separator: " • ")
        soundsLabel.text = list.isEmpty ? "No sounds" : list
        soundsLabel.font = UIFont.lcBodyBold()
        soundsLabel.textColor = .label
        soundsLabel.numberOfLines = 1

        let preview = UILabel()
        let prev = note.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        preview.text = prev.isEmpty
            ? "No notes"
            : (prev.count > 120 ? String(prev.prefix(120)) + "…" : prev)
        preview.font = UIFont.lcBody()
        preview.textColor = .secondaryLabel
        preview.numberOfLines = 3

        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .lcRed
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let header = UIStackView(arrangedSubviews: [dateLabel, UIView(), deleteButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        let stack = UIStackView(arrangedSubviews: [header, soundsLabel, preview])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func didTapDelete() {
        onDelete?()
    }
}
