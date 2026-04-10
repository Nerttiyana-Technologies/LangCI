// AVTSoundWallViewController.swift
// LangCI
//
// Redesigned Sound Wall. Clean iOS-native look:
//   • Large title nav with + button
//   • UICollectionView compositional layout showing phoneme target cards
//   • Clean cards with IPA / sound / frequency / level pill
//   • Tap a card to start a drill
//   • Empty state when no targets yet

import UIKit

final class AVTSoundWallViewController: UIViewController {

    // MARK: - UI

    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()

    // MARK: - State

    private var targets: [AVTTarget] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadTargets()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Sound Wall"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .lcBackground

        let add = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(didTapAdd)
        )
        add.tintColor = .lcPurple
        navigationItem.rightBarButtonItem = add
    }

    private func buildUI() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .lcBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SoundWallCell.self, forCellWithReuseIdentifier: SoundWallCell.identifier)
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)

        emptyLabel.text = "No sounds yet.\nTap + to add your first target."
        emptyLabel.font = UIFont.lcBody()
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func makeLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .estimated(160)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(160)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 20, trailing: 10)
            return section
        }
    }

    // MARK: - Data

    private func loadTargets() {
        Task {
            do {
                let allTargets = try await ServiceLocator.shared.avtService.getAllTargets()
                await MainActor.run {
                    self.targets = allTargets
                    self.emptyLabel.isHidden = !allTargets.isEmpty
                    self.collectionView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.emptyLabel.isHidden = false
                    self.lcShowToast("Couldn't load targets", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }

    // MARK: - Add

    @objc private func didTapAdd() {
        lcHaptic(.light)
        let alert = UIAlertController(
            title: "Add Sound Target",
            message: "Enter the phoneme details.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Sound (e.g. 'sh', 'ush')" }
        alert.addTextField { $0.placeholder = "IPA (e.g. 'ʃ')" }
        alert.addTextField { $0.placeholder = "Frequency range (e.g. '2–8 kHz')" }
        alert.addTextField { $0.placeholder = "Description (optional)" }

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            guard let sound = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces), !sound.isEmpty,
                  let ipa = alert.textFields?[1].text?.trimmingCharacters(in: .whitespaces), !ipa.isEmpty else {
                self.lcShowToast("Missing required fields", icon: "exclamationmark.triangle.fill", tint: .lcAmber)
                return
            }
            let freq = alert.textFields?[2].text ?? ""
            let desc = alert.textFields?[3].text ?? ""
            self.saveNewTarget(sound: sound, ipa: ipa, freqRange: freq, description: desc)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func saveNewTarget(sound: String, ipa: String, freqRange: String, description: String) {
        Task {
            do {
                _ = try await ServiceLocator.shared.avtService.saveTarget(
                    AVTTarget(
                        id: 0,
                        sound: sound,
                        phonemeIpa: ipa,
                        frequencyRange: freqRange,
                        soundDescription: description,
                        currentLevel: .detection,
                        isActive: true,
                        assignedAt: Date(),
                        audiologistNote: nil
                    )
                )
                await MainActor.run {
                    self.loadTargets()
                    self.lcHapticSuccess()
                    self.lcShowToast("Target added", icon: "checkmark.circle.fill", tint: .lcGreen)
                }
            } catch {
                await MainActor.run {
                    self.lcShowToast("Save failed", icon: "xmark.octagon.fill", tint: .lcRed)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension AVTSoundWallViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return targets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SoundWallCell.identifier, for: indexPath) as! SoundWallCell
        cell.configure(with: targets[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        lcHaptic(.light)
        let target = targets[indexPath.item]
        let drillVC = AVTDrillViewController(
            sound: target.sound,
            level: target.currentLevel,
            targetId: target.id
        )
        navigationController?.pushViewController(drillVC, animated: true)
    }
}

// MARK: - SoundWallCell

final class SoundWallCell: UICollectionViewCell {
    static let identifier = "SoundWallCell"

    private let cardView = UIView()
    private let ipaLabel = UILabel()
    private let soundLabel = UILabel()
    private let freqLabel = UILabel()
    private let levelPill = PaddedPillLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .lcCard
        cardView.layer.cornerRadius = 14
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)

        ipaLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        ipaLabel.textColor = .label
        ipaLabel.textAlignment = .center
        ipaLabel.translatesAutoresizingMaskIntoConstraints = false

        soundLabel.font = UIFont.lcBodyBold()
        soundLabel.textColor = .label
        soundLabel.textAlignment = .center
        soundLabel.translatesAutoresizingMaskIntoConstraints = false

        freqLabel.font = UIFont.lcCaption()
        freqLabel.textColor = .secondaryLabel
        freqLabel.textAlignment = .center
        freqLabel.translatesAutoresizingMaskIntoConstraints = false

        levelPill.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        levelPill.textColor = .white
        levelPill.textAlignment = .center
        levelPill.layer.cornerRadius = 10
        levelPill.clipsToBounds = true
        levelPill.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        levelPill.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [ipaLabel, soundLabel, freqLabel, levelPill])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.cardView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func configure(with target: AVTTarget) {
        ipaLabel.text = "/\(target.phonemeIpa)/"
        soundLabel.text = target.sound.uppercased()
        freqLabel.text = target.frequencyRange.isEmpty ? "—" : target.frequencyRange
        levelPill.text = target.currentLevel.label
        levelPill.backgroundColor = target.currentLevel.color

        contentView.alpha = target.isActive ? 1.0 : 0.5

        // Top border accent in level color
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = target.currentLevel.color.withAlphaComponent(0.25).cgColor
    }
}

// MARK: - PaddedPillLabel

final class PaddedPillLabel: UILabel {
    var insets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
