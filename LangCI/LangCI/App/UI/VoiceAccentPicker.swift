// VoiceAccentPicker.swift
// LangCI — Reusable voice accent picker for TTS screens
//
// A horizontal scrollable chip row letting users choose which
// accent/region voices to use: India, US, UK, AU, Tamil, All.
// Updates MultiVoiceTTS.shared automatically.

import UIKit

final class VoiceAccentPicker: UIView {

    /// Whether to include Tamil as an option (false for phonetic tests)
    var includeTamil: Bool = true {
        didSet { rebuildChips() }
    }

    /// Called when accent changes — passes the selected accent
    var onAccentChanged: ((MultiVoiceTTS.VoiceAccent) -> Void)?

    private let label = UILabel()
    private let scrollView = UIScrollView()
    private let chipRow = UIStackView()
    private var chips: [UIButton] = []
    private var accents: [MultiVoiceTTS.VoiceAccent] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.text = "Voice Accent"
        label.font = UIFont.lcCaption()
        label.textColor = .secondaryLabel

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        chipRow.axis = .horizontal
        chipRow.spacing = 8
        chipRow.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(chipRow)

        let stack = UIStackView(arrangedSubviews: [label, scrollView])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),

            chipRow.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 2),
            chipRow.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -2),
            chipRow.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 2),
            chipRow.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -2),
            scrollView.heightAnchor.constraint(equalToConstant: 40),
        ])

        rebuildChips()
    }

    private func rebuildChips() {
        chipRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips = []

        accents = includeTamil
            ? [.all, .india, .us, .uk, .au, .tamil]
            : [.all, .india, .us, .uk, .au]

        for (i, accent) in accents.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle("\(accent.icon) \(accent.rawValue)", for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            chip.layer.cornerRadius = 16
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            chip.tag = i
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)

            if accent == MultiVoiceTTS.shared.selectedAccent {
                chip.backgroundColor = .lcTeal
                chip.tintColor = .white
            } else {
                chip.backgroundColor = .secondarySystemFill
                chip.tintColor = .label
            }

            chipRow.addArrangedSubview(chip)
            chips.append(chip)
        }
    }

    @objc private func chipTapped(_ sender: UIButton) {
        let accent = accents[sender.tag]
        MultiVoiceTTS.shared.selectAccent(accent)
        onAccentChanged?(accent)

        for (i, chip) in chips.enumerated() {
            if i == sender.tag {
                chip.backgroundColor = .lcTeal
                chip.tintColor = .white
            } else {
                chip.backgroundColor = .secondarySystemFill
                chip.tintColor = .label
            }
        }
    }
}
