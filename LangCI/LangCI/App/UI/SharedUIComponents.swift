// SharedUIComponents.swift
// LangCI — reusable UIKit components used across all screens.

import UIKit

// MARK: - HeroHeaderView
// Gradient banner matching the MAUI hero header style.

final class HeroHeaderView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()

    init(title: String, subtitle: String, systemIcon: String, color: UIColor) {
        super.init(frame: .zero)
        build(title: title, subtitle: subtitle, systemIcon: systemIcon, color: color)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func build(title: String, subtitle: String, systemIcon: String, color: UIColor) {
        gradientLayer.colors = [
            color.cgColor,
            color.withAlphaComponent(0.72).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)
        layer.masksToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .light)
        iconImageView.image       = UIImage(systemName: systemIcon, withConfiguration: config)
        iconImageView.tintColor   = UIColor.white.withAlphaComponent(0.90)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text      = title
        titleLabel.font      = UIFont.lcHeroTitle()
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text          = subtitle
        subtitleLabel.font          = UIFont.lcHeroSubtitle()
        subtitleLabel.textColor     = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis    = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let hStack = UIStackView(arrangedSubviews: [textStack, iconImageView])
        hStack.axis      = .horizontal
        hStack.spacing   = 12
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)

        let iconH = iconImageView.heightAnchor.constraint(equalToConstant: 52)
        iconH.priority = .defaultHigh  // avoid conflict with safe-area inset

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding),
            hStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 52),
            iconH
        ])
    }

    func updateSubtitle(_ text: String) { subtitleLabel.text = text }
}

// MARK: - StatCardView
// Small rounded card showing a value + label.

final class StatCardView: UIView {

    private let valueLabel = UILabel()
    private let nameLabel  = UILabel()
    private let iconView   = UIImageView()

    init(icon: String, value: String, label: String, tint: UIColor = .lcBlue) {
        super.init(frame: .zero)
        build(icon: icon, value: value, label: label, tint: tint)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(icon: String, value: String, label: String, tint: UIColor) {
        backgroundColor    = .lcCard
        layer.cornerRadius = LC.cornerRadius
        lcApplyShadow()
        translatesAutoresizingMaskIntoConstraints = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image     = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text      = value
        valueLabel.font      = UIFont.lcCardValue()
        valueLabel.textColor = .label
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.text      = label
        nameLabel.font      = UIFont.lcCardLabel()
        nameLabel.textColor = .secondaryLabel
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel, nameLabel])
        stack.axis      = .vertical
        stack.alignment = .center
        stack.spacing   = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func update(value: String) { valueLabel.text = value }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UIView {
    init(title: String) {
        super.init(frame: .zero)
        let label = UILabel()
        label.text          = title.uppercased()
        label.font          = UIFont.lcSectionTitle()
        label.textColor     = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - LCButton (primary action button)

final class LCButton: UIButton {
    init(title: String, color: UIColor = .lcBlue) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        self.configuration = config
        titleLabel?.font = UIFont.lcBodyBold()
        layer.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false
        lcApplyShadow(radius: 6, opacity: 0.18)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - LCCard (generic white card container)

final class LCCard: UIView {
    /// Alias so call sites can say `card.contentView.addSubview(...)` interchangeably
    /// with adding directly to the card. Kept as `self` so no additional layout
    /// constraints are required.
    var contentView: UIView { self }

    init() {
        super.init(frame: .zero)
        backgroundColor    = .lcCard
        layer.cornerRadius = LC.cornerRadius
        lcApplyShadow()
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - ProgressBarView

final class ProgressBarView: UIView {

    private let track    = UIView()
    private let fill     = UIView()
    private var fillWidth: NSLayoutConstraint!

    var color: UIColor = .lcBlue { didSet { fill.backgroundColor = color } }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 5
        clipsToBounds      = true

        track.backgroundColor = UIColor.systemFill
        track.translatesAutoresizingMaskIntoConstraints = false

        fill.backgroundColor = color
        fill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(track)
        addSubview(fill)

        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: topAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillWidth
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setProgress(_ value: Double, animated: Bool = true) {
        layoutIfNeeded()
        let clamped = max(0, min(1, value))
        fillWidth.constant = bounds.width * clamped
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0) { self.layoutIfNeeded() }
        } else {
            layoutIfNeeded()
        }
    }
}

// MARK: - EmptyStateView

final class EmptyStateView: UIView {
    init(icon: String, title: String, message: String, tint: UIColor = .lcBlue) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 48, weight: .ultraLight)
        let img = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg))
        img.tintColor = tint.withAlphaComponent(0.6)
        img.contentMode = .scaleAspectFit

        let t = UILabel(); t.text = title
        t.font = UIFont.lcBodyBold(); t.textColor = .label; t.textAlignment = .center

        let m = UILabel(); m.text = message
        m.font = UIFont.lcBody(); m.textColor = .secondaryLabel
        m.textAlignment = .center; m.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [img, t, m])
        stack.axis = .vertical; stack.alignment = .center
        stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            img.heightAnchor.constraint(equalToConstant: 64),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - LCLoadingView
// Centered spinner + optional message. Use for async data loads.

final class LCLoadingView: UIView {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    init(message: String = "Loading…") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        spinner.startAnimating()
        spinner.hidesWhenStopped = false

        label.text = message
        label.font = UIFont.lcCaption()
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func start() { spinner.startAnimating() }
    func stop() { spinner.stopAnimating() }
}

// MARK: - LCListRow
// Clean iOS-grouped list row: icon badge + title/subtitle + chevron.
// Use inside an LCCard as a single-tap row, or repeat with separators.

final class LCListRow: UIControl {
    private let iconBadge = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let accessoryLabel = UILabel()

    /// Optional trailing text label shown between subtitle and chevron.
    var accessoryText: String? {
        didSet { accessoryLabel.text = accessoryText; accessoryLabel.isHidden = accessoryText == nil }
    }

    init(icon: String, title: String, subtitle: String? = nil, tint: UIColor = .lcBlue) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        iconBadge.backgroundColor = tint.withAlphaComponent(0.12)
        iconBadge.layer.cornerRadius = 9
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.isUserInteractionEnabled = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = UIFont.lcBodyBold()
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.lcCaption()
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        subtitleLabel.isHidden = subtitle == nil

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        accessoryLabel.font = UIFont.lcCaption()
        accessoryLabel.textColor = .secondaryLabel
        accessoryLabel.textAlignment = .right
        accessoryLabel.isHidden = true
        accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
        accessoryLabel.setContentHuggingPriority(.required, for: .horizontal)

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(iconBadge)
        addSubview(textStack)
        addSubview(accessoryLabel)
        addSubview(chevron)

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LC.cardPadding),
            iconBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),

            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: accessoryLabel.leadingAnchor, constant: -8),

            accessoryLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            accessoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LC.cardPadding),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.backgroundColor = self.isHighlighted
                    ? UIColor.systemFill.withAlphaComponent(0.3)
                    : .clear
            }
        }
    }
}

// MARK: - LCStatRow
// Horizontal row of label/value pairs separated by thin dividers.
// Perfect for compact KPI summaries inside a card header.

final class LCStatRow: UIStackView {
    struct Item { let label: String; let value: String; let tint: UIColor }

    init(items: [Item]) {
        super.init(frame: .zero)
        axis = .horizontal
        distribution = .fill
        alignment = .center
        spacing = 0
        translatesAutoresizingMaskIntoConstraints = false

        var columns: [UIStackView] = []

        for (index, item) in items.enumerated() {
            let valueLabel = UILabel()
            valueLabel.text = item.value
            valueLabel.font = UIFont.lcCardValue()
            valueLabel.textColor = item.tint
            valueLabel.textAlignment = .center
            valueLabel.adjustsFontSizeToFitWidth = true
            valueLabel.minimumScaleFactor = 0.7

            let nameLabel = UILabel()
            nameLabel.text = item.label.uppercased()
            nameLabel.font = UIFont.lcCardLabel()
            nameLabel.textColor = .secondaryLabel
            nameLabel.textAlignment = .center
            nameLabel.adjustsFontSizeToFitWidth = true
            nameLabel.minimumScaleFactor = 0.7

            let col = UIStackView(arrangedSubviews: [valueLabel, nameLabel])
            col.axis = .vertical
            col.spacing = 2
            col.alignment = .center
            columns.append(col)

            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = .separator
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
                divider.heightAnchor.constraint(equalToConstant: 28).isActive = true
                addArrangedSubview(divider)
            }
            addArrangedSubview(col)
        }

        // Make all columns equal width (dividers keep their fixed 1pt width)
        for col in columns.dropFirst() {
            col.widthAnchor.constraint(equalTo: columns[0].widthAnchor).isActive = true
        }
    }
    required init(coder: NSCoder) { fatalError() }
}

// MARK: - LCPillButton
// Compact secondary button — pill-shaped, border only, small content insets.
// Use for filter chips, secondary actions, tag toggles.

final class LCPillButton: UIButton {
    private var tint: UIColor

    init(title: String, systemIcon: String? = nil, tint: UIColor = .lcBlue) {
        self.tint = tint
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = systemIcon.flatMap { UIImage(systemName: $0) }
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.baseForegroundColor = tint
        self.configuration = config
        titleLabel?.font = UIFont.lcCaption()
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = tint.withAlphaComponent(0.35).cgColor
        backgroundColor = tint.withAlphaComponent(0.08)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 32).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    var isSelectedPill: Bool = false {
        didSet {
            backgroundColor = isSelectedPill ? tint : tint.withAlphaComponent(0.08)
            var config = configuration
            config?.baseForegroundColor = isSelectedPill ? .white : tint
            configuration = config
            layer.borderColor = isSelectedPill ? tint.cgColor : tint.withAlphaComponent(0.35).cgColor
        }
    }
}

// MARK: - LCIconButton
// Round icon button with tinted background. Used for play/stop/add/trash.

final class LCIconButton: UIButton {
    init(systemIcon: String, tint: UIColor = .lcBlue, size: CGFloat = 44) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: systemIcon,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: size * 0.40, weight: .semibold))
        config.baseBackgroundColor = tint
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        self.configuration = config
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
        lcApplyShadow(radius: 4, opacity: 0.15)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - LCDivider
// Thin horizontal separator used between LCListRows inside an LCCard. Uses a
// CALayer so hairline thickness can react to displayScale from the trait
// collection (no UIScreen.main dependency).

final class LCDivider: UIView {
    private let lineLayer = CALayer()
    private let leftInset: CGFloat

    init(leftInset: CGFloat = LC.cardPadding + 34 + 12) {
        self.leftInset = leftInset
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        lineLayer.backgroundColor = UIColor.separator.cgColor
        layer.addSublayer(lineLayer)
        heightAnchor.constraint(equalToConstant: 1).isActive = true

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.lineLayer.backgroundColor = UIColor.separator.cgColor
            self.setNeedsLayout()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
        let thickness = 1.0 / scale
        lineLayer.frame = CGRect(
            x: leftInset,
            y: bounds.height - thickness,
            width: max(0, bounds.width - leftInset - LC.cardPadding),
            height: thickness
        )
    }
}

// MARK: - LCToastView
// Lightweight transient toast shown by the UIViewController extension below.

final class LCToastView: UIView {
    init(message: String, icon: String, tint: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor.systemGray5 : UIColor.white }
        layer.cornerRadius = 14
        lcApplyShadow(radius: 12, opacity: 0.20)

        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = message
        label.font = UIFont.lcBodyBold()
        label.textColor = .label
        label.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - UIViewController helpers

extension UIViewController {

    /// Show a transient toast at the top of the view. Auto-dismisses after `duration`.
    func lcShowToast(_ message: String,
                     icon: String = "checkmark.circle.fill",
                     tint: UIColor = .lcGreen,
                     duration: TimeInterval = 1.8) {
        let toast = LCToastView(message: message, icon: icon, tint: tint)
        toast.alpha = 0
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])

        toast.transform = CGAffineTransform(translationX: 0, y: -20)
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.75,
                       initialSpringVelocity: 0) {
            toast.alpha = 1
            toast.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.25, animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: -10)
            }, completion: { _ in toast.removeFromSuperview() })
        }
    }

    /// Trigger a haptic feedback tap. Lightweight wrapper for consistency.
    func lcHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Success haptic — used for save / complete actions.
    func lcHapticSuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}

// MARK: - LCCard convenience

extension LCCard {
    /// Embeds a UIStackView inside the card with standard padding.
    /// Returns the stack for chaining.
    @discardableResult
    func installContentStack(axis: NSLayoutConstraint.Axis = .vertical,
                             spacing: CGFloat = 12,
                             padding: CGFloat = LC.cardPadding) -> UIStackView {
        let stack = UIStackView()
        stack.axis = axis
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ])
        return stack
    }
}
