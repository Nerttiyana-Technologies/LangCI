// AddWordViewController.swift
// LangCI — modal editor for adding user-created words to the library.
//
// Presented from LibraryViewController's "+" bar button. Users fill in:
//   • Native script (required)        — e.g. "milk" or "தண்ணீர்"
//   • IPA / pronunciation (optional)  — e.g. "/mɪlk/"
//   • Phonetic key / target sound     — e.g. "m" for /m/ drills
//   • Language picker                 — segmented control
//   • Category                        — action sheet preset picker
//
// On save the word is persisted via WordService.saveWord with
// source = .user, status = .active so it shows up in the library
// instantly.

import UIKit

final class AddWordViewController: UIViewController {

    // MARK: - Config

    private let languages: [Language]
    private var selectedLanguageId: Int?
    private var selectedCategory: String = "Uncategorized"
    private let onSaved: () -> Void

    private let categoryOptions = [
        "Ling 6", "Phonemes", "Family", "Animals",
        "Food", "Vehicles", "Everyday", "Uncategorized"
    ]

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let headerLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let nativeField = LCFormField(
        title: "Word",
        placeholder: "Type the word — e.g. milk, அம்மா"
    )
    private let ipaField = LCFormField(
        title: "Pronunciation (IPA) — optional",
        placeholder: "/mɪlk/"
    )
    private let keyField = LCFormField(
        title: "Target sound — optional",
        placeholder: "m, sh, s, ling6…"
    )

    private let languageSegment = UISegmentedControl()
    private let categoryButton = LCButton(title: "Category: Uncategorized", color: .lcOrange)
    private let saveButton = LCButton(title: "Save word", color: .lcOrange)

    // MARK: - Init

    init(languages: [Language],
         defaultLanguageId: Int?,
         onSaved: @escaping () -> Void) {
        self.languages = languages
        self.selectedLanguageId = defaultLanguageId ?? languages.first?.id
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground
        title = "Add Word"

        setupNavBar()
        setupLayout()
        buildLanguageSegment()

        categoryButton.addTarget(self, action: #selector(pickCategory), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveWord), for: .touchUpInside)

        nativeField.textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        refreshSaveEnabled()
    }

    // MARK: - Setup

    private func setupNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 24, leading: 20, bottom: 24, trailing: 20)
        scrollView.addSubview(stack)

        headerLabel.text = "New word"
        headerLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        headerLabel.textColor = .label

        subtitleLabel.text = "Add a word to your personal practice library. It'll show up in the library with a \"user\" badge."
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(headerLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)

        stack.addArrangedSubview(nativeField)
        stack.addArrangedSubview(ipaField)
        stack.addArrangedSubview(keyField)

        let langLabel = UILabel()
        langLabel.text = "LANGUAGE"
        langLabel.font = .systemFont(ofSize: 11, weight: .bold)
        langLabel.textColor = .secondaryLabel
        stack.setCustomSpacing(24, after: keyField)
        stack.addArrangedSubview(langLabel)
        stack.addArrangedSubview(languageSegment)

        let catLabel = UILabel()
        catLabel.text = "CATEGORY"
        catLabel.font = .systemFont(ofSize: 11, weight: .bold)
        catLabel.textColor = .secondaryLabel
        stack.setCustomSpacing(20, after: languageSegment)
        stack.addArrangedSubview(catLabel)
        stack.addArrangedSubview(categoryButton)

        stack.setCustomSpacing(36, after: categoryButton)
        stack.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            languageSegment.heightAnchor.constraint(equalToConstant: 36),
            categoryButton.heightAnchor.constraint(equalToConstant: 48),
            saveButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func buildLanguageSegment() {
        languageSegment.removeAllSegments()
        if languages.isEmpty {
            languageSegment.insertSegment(withTitle: "English", at: 0, animated: false)
            languageSegment.selectedSegmentIndex = 0
            return
        }
        for (idx, lang) in languages.enumerated() {
            languageSegment.insertSegment(withTitle: lang.name, at: idx, animated: false)
        }
        if let selected = selectedLanguageId,
           let idx = languages.firstIndex(where: { $0.id == selected }) {
            languageSegment.selectedSegmentIndex = idx
        } else {
            languageSegment.selectedSegmentIndex = 0
            selectedLanguageId = languages.first?.id
        }
        languageSegment.addTarget(
            self, action: #selector(languageChanged), for: .valueChanged
        )
    }

    // MARK: - Actions

    @objc private func languageChanged() {
        let idx = languageSegment.selectedSegmentIndex
        guard idx >= 0 && idx < languages.count else { return }
        selectedLanguageId = languages[idx].id
    }

    @objc private func pickCategory() {
        let sheet = UIAlertController(
            title: "Category",
            message: "Pick a category so filters can find it.",
            preferredStyle: .actionSheet
        )
        for option in categoryOptions {
            sheet.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                self?.selectedCategory = option
                self?.categoryButton.setTitle("Category: \(option)", for: .normal)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // iPad popover anchor
        sheet.popoverPresentationController?.sourceView = categoryButton
        sheet.popoverPresentationController?.sourceRect = categoryButton.bounds
        present(sheet, animated: true)
    }

    @objc private func textChanged() {
        refreshSaveEnabled()
    }

    private func refreshSaveEnabled() {
        let text = (nativeField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        saveButton.isEnabled = !text.isEmpty
        saveButton.alpha = saveButton.isEnabled ? 1.0 : 0.55
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveWord() {
        let native = (nativeField.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !native.isEmpty, let langId = selectedLanguageId else { return }

        let ipa = (ipaField.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (keyField.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var word = WordEntry(id: 0, globalId: UUID(), languageId: langId)
        word.nativeScript = native
        word.ipaPhoneme = ipa
        word.phoneticKey = key.isEmpty ? nil : key
        word.categoryCode = selectedCategory == "Uncategorized" ? nil : selectedCategory
        word.source = .user
        word.status = .active
        word.syncStatus = .local
        word.createdAt = Date()
        word.updatedAt = Date()

        saveButton.isEnabled = false
        Task { @MainActor in
            do {
                _ = try await ServiceLocator.shared.wordService.saveWord(word)
                self.lcHapticSuccess()
                self.onSaved()
                self.dismiss(animated: true)
            } catch {
                self.presentError(error)
                self.saveButton.isEnabled = true
            }
        }
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(
            title: "Couldn't save word",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - LCFormField — a labelled text field card

final class LCFormField: UIView {

    let titleLabel = UILabel()
    let textField = UITextField()
    private let background = UIView()

    init(title: String, placeholder: String) {
        super.init(frame: .zero)
        titleLabel.text = title.uppercased()
        textField.placeholder = placeholder
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        background.backgroundColor = .lcCard
        background.layer.cornerRadius = 14
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.textColor = .label
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(textField)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),

            background.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.heightAnchor.constraint(equalToConstant: 52),

            textField.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -14),
            textField.topAnchor.constraint(equalTo: background.topAnchor),
            textField.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
    }
}
