// VoiceLibraryViewController.swift
// LangCI — Voice Library: manage recorded people & their voice clips
//
// Shows all people with their recordings. Tap a person to see their
// clips, play them back, or delete them. "Record Voices" button leads
// to the guided recording flow.

import UIKit
import AVFoundation

final class VoiceLibraryViewController: UIViewController {

    // MARK: - State

    private let service = ServiceLocator.shared.voiceRecordingService!
    private var people: [RecordedPerson] = []
    private var recordings: [Int: [VoiceRecording]] = [:]  // personId → clips
    private var expandedPersonIds: Set<Int> = []            // collapsed by default
    private var audioPlayer: AVAudioPlayer?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Voice Library"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        let addBtn = UIBarButtonItem(
            image: UIImage(systemName: "mic.badge.plus"),
            style: .plain, target: self, action: #selector(recordVoices))
        navigationItem.rightBarButtonItem = addBtn

        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        loadData()
    }

    // MARK: - Data

    private func loadData() {
        Task {
            people = (try? await service.getAllPeople()) ?? []
            for person in people {
                let clips = (try? await service.getRecordings(forPerson: person.id)) ?? []
                recordings[person.id] = clips
            }
            await MainActor.run { rebuildCards() }
        }
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
            top: 8, leading: 16, bottom: 32, trailing: 16)
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

    private func rebuildCards() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if people.isEmpty {
            contentStack.addArrangedSubview(buildEmptyState())
        } else {
            // Record Voices CTA
            contentStack.addArrangedSubview(buildRecordCTA())

            for person in people {
                contentStack.addArrangedSubview(buildPersonSection(person))
            }
        }

        // Tip
        contentStack.addArrangedSubview(buildTipCard())
    }

    // MARK: - Empty State

    private func buildEmptyState() -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "mic.fill"))
        icon.tintColor = .lcTeal
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let title = UILabel()
        title.text = "No Voice Recordings Yet"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Record your wife, audiologist, family, or friends speaking short phrases. Your brain learns faster with familiar voices!"
        subtitle.font = UIFont.lcCaption()
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        let btn = LCButton(title: "Start Recording", color: .lcTeal)
        btn.addTarget(self, action: #selector(recordVoices), for: .touchUpInside)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(btn)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        return card
    }

    // MARK: - Record CTA

    private func buildRecordCTA() -> UIView {
        let card = LCCard()
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(recordVoices)))

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.lcTeal.withAlphaComponent(0.15).cgColor,
                           UIColor.lcBlue.withAlphaComponent(0.08).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = LC.cornerRadius
        card.layer.insertSublayer(gradient, at: 0)
        card.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcTeal.withAlphaComponent(0.2)
        iconBg.layer.cornerRadius = 22
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "mic.badge.plus"))
        icon.tintColor = .lcTeal
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        let title = UILabel()
        title.text = "Record More Voices"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        let sub = UILabel()
        sub.text = "Add clips from family, friends, or therapist"
        sub.font = UIFont.lcCaption()
        sub.textColor = .secondaryLabel
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(sub)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])
        DispatchQueue.main.async { gradient.frame = card.bounds }
        return card
    }

    // MARK: - Person Section

    private func buildPersonSection(_ person: RecordedPerson) -> UIView {
        let card = LCCard()
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 8
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let isExpanded = expandedPersonIds.contains(person.id)
        let clips = recordings[person.id] ?? []
        let color = colorForKey(person.color)

        // Header — tappable to expand/collapse
        let header = UIView()
        header.isUserInteractionEnabled = true
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 10
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.isUserInteractionEnabled = false
        header.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: header.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor),
        ])

        let iconBg = UIView()
        iconBg.backgroundColor = color.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 18
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let icon = UIImageView(image: UIImage(systemName: person.icon))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 1
        let name = UILabel()
        name.text = person.name
        name.font = .systemFont(ofSize: 16, weight: .bold)
        name.textColor = .label
        let sub = UILabel()
        sub.text = "\(person.relationship) \u{2022} \(clips.count) clips"
        sub.font = .systemFont(ofSize: 12, weight: .medium)
        sub.textColor = .secondaryLabel
        textStack.addArrangedSubview(name)
        textStack.addArrangedSubview(sub)

        let chevron = UIImageView(image: UIImage(systemName: isExpanded ? "chevron.up" : "chevron.down"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        headerStack.addArrangedSubview(iconBg)
        headerStack.addArrangedSubview(textStack)
        headerStack.addArrangedSubview(chevron)

        let tap = PersonToggleGesture(target: self, action: #selector(togglePersonSection(_:)))
        tap.personId = person.id
        header.addGestureRecognizer(tap)

        wrapper.addArrangedSubview(header)

        // Clip rows + delete button — only visible when expanded
        if isExpanded {
            for clip in clips {
                wrapper.addArrangedSubview(buildClipRow(clip, person: person))
            }

            let deleteBtn = UIButton(type: .system)
            deleteBtn.setTitle("Remove \(person.name)", for: .normal)
            deleteBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            deleteBtn.setTitleColor(.lcRed, for: .normal)
            deleteBtn.tag = person.id
            deleteBtn.addTarget(self, action: #selector(deletePersonTapped(_:)), for: .touchUpInside)
            wrapper.addArrangedSubview(deleteBtn)
        }

        card.addSubview(wrapper)
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            wrapper.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            wrapper.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            wrapper.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])

        return card
    }

    @objc private func togglePersonSection(_ gesture: PersonToggleGesture) {
        let pid = gesture.personId
        if expandedPersonIds.contains(pid) {
            expandedPersonIds.remove(pid)
        } else {
            expandedPersonIds.insert(pid)
        }
        rebuildCards()
        lcHaptic(.light)
    }

    private func buildClipRow(_ clip: VoiceRecording, person: RecordedPerson) -> UIView {
        let card = UIView()
        card.backgroundColor = .lcCard
        card.layer.cornerRadius = 10
        card.lcApplyShadow(radius: 3, opacity: 0.06)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Play button
        let playBtn = UIButton(type: .system)
        playBtn.setImage(UIImage(systemName: "play.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28)), for: .normal)
        playBtn.tintColor = colorForKey(person.color)
        playBtn.tag = clip.id
        playBtn.addTarget(self, action: #selector(playClip(_:)), for: .touchUpInside)
        playBtn.widthAnchor.constraint(equalToConstant: 36).isActive = true

        // Info
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 2
        let title = UILabel()
        title.text = clip.label
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        let dur = UILabel()
        dur.text = String(format: "%.1fs", clip.durationSeconds)
        dur.font = .systemFont(ofSize: 11, weight: .medium)
        dur.textColor = .tertiaryLabel
        infoStack.addArrangedSubview(title)
        infoStack.addArrangedSubview(dur)

        // Delete
        let delBtn = UIButton(type: .system)
        delBtn.setImage(UIImage(systemName: "trash",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)), for: .normal)
        delBtn.tintColor = .lcRed
        delBtn.tag = clip.id
        delBtn.addTarget(self, action: #selector(deleteClipTapped(_:)), for: .touchUpInside)
        delBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true

        stack.addArrangedSubview(playBtn)
        stack.addArrangedSubview(infoStack)
        stack.addArrangedSubview(delBtn)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])

        return card
    }

    // MARK: - Tip

    private func buildTipCard() -> UIView {
        let card = LCCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false

        let bulb = UIImageView(image: UIImage(systemName: "lightbulb.fill"))
        bulb.tintColor = .lcAmber
        bulb.contentMode = .scaleAspectFit
        bulb.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let tip = UILabel()
        tip.text = "Record 5-8 clips per person. Your brain is wired to recognise familiar voices first — hearing your wife or audiologist through the CI accelerates adaptation far faster than synthetic voices."
        tip.font = .systemFont(ofSize: 13, weight: .medium)
        tip.textColor = .secondaryLabel
        tip.numberOfLines = 0

        stack.addArrangedSubview(bulb)
        stack.addArrangedSubview(tip)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - Actions

    @objc private func recordVoices() {
        let vc = RecordVoiceViewController()
        vc.onSave = { [weak self] _ in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func playClip(_ sender: UIButton) {
        let clipId = sender.tag
        // Find clip in all recordings
        for (_, clips) in recordings {
            if let clip = clips.first(where: { $0.id == clipId }) {
                let url = clip.fileURL
                guard FileManager.default.fileExists(atPath: url.path) else {
                    return
                }
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    lcHaptic(.light)
                } catch { }
                return
            }
        }
    }

    @objc private func deleteClipTapped(_ sender: UIButton) {
        let clipId = sender.tag
        let alert = UIAlertController(title: "Delete Recording?",
            message: "This cannot be undone.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.service.deleteRecording(id: clipId)
                await MainActor.run { self?.loadData() }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func deletePersonTapped(_ sender: UIButton) {
        let personId = sender.tag
        guard let person = people.first(where: { $0.id == personId }) else { return }
        let alert = UIAlertController(title: "Remove \(person.name)?",
            message: "This will delete all their recordings.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.service.deletePerson(id: personId)
                await MainActor.run { self?.loadData() }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Helpers

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

private class PersonToggleGesture: UITapGestureRecognizer {
    var personId: Int = 0
}
