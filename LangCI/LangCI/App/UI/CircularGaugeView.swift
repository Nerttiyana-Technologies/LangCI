// CircularGaugeView.swift
// LangCI
//
// A compact circular gauge that shows a numeric value with an animated arc.
// Used in the Reading Aloud drill to display live Hz, dB, and WPM.
//
// Layout:
//   ┌──────────────┐
//   │   ╭─270°─╮   │
//   │   │       │   │
//   │   │  142  │   │   ← value label (large, bold)
//   │   │   Hz  │   │   ← unit label (small, secondary)
//   │   ╰───────╯   │
//   │    Pitch      │   ← title label
//   └──────────────┘

import UIKit

final class CircularGaugeView: UIView {

    // MARK: - Configuration

    struct Config {
        let title: String
        let unit: String
        let minValue: Double
        let maxValue: Double
        let color: UIColor
        let warningThreshold: Double?  // nil = no warning zone
        let format: String             // e.g. "%.0f" or "%.1f"
    }

    private let config: Config

    // MARK: - Layers

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()

    // MARK: - Labels

    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let titleLabel = UILabel()

    // MARK: - State

    private var displayedValue: Double = 0

    // MARK: - Constants

    private let startAngle: CGFloat = .pi * 0.75      // 135°
    private let endAngle: CGFloat   = .pi * 2.25      // 405° (= 360° + 45°)
    private let lineWidth: CGFloat  = 8

    // MARK: - Init

    init(config: Config) {
        self.config = config
        super.init(frame: .zero)
        setupLayers()
        setupLabels()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateArcPaths()
    }

    // MARK: - Public

    /// Animate the gauge to the new value.
    func setValue(_ value: Double, animated: Bool = true) {
        let clamped = min(max(value, config.minValue), config.maxValue)
        displayedValue = clamped

        // Update label
        valueLabel.text = String(format: config.format, clamped)

        // Colour shift based on warning threshold
        if let threshold = config.warningThreshold {
            progressLayer.strokeColor = clamped > threshold
                ? UIColor.systemOrange.cgColor
                : config.color.cgColor
            glowLayer.strokeColor = progressLayer.strokeColor
        }

        // Arc progress (0 → 1)
        let range = config.maxValue - config.minValue
        let progress = range > 0 ? (clamped - config.minValue) / range : 0

        if animated {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = progressLayer.strokeEnd
            anim.toValue = progress
            anim.duration = 0.15
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            progressLayer.add(anim, forKey: "strokeEnd")
        }
        progressLayer.strokeEnd = CGFloat(progress)
        glowLayer.strokeEnd = CGFloat(progress)
    }

    /// Reset the gauge to zero (no animation).
    func reset() {
        displayedValue = 0
        valueLabel.text = "—"
        progressLayer.strokeEnd = 0
        glowLayer.strokeEnd = 0
    }

    // MARK: - Setup

    private func setupLayers() {
        // Track (full arc, light gray)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemFill.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        // Glow (behind the progress arc)
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = config.color.withAlphaComponent(0.25).cgColor
        glowLayer.lineWidth = lineWidth + 6
        glowLayer.lineCap = .round
        glowLayer.strokeEnd = 0
        layer.addSublayer(glowLayer)

        // Progress arc
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = config.color.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }

    private func setupLabels() {
        valueLabel.text = "—"
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        unitLabel.text = config.unit
        unitLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        unitLabel.textColor = .secondaryLabel
        unitLabel.textAlignment = .center
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(unitLabel)

        titleLabel.text = config.title
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),

            unitLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            unitLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 0),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 2)
        ])
    }

    // MARK: - Arc path

    private func updateArcPaths() {
        let inset = lineWidth / 2 + 4  // leave room for the glow layer
        let rect = bounds.insetBy(dx: inset, dy: inset)
        // The arc's center is offset upward slightly so the title label
        // sits below the arc gap.
        let center = CGPoint(x: rect.midX, y: rect.midY - 2)
        let radius = min(rect.width, rect.height) / 2

        let arcPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true)

        trackLayer.path = arcPath.cgPath
        progressLayer.path = arcPath.cgPath
        glowLayer.path = arcPath.cgPath
    }
}
