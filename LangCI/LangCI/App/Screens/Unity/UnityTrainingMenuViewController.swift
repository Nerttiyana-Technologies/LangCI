// UnityTrainingMenuViewController.swift
// LangCI
//
// Menu screen listing available 3D/VR training modules.
// Each module launches a Unity scene via UnityViewController.

import UIKit

final class UnityTrainingMenuViewController: UIViewController {

    // MARK: - Data

    private struct TrainingModule {
        let title: String
        let subtitle: String
        let icon: String
        let tint: UIColor
        let sceneName: String
        let isAvailable: Bool
    }

    private let modules: [TrainingModule] = [
        TrainingModule(
            title: "Sound Localization",
            subtitle: "Identify which direction a sound is coming from in a 3D room",
            icon: "location.fill",
            tint: .lcPurple,
            sceneName: "SoundLocalization",
            isAvailable: true
        ),
        TrainingModule(
            title: "Lip Reading",
            subtitle: "Watch 3D face animations and match sounds to lip movements",
            icon: "mouth.fill",
            tint: .lcTeal,
            sceneName: "LipReading",
            isAvailable: false  // Coming soon
        ),
        TrainingModule(
            title: "Environmental Scenes",
            subtitle: "Identify sounds in realistic 3D environments — kitchen, street, park",
            icon: "tree.fill",
            tint: .lcGreen,
            sceneName: "EnvironmentalScenes",
            isAvailable: false  // Coming soon
        ),
    ]

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "3D Training"
        view.backgroundColor = .lcBackground
        buildUI()
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 16, leading: 16, bottom: 32, trailing: 16
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // Header info
        let headerLabel = UILabel()
        headerLabel.text = "Immersive 3D training exercises for cochlear implant rehabilitation. Works on your phone — or pair with a VR headset for a fully immersive experience."
        headerLabel.font = .systemFont(ofSize: 15)
        headerLabel.textColor = .secondaryLabel
        headerLabel.numberOfLines = 0
        contentStack.addArrangedSubview(headerLabel)
        contentStack.setCustomSpacing(24, after: headerLabel)

        // VR status card
        let vrCard = buildVRStatusCard()
        contentStack.addArrangedSubview(vrCard)
        contentStack.setCustomSpacing(24, after: vrCard)

        // Module cards
        for (index, module) in modules.enumerated() {
            let card = buildModuleCard(module, tag: index)
            contentStack.addArrangedSubview(card)
        }
    }

    // MARK: - VR Status

    private func buildVRStatusCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.lcAmber.withAlphaComponent(0.1)
        card.layer.cornerRadius = 12

        let icon = UIImageView(image: UIImage(systemName: "visionpro.fill"))
        icon.tintColor = .lcAmber
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "VR Mode: Pair your SenseXR or compatible VR headset for stereoscopic 3D. Training also works in standard phone mode."
        label.font = .systemFont(ofSize: 13)
        label.textColor = .lcAmber
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        return card
    }

    // MARK: - Module Card

    private func buildModuleCard(_ module: TrainingModule, tag: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.isUserInteractionEnabled = true

        let iconView = UIImageView(image: UIImage(systemName: module.icon))
        iconView.tintColor = module.isAvailable ? module.tint : .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = module.title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = module.isAvailable ? .label : .tertiaryLabel

        let subtitleLabel = UILabel()
        subtitleLabel.text = module.isAvailable ? module.subtitle : "\(module.subtitle)\n(Coming soon)"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = module.isAvailable ? .secondaryLabel : .tertiaryLabel
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = module.isAvailable ? .tertiaryLabel : .quaternaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(textStack)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -10),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
        ])

        if module.isAvailable {
            let tap = UITapGestureRecognizer(target: self, action: #selector(moduleTapped(_:)))
            card.tag = tag
            card.addGestureRecognizer(tap)
        } else {
            card.alpha = 0.6
        }

        return card
    }

    // MARK: - Actions

    @objc private func moduleTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, tag < modules.count else { return }
        let module = modules[tag]

        lcHaptic(.medium)

        let vc: UIViewController
        switch module.sceneName {
        case "SoundLocalization":
            vc = SoundLocalizationViewController()
        default:
            // Future modules can use Unity or native
            vc = SoundLocalizationViewController()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
