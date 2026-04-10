// EditMilestoneViewController.swift
// LangCI
//
// Modal sheet for adding a new milestone or editing an existing one.
// Presented as a form sheet with medium/large detents from
// MilestonesViewController. Lets the user pick a type, set the
// achieved date, choose an emoji, and add an optional note.

import UIKit

final class EditMilestoneViewController: UIViewController {

    // MARK: - Public

    var onSave: (() -> Void)?

    // MARK: - State

    private var entry: MilestoneEntry
    private let isEditing_: Bool
    private var selectedType: MilestoneType {
        didSet { typeDidChange() }
    }
    private var emoji: String
    private var userEditedEmoji = false

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let typeCard = LCCard()
    private let typeLabel = UILabel()
    private let typeButton = LCButton(title: "Choose Type", color: .lcPurple)

    private let dateCard = LCCard()
    private let dateLabel = UILabel()
    private let datePicker = UIDatePicker()

    private let emojiCard = LCCard()
    private let emojiPreview = UILabel()
    private let emojiField = UITextField()
    private let emojiHint = UILabel()

    private let titleCard = LCCard()
    private let titleField = UITextField()
    private let titleHint = UILabel()

    private let notesCard = LCCard()
    private let notesView = UITextView()
    private let notesPlaceholder = UILabel()

    private let saveButton = LCButton(title: "Save Milestone", color: .lcPurple)

    // MARK: - Init

    init(existing: MilestoneEntry?) {
        if let existing {
            self.entry = existing
            self.isEditing_ = true
            self.selectedType = existing.type
            self.emoji = existing.emoji
        } else {
            let blank = MilestoneEntry(
                id: 0,
                type: .firstWord,
                achievedAt: Date(),
                accuracyAtMilestone: nil,
                description: "",
                notes: nil,
                emoji: "💬"
            )
            self.entry = blank
            self.isEditing_ = false
            self.selectedType = .firstWord
            self.emoji = blank.defaultEmoji
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground
        title = isEditing_ ? "Edit Milestone" : "New Milestone"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )

        buildUI()
        typeDidChange()
    }

    // MARK: - UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(
            top: 16, leading: LC.cardPadding,
            bottom: 24, trailing: LC.cardPadding
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        buildTypeCard()
        buildDateCard()
        buildEmojiCard()
        buildTitleCard()
        buildNotesCard()

        stack.addArrangedSubview(typeCard)
        stack.addArrangedSubview(titleCard)
        stack.addArrangedSubview(dateCard)
        stack.addArrangedSubview(emojiCard)
        stack.addArrangedSubview(notesCard)

        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(saveButton)
    }

    private func buildTypeCard() {
        typeLabel.text = ""
        typeLabel.font = .lcCardLabel()
        typeLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.tag = 9001
        valueLabel.font = .lcCardValue()
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0

        typeButton.addTarget(self, action: #selector(didTapPickType), for: .touchUpInside)
        typeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let column = UIStackView(arrangedSubviews: [typeLabel, valueLabel, typeButton])
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        typeCard.addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: typeCard.topAnchor, constant: LC.cardPadding),
            column.leadingAnchor.constraint(equalTo: typeCard.leadingAnchor, constant: LC.cardPadding),
            column.trailingAnchor.constraint(equalTo: typeCard.trailingAnchor, constant: -LC.cardPadding),
            column.bottomAnchor.constraint(equalTo: typeCard.bottomAnchor, constant: -LC.cardPadding)
        ])

        typeLabel.text = "TYPE"
        valueLabel.text = entry.typeLabel
    }

    private func buildDateCard() {
        dateLabel.text = "ACHIEVED ON"
        dateLabel.font = .lcCardLabel()
        dateLabel.textColor = .secondaryLabel

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.date = entry.achievedAt
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        let column = UIStackView(arrangedSubviews: [dateLabel, datePicker])
        column.axis = .vertical
        column.spacing = 8
        column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false
        dateCard.addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: dateCard.topAnchor, constant: LC.cardPadding),
            column.leadingAnchor.constraint(equalTo: dateCard.leadingAnchor, constant: LC.cardPadding),
            column.trailingAnchor.constraint(equalTo: dateCard.trailingAnchor, constant: -LC.cardPadding),
            column.bottomAnchor.constraint(equalTo: dateCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildEmojiCard() {
        let label = UILabel()
        label.text = "EMOJI"
        label.font = .lcCardLabel()
        label.textColor = .secondaryLabel

        emojiPreview.text = emoji
        emojiPreview.font = .systemFont(ofSize: 36)
        emojiPreview.textAlignment = .center
        emojiPreview.translatesAutoresizingMaskIntoConstraints = false
        emojiPreview.widthAnchor.constraint(equalToConstant: 56).isActive = true

        emojiField.text = emoji
        emojiField.font = .systemFont(ofSize: 24)
        emojiField.borderStyle = .roundedRect
        emojiField.placeholder = "🎉"
        emojiField.autocorrectionType = .no
        emojiField.addTarget(self, action: #selector(emojiChanged), for: .editingChanged)

        let row = UIStackView(arrangedSubviews: [emojiPreview, emojiField])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        emojiHint.text = "Tap the field and pick from your emoji keyboard."
        emojiHint.font = .lcCaption()
        emojiHint.textColor = .tertiaryLabel
        emojiHint.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [label, row, emojiHint])
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        emojiCard.addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: emojiCard.topAnchor, constant: LC.cardPadding),
            column.leadingAnchor.constraint(equalTo: emojiCard.leadingAnchor, constant: LC.cardPadding),
            column.trailingAnchor.constraint(equalTo: emojiCard.trailingAnchor, constant: -LC.cardPadding),
            column.bottomAnchor.constraint(equalTo: emojiCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildTitleCard() {
        let label = UILabel()
        label.text = "TITLE"
        label.font = .lcCardLabel()
        label.textColor = .secondaryLabel

        titleField.placeholder = "e.g. First trip outside without help"
        titleField.borderStyle = .roundedRect
        titleField.text = entry.description
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)

        titleHint.text = "Required for Custom milestones. Optional otherwise."
        titleHint.font = .lcCaption()
        titleHint.textColor = .tertiaryLabel
        titleHint.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [label, titleField, titleHint])
        column.axis = .vertical
        column.spacing = 6
        column.translatesAutoresizingMaskIntoConstraints = false
        titleCard.addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: titleCard.topAnchor, constant: LC.cardPadding),
            column.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: LC.cardPadding),
            column.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -LC.cardPadding),
            column.bottomAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    private func buildNotesCard() {
        let label = UILabel()
        label.text = "NOTES"
        label.font = .lcCardLabel()
        label.textColor = .secondaryLabel

        notesView.font = .lcBody()
        notesView.text = entry.notes ?? ""
        notesView.layer.cornerRadius = 8
        notesView.backgroundColor = .secondarySystemBackground
        notesView.delegate = self
        notesView.translatesAutoresizingMaskIntoConstraints = false
        notesView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        notesPlaceholder.text = "Anything you want to remember about this moment…"
        notesPlaceholder.font = .lcBody()
        notesPlaceholder.textColor = .tertiaryLabel
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notesView.addSubview(notesPlaceholder)
        NSLayoutConstraint.activate([
            notesPlaceholder.topAnchor.constraint(equalTo: notesView.topAnchor, constant: 10),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesView.leadingAnchor, constant: 6),
            notesPlaceholder.trailingAnchor.constraint(equalTo: notesView.trailingAnchor, constant: -6)
        ])
        notesPlaceholder.isHidden = !notesView.text.isEmpty

        let column = UIStackView(arrangedSubviews: [label, notesView])
        column.axis = .vertical
        column.spacing = 6
        column.translatesAutoresizingMaskIntoConstraints = false
        notesCard.addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: LC.cardPadding),
            column.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: LC.cardPadding),
            column.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -LC.cardPadding),
            column.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -LC.cardPadding)
        ])
    }

    // MARK: - State helpers

    private func typeDidChange() {
        entry.type = selectedType
        // Refresh the value label inside the type card.
        if let value = typeCard.viewWithTag(9001) as? UILabel {
            let preview = MilestoneEntry(
                id: entry.id,
                type: selectedType,
                achievedAt: entry.achievedAt,
                description: entry.description,
                notes: entry.notes
            )
            value.text = preview.typeLabel
        }
        // Auto-refresh emoji to the default for the new type unless
        // the user has explicitly typed their own emoji.
        if !userEditedEmoji {
            let preview = MilestoneEntry(id: 0, type: selectedType)
            emoji = preview.defaultEmoji
            emojiField.text = emoji
            emojiPreview.text = emoji
        }
    }

    @objc private func dateChanged() {
        entry.achievedAt = datePicker.date
    }

    @objc private func emojiChanged() {
        let raw = emojiField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        emoji = raw.isEmpty ? entry.defaultEmoji : String(raw.prefix(4))
        emojiPreview.text = emoji
        userEditedEmoji = !raw.isEmpty
    }

    @objc private func titleChanged() {
        entry.description = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    // MARK: - Actions

    @objc private func didTapPickType() {
        lcHaptic(.light)
        let alert = UIAlertController(
            title: "Milestone Type",
            message: nil,
            preferredStyle: .actionSheet
        )
        for type in MilestoneType.userPickable {
            let stub = MilestoneEntry(id: 0, type: type)
            alert.addAction(UIAlertAction(
                title: "\(stub.defaultEmoji)  \(stub.typeLabel)",
                style: .default
            ) { [weak self] _ in
                self?.selectedType = type
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = typeButton
            popover.sourceRect = typeButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        // Validation: Custom requires a title.
        if selectedType == .custom && entry.description.isEmpty {
            lcHaptic(.light)
            lcShowToast("Custom milestones need a title",
                        icon: "exclamationmark.triangle.fill",
                        tint: .lcAmber)
            return
        }

        var toSave = entry
        toSave.type = selectedType
        toSave.achievedAt = datePicker.date
        toSave.emoji = emoji.isEmpty ? toSave.defaultEmoji : emoji
        let notes = notesView.text.trimmingCharacters(in: .whitespaces)
        toSave.notes = notes.isEmpty ? nil : notes

        Task {
            do {
                _ = try await ServiceLocator.shared.milestoneService.save(toSave)
                await MainActor.run {
                    self.lcHapticSuccess()
                    self.onSave?()
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Save failed",
                                     icon: "exclamationmark.triangle.fill",
                                     tint: .lcRed)
                }
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension EditMilestoneViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
    }
}
