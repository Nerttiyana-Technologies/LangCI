// CustomPromptsViewController.swift
// LangCI — Browse Tamil word categories & add custom prompts
//
// Your wife (or audiologist, family) can:
//   1. Browse pre-built Tamil word categories (greetings, family, food, etc.)
//   2. Tap words to add them as recording prompts
//   3. Type any custom Tamil text via free-text entry
//
// Added prompts flow into RecordVoiceViewController for recording
// and into training sessions as custom word items.

import UIKit

final class CustomPromptsViewController: UIViewController {

    // MARK: - Configuration

    /// Person who is adding prompts (e.g. wife)
    var person: RecordedPerson?

    /// Callback when prompts are added — returns the new prompts
    var onPromptsAdded: (([CustomVoicePrompt]) -> Void)?

    // MARK: - State

    private let service = ServiceLocator.shared.voiceRecordingService!
    private var existingPrompts: [CustomVoicePrompt] = []
    private var selectedWords: [(TamilWord, String)] = []  // (word, categoryId)

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var categoryStacks: [String: UIStackView] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Tamil Words"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        let doneBtn = UIBarButtonItem(
            title: "Done (\(selectedWords.count))",
            style: .done, target: self, action: #selector(doneTapped))
        doneBtn.tintColor = .lcGreen
        navigationItem.rightBarButtonItem = doneBtn

        buildUI()
        loadExisting()
    }

    // MARK: - Data

    private func loadExisting() {
        Task {
            existingPrompts = (try? await service.getAllCustomPrompts()) ?? []
            await MainActor.run { rebuildContent() }
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 12, leading: 16, bottom: 40, trailing: 16)
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
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryStacks.removeAll()

        // Tip
        let tip = UILabel()
        tip.text = "Pick Tamil words or type your own. Selected words will be added as recording prompts for voice training."
        tip.font = .systemFont(ofSize: 13, weight: .medium)
        tip.textColor = .secondaryLabel
        tip.numberOfLines = 0
        contentStack.addArrangedSubview(tip)

        // Free text entry card
        contentStack.addArrangedSubview(buildFreeTextCard())

        // Category sections
        for category in TamilWordCategory.allCategories {
            contentStack.addArrangedSubview(buildCategorySection(category))
        }

        // Existing custom prompts
        let customPrompts = existingPrompts.filter { !$0.isBuiltIn }
        if !customPrompts.isEmpty {
            contentStack.addArrangedSubview(buildSectionLabel("YOUR CUSTOM WORDS"))
            for prompt in customPrompts {
                contentStack.addArrangedSubview(buildExistingPromptRow(prompt))
            }
        }
    }

    // MARK: - Free Text Entry

    private func buildFreeTextCard() -> UIView {
        let card = LCCard()

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcAmber.withAlphaComponent(0.12).cgColor,
                           UIColor.lcOrange.withAlphaComponent(0.06).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        let icon = UIImageView(image: UIImage(systemName: "character.textbox"))
        icon.tintColor = .lcAmber
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let title = UILabel()
        title.text = "Type Custom Text"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = .label

        headerRow.addArrangedSubview(icon)
        headerRow.addArrangedSubview(title)

        let subtitle = UILabel()
        subtitle.text = "Type any Tamil word, phrase, or sentence you want to record"
        subtitle.font = .systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2

        let addBtn = LCButton(title: "+ Add Custom Word", color: .lcAmber)
        addBtn.addTarget(self, action: #selector(addCustomTapped), for: .touchUpInside)

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(addBtn)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        DispatchQueue.main.async { gradient.frame = card.bounds }

        return card
    }

    @objc private func addCustomTapped() {
        let alert = UIAlertController(
            title: "Add Custom Word",
            message: "Type the Tamil text you want to record",
            preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "Tamil text (e.g. வணக்கம்)"
            tf.font = .systemFont(ofSize: 16)
        }
        alert.addTextField { tf in
            tf.placeholder = "Romanised (e.g. Vanakkam)"
            tf.font = .systemFont(ofSize: 14)
        }
        alert.addTextField { tf in
            tf.placeholder = "English meaning (e.g. Hello)"
            tf.font = .systemFont(ofSize: 14)
        }

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let tamil = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let roman = alert.textFields?[1].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let meaning = alert.textFields?[2].text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !tamil.isEmpty else { return }

            let prompt = CustomVoicePrompt(
                id: 0, text: tamil,
                transliteration: roman.isEmpty ? tamil : roman,
                meaning: meaning,
                category: "custom",
                createdBy: self.person?.id,
                isBuiltIn: false,
                createdAt: Date())

            Task {
                if let saved = try? await self.service.addCustomPrompt(prompt) {
                    await MainActor.run {
                        self.existingPrompts.append(saved)
                        self.rebuildContent()
                        lcHapticSuccess()
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Category Section

    private func buildCategorySection(_ category: TamilWordCategory) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        // Header
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        let color = colorForKey(category.color)
        let iconView = UIImageView(image: UIImage(systemName: category.icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = "\(category.title)  \(category.tamilTitle)"
        titleLbl.font = .systemFont(ofSize: 14, weight: .bold)
        titleLbl.textColor = .label

        let countLbl = UILabel()
        countLbl.text = "\(category.words.count)"
        countLbl.font = .systemFont(ofSize: 12, weight: .medium)
        countLbl.textColor = .secondaryLabel

        headerRow.addArrangedSubview(iconView)
        headerRow.addArrangedSubview(titleLbl)
        headerRow.addArrangedSubview(UIView()) // spacer
        headerRow.addArrangedSubview(countLbl)
        container.addArrangedSubview(headerRow)

        // Word chips — flow layout using rows of horizontal stacks
        let wordGrid = buildWordGrid(category.words, categoryId: category.id, color: color)
        categoryStacks[category.id] = wordGrid
        container.addArrangedSubview(wordGrid)

        return container
    }

    private func buildWordGrid(_ words: [TamilWord], categoryId: String, color: UIColor) -> UIStackView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6

        var currentRow = UIStackView()
        currentRow.axis = .horizontal
        currentRow.spacing = 6
        currentRow.distribution = .fill

        // Simple approach: 2 words per row for readability
        for (i, word) in words.enumerated() {
            let chip = buildWordChip(word, categoryId: categoryId, color: color)
            currentRow.addArrangedSubview(chip)

            if (i + 1) % 2 == 0 || i == words.count - 1 {
                // Pad odd rows with spacer
                if (i + 1) % 2 != 0 {
                    let spacer = UIView()
                    currentRow.addArrangedSubview(spacer)
                }
                grid.addArrangedSubview(currentRow)
                currentRow = UIStackView()
                currentRow.axis = .horizontal
                currentRow.spacing = 6
                currentRow.distribution = .fillEqually
            }
        }

        return grid
    }

    private func buildWordChip(_ word: TamilWord, categoryId: String, color: UIColor) -> UIView {
        let isAlreadyAdded = existingPrompts.contains { $0.text == word.tamil && $0.isBuiltIn }
        let isSelected = selectedWords.contains { $0.0.id == word.id }

        let card = UIView()
        card.layer.cornerRadius = 10
        card.layer.borderWidth = isSelected ? 2 : 0.5
        card.layer.borderColor = isSelected ? color.cgColor : UIColor.separator.cgColor

        if isAlreadyAdded {
            card.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.08)
        } else if isSelected {
            card.backgroundColor = color.withAlphaComponent(0.1)
        } else {
            card.backgroundColor = .lcCard
        }

        card.isUserInteractionEnabled = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        card.addSubview(stack)

        let tamilLbl = UILabel()
        tamilLbl.text = word.tamil
        tamilLbl.font = .systemFont(ofSize: 16, weight: .bold)
        tamilLbl.textColor = .label

        let romanLbl = UILabel()
        romanLbl.text = word.transliteration
        romanLbl.font = .systemFont(ofSize: 11, weight: .medium)
        romanLbl.textColor = .secondaryLabel

        let meaningLbl = UILabel()
        meaningLbl.text = word.meaning
        meaningLbl.font = .systemFont(ofSize: 10, weight: .regular)
        meaningLbl.textColor = .tertiaryLabel

        stack.addArrangedSubview(tamilLbl)
        stack.addArrangedSubview(romanLbl)
        stack.addArrangedSubview(meaningLbl)

        if isAlreadyAdded {
            let check = UILabel()
            check.text = "\u{2705} Added"
            check.font = .systemFont(ofSize: 10, weight: .bold)
            check.textColor = .lcGreen
            stack.addArrangedSubview(check)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
        ])

        if !isAlreadyAdded {
            let tap = WordTapGesture(target: self, action: #selector(wordTapped(_:)))
            tap.word = word
            tap.categoryId = categoryId
            card.addGestureRecognizer(tap)
        }

        return card
    }

    @objc private func wordTapped(_ gesture: WordTapGesture) {
        guard let word = gesture.word, let catId = gesture.categoryId else { return }

        if let idx = selectedWords.firstIndex(where: { $0.0.id == word.id }) {
            selectedWords.remove(at: idx)
        } else {
            selectedWords.append((word, catId))
        }

        updateDoneButton()
        rebuildContent()
        lcHaptic(.light)
    }

    // MARK: - Existing Prompt Row

    private func buildExistingPromptRow(_ prompt: CustomVoicePrompt) -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let tamilLbl = UILabel()
        tamilLbl.text = prompt.text
        tamilLbl.font = .systemFont(ofSize: 15, weight: .bold)
        tamilLbl.textColor = .label

        let detailLbl = UILabel()
        detailLbl.text = "\(prompt.transliteration) — \(prompt.meaning)"
        detailLbl.font = .systemFont(ofSize: 12, weight: .medium)
        detailLbl.textColor = .secondaryLabel

        textStack.addArrangedSubview(tamilLbl)
        textStack.addArrangedSubview(detailLbl)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setImage(UIImage(systemName: "trash.circle.fill"), for: .normal)
        deleteBtn.tintColor = .lcRed
        deleteBtn.tag = prompt.id
        deleteBtn.addTarget(self, action: #selector(deletePromptTapped(_:)), for: .touchUpInside)
        deleteBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true

        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(deleteBtn)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        return card
    }

    @objc private func deletePromptTapped(_ sender: UIButton) {
        let promptId = sender.tag
        let alert = UIAlertController(title: "Delete Word?",
            message: "This will remove the word from your custom list.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                try? await self.service.deleteCustomPrompt(id: promptId)
                self.existingPrompts.removeAll { $0.id == promptId }
                await MainActor.run { self.rebuildContent() }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Done

    private func updateDoneButton() {
        let count = selectedWords.count
        navigationItem.rightBarButtonItem?.title = count > 0 ? "Done (\(count))" : "Done"
    }

    @objc private func doneTapped() {
        guard !selectedWords.isEmpty else {
            navigationController?.popViewController(animated: true)
            return
        }

        // Save selected words as custom prompts
        Task {
            var saved: [CustomVoicePrompt] = []
            for (word, catId) in selectedWords {
                let prompt = CustomVoicePrompt(
                    id: 0, text: word.tamil,
                    transliteration: word.transliteration,
                    meaning: word.meaning,
                    category: catId,
                    createdBy: person?.id,
                    isBuiltIn: true,
                    createdAt: Date())
                if let s = try? await service.addCustomPrompt(prompt) {
                    saved.append(s)
                }
            }
            await MainActor.run {
                onPromptsAdded?(saved)
                lcHapticSuccess()
                navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - Helpers

    private func buildSectionLabel(_ text: String) -> UIView {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .tertiaryLabel
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: 1.2, range: NSRange(location: 0, length: text.count))
        lbl.attributedText = attr
        return lbl
    }

    private func colorForKey(_ key: String) -> UIColor {
        switch key {
        case "lcBlue":   return .lcBlue
        case "lcPurple": return .lcPurple
        case "lcTeal":   return .lcTeal
        case "lcGreen":  return .lcGreen
        case "lcAmber":  return .lcAmber
        case "lcOrange": return .lcOrange
        case "lcRed":    return .lcRed
        case "lcGold":   return .lcGold
        default:         return .lcTeal
        }
    }
}

// MARK: - Gesture subclass

private class WordTapGesture: UITapGestureRecognizer {
    var word: TamilWord?
    var categoryId: String?
}
