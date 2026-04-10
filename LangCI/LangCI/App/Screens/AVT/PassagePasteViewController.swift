// PassagePasteViewController.swift
// LangCI
//
// Modal that lets the user paste their own text to use as a reading passage.
// Saves it as a non-bundled ReadingPassage.

import UIKit

final class PassagePasteViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let titleField = UITextField()
    private let bodyView = UITextView()
    private let categoryControl = UISegmentedControl(items:
        ReadingCategory.allCases.map { $0.emoji + " " + $0.label }
    )
    private let difficultyControl = UISegmentedControl(items: ["Easy", "Medium", "Hard"])
    private let wordCountLabel = UILabel()
    private let saveButton = LCButton(title: "Save & Start Reading", color: .lcBlue)

    // MARK: - Callback

    private let onSave: (ReadingPassage) -> Void

    // MARK: - Init

    init(onSave: @escaping (ReadingPassage) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Paste Passage"
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
        stack.spacing = 16
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

        // Hint
        let hint = UILabel()
        hint.text = "Paste a paragraph or two you want to read aloud — a newspaper headline, a page of a book, anything that matches what your therapist asked you to read."
        hint.font = UIFont.lcCaption()
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        stack.addArrangedSubview(hint)

        // Title
        stack.addArrangedSubview(sectionLabel("Title"))
        styleField(titleField, placeholder: "e.g. Morning news headline")
        titleField.heightAnchor.constraint(equalToConstant: 46).isActive = true
        stack.addArrangedSubview(titleField)

        // Category
        stack.addArrangedSubview(sectionLabel("Category"))
        categoryControl.selectedSegmentIndex = ReadingCategory.everyday.rawValue
        stack.addArrangedSubview(categoryControl)

        // Difficulty
        stack.addArrangedSubview(sectionLabel("Difficulty"))
        difficultyControl.selectedSegmentIndex = 0
        stack.addArrangedSubview(difficultyControl)

        // Body
        stack.addArrangedSubview(sectionLabel("Passage text"))
        bodyView.font = UIFont.lcBody()
        bodyView.textColor = .label
        bodyView.backgroundColor = .lcCard
        bodyView.layer.cornerRadius = LC.cornerRadius
        bodyView.textContainerInset = .init(top: 14, left: 12, bottom: 14, right: 12)
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        bodyView.delegate = self
        stack.addArrangedSubview(bodyView)

        wordCountLabel.text = "0 words"
        wordCountLabel.font = UIFont.lcCaption()
        wordCountLabel.textColor = .tertiaryLabel
        wordCountLabel.textAlignment = .right
        stack.addArrangedSubview(wordCountLabel)

        // Save button
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(saveButton)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stack.addArrangedSubview(spacer)

        titleField.becomeFirstResponder()
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.lcBodyBold()
        label.textColor = .secondaryLabel
        return label
    }

    private func styleField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = UIFont.lcBody()
        field.textColor = .label
        field.backgroundColor = .lcCard
        field.layer.cornerRadius = LC.cornerRadius
        field.autocorrectionType = .default
        field.translatesAutoresizingMaskIntoConstraints = false
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = pad
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.rightViewMode = .always
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        let title = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let body  = bodyView.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            lcShowToast("Title is required",
                        icon: "exclamationmark.triangle.fill",
                        tint: .lcAmber)
            return
        }
        guard !body.isEmpty, body.count >= 20 else {
            lcShowToast("Please paste at least 20 characters",
                        icon: "exclamationmark.triangle.fill",
                        tint: .lcAmber)
            return
        }
        let category = ReadingCategory(rawValue: categoryControl.selectedSegmentIndex) ?? .everyday
        let difficulty = difficultyControl.selectedSegmentIndex + 1
        let passage = ReadingPassage(
            title: title,
            category: category,
            difficulty: difficulty,
            body: body,
            isBundled: false
        )
        dismiss(animated: true) { [onSave] in
            onSave(passage)
        }
    }
}

extension PassagePasteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let count = textView.text
            .split { $0.isWhitespace || $0.isNewline }
            .count
        wordCountLabel.text = "\(count) word\(count == 1 ? "" : "s")"
    }
}
