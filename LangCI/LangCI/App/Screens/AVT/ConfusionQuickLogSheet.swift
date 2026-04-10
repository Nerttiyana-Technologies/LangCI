// ConfusionQuickLogSheet.swift
// LangCI
//
// Modal sheet presented from the Confusion Log screen AND inline from the
// AVT drill when the user marks an attempt wrong. Captures a single
// "said X, I heard Y" pair with optional target sound + note.

import UIKit

final class ConfusionQuickLogSheet: UIViewController {

    // Pre-fill hints — set before presenting.
    var prefillSaid: String = ""
    var prefillHeard: String = ""
    var prefillSound: String = ""
    var source: ConfusionSource = .manual
    var avtSessionId: Int? = nil

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let saidField = UITextField()
    private let heardField = UITextField()
    private let soundField = UITextField()
    private let noteField = UITextView()

    private let saveButton = LCButton(title: "Save", color: .lcPurple)

    // MARK: - Callback

    private let onSave: (ConfusionPair) -> Void

    // MARK: - Init

    init(prefillSaid: String = "",
         prefillHeard: String = "",
         prefillSound: String = "",
         source: ConfusionSource = .manual,
         avtSessionId: Int? = nil,
         onSave: @escaping (ConfusionPair) -> Void)
    {
        self.prefillSaid = prefillSaid
        self.prefillHeard = prefillHeard
        self.prefillSound = prefillSound
        self.source = source
        self.avtSessionId = avtSessionId
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log Confusion"
        view.backgroundColor = .lcBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 18
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 20, leading: LC.cardPadding,
                                               bottom: 20, trailing: LC.cardPadding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Explanation
        let hint = UILabel()
        hint.text = "Capture a moment when what you heard wasn't what was actually said. Examples: Amma → Appa, sheep → seep, mm → nn."
        hint.font = UIFont.lcCaption()
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        stack.addArrangedSubview(hint)

        // Said field
        stack.addArrangedSubview(labeledField(
            title: "What was actually said",
            field: saidField,
            placeholder: "e.g. Amma",
            prefill: prefillSaid
        ))

        // Heard field
        stack.addArrangedSubview(labeledField(
            title: "What I heard",
            field: heardField,
            placeholder: "e.g. Appa",
            prefill: prefillHeard
        ))

        // Sound field (optional)
        stack.addArrangedSubview(labeledField(
            title: "Target sound (optional)",
            field: soundField,
            placeholder: "e.g. mm, sh, p",
            prefill: prefillSound
        ))

        // Note field
        let noteLabel = UILabel()
        noteLabel.text = "Note (optional)"
        noteLabel.font = UIFont.lcBodyBold()
        noteLabel.textColor = .secondaryLabel
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(noteLabel)

        noteField.font = UIFont.lcBody()
        noteField.textColor = .label
        noteField.backgroundColor = .lcCard
        noteField.layer.cornerRadius = LC.cornerRadius
        noteField.textContainerInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.heightAnchor.constraint(equalToConstant: 88).isActive = true
        stack.addArrangedSubview(noteField)

        // Save button
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(saveButton)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(spacer)

        saidField.becomeFirstResponder()
    }

    private func labeledField(title: String,
                              field: UITextField,
                              placeholder: String,
                              prefill: String) -> UIView
    {
        let label = UILabel()
        label.text = title
        label.font = UIFont.lcBodyBold()
        label.textColor = .secondaryLabel

        field.placeholder = placeholder
        field.text = prefill
        field.font = UIFont.lcBody()
        field.textColor = .label
        field.backgroundColor = .lcCard
        field.layer.cornerRadius = LC.cornerRadius
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 46).isActive = true
        // Add padding
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = pad
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.rightViewMode = .always

        let wrap = UIStackView(arrangedSubviews: [label, field])
        wrap.axis = .vertical
        wrap.spacing = 6
        return wrap
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        let said  = saidField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let heard = heardField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !said.isEmpty, !heard.isEmpty else {
            lcHaptic(.light)
            lcShowToast("Both 'said' and 'heard' are required",
                        icon: "exclamationmark.triangle.fill",
                        tint: .lcAmber)
            return
        }
        let sound = soundField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let note  = noteField.text.trimmingCharacters(in: .whitespaces)
        let pair = ConfusionPair(
            saidWord: said,
            heardWord: heard,
            targetSound: sound,
            source: source,
            avtSessionId: avtSessionId,
            contextNote: note.isEmpty ? nil : note,
            loggedAt: Date()
        )
        dismiss(animated: true) { [onSave] in
            onSave(pair)
        }
    }
}
