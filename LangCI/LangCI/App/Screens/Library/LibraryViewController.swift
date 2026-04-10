// LibraryViewController.swift
// LangCI — browse, filter & search the word library.
//
// Redesigned with a clean iOS-native look:
//   • Large title navigation
//   • UISearchController integrated into the nav bar
//   • Horizontal LCPillButton language filter
//   • Grouped word table with category section headers
//   • WordLibraryCell with colored category pill + IPA
//   • Loading & empty states
//
// The companion WordDetailViewController is declared at the bottom.

import UIKit

// MARK: - LibraryViewController

final class LibraryViewController: UIViewController {

    // MARK: Services
    private var wordService: WordService { ServiceLocator.shared.wordService }
    private var languageService: LanguageService { ServiceLocator.shared.languageService }

    // MARK: UI
    private let searchController = UISearchController(searchResultsController: nil)

    private let filterBar = UIView()
    private let filterScroll = UIScrollView()
    private let filterStack = UIStackView()
    private let filterDivider = UIView()

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let loadingView = LCLoadingView(message: "Loading words…")

    private let emptyView = EmptyStateView(
        icon: "books.vertical",
        title: "No words yet",
        message: "Words will appear here once your active language has entries. Try switching language or check your publisher pack.",
        tint: .lcOrange
    )

    // MARK: State
    private var activeLanguages: [Language] = []
    private var allWords: [WordEntry] = []
    private var filteredWords: [WordEntry] = []
    private var groupedWords: [String: [WordEntry]] = [:]
    private var sections: [String] = []

    private var selectedLanguageId: Int?
    private var selectedDialectId: Int?
    private var searchText: String = ""
    private var searchDebounceTimer: Timer?

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground

        setupNavigationBar()
        setupFilterBar()
        setupTableView()
        setupOverlays()
        setupLayout()

        loadLanguages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        if selectedLanguageId != nil || !activeLanguages.isEmpty {
            loadWords()
        }
    }

    // MARK: Setup
    private func setupNavigationBar() {
        title = "Library"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        searchController.searchBar.placeholder = "Search words"
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.tintColor = .lcOrange
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        // + button to add a new word to the user's personal library.
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(addWordTapped)
        )
        addButton.tintColor = .lcOrange
        navigationItem.rightBarButtonItem = addButton
    }

    // MARK: Add word
    @objc private func addWordTapped() {
        lcHaptic(.light)
        let editor = AddWordViewController(
            languages: activeLanguages,
            defaultLanguageId: selectedLanguageId
        ) { [weak self] in
            // Reload so the new word shows up immediately.
            self?.loadWords()
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    private func setupFilterBar() {
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterBar.backgroundColor = .lcBackground

        filterScroll.showsHorizontalScrollIndicator = false
        filterScroll.translatesAutoresizingMaskIntoConstraints = false

        filterStack.axis = .horizontal
        filterStack.spacing = 8
        filterStack.alignment = .center
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterStack.isLayoutMarginsRelativeArrangement = true
        filterStack.directionalLayoutMargins = .init(top: 0, leading: LC.cardPadding,
                                                     bottom: 0, trailing: LC.cardPadding)

        filterScroll.addSubview(filterStack)
        filterBar.addSubview(filterScroll)

        filterDivider.backgroundColor = .separator
        filterDivider.translatesAutoresizingMaskIntoConstraints = false
        filterBar.addSubview(filterDivider)

        view.addSubview(filterBar)

        NSLayoutConstraint.activate([
            filterScroll.topAnchor.constraint(equalTo: filterBar.topAnchor),
            filterScroll.leadingAnchor.constraint(equalTo: filterBar.leadingAnchor),
            filterScroll.trailingAnchor.constraint(equalTo: filterBar.trailingAnchor),
            filterScroll.heightAnchor.constraint(equalToConstant: 48),

            filterStack.topAnchor.constraint(equalTo: filterScroll.topAnchor),
            filterStack.bottomAnchor.constraint(equalTo: filterScroll.bottomAnchor),
            filterStack.leadingAnchor.constraint(equalTo: filterScroll.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: filterScroll.trailingAnchor),
            filterStack.heightAnchor.constraint(equalTo: filterScroll.heightAnchor),

            filterDivider.leadingAnchor.constraint(equalTo: filterBar.leadingAnchor),
            filterDivider.trailingAnchor.constraint(equalTo: filterBar.trailingAnchor),
            filterDivider.bottomAnchor.constraint(equalTo: filterBar.bottomAnchor),
            filterDivider.heightAnchor.constraint(equalToConstant: 0.5),

            filterBar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(WordLibraryCell.self, forCellReuseIdentifier: WordLibraryCell.identifier)
        tableView.backgroundColor = .lcBackground
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 24, right: 0)
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)
    }

    private func setupOverlays() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        view.addSubview(loadingView)

        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: tableView.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),

            emptyView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 12),
            emptyView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor)
        ])
    }

    // MARK: Data Loading
    private func loadLanguages() {
        showLoading(true)
        Task { @MainActor in
            do {
                let langs = try await languageService.getActiveLanguages()
                self.activeLanguages = langs
                if self.selectedLanguageId == nil {
                    self.selectedLanguageId = langs.first?.id
                }
                self.rebuildFilterPills()
                await self.loadWordsAsync()
            } catch {
                self.showLoading(false)
                self.showError("Failed to load languages: \(error.localizedDescription)")
            }
        }
    }

    private func loadWords() {
        Task { @MainActor in await loadWordsAsync() }
    }

    @MainActor
    private func loadWordsAsync() async {
        guard let languageId = selectedLanguageId else {
            self.allWords = []
            self.filterAndGroupWords()
            self.showLoading(false)
            self.updateEmptyState()
            return
        }

        showLoading(true)
        do {
            let words = try await wordService.getWords(
                languageId: languageId,
                dialectId: selectedDialectId
            )
            self.allWords = words
            self.filterAndGroupWords()
            self.showLoading(false)
            self.updateEmptyState()
        } catch {
            self.showLoading(false)
            self.showError("Failed to load words: \(error.localizedDescription)")
        }
    }

    private func searchWords(query: String) {
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            guard let self = self, let languageId = self.selectedLanguageId else { return }
            Task { @MainActor in
                do {
                    let results = try await self.wordService.searchWords(query: query, languageId: languageId)
                    self.filteredWords = results
                    self.tableView.reloadData()
                    self.updateEmptyState()
                } catch {
                    self.showError("Search failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func filterAndGroupWords() {
        if searchText.isEmpty {
            filteredWords = allWords
            groupedWords = Dictionary(grouping: allWords) { word in
                word.categoryCode?.isEmpty == false ? word.categoryCode! : "Uncategorized"
            }
            sections = groupedWords.keys.sorted()
        } else {
            groupedWords = [:]
            sections = []
        }
        tableView.reloadData()
    }

    // MARK: Filter Pills
    private func rebuildFilterPills() {
        filterStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for language in activeLanguages {
            let pill = LCPillButton(title: language.name, tint: .lcOrange)
            pill.isSelectedPill = (selectedLanguageId == language.id)
            pill.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.lcHaptic(.light)
                self.selectedLanguageId = language.id
                self.selectedDialectId = nil
                self.rebuildFilterPills()
                self.loadWords()
            }, for: .touchUpInside)
            filterStack.addArrangedSubview(pill)
        }
    }

    // MARK: Loading / Empty state
    private func showLoading(_ show: Bool) {
        loadingView.isHidden = !show
        if show {
            loadingView.start()
            emptyView.isHidden = true
        } else {
            loadingView.stop()
        }
    }

    private func updateEmptyState() {
        let noResults: Bool
        if searchText.isEmpty {
            noResults = allWords.isEmpty
        } else {
            noResults = filteredWords.isEmpty
        }
        emptyView.isHidden = !noResults
        tableView.isHidden = noResults
    }

    // MARK: Error
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension LibraryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return searchText.isEmpty ? sections.count : (filteredWords.isEmpty ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchText.isEmpty {
            let key = sections[section]
            return groupedWords[key]?.count ?? 0
        } else {
            return filteredWords.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: WordLibraryCell.identifier, for: indexPath)

        let word: WordEntry
        if searchText.isEmpty {
            let key = sections[indexPath.section]
            word = groupedWords[key]?[indexPath.row] ?? WordEntry(id: 0, globalId: UUID(), languageId: 0)
        } else {
            word = filteredWords[indexPath.row]
        }

        if let wordCell = cell as? WordLibraryCell {
            wordCell.configure(with: word)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard searchText.isEmpty, section < sections.count else { return nil }
        let key = sections[section]
        let count = groupedWords[key]?.count ?? 0
        return "\(key.uppercased())   •   \(count)"
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.tableView(tableView, titleForHeaderInSection: section) else { return nil }
        let container = UIView()
        container.backgroundColor = .lcBackground

        let label = UILabel()
        label.text = title
        label.font = UIFont.lcSectionTitle()
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: LC.cardPadding),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -LC.cardPadding),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 42
    }
}

// MARK: - UITableViewDelegate
extension LibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        lcHaptic(.light)

        let word: WordEntry
        if searchText.isEmpty {
            let key = sections[indexPath.section]
            guard let list = groupedWords[key], indexPath.row < list.count else { return }
            word = list[indexPath.row]
        } else {
            guard indexPath.row < filteredWords.count else { return }
            word = filteredWords[indexPath.row]
        }

        let detailVC = WordDetailViewController(wordEntry: word)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension LibraryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        self.searchText = text
        if text.isEmpty {
            filterAndGroupWords()
            updateEmptyState()
        } else {
            searchWords(query: text)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchText = ""
        filterAndGroupWords()
        updateEmptyState()
    }
}

// MARK: - WordLibraryCell

final class WordLibraryCell: UITableViewCell {
    static let identifier = "WordLibraryCell"

    private let cardView = UIView()
    private let nativeScriptLabel = UILabel()
    private let ipaLabel = UILabel()
    private let translationLabel = UILabel()
    private let categoryPill = PaddedLabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = .lcCard
        cardView.layer.cornerRadius = 14
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        nativeScriptLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nativeScriptLabel.textColor = .label
        nativeScriptLabel.numberOfLines = 1

        ipaLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ipaLabel.textColor = .secondaryLabel
        ipaLabel.numberOfLines = 1

        translationLabel.font = UIFont.lcCaption()
        translationLabel.textColor = .tertiaryLabel
        translationLabel.numberOfLines = 1

        categoryPill.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        categoryPill.textColor = .lcOrange
        categoryPill.backgroundColor = UIColor.lcOrange.withAlphaComponent(0.12)
        categoryPill.layer.cornerRadius = 7
        categoryPill.clipsToBounds = true
        categoryPill.textAlignment = .center
        categoryPill.textInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        categoryPill.setContentHuggingPriority(.required, for: .horizontal)

        chevronView.tintColor = .tertiaryLabel
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nativeScriptLabel, ipaLabel, translationLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(textStack)
        cardView.addSubview(categoryPill)
        cardView.addSubview(chevronView)

        categoryPill.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LC.cardPadding),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LC.cardPadding),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            textStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: categoryPill.leadingAnchor, constant: -10),

            categoryPill.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -10),
            categoryPill.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            categoryPill.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),

            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
            chevronView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) {
            self.cardView.backgroundColor = highlighted
                ? UIColor.lcCard.withAlphaComponent(0.6)
                : .lcCard
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.985, y: 0.985)
                : .identity
        }
    }

    func configure(with word: WordEntry) {
        nativeScriptLabel.text = word.nativeScript.isEmpty ? "—" : word.nativeScript
        ipaLabel.text = word.ipaPhoneme.isEmpty ? nil : "/\(word.ipaPhoneme)/"
        ipaLabel.isHidden = word.ipaPhoneme.isEmpty

        if let translation = word.phoneticKey, !translation.isEmpty {
            translationLabel.text = translation
            translationLabel.isHidden = false
        } else {
            translationLabel.isHidden = true
        }

        if let code = word.categoryCode, !code.isEmpty {
            categoryPill.text = code.uppercased()
            categoryPill.isHidden = false
        } else {
            categoryPill.isHidden = true
        }
    }
}

// MARK: - PaddedLabel (category pill helper)

final class PaddedLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}

// MARK: - WordDetailViewController

final class WordDetailViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Hero card
    private let heroCard = LCCard()
    private let nativeScriptLabel = UILabel()
    private let ipaLabel = UILabel()
    private let translationLabel = UILabel()
    private let playButton = LCIconButton(systemIcon: "speaker.wave.2.fill", tint: .lcOrange, size: 56)

    // Details card
    private let detailsCard = LCCard()

    // Recordings card
    private let recordingsCard = LCCard()
    private let recordingsTitleLabel = UILabel()
    private let recordingsContainerStack = UIStackView()
    private let recordingsEmptyLabel = UILabel()

    // Actions
    private let requestRecordingButton = LCButton(title: "Request Recording", color: .lcOrange)

    // State
    private let wordEntry: WordEntry
    private var recordings: [Recording] = []
    private var recordingService: RecordingService { ServiceLocator.shared.recordingService }

    // MARK: Init
    init(wordEntry: WordEntry) {
        self.wordEntry = wordEntry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lcBackground
        title = "Word"
        navigationItem.largeTitleDisplayMode = .never

        setupScrollView()
        setupHeroCard()
        setupDetailsCard()
        setupRecordingsCard()
        setupActions()

        loadRecordings()
    }

    // MARK: Setup
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = LC.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 16, leading: LC.cardPadding,
                                                      bottom: 24, trailing: LC.cardPadding)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeroCard() {
        let inner = UIStackView()
        inner.axis = .vertical
        inner.alignment = .center
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false

        nativeScriptLabel.text = wordEntry.nativeScript
        nativeScriptLabel.font = UIFont.systemFont(ofSize: 44, weight: .bold)
        nativeScriptLabel.textColor = .label
        nativeScriptLabel.textAlignment = .center
        nativeScriptLabel.numberOfLines = 2
        nativeScriptLabel.adjustsFontSizeToFitWidth = true
        nativeScriptLabel.minimumScaleFactor = 0.5

        ipaLabel.text = wordEntry.ipaPhoneme.isEmpty ? nil : "/\(wordEntry.ipaPhoneme)/"
        ipaLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        ipaLabel.textColor = .secondaryLabel
        ipaLabel.textAlignment = .center
        ipaLabel.isHidden = wordEntry.ipaPhoneme.isEmpty

        translationLabel.text = wordEntry.phoneticKey
        translationLabel.font = UIFont.lcBody()
        translationLabel.textColor = .tertiaryLabel
        translationLabel.textAlignment = .center
        translationLabel.numberOfLines = 0
        translationLabel.isHidden = (wordEntry.phoneticKey ?? "").isEmpty

        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

        inner.addArrangedSubview(nativeScriptLabel)
        inner.addArrangedSubview(ipaLabel)
        if !translationLabel.isHidden {
            inner.setCustomSpacing(6, after: ipaLabel)
            inner.addArrangedSubview(translationLabel)
        }
        inner.setCustomSpacing(20, after: inner.arrangedSubviews.last!)
        inner.addArrangedSubview(playButton)

        heroCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 28),
            inner.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),
            inner.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -28)
        ])

        contentStack.addArrangedSubview(heroCard)
    }

    private func setupDetailsCard() {
        let category = wordEntry.categoryCode?.isEmpty == false ? wordEntry.categoryCode! : "Uncategorized"
        let sourceText: String
        switch wordEntry.source {
        case .publisher: sourceText = "Publisher pack"
        case .user: sourceText = "User added"
        }
        let statusText: String
        switch wordEntry.status {
        case .draft: statusText = "Draft"
        case .active: statusText = "Active"
        case .archived: statusText = "Archived"
        }

        let categoryRow = LCListRow(icon: "tag.fill", title: "Category", subtitle: category, tint: .lcOrange)
        let sourceRow = LCListRow(icon: "tray.fill", title: "Source", subtitle: sourceText, tint: .lcBlue)
        let statusRow = LCListRow(icon: "checkmark.seal.fill", title: "Status", subtitle: statusText, tint: .lcGreen)

        let inner = UIStackView(arrangedSubviews: [categoryRow, LCDivider(), sourceRow, LCDivider(), statusRow])
        inner.axis = .vertical
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false

        // Disable taps — these rows are purely informational
        categoryRow.isUserInteractionEnabled = false
        sourceRow.isUserInteractionEnabled = false
        statusRow.isUserInteractionEnabled = false

        detailsCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: detailsCard.topAnchor, constant: 4),
            inner.leadingAnchor.constraint(equalTo: detailsCard.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: detailsCard.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: detailsCard.bottomAnchor, constant: -4)
        ])

        let sectionHeader = SectionHeaderView(title: "Details")
        contentStack.addArrangedSubview(sectionHeader)
        contentStack.setCustomSpacing(8, after: sectionHeader)
        contentStack.addArrangedSubview(detailsCard)
    }

    private func setupRecordingsCard() {
        recordingsTitleLabel.font = UIFont.lcBodyBold()
        recordingsTitleLabel.textColor = .label
        recordingsTitleLabel.text = "Family Recordings"
        recordingsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        recordingsContainerStack.axis = .vertical
        recordingsContainerStack.spacing = 0
        recordingsContainerStack.translatesAutoresizingMaskIntoConstraints = false

        recordingsEmptyLabel.text = "No recordings yet. Record this word or request one from a family member."
        recordingsEmptyLabel.font = UIFont.lcCaption()
        recordingsEmptyLabel.textColor = .secondaryLabel
        recordingsEmptyLabel.numberOfLines = 0
        recordingsEmptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView(arrangedSubviews: [recordingsTitleLabel, recordingsContainerStack, recordingsEmptyLabel])
        inner.axis = .vertical
        inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false

        recordingsCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: recordingsCard.topAnchor, constant: LC.cardPadding),
            inner.leadingAnchor.constraint(equalTo: recordingsCard.leadingAnchor, constant: LC.cardPadding),
            inner.trailingAnchor.constraint(equalTo: recordingsCard.trailingAnchor, constant: -LC.cardPadding),
            inner.bottomAnchor.constraint(equalTo: recordingsCard.bottomAnchor, constant: -LC.cardPadding)
        ])

        let sectionHeader = SectionHeaderView(title: "Recordings")
        contentStack.addArrangedSubview(sectionHeader)
        contentStack.setCustomSpacing(8, after: sectionHeader)
        contentStack.addArrangedSubview(recordingsCard)
    }

    private func setupActions() {
        requestRecordingButton.addTarget(self, action: #selector(requestRecordingTapped), for: .touchUpInside)
        requestRecordingButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        contentStack.addArrangedSubview(requestRecordingButton)
    }

    // MARK: Data
    private func loadRecordings() {
        Task { @MainActor in
            do {
                let recs = try await recordingService.getRecordings(for: wordEntry.id)
                self.recordings = recs
                self.rebuildRecordingsList()
            } catch {
                self.showError("Failed to load recordings: \(error.localizedDescription)")
            }
        }
    }

    private func rebuildRecordingsList() {
        recordingsContainerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if recordings.isEmpty {
            recordingsEmptyLabel.isHidden = false
            recordingsContainerStack.isHidden = true
            return
        }
        recordingsEmptyLabel.isHidden = true
        recordingsContainerStack.isHidden = false

        for (idx, rec) in recordings.enumerated() {
            let row = WordRecordingRow(recording: rec,
                                       onPlay: { [weak self] in self?.playRecording(rec) },
                                       onDelete: { [weak self] in self?.confirmDeleteRecording(rec) })
            recordingsContainerStack.addArrangedSubview(row)
            if idx < recordings.count - 1 {
                let div = LCDivider(leftInset: 0)
                recordingsContainerStack.addArrangedSubview(div)
            }
        }
    }

    // MARK: Actions
    @objc private func playTapped() {
        lcHaptic(.light)
        // Play most recent recording if any, else show hint
        if let first = recordings.first {
            playRecording(first)
        } else {
            lcShowToast("No audio yet — record this word to hear it",
                        icon: "info.circle.fill",
                        tint: .lcBlue)
        }
    }

    private func playRecording(_ recording: Recording) {
        Task { @MainActor in
            do {
                try await recordingService.playRecording(path: recording.filePath)
            } catch {
                self.showError("Couldn't play this recording.")
            }
        }
    }

    private func confirmDeleteRecording(_ recording: Recording) {
        let alert = UIAlertController(title: "Delete Recording?",
                                      message: "This will permanently remove this audio clip.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteRecording(recording)
        })
        present(alert, animated: true)
    }

    private func deleteRecording(_ recording: Recording) {
        Task { @MainActor in
            do {
                try await recordingService.deleteRecording(id: recording.id)
                self.recordings.removeAll { $0.id == recording.id }
                self.rebuildRecordingsList()
                self.lcHapticSuccess()
                self.lcShowToast("Recording deleted",
                                 icon: "trash.fill",
                                 tint: .lcRed)
            } catch {
                self.showError("Couldn't delete this recording.")
            }
        }
    }

    @objc private func requestRecordingTapped() {
        lcHaptic(.light)
        let alert = UIAlertController(
            title: "Request Recording",
            message: "Send a request to family members asking them to record “\(wordEntry.nativeScript)”?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            self?.lcHapticSuccess()
            self?.lcShowToast("Request sent")
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WordRecordingRow

private final class WordRecordingRow: UIView {

    private let memberBadge = UIView()
    private let memberInitial = UILabel()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let playButton = LCIconButton(systemIcon: "play.fill", tint: .lcGreen, size: 38)
    private let deleteButton = LCIconButton(systemIcon: "trash.fill", tint: .lcRed, size: 38)

    private let onPlay: () -> Void
    private let onDelete: () -> Void

    init(recording: Recording, onPlay: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.onPlay = onPlay
        self.onDelete = onDelete
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // Member badge
        let memberName = recording.familyMember?.name ?? "Family Member"
        let initial = memberName.isEmpty ? "?" : String(memberName.prefix(1)).uppercased()
        let tint = UIColor.lcBlue
        memberBadge.backgroundColor = tint.withAlphaComponent(0.14)
        memberBadge.layer.cornerRadius = 19
        memberBadge.translatesAutoresizingMaskIntoConstraints = false

        memberInitial.text = initial
        memberInitial.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        memberInitial.textColor = tint
        memberInitial.textAlignment = .center
        memberInitial.translatesAutoresizingMaskIntoConstraints = false
        memberBadge.addSubview(memberInitial)

        // Labels
        nameLabel.text = memberName
        nameLabel.font = UIFont.lcBodyBold()
        nameLabel.textColor = .label

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .short
        dateFmt.timeStyle = .short
        let duration = recording.durationSeconds
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        metaLabel.text = "\(dateFmt.string(from: recording.recordedAt))  •  \(String(format: "%d:%02d", minutes, seconds))"
        metaLabel.font = UIFont.lcCaption()
        metaLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        playButton.addAction(UIAction { [weak self] _ in self?.onPlay() }, for: .touchUpInside)
        deleteButton.addAction(UIAction { [weak self] _ in self?.onDelete() }, for: .touchUpInside)

        addSubview(memberBadge)
        addSubview(textStack)
        addSubview(playButton)
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 62),

            memberBadge.leadingAnchor.constraint(equalTo: leadingAnchor),
            memberBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            memberBadge.widthAnchor.constraint(equalToConstant: 38),
            memberBadge.heightAnchor.constraint(equalToConstant: 38),
            memberBadge.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            memberBadge.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),

            memberInitial.centerXAnchor.constraint(equalTo: memberBadge.centerXAnchor),
            memberInitial.centerYAnchor.constraint(equalTo: memberBadge.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: memberBadge.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),

            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            playButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
