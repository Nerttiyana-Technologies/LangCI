// HomeWowFactors.swift
// LangCI — extra "wow factor" views used by HomeViewController.
//
// These are the polish ingredients that make the home screen feel
// delightful instead of flat:
//
//   • AnimatedGradientHeroView
//     — A CAGradientLayer whose colors drift through a warm palette on
//       a slow loop. Used as the hero banner.
//   • DailyGoalRingView
//     — A circular CAShapeLayer progress ring with an animated stroke.
//   • CountUpLabel
//     — A UILabel that tweens to a target integer value with a display
//       link for buttery-smooth frame updates.
//   • PracticeCTAcard
//     — Big "Today's practice" call-to-action card with icon + caption.
//   • ConfettiView
//     — A lightweight CAEmitterLayer confetti burst we fire when the
//       user crosses a streak milestone.
//
// Everything here is pure UIKit + QuartzCore so it compiles without
// pulling in new dependencies.

import UIKit
import QuartzCore

// MARK: - AnimatedGradientHeroView

/// A hero banner that cycles through a warm orange→magenta→teal gradient
/// using CABasicAnimation so the home screen greets the user with some
/// life. Also hosts a big greeting label.
final class AnimatedGradientHeroView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let greetingLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconView = UIImageView()

    // Animation sets. Each entry = a 4-stop gradient.
    private let palettes: [[CGColor]] = [
        [
            UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.98, green: 0.32, blue: 0.40, alpha: 1).cgColor
        ],
        [
            UIColor(red: 0.98, green: 0.32, blue: 0.40, alpha: 1).cgColor,
            UIColor(red: 0.40, green: 0.40, blue: 0.90, alpha: 1).cgColor
        ],
        [
            UIColor(red: 0.40, green: 0.40, blue: 0.90, alpha: 1).cgColor,
            UIColor(red: 0.10, green: 0.70, blue: 0.76, alpha: 1).cgColor
        ],
        [
            UIColor(red: 0.10, green: 0.70, blue: 0.76, alpha: 1).cgColor,
            UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1).cgColor
        ]
    ]
    private var paletteIndex = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        startAnimating()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 22
        clipsToBounds = true
        layer.masksToBounds = true

        gradientLayer.colors = palettes[0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        greetingLabel.text = greetingText()
        greetingLabel.font = .systemFont(ofSize: 26, weight: .heavy)
        greetingLabel.textColor = .white
        greetingLabel.numberOfLines = 1
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Ready to train your ears?"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular)
        iconView.image = UIImage(
            systemName: "ear.badge.waveform",
            withConfiguration: iconCfg
        )
        iconView.tintColor = UIColor.white.withAlphaComponent(0.92)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(greetingLabel)
        addSubview(subtitleLabel)
        addSubview(iconView)

        NSLayoutConstraint.activate([
            greetingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            greetingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            greetingLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: greetingLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),

            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    func updateSubtitle(_ text: String) {
        subtitleLabel.text = text
    }

    func updateGreeting(_ text: String) {
        greetingLabel.text = text
    }

    private func greetingText() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning 👋"
        case 12..<17: return "Good afternoon ☀️"
        case 17..<22: return "Good evening 🌙"
        default:       return "Good night 🌌"
        }
    }

    private func startAnimating() {
        animateToNextPalette()
    }

    private func animateToNextPalette() {
        let next = (paletteIndex + 1) % palettes.count
        let anim = CABasicAnimation(keyPath: "colors")
        anim.fromValue = palettes[paletteIndex]
        anim.toValue = palettes[next]
        anim.duration = 6.0
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        anim.delegate = PaletteAdvancer { [weak self] in
            guard let self = self else { return }
            self.paletteIndex = next
            self.gradientLayer.colors = self.palettes[self.paletteIndex]
            self.animateToNextPalette()
        }
        gradientLayer.add(anim, forKey: "paletteShift")
    }
}

// Helper that forwards CAAnimation completion back to a closure so the
// hero can chain palette animations without holding a strong reference
// back to itself inside the animation.
private final class PaletteAdvancer: NSObject, CAAnimationDelegate {
    let onComplete: () -> Void
    init(_ onComplete: @escaping () -> Void) { self.onComplete = onComplete }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag { onComplete() }
    }
}

// MARK: - DailyGoalRingView

/// Circular progress ring for the "daily goal" indicator on the home
/// card. Animates from 0 → current on setProgress().
final class DailyGoalRingView: UIView {

    private let backgroundLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let centerLabel = UILabel()
    private let sublabel = UILabel()

    var ringColor: UIColor = .lcOrange {
        didSet { progressLayer.strokeColor = ringColor.cgColor }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let lineWidth: CGFloat = 10
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 3 / 2,
            clockwise: true
        )
        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        backgroundLayer.lineWidth = lineWidth
        progressLayer.lineWidth = lineWidth
    }

    private func build() {
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.systemGray5.cgColor
        backgroundLayer.lineCap = .round
        layer.addSublayer(backgroundLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = ringColor.cgColor
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)

        centerLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        centerLabel.textColor = .label
        centerLabel.textAlignment = .center
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerLabel)

        sublabel.text = "of 3"
        sublabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sublabel.textColor = .secondaryLabel
        sublabel.textAlignment = .center
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sublabel)

        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
            sublabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublabel.topAnchor.constraint(equalTo: centerLabel.bottomAnchor, constant: 0)
        ])
    }

    /// Set progress 0.0…1.0 with a spring-like animation.
    func setProgress(_ value: Double, done: Int, goal: Int) {
        centerLabel.text = "\(done)"
        sublabel.text = "of \(goal)"
        let clamped = CGFloat(max(0, min(1, value)))
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = progressLayer.presentation()?.strokeEnd ?? 0
        anim.toValue = clamped
        anim.duration = 0.9
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.add(anim, forKey: "ringFill")
        progressLayer.strokeEnd = clamped
    }
}

// MARK: - CountUpLabel

/// UILabel subclass that tweens its integer value toward a target with
/// a display link. Handy for stat cards that shouldn't just snap.
final class CountUpLabel: UILabel {

    private var displayLink: CADisplayLink?
    private var startValue: Int = 0
    private var endValue: Int = 0
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 1.0
    var suffix: String = ""

    func setValue(_ target: Int, duration: CFTimeInterval = 1.0) {
        self.startValue = currentInteger()
        self.endValue = target
        self.duration = duration
        self.startTime = CACurrentMediaTime()
        displayLink?.invalidate()
        if startValue == target {
            text = "\(target)\(suffix)"
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func currentInteger() -> Int {
        guard let t = text else { return 0 }
        let digits = t.filter { $0.isNumber }
        return Int(digits) ?? 0
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let elapsed = now - startTime
        let progress = min(1.0, elapsed / duration)
        // Ease-out cubic
        let eased = 1 - pow(1 - progress, 3)
        let value = Int(Double(startValue) + Double(endValue - startValue) * eased)
        text = "\(value)\(suffix)"
        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            text = "\(endValue)\(suffix)"
        }
    }

    deinit { displayLink?.invalidate() }
}

// MARK: - PracticeCTACard

/// The big "Today's practice" call-to-action card. Gradient background,
/// headline, supporting caption, and an arrow indicating tap.
final class PracticeCTACard: UIControl {

    private let gradient = CAGradientLayer()
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let iconView = UIImageView()
    private let arrowView = UIImageView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
                self.alpha = self.isHighlighted ? 0.92 : 1.0
            }
        }
    }

    private func build() {
        layer.cornerRadius = 22
        clipsToBounds = true

        gradient.colors = [
            UIColor(red: 0.11, green: 0.72, blue: 0.62, alpha: 1).cgColor,
            UIColor(red: 0.06, green: 0.55, blue: 0.78, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)

        titleLabel.text = "Today's practice"
        titleLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.text = "Start a 3-minute listening drill →"
        captionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        iconView.image = UIImage(systemName: "waveform.path.ecg", withConfiguration: iconCfg)
        iconView.tintColor = UIColor.white.withAlphaComponent(0.92)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let arrowCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        arrowView.image = UIImage(systemName: "arrow.right.circle.fill", withConfiguration: arrowCfg)
        arrowView.tintColor = UIColor.white.withAlphaComponent(0.92)
        arrowView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(captionLabel)
        addSubview(iconView)
        addSubview(arrowView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),

            captionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            captionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            arrowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            arrowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 28),
            arrowView.heightAnchor.constraint(equalToConstant: 28),

            bottomAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 18)
        ])
    }

    func updateCaption(_ text: String) {
        captionLabel.text = text
    }
}

// MARK: - ConfettiView

/// Fires a short confetti burst when triggered. Use for streak
/// milestones. Removes itself from the superview once the animation is
/// done.
final class ConfettiView: UIView {

    private let emitter = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        emitter.emitterSize = CGSize(width: bounds.width, height: 2)
        emitter.emitterShape = .line
    }

    func fire(duration: TimeInterval = 2.0) {
        emitter.birthRate = 1
        emitter.emitterCells = makeCells()
        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .lcOrange, .lcGreen, .lcBlue, .lcTeal, .lcGold, .lcPurple
        ]
        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 3.5
            cell.velocity = 180
            cell.velocityRange = 40
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 6
            cell.spin = 3
            cell.spinRange = 2
            cell.scale = 0.04
            cell.scaleRange = 0.02
            cell.yAcceleration = 120
            cell.color = color.cgColor
            cell.contents = makeSquareImage(color: color).cgImage
            return cell
        }
    }

    private func makeSquareImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 12, height: 12)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
