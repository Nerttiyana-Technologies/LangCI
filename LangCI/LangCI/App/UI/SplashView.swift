// SplashView.swift
// LangCI
//
// Branded splash overlay shown briefly on app launch.
// Displays a blue-to-teal gradient with the app icon centered,
// the app name, and a tagline. Fades out after a short delay.

import UIKit

final class SplashView: UIView {

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Gradient

    private let gradientLayer: CAGradientLayer = {
        let gl = CAGradientLayer()
        // Deep navy → teal, matching the app's brand palette
        gl.colors = [
            UIColor(red: 0.07, green: 0.13, blue: 0.28, alpha: 1).cgColor,
            UIColor(red: 0.09, green: 0.47, blue: 0.55, alpha: 1).cgColor
        ]
        gl.startPoint = CGPoint(x: 0.5, y: 0)
        gl.endPoint   = CGPoint(x: 0.5, y: 1)
        return gl
    }()

    // MARK: - Build

    private func buildUI() {
        layer.insertSublayer(gradientLayer, at: 0)

        // Logo — use the pre-sized 400×400 LaunchLogo to avoid
        // decoding the full 1024×1024 AppIcon on the main thread.
        let logoView = UIImageView()
        if let icon = UIImage(named: "LaunchLogo") ?? UIImage(named: "AppIcon-Light") {
            logoView.image = icon
        }
        logoView.contentMode = .scaleAspectFit
        logoView.layer.cornerRadius = 28
        logoView.clipsToBounds = true
        logoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoView)

        // App name
        let nameLabel = UILabel()
        nameLabel.text = "LangCI"
        nameLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        // Tagline
        let tagline = UILabel()
        tagline.text = "Voice Training for CI Users"
        tagline.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        tagline.textColor = UIColor.white.withAlphaComponent(0.7)
        tagline.textAlignment = .center
        tagline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tagline)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50),
            logoView.widthAnchor.constraint(equalToConstant: 120),
            logoView.heightAnchor.constraint(equalToConstant: 120),

            nameLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 20),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            tagline.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            tagline.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    // MARK: - Animate out

    /// Fades out the splash and removes it from the view hierarchy.
    func dismissAnimated(delay: TimeInterval = 1.2, duration: TimeInterval = 0.5,
                         completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
