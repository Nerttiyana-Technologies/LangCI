// AboutViewController.swift
// LangCI — The story behind the app
//
// A personal About screen telling users why LangCI exists — written
// in the first person because it's a personal project from one CI user
// who wanted a tool he wished existed on day one of activation.

import UIKit
import SafariServices

final class AboutViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Suresh's CI journey dates
    private let surgeryDate = "16 March 2026"
    private let activationDate = "6 April 2026"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .never

        buildScaffold()
        populateContent()
    }

    // MARK: - Build

    private func buildScaffold() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 24, leading: 20, bottom: 40, trailing: 20)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
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
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Content

    private func populateContent() {
        contentStack.addArrangedSubview(buildHeader())
        contentStack.addArrangedSubview(buildJourneyCard())
        contentStack.addArrangedSubview(sectionTitle("Why LangCI exists"))
        contentStack.addArrangedSubview(paragraph(
            """
            The first days after CI activation are overwhelming. The world sounds \
            unfamiliar. Every voice, every letter, every sibilant feels like a new \
            language to learn — and in many ways, it is.

            I couldn't find a single app that helped me practise the way my audiologist \
            did: with Tamil and English side by side, with the real voices of my family, \
            and with the specific sounds (/s/, /sh/, /ush/) that my brain had to re-learn \
            to hear correctly.

            So I started building one.
            """))

        contentStack.addArrangedSubview(sectionTitle("What LangCI tries to do"))
        contentStack.addArrangedSubview(bulletList([
            "Help you practise the sounds your CI struggles with the most",
            "Let you hear words in your family's real voices, not just synthetic ones",
            "Work in English and Tamil — with more languages over time",
            "Give audiologists a digital version of the paper tracking sheets they already use",
            "Show your progress over weeks and months, so you can see the improvement that's hard to feel day-to-day"
        ]))

        contentStack.addArrangedSubview(sectionTitle("Built with care"))
        contentStack.addArrangedSubview(paragraph(
            """
            LangCI is built by someone living the journey. Every feature exists because \
            I — or my audiologist, or my wife — wanted it at a specific moment of training. \
            If something feels missing, tell me. Chances are someone else needs it too.

            It is free, open source, and runs entirely on your device. Nothing leaves \
            your phone.
            """))

        contentStack.addArrangedSubview(sectionTitle("Thank you"))
        contentStack.addArrangedSubview(paragraph(
            """
            To my audiologist, who taught me what a Ling 6 test is and showed me \
            that re-learning to hear is possible.

            To my wife, who patiently listens while I practise the same words for \
            the hundredth time.

            To the global cochlear implant community, for showing me I am not alone.

            This app is part of my journey — and maybe yours too.
            """))

        contentStack.addArrangedSubview(signature())
        contentStack.addArrangedSubview(buildLinksCard())
        contentStack.addArrangedSubview(disclaimerFootnote())
    }

    // MARK: - Header with CI icon and app name

    private func buildHeader() -> UIView {
        let container = UIView()

        let iconWrap = UIView()
        iconWrap.backgroundColor = UIColor.lcTeal.withAlphaComponent(0.15)
        iconWrap.layer.cornerRadius = 22
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iconWrap.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let icon = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 38, weight: .semibold)
        icon.image = UIImage(systemName: "ear.and.waveform", withConfiguration: cfg)
        icon.tintColor = .lcTeal
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
        ])

        let title = UILabel()
        title.text = "LangCI"
        title.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        title.textColor = .label
        title.textAlignment = .center

        let tagline = UILabel()
        tagline.text = "A training companion for cochlear implant users"
        tagline.font = UIFont.lcBody()
        tagline.textColor = .secondaryLabel
        tagline.textAlignment = .center
        tagline.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconWrap, title, tagline])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Journey card (the two key dates)

    private func buildJourneyCard() -> LCCard {
        let card = LCCard()
        card.contentView.backgroundColor = UIColor.lcTeal.withAlphaComponent(0.06)

        let header = UILabel()
        header.text = "My CI Journey"
        header.font = UIFont.lcBodyBold()
        header.textColor = .label

        let intro = UILabel()
        intro.text = "LangCI is part of my own cochlear implant journey."
        intro.font = UIFont.lcBody()
        intro.textColor = .secondaryLabel
        intro.numberOfLines = 0

        let surgeryRow = milestoneRow(
            icon: "calendar.badge.clock",
            tint: .lcBlue,
            title: "Surgery",
            value: surgeryDate)

        let activationRow = milestoneRow(
            icon: "ear.fill",
            tint: .lcTeal,
            title: "Activation",
            value: activationDate)

        let stack = UIStackView(arrangedSubviews: [header, intro, surgeryRow, activationRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
        ])
        return card
    }

    private func milestoneRow(icon: String, tint: UIColor, title: String, value: String) -> UIView {
        let iconView = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = tint
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.lcBody()
        valueLabel.textColor = .label

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, valueLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }

    // MARK: - Section / paragraph helpers

    private func sectionTitle(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        lbl.textColor = .label
        return lbl
    }

    private func paragraph(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.lcBody()
        lbl.textColor = .label
        lbl.numberOfLines = 0
        return lbl
    }

    private func bulletList(_ items: [String]) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        for item in items {
            let dot = UILabel()
            dot.text = "•"
            dot.font = UIFont.systemFont(ofSize: 17, weight: .bold)
            dot.textColor = .lcTeal
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 18).isActive = true

            let text = UILabel()
            text.text = item
            text.font = UIFont.lcBody()
            text.textColor = .label
            text.numberOfLines = 0

            let row = UIStackView(arrangedSubviews: [dot, text])
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = 6
            stack.addArrangedSubview(row)
        }
        return stack
    }

    private func signature() -> UILabel {
        let lbl = UILabel()
        lbl.text = "— Suresh"
        lbl.font = UIFont.italicSystemFont(ofSize: 16)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .right
        return lbl
    }

    // MARK: - Links

    private func buildLinksCard() -> LCCard {
        let card = LCCard()

        let header = UILabel()
        header.text = "Links"
        header.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        header.textColor = .secondaryLabel

        let sourceRow = linkRow(
            icon: "chevron.left.forwardslash.chevron.right",
            title: "Source code on GitHub",
            subtitle: "Free and open source",
            url: "https://github.com/isureshsubramanian/LangCI")

        let privacyRow = linkRow(
            icon: "lock.shield",
            title: "Privacy Policy",
            subtitle: "All data stays on your device",
            url: "https://github.com/isureshsubramanian/LangCI/blob/main/docs/PRIVACY_POLICY.md")

        let sourcesRow = linkRow(
            icon: "book.closed.fill",
            title: "Clinical References",
            subtitle: "Sources behind our training methods",
            url: nil,
            tapAction: #selector(openReferences))

        let versionRow = infoRow(
            icon: "app.badge",
            title: "Version",
            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")

        let stack = UIStackView(arrangedSubviews: [header, sourceRow, separator(), privacyRow, separator(), sourcesRow, separator(), versionRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),
        ])
        return card
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: String?, tapAction: Selector? = nil) -> UIView {
        let iconView = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = .lcTeal
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.lcBody()
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel

        let text = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        text.axis = .vertical
        text.spacing = 1

        let chevron = UIImageView(image: UIImage(systemName: "arrow.up.right.square"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .center
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let row = UIStackView(arrangedSubviews: [iconView, text, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.isUserInteractionEnabled = true

        if let urlString = url, let url = URL(string: urlString) {
            let tap = LinkTapGesture(target: self, action: #selector(openURLFromRow(_:)))
            tap.url = url
            row.addGestureRecognizer(tap)
        } else if let action = tapAction {
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        }
        return row
    }

    private func infoRow(icon: String, title: String, value: String) -> UIView {
        let iconView = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.lcBody()
        titleLbl.textColor = .label

        let valueLbl = UILabel()
        valueLbl.text = value
        valueLbl.font = UIFont.lcBody()
        valueLbl.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [iconView, titleLbl, UIView(), valueLbl])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    private func disclaimerFootnote() -> UILabel {
        let lbl = UILabel()
        lbl.text = """
LangCI is a practice and training tool. It is not a medical device and does not replace clinical evaluation by a qualified audiologist or healthcare provider.
"""
        lbl.font = UIFont.systemFont(ofSize: 11)
        lbl.textColor = .tertiaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        return lbl
    }

    // MARK: - Actions

    @objc private func openURLFromRow(_ gesture: LinkTapGesture) {
        guard let url = gesture.url else { return }
        lcHaptic(.light)
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .lcTeal
        present(safari, animated: true)
    }

    @objc private func openReferences() {
        lcHaptic(.light)
        navigationController?.pushViewController(MedicalReferencesViewController(), animated: true)
    }
}

private class LinkTapGesture: UITapGestureRecognizer {
    var url: URL?
}
