// SoundLocalizationViewController.swift
// LangCI
//
// Native sound localization training.
// Uses AVAudioEngine with HRTF spatial audio for realistic directional sound.

import UIKit
import AVFoundation

final class SoundLocalizationViewController: UIViewController {

    // MARK: - Settings

    private let totalRounds = 10
    private let preDelay: TimeInterval = 1.2
    private let feedbackDuration: TimeInterval = 1.3

    // MARK: - State

    private var currentRound = 0
    private var correctCount = 0
    private var waitingForInput = false
    private var activeSpeakerIndex = -1
    private var hasLaidOut = false

    // MARK: - Audio

    private var audioEngine: AVAudioEngine!
    private var environmentNode: AVAudioEnvironmentNode!
    private var playerNode: AVAudioPlayerNode!
    private var audioBuffer: AVAudioPCMBuffer!

    // MARK: - Speaker Model

    private struct Speaker {
        let label: String
        let short: String
        let angle: CGFloat      // degrees clockwise from top (12-o'clock = 0)
        let color: UIColor
        let pos: AVAudio3DPoint  // 3D audio position
    }

    private let speakers: [Speaker] = {
        let r: Float = 3
        let d: Float = 2.12      // r * cos(45°)
        return [
            Speaker(label: "Front",       short: "F",  angle: 0,   color: .init(red:0.30,green:0.58,blue:1.0, alpha:1), pos: .init(x: 0, y:0, z:-r)),
            Speaker(label: "Front Right", short: "FR", angle: 45,  color: .init(red:0.18,green:0.72,blue:0.78,alpha:1), pos: .init(x: d, y:0, z:-d)),
            Speaker(label: "Right",       short: "R",  angle: 90,  color: .init(red:0.22,green:0.76,blue:0.42,alpha:1), pos: .init(x: r, y:0, z: 0)),
            Speaker(label: "Back Right",  short: "BR", angle: 135, color: .init(red:0.52,green:0.73,blue:0.20,alpha:1), pos: .init(x: d, y:0, z: d)),
            Speaker(label: "Back",        short: "B",  angle: 180, color: .init(red:0.92,green:0.72,blue:0.12,alpha:1), pos: .init(x: 0, y:0, z: r)),
            Speaker(label: "Back Left",   short: "BL", angle: 225, color: .init(red:0.96,green:0.48,blue:0.18,alpha:1), pos: .init(x:-d, y:0, z: d)),
            Speaker(label: "Left",        short: "L",  angle: 270, color: .init(red:0.76,green:0.28,blue:0.52,alpha:1), pos: .init(x:-r, y:0, z: 0)),
            Speaker(label: "Front Left",  short: "FL", angle: 315, color: .init(red:0.52,green:0.32,blue:0.88,alpha:1), pos: .init(x:-d, y:0, z:-d)),
        ]
    }()

    // MARK: - UI Elements

    private var speakerViews: [SpeakerDot] = []
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Header
    private let tipBanner = UIView()

    // Stats row
    private let roundPill = PillLabel()
    private let scorePill = PillLabel()

    // Arena
    private let arenaCard = UIView()
    private let arenaInner = UIView()
    private let ringLayer = CAShapeLayer()

    // Bottom
    private let instructionLabel = UILabel()
    private let replayBtn = UIButton(type: .system)
    private let progressBar = UIProgressView(progressViewStyle: .default)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sound Localization"
        view.backgroundColor = .lcBackground
        navigationController?.navigationBar.prefersLargeTitles = false

        setupAudio()
        buildUI()
        startRound()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasLaidOut, arenaInner.bounds.width > 0 else { return }
        hasLaidOut = true
        layoutArena()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioEngine?.stop()
    }

    // MARK: - Audio

    private func setupAudio() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default)
            try s.setActive(true)
        } catch { print("[SoundLoc] session: \(error)") }

        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()
        playerNode = AVAudioPlayerNode()

        audioEngine.attach(environmentNode)
        audioEngine.attach(playerNode)

        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.connect(playerNode, to: environmentNode, format: fmt)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)

        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0)
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        environmentNode.distanceAttenuationParameters.referenceDistance = 0.5
        environmentNode.distanceAttenuationParameters.maximumDistance = 30.0
        environmentNode.distanceAttenuationParameters.rolloffFactor = 1.0

        audioBuffer = makeBeep(fmt)

        do { try audioEngine.start() }
        catch { print("[SoundLoc] engine: \(error)") }
    }

    private func makeBeep(_ fmt: AVAudioFormat) -> AVAudioPCMBuffer {
        let sr = fmt.sampleRate
        let dur = 0.6
        let n = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        buf.frameLength = n
        let d = buf.floatChannelData![0]
        let freq: Float = 1000
        for i in 0..<Int(n) {
            let t = Float(i) / Float(sr)
            var env: Float = 1
            if t < 0.02 { env = t / 0.02 }
            if t > Float(dur) - 0.02 { env = (Float(dur) - t) / 0.02 }
            d[i] = sin(2 * .pi * freq * t) * 0.95 * env
        }
        return buf
    }

    private func playFromSpeaker(_ idx: Int) {
        let sp = speakers[idx]
        playerNode.position = sp.pos
        playerNode.renderingAlgorithm = .HRTFHQ
        playerNode.stop()
        playerNode.scheduleBuffer(audioBuffer, at: nil, options: [])
        playerNode.play()
        playerNode.volume = 1.0
        environmentNode.outputVolume = 1.0
    }

    // MARK: - Build UI

    private func buildUI() {
        // Scroll view
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        let pad: CGFloat = 16

        // 1) Headphone tip banner
        buildTipBanner()
        tipBanner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tipBanner)

        // 2) Progress bar
        progressBar.progressTintColor = .lcPurple
        progressBar.trackTintColor = UIColor.lcPurple.withAlphaComponent(0.12)
        progressBar.progress = 0
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressBar)

        // 3) Stats row
        roundPill.translatesAutoresizingMaskIntoConstraints = false
        scorePill.translatesAutoresizingMaskIntoConstraints = false
        roundPill.update(icon: "number.circle.fill", text: "Round 1 / \(totalRounds)", tint: .secondaryLabel)
        scorePill.update(icon: "checkmark.circle.fill", text: "0 correct", tint: .lcPurple)
        contentView.addSubview(roundPill)
        contentView.addSubview(scorePill)

        // 4) Arena card
        arenaCard.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1)
        arenaCard.layer.cornerRadius = LC.cornerRadius
        arenaCard.clipsToBounds = true
        arenaCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arenaCard)

        arenaInner.translatesAutoresizingMaskIntoConstraints = false
        arenaCard.addSubview(arenaInner)

        // Ear icon at center
        let earBg = UIView()
        earBg.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        earBg.layer.cornerRadius = 24
        earBg.translatesAutoresizingMaskIntoConstraints = false
        arenaInner.addSubview(earBg)
        let ear = UIImageView(image: UIImage(systemName: "ear.fill"))
        ear.tintColor = UIColor.white.withAlphaComponent(0.25)
        ear.contentMode = .scaleAspectFit
        ear.translatesAutoresizingMaskIntoConstraints = false
        earBg.addSubview(ear)

        // Speaker dots
        for (i, sp) in speakers.enumerated() {
            let dot = SpeakerDot(color: sp.color, short: sp.short, name: sp.label, index: i)
            dot.onTap = { [weak self] idx in self?.speakerTapped(idx) }
            arenaInner.addSubview(dot)
            speakerViews.append(dot)
        }

        // 5) Instruction label
        instructionLabel.text = "Listen carefully..."
        instructionLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        instructionLabel.textColor = .label
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        // 6) Replay button — fixed width, no wrapping
        configureReplayButton()
        replayBtn.translatesAutoresizingMaskIntoConstraints = false
        replayBtn.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        contentView.addSubview(replayBtn)

        // MARK: Layout constraints
        NSLayoutConstraint.activate([
            // Tip banner
            tipBanner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tipBanner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            tipBanner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            // Progress bar
            progressBar.topAnchor.constraint(equalTo: tipBanner.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            progressBar.heightAnchor.constraint(equalToConstant: 5),

            // Stats row
            roundPill.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            roundPill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            scorePill.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            scorePill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            // Arena card
            arenaCard.topAnchor.constraint(equalTo: roundPill.bottomAnchor, constant: 14),
            arenaCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            arenaCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            arenaCard.heightAnchor.constraint(equalTo: arenaCard.widthAnchor),

            arenaInner.topAnchor.constraint(equalTo: arenaCard.topAnchor),
            arenaInner.leadingAnchor.constraint(equalTo: arenaCard.leadingAnchor),
            arenaInner.trailingAnchor.constraint(equalTo: arenaCard.trailingAnchor),
            arenaInner.bottomAnchor.constraint(equalTo: arenaCard.bottomAnchor),

            earBg.centerXAnchor.constraint(equalTo: arenaInner.centerXAnchor),
            earBg.centerYAnchor.constraint(equalTo: arenaInner.centerYAnchor),
            earBg.widthAnchor.constraint(equalToConstant: 48),
            earBg.heightAnchor.constraint(equalToConstant: 48),
            ear.centerXAnchor.constraint(equalTo: earBg.centerXAnchor),
            ear.centerYAnchor.constraint(equalTo: earBg.centerYAnchor),
            ear.widthAnchor.constraint(equalToConstant: 24),
            ear.heightAnchor.constraint(equalToConstant: 24),

            // Instruction
            instructionLabel.topAnchor.constraint(equalTo: arenaCard.bottomAnchor, constant: 18),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),

            // Replay button — centered, fixed size so text never wraps
            replayBtn.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 14),
            replayBtn.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            replayBtn.heightAnchor.constraint(equalToConstant: 50),
            replayBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
        ])
    }

    private func buildTipBanner() {
        tipBanner.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.08)
        tipBanner.layer.cornerRadius = 12

        let icon = UIImageView(image: UIImage(systemName: "headphones"))
        icon.tintColor = .lcPurple
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "Wear headphones for the best spatial audio experience"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.lcPurple.withAlphaComponent(0.9)
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.spacing = 10
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 10, leading: 14, bottom: 10, trailing: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        tipBanner.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tipBanner.topAnchor),
            stack.leadingAnchor.constraint(equalTo: tipBanner.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: tipBanner.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: tipBanner.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    /// Configure Replay button so the title never wraps.
    private func configureReplayButton() {
        var cfg = UIButton.Configuration.filled()
        cfg.image = UIImage(systemName: "speaker.wave.2.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        cfg.title = "Replay Sound"
        cfg.imagePadding = 8
        cfg.baseBackgroundColor = .lcPurple
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 12, leading: 28, bottom: 12, trailing: 28)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr
            a.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return a
        }
        replayBtn.configuration = cfg
        // Prevent multi-line
        replayBtn.titleLabel?.numberOfLines = 1
        replayBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        replayBtn.titleLabel?.minimumScaleFactor = 0.8
        replayBtn.titleLabel?.lineBreakMode = .byClipping
    }

    private func layoutArena() {
        let s = arenaInner.bounds.size
        let cx = s.width / 2, cy = s.height / 2
        let r = min(cx, cy) * 0.70
        let dotSize: CGFloat = 60

        // Outer ring
        ringLayer.path = UIBezierPath(
            arcCenter: .init(x: cx, y: cy), radius: r,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.white.withAlphaComponent(0.07).cgColor
        ringLayer.lineWidth = 1.5
        ringLayer.lineDashPattern = [5, 7]
        arenaInner.layer.insertSublayer(ringLayer, at: 0)

        // Inner ring (smaller, for depth)
        let innerRing = CAShapeLayer()
        innerRing.path = UIBezierPath(
            arcCenter: .init(x: cx, y: cy), radius: r * 0.42,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath
        innerRing.fillColor = UIColor.clear.cgColor
        innerRing.strokeColor = UIColor.white.withAlphaComponent(0.04).cgColor
        innerRing.lineWidth = 1
        innerRing.lineDashPattern = [3, 6]
        arenaInner.layer.insertSublayer(innerRing, at: 0)

        // Radial lines from center outward
        for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
            let rad = (angle - 90) * .pi / 180
            let line = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: .init(x: cx + 30 * cos(rad), y: cy + 30 * sin(rad)))
            path.addLine(to: .init(x: cx + (r - dotSize / 2 - 6) * cos(rad),
                                   y: cy + (r - dotSize / 2 - 6) * sin(rad)))
            line.path = path.cgPath
            line.strokeColor = UIColor.white.withAlphaComponent(0.04).cgColor
            line.lineWidth = 1
            arenaInner.layer.insertSublayer(line, at: 0)
        }

        // Place speaker dots
        for (i, dot) in speakerViews.enumerated() {
            let deg = speakers[i].angle - 90
            let rad = deg * .pi / 180
            let x = cx + r * cos(rad) - dotSize / 2
            let y = cy + r * sin(rad) - dotSize / 2
            dot.frame = CGRect(x: x, y: y, width: dotSize, height: dotSize)
            dot.layer.cornerRadius = dotSize / 2
        }
    }

    // MARK: - Game Loop

    private func startRound() {
        currentRound += 1
        waitingForInput = false

        roundPill.update(icon: "number.circle.fill", text: "Round \(currentRound) / \(totalRounds)", tint: .secondaryLabel)
        instructionLabel.text = "Listen carefully..."
        instructionLabel.textColor = .label

        UIView.animate(withDuration: 0.3) {
            self.progressBar.setProgress(Float(self.currentRound - 1) / Float(self.totalRounds), animated: true)
        }

        for dot in speakerViews { dot.setState(.idle) }

        DispatchQueue.main.asyncAfter(deadline: .now() + preDelay) { [weak self] in
            self?.doPlay()
        }
    }

    private func doPlay() {
        activeSpeakerIndex = Int.random(in: 0..<speakers.count)
        playFromSpeaker(activeSpeakerIndex)
        instructionLabel.text = "Where did the sound come from?"
        waitingForInput = true
        for dot in speakerViews { dot.setState(.active) }
    }

    private func speakerTapped(_ idx: Int) {
        guard waitingForInput else { return }
        waitingForInput = false
        lcHaptic(.medium)

        let ok = idx == activeSpeakerIndex
        if ok {
            correctCount += 1
            speakerViews[idx].setState(.correct)
            instructionLabel.text = "Correct! 🎯"
            instructionLabel.textColor = UIColor(red: 0.12, green: 0.72, blue: 0.32, alpha: 1)
            lcHapticSuccess()
        } else {
            speakerViews[idx].setState(.wrong)
            speakerViews[activeSpeakerIndex].setState(.reveal)
            instructionLabel.text = "It was \(speakers[activeSpeakerIndex].label)"
            instructionLabel.textColor = UIColor(red: 0.92, green: 0.52, blue: 0.12, alpha: 1)
        }

        for (i, dot) in speakerViews.enumerated() {
            if i != idx && i != activeSpeakerIndex { dot.setState(.dimmed) }
        }

        scorePill.update(icon: "checkmark.circle.fill", text: "\(correctCount)/\(currentRound) correct", tint: .lcPurple)

        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) { [weak self] in
            guard let self else { return }
            if self.currentRound >= self.totalRounds { self.finish() }
            else { self.startRound() }
        }
    }

    private func finish() {
        let pct = Int(Double(correctCount) / Double(totalRounds) * 100)
        progressBar.setProgress(1.0, animated: true)
        instructionLabel.text = "Training Complete!\n\(correctCount) of \(totalRounds) correct (\(pct)%)"
        instructionLabel.textColor = .label
        for dot in speakerViews { dot.setState(.idle) }

        var cfg = UIButton.Configuration.filled()
        cfg.image = UIImage(systemName: "checkmark.circle.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        cfg.title = "Done"
        cfg.imagePadding = 8
        cfg.baseBackgroundColor = .lcGreen
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .large
        cfg.contentInsets = .init(top: 12, leading: 28, bottom: 12, trailing: 28)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr
            a.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return a
        }
        replayBtn.configuration = cfg
        replayBtn.removeTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        replayBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    }

    @objc private func replayTapped() {
        guard waitingForInput, activeSpeakerIndex >= 0 else { return }
        playFromSpeaker(activeSpeakerIndex)
        lcHaptic(.light)

        // Brief visual feedback on the button
        UIView.animate(withDuration: 0.08, animations: {
            self.replayBtn.transform = .init(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                self.replayBtn.transform = .identity
            }
        }
    }

    @objc private func doneTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Pill Label

private final class PillLabel: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 14
        backgroundColor = UIColor.secondarySystemFill

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.spacing = 5
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 6, leading: 10, bottom: 6, trailing: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(icon name: String, text: String, tint: UIColor) {
        iconView.image = UIImage(systemName: name)
        iconView.tintColor = tint
        label.text = text
        label.textColor = tint
    }
}

// MARK: - Speaker Dot

private final class SpeakerDot: UIView {

    enum State { case idle, active, dimmed, correct, wrong, reveal }

    let index: Int
    var onTap: ((Int) -> Void)?
    private let baseColor: UIColor
    private let shortLbl = UILabel()
    private let nameLbl = UILabel()
    private let glowLayer = CALayer()

    init(color: UIColor, short: String, name: String, index: Int) {
        self.baseColor = color
        self.index = index
        super.init(frame: .zero)

        clipsToBounds = false
        backgroundColor = color.withAlphaComponent(0.30)
        layer.borderWidth = 2.5
        layer.borderColor = color.cgColor

        // Glow behind the dot
        glowLayer.backgroundColor = color.withAlphaComponent(0.15).cgColor
        glowLayer.cornerRadius = 38
        glowLayer.frame = CGRect(x: -8, y: -8, width: 76, height: 76)
        layer.insertSublayer(glowLayer, at: 0)

        shortLbl.text = short
        shortLbl.font = .monospacedSystemFont(ofSize: 15, weight: .bold)
        shortLbl.textColor = .white
        shortLbl.textAlignment = .center
        shortLbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shortLbl)

        nameLbl.text = name
        nameLbl.font = .systemFont(ofSize: 7, weight: .semibold)
        nameLbl.textColor = UIColor.white.withAlphaComponent(0.6)
        nameLbl.textAlignment = .center
        nameLbl.adjustsFontSizeToFitWidth = true
        nameLbl.minimumScaleFactor = 0.5
        nameLbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLbl)

        let nameWidth = nameLbl.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -4)
        nameWidth.priority = .defaultHigh   // avoid conflict before frame is set

        NSLayoutConstraint.activate([
            shortLbl.centerXAnchor.constraint(equalTo: centerXAnchor),
            shortLbl.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
            nameLbl.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLbl.topAnchor.constraint(equalTo: shortLbl.bottomAnchor, constant: 0),
            nameWidth,
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gSize = bounds.width + 16
        glowLayer.frame = CGRect(
            x: (bounds.width - gSize) / 2,
            y: (bounds.height - gSize) / 2,
            width: gSize, height: gSize
        )
        glowLayer.cornerRadius = gSize / 2
    }

    func setState(_ s: State) {
        layer.removeAllAnimations()
        transform = .identity
        alpha = 1
        switch s {
        case .idle:
            backgroundColor = baseColor.withAlphaComponent(0.15)
            layer.borderColor = baseColor.withAlphaComponent(0.30).cgColor
            layer.borderWidth = 2
            glowLayer.backgroundColor = baseColor.withAlphaComponent(0.06).cgColor
        case .active:
            backgroundColor = baseColor.withAlphaComponent(0.38)
            layer.borderColor = baseColor.cgColor
            layer.borderWidth = 2.5
            glowLayer.backgroundColor = baseColor.withAlphaComponent(0.15).cgColor
        case .dimmed:
            backgroundColor = baseColor.withAlphaComponent(0.06)
            layer.borderColor = baseColor.withAlphaComponent(0.12).cgColor
            alpha = 0.30
            glowLayer.backgroundColor = UIColor.clear.cgColor
        case .correct:
            backgroundColor = UIColor(red:0.12,green:0.75,blue:0.32,alpha:0.50)
            layer.borderColor = UIColor(red:0.12,green:0.82,blue:0.32,alpha:1).cgColor
            layer.borderWidth = 3
            glowLayer.backgroundColor = UIColor(red:0.12,green:0.82,blue:0.32,alpha:0.20).cgColor
            bounce()
        case .wrong:
            backgroundColor = UIColor(red:0.88,green:0.20,blue:0.20,alpha:0.40)
            layer.borderColor = UIColor(red:0.92,green:0.22,blue:0.22,alpha:1).cgColor
            layer.borderWidth = 3
            glowLayer.backgroundColor = UIColor(red:0.92,green:0.22,blue:0.22,alpha:0.15).cgColor
            shake()
        case .reveal:
            backgroundColor = UIColor(red:0.12,green:0.75,blue:0.32,alpha:0.50)
            layer.borderColor = UIColor(red:0.12,green:0.82,blue:0.32,alpha:1).cgColor
            layer.borderWidth = 3
            glowLayer.backgroundColor = UIColor(red:0.12,green:0.82,blue:0.32,alpha:0.20).cgColor
            pulse()
        }
    }

    @objc private func tap() { onTap?(index) }

    private func bounce() {
        UIView.animate(withDuration: 0.12, animations: {
            self.transform = .init(scaleX: 1.18, y: 1.18)
        }) { _ in UIView.animate(withDuration: 0.12) { self.transform = .identity } }
    }

    private func shake() {
        let a = CAKeyframeAnimation(keyPath: "transform.translation.x")
        a.values = [-7, 7, -5, 5, -2, 2, 0]
        a.duration = 0.35
        layer.add(a, forKey: "s")
    }

    private func pulse() {
        UIView.animate(withDuration: 0.35, delay: 0,
                       options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.transform = .init(scaleX: 1.12, y: 1.12)
        }
    }
}
