// HomeViewController.swift
// LangCI
//
// Production-quality UIKit dashboard for Home screen with scrollable layout,
// gradient hero header, level/points card, stats, quick actions, and recent activity.

import UIKit

// MARK: - Recent Activity (unified model for both session types)

enum RecentActivity {
    case word(TrainingSession)
    case sound(EnvironmentalSoundSession)

    var date: Date {
        switch self {
        case .word(let s):  return s.startedAt
        case .sound(let s): return s.startedAt
        }
    }
}

// MARK: - HomeViewController

final class HomeViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let containerStack = UIStackView()

    // Wow-factor hero: animated gradient + greeting
    private let heroHeaderView = AnimatedGradientHeroView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // Today's practice CTA card — big, coloured, tappable
    private let practiceCTA = PracticeCTACard()

    // Level & Points Card (unchanged) + daily goal ring
    private let levelCard = LCCard()
    private let levelBadge = UIView()
    private let levelBadgeLabel = UILabel()
    private let levelTitleLabel = UILabel()
    private let levelSubtitleLabel = UILabel()
    private let progressBar = ProgressBarView()
    private let progressCaption = UILabel()
    private let dailyGoalRing = DailyGoalRingView()

    // Stats Row (4 cards) with count-up numbers
    private let statsRow = UIStackView()
    private let streakCard = StatCardView(icon: "flame.fill", value: "0", label: "Streak", tint: .lcOrange)
    private let accuracyCard = StatCardView(icon: "target", value: "0%", label: "Accuracy", tint: .lcGreen)
    private let sessionsCard = StatCardView(icon: "books.vertical.fill", value: "0", label: "Sessions", tint: .lcBlue)
    private let badgesCard = StatCardView(icon: "medal.fill", value: "0", label: "Badges", tint: .lcGold)

    // Quick Actions (icon grid)
    private let actionsRow = UIStackView()
    private let secondaryActionsRow = UIStackView()

    // Sound Therapy card
    private let soundTherapyCard = LCCard()
    // Environmental Sound card
    private let envSoundCard = LCCard()

    // Recent Activity (collapsible)
    private let activityHeaderButton = UIButton(type: .system)
    private let activityChevron = UIImageView()
    private let activityHeaderContainer = UIView()
    private let activityTable = UITableView(frame: .zero, style: .plain)
    private var activityHeightConstraint: NSLayoutConstraint!
    private var isActivityExpanded = true

    // State
    private var recentActivities: [RecentActivity] = []
    private var homeStats: HomeStats?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar — the custom hero gradient replaces it
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadHomeData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore for pushed VCs that need a nav bar
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - UI Setup

    private func buildUI() {
        view.backgroundColor = .lcBackground

        // ---- Hero gradient pinned behind status bar (edge-to-edge) ----
        // The gradient extends from the very top of the screen through the
        // safe area and a bit beyond, so the greeting text sits inside the
        // safe area while the colour bleeds behind the status bar.
        heroHeaderView.translatesAutoresizingMaskIntoConstraints = false
        heroHeaderView.layer.cornerRadius = 0          // edge-to-edge, no rounding
        heroHeaderView.clipsToBounds = true
        view.addSubview(heroHeaderView)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        heroHeaderView.addSubview(loadingIndicator)

        // ---- Scroll view starts just below the hero ----
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)

        // Container stack (all cards)
        containerStack.axis = .vertical
        containerStack.spacing = LC.sectionSpacing
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerStack)

        // 1. Today's practice CTA (now the first item in the scroll)
        practiceCTA.addTarget(self, action: #selector(didTapStartTraining), for: .touchUpInside)
        containerStack.addArrangedSubview(practiceCTA)

        // 2. Level & Points Card (with daily-goal ring)
        buildLevelCard()
        containerStack.addArrangedSubview(levelCard)

        // 3. Stats Row
        buildStatsRow()
        containerStack.addArrangedSubview(statsRow)

        // 4. Quick Actions
        buildQuickActions()
        containerStack.addArrangedSubview(actionsRow)
        containerStack.addArrangedSubview(secondaryActionsRow)

        // 5. Sound Therapy card (above recent activity)
        buildSoundTherapyCard()
        containerStack.addArrangedSubview(soundTherapyCard)

        // 5b. Environmental Sound Training card
        buildEnvSoundCard()
        containerStack.addArrangedSubview(envSoundCard)

        // 6. Recent Activity (collapsible)
        buildActivityHeader()
        containerStack.addArrangedSubview(activityHeaderContainer)
        containerStack.addArrangedSubview(activityTable)

        // ---- Layout constraints ----
        NSLayoutConstraint.activate([
            // Hero: pinned to top, leading, trailing edges of the screen.
            // Bottom sits just below the safe area top + greeting height.
            heroHeaderView.topAnchor.constraint(equalTo: view.topAnchor),
            heroHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heroHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Height = safe-area-top (status bar) + greeting content (~90pt)
            heroHeaderView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90),

            loadingIndicator.centerXAnchor.constraint(equalTo: heroHeaderView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: heroHeaderView.centerYAnchor),

            // Scroll view starts right below the hero
            scrollView.topAnchor.constraint(equalTo: heroHeaderView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            containerStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: LC.sectionSpacing),
            containerStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -LC.cardPadding),
            containerStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: LC.cardPadding),
            containerStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -LC.cardPadding),
            containerStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2 * LC.cardPadding),

            practiceCTA.heightAnchor.constraint(equalToConstant: 110)
        ])

        activityHeightConstraint = activityTable.heightAnchor.constraint(equalToConstant: 200)
        activityHeightConstraint.isActive = true
    }

    private func buildLevelCard() {
        levelCard.translatesAutoresizingMaskIntoConstraints = false
        let padding = LC.cardPadding

        // Level badge (circle on left)
        levelBadge.translatesAutoresizingMaskIntoConstraints = false
        levelBadge.backgroundColor = .lcBlue
        levelBadge.layer.cornerRadius = 28
        levelBadge.clipsToBounds = true

        levelBadgeLabel.text = "1"
        levelBadgeLabel.font = UIFont.lcCardValue()
        levelBadgeLabel.textColor = .white
        levelBadgeLabel.textAlignment = .center
        levelBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        levelBadge.addSubview(levelBadgeLabel)
        NSLayoutConstraint.activate([
            levelBadgeLabel.centerXAnchor.constraint(equalTo: levelBadge.centerXAnchor),
            levelBadgeLabel.centerYAnchor.constraint(equalTo: levelBadge.centerYAnchor)
        ])

        // Right side: title, subtitle, progress bar, caption
        levelTitleLabel.text = "Level 1"
        levelTitleLabel.font = UIFont.lcBodyBold()
        levelTitleLabel.textColor = .label
        levelTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        levelSubtitleLabel.text = "0 points"
        levelSubtitleLabel.font = UIFont.lcCaption()
        levelSubtitleLabel.textColor = .secondaryLabel
        levelSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        progressBar.color = .lcBlue
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        progressCaption.text = "0 pts to Level 2"
        progressCaption.font = UIFont.lcCaption()
        progressCaption.textColor = .secondaryLabel
        progressCaption.translatesAutoresizingMaskIntoConstraints = false

        // Vertical stack for right side
        let rightStack = UIStackView(arrangedSubviews: [
            levelTitleLabel,
            levelSubtitleLabel,
            progressBar,
            progressCaption
        ])
        rightStack.axis = .vertical
        rightStack.spacing = 6
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        // Daily goal ring on the far right of the level card
        dailyGoalRing.ringColor = .lcOrange
        dailyGoalRing.translatesAutoresizingMaskIntoConstraints = false

        // Horizontal stack for badge + right side + daily ring
        let hStack = UIStackView(arrangedSubviews: [levelBadge, rightStack, dailyGoalRing])
        hStack.axis = .horizontal
        hStack.spacing = 16
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        levelCard.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: levelCard.topAnchor, constant: padding),
            hStack.bottomAnchor.constraint(equalTo: levelCard.bottomAnchor, constant: -padding),
            hStack.leadingAnchor.constraint(equalTo: levelCard.leadingAnchor, constant: padding),
            hStack.trailingAnchor.constraint(equalTo: levelCard.trailingAnchor, constant: -padding),

            levelBadge.widthAnchor.constraint(equalToConstant: 56),
            levelBadge.heightAnchor.constraint(equalToConstant: 56),

            dailyGoalRing.widthAnchor.constraint(equalToConstant: 64),
            dailyGoalRing.heightAnchor.constraint(equalToConstant: 64),

            progressBar.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    private func buildStatsRow() {
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.spacing = 12
        statsRow.translatesAutoresizingMaskIntoConstraints = false

        statsRow.addArrangedSubview(streakCard)
        statsRow.addArrangedSubview(accuracyCard)
        statsRow.addArrangedSubview(sessionsCard)
        statsRow.addArrangedSubview(badgesCard)

        NSLayoutConstraint.activate([
            streakCard.heightAnchor.constraint(equalToConstant: 100),
            accuracyCard.heightAnchor.constraint(equalToConstant: 100),
            sessionsCard.heightAnchor.constraint(equalToConstant: 100),
            badgesCard.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func buildQuickActions() {
        // Row 1: Train + Ling 6
        actionsRow.axis = .horizontal
        actionsRow.distribution = .fillEqually
        actionsRow.spacing = 12
        actionsRow.translatesAutoresizingMaskIntoConstraints = false

        actionsRow.addArrangedSubview(
            makeActionTile(icon: "brain.head.profile", title: "Train",
                           color: .lcGreen, action: #selector(didTapStartTraining)))
        actionsRow.addArrangedSubview(
            makeActionTile(icon: "ear.and.waveform", title: "Ling 6",
                           color: .lcTeal, action: #selector(didTapLing6)))

        // Row 2: Confusion Drill + Read Newspaper
        secondaryActionsRow.axis = .horizontal
        secondaryActionsRow.distribution = .fillEqually
        secondaryActionsRow.spacing = 12
        secondaryActionsRow.translatesAutoresizingMaskIntoConstraints = false

        secondaryActionsRow.addArrangedSubview(
            makeActionTile(icon: "arrow.triangle.swap", title: "Confusion",
                           color: .lcPurple, action: #selector(didTapConfusionDrill)))
        secondaryActionsRow.addArrangedSubview(
            makeActionTile(icon: "newspaper.fill", title: "Read",
                           color: .lcOrange, action: #selector(didTapReadNewspaper)))
    }

    private func makeActionTile(icon: String, title: String,
                                 color: UIColor, action: Selector) -> UIControl {
        let tile = ActionTileView(icon: icon, title: title, color: color)
        tile.addTarget(self, action: action, for: .touchUpInside)
        return tile
    }

    // MARK: - Sound Therapy Card

    private func buildSoundTherapyCard() {
        soundTherapyCard.isUserInteractionEnabled = true
        soundTherapyCard.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapSoundTherapy))
        )

        // Gradient accent
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.lcPurple.withAlphaComponent(0.12).cgColor,
                                UIColor.lcTeal.withAlphaComponent(0.08).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = LC.cornerRadius
        soundTherapyCard.layer.insertSublayer(gradientLayer, at: 0)
        soundTherapyCard.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcPurple.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 22
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "ear.fill"))
        icon.tintColor = .lcPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
        ])

        // Text
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLbl = UILabel()
        titleLbl.text = "Sound Therapy"
        titleLbl.font = .systemFont(ofSize: 16, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = "Train your ears with sh, mm, ush sounds"
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(subtitleLbl)

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        soundTherapyCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: soundTherapyCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: soundTherapyCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: soundTherapyCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: soundTherapyCard.trailingAnchor, constant: -12),
        ])

        // Resize gradient on layout
        DispatchQueue.main.async { gradientLayer.frame = self.soundTherapyCard.bounds }
    }

    @objc private func didTapSoundTherapy() {
        let vc = SoundTherapyHomeViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Environmental Sound Card

    private func buildEnvSoundCard() {
        envSoundCard.isUserInteractionEnabled = true
        envSoundCard.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapEnvSound))
        )

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.lcGreen.withAlphaComponent(0.12).cgColor,
                                UIColor.lcAmber.withAlphaComponent(0.08).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = LC.cornerRadius
        envSoundCard.layer.insertSublayer(gradientLayer, at: 0)
        envSoundCard.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.lcGreen.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 22
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "waveform.badge.magnifyingglass"))
        icon.tintColor = .lcGreen
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
        ])

        // Text
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLbl = UILabel()
        titleLbl.text = "Environmental Sounds"
        titleLbl.font = .systemFont(ofSize: 16, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = "Identify everyday sounds — alarms, birds, traffic"
        subtitleLbl.font = UIFont.lcCaption()
        subtitleLbl.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(subtitleLbl)

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        envSoundCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: envSoundCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: envSoundCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: envSoundCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: envSoundCard.trailingAnchor, constant: -12),
        ])

        DispatchQueue.main.async { gradientLayer.frame = self.envSoundCard.bounds }
    }

    @objc private func didTapEnvSound() {
        let vc = EnvironmentalSoundHomeViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func buildActivityHeader() {
        activityHeaderContainer.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "RECENT ACTIVITY"
        titleLabel.font = UIFont.lcSectionTitle()
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        activityChevron.image = UIImage(systemName: "chevron.down")
        activityChevron.tintColor = .secondaryLabel
        activityChevron.contentMode = .scaleAspectFit
        activityChevron.translatesAutoresizingMaskIntoConstraints = false

        activityHeaderContainer.addSubview(titleLabel)
        activityHeaderContainer.addSubview(activityChevron)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: activityHeaderContainer.leadingAnchor, constant: LC.cardPadding),
            titleLabel.topAnchor.constraint(equalTo: activityHeaderContainer.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: activityHeaderContainer.bottomAnchor, constant: -4),

            activityChevron.trailingAnchor.constraint(equalTo: activityHeaderContainer.trailingAnchor, constant: -LC.cardPadding),
            activityChevron.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            activityChevron.widthAnchor.constraint(equalToConstant: 16),
            activityChevron.heightAnchor.constraint(equalToConstant: 16)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(didToggleActivity))
        activityHeaderContainer.addGestureRecognizer(tap)
        activityHeaderContainer.isUserInteractionEnabled = true
    }

    @objc private func didToggleActivity() {
        isActivityExpanded.toggle()

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.activityTable.isHidden = !self.isActivityExpanded
            self.activityTable.alpha = self.isActivityExpanded ? 1 : 0
            self.activityChevron.transform = self.isActivityExpanded
                ? .identity
                : CGAffineTransform(rotationAngle: -.pi / 2)
            self.containerStack.layoutIfNeeded()
        }
    }

    private func setupTableView() {
        activityTable.translatesAutoresizingMaskIntoConstraints = false
        activityTable.dataSource = self
        activityTable.delegate = self
        activityTable.backgroundColor = .lcBackground
        activityTable.separatorStyle = .singleLine
        activityTable.separatorInset = UIEdgeInsets(top: 0, left: LC.cardPadding, bottom: 0, right: LC.cardPadding)
        activityTable.register(ActivitySessionCell.self, forCellReuseIdentifier: ActivitySessionCell.identifier)
        activityTable.isScrollEnabled = false
    }

    // MARK: - Data Loading

    private func loadHomeData() {
        loadingIndicator.startAnimating()

        Task {
            do {
                // Load home stats and recent sessions in parallel
                async let stats = ServiceLocator.shared.progressService.getHomeStats()
                async let sessions = ServiceLocator.shared.trainingService.getRecentSessions(count: 5)
                async let envSessions = ServiceLocator.shared.environmentalSoundService!.getRecentSessions(count: 5)

                self.homeStats = try await stats
                let wordSessions = try await sessions
                let soundSessions = (try? await envSessions) ?? []

                // Merge both session types into unified recent activities
                var activities: [RecentActivity] = []
                activities += wordSessions.map { RecentActivity.word($0) }
                activities += soundSessions.map { RecentActivity.sound($0) }
                activities.sort { $0.date > $1.date }
                self.recentActivities = Array(activities.prefix(5))

                await MainActor.run {
                    self.updateUI()
                    self.loadingIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.showErrorState(error: error)
                }
            }
        }
    }

    private func updateUI() {
        guard let stats = homeStats else { return }

        // Update hero subtitle with greeting
        let streakSubtitle: String
        if stats.currentStreak > 0 {
            streakSubtitle = "🔥 \(stats.currentStreak)-day streak — keep it going!"
        } else {
            streakSubtitle = "A 3-minute drill keeps your ears sharp."
        }
        heroHeaderView.updateSubtitle(streakSubtitle)

        // Update level card
        levelBadgeLabel.text = "\(stats.currentLevel)"
        levelTitleLabel.text = "Level \(stats.currentLevel)"
        levelSubtitleLabel.text = "\(stats.totalPoints) points"

        // Calculate progress to next level
        let progressValue = stats.pointsForCurrentLevel > 0
            ? Double(stats.totalPoints - (stats.pointsForCurrentLevel - stats.pointsForNextLevel)) / Double(stats.pointsForCurrentLevel)
            : 0.0
        progressBar.setProgress(progressValue, animated: true)
        progressCaption.text = "\(stats.pointsToNextLevel) pts to Level \(stats.currentLevel + 1)"

        // Daily-goal ring: count today's sessions (cap at 3)
        let dailyGoal = 3
        let sessionsToday = countSessionsToday()
        let ringFraction = Double(min(sessionsToday, dailyGoal)) / Double(dailyGoal)
        dailyGoalRing.setProgress(ringFraction, done: sessionsToday, goal: dailyGoal)

        // Practice CTA caption changes based on goal progress
        if sessionsToday == 0 {
            practiceCTA.updateCaption("Start a 3-minute listening drill →")
        } else if sessionsToday < dailyGoal {
            practiceCTA.updateCaption("\(dailyGoal - sessionsToday) more to hit today's goal →")
        } else {
            practiceCTA.updateCaption("Goal reached — bonus round? →")
        }

        // Stats cards — use count-up on the numeric ones for a subtle
        // "wow" effect. Fall back to direct updates where the value is
        // formatted (accuracy %).
        animateStatCardValue(streakCard, to: stats.currentStreak)
        // Mirror the authoritative streak into StreakService's UserDefaults
        // cache so other screens can read it instantly, and fire confetti
        // if a milestone was just crossed.
        StreakService.shared.updateCache(
            current: stats.currentStreak,
            longest: stats.longestStreak
        )
        if let milestone = StreakService.shared.consumeNewMilestone(for: stats.currentStreak) {
            celebrateMilestone(milestone)
        }
        let accuracyPercent = stats.totalAttempts > 0
            ? Int(Double(stats.totalCorrect) / Double(stats.totalAttempts) * 100)
            : 0
        accuracyCard.update(value: "\(accuracyPercent)%")
        animateStatCardValue(sessionsCard, to: stats.totalSessions)
        animateStatCardValue(badgesCard, to: stats.badgesEarned)

        // Reload table with recent sessions
        activityTable.reloadData()
        updateTableHeight()
    }

    /// Tiny helper to spring the stat card's numeric value in a
    /// count-up instead of a snap.
    private func animateStatCardValue(_ card: StatCardView, to target: Int) {
        // StatCardView exposes only `update(value:)`, so we fake a
        // count-up by scheduling a short sequence of updates.
        let start = 0
        let steps = 12
        let stepDuration: TimeInterval = 0.04
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            // ease-out cubic
            let eased = 1 - pow(1 - t, 3)
            let val = Int(Double(start) + Double(target - start) * eased)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                card.update(value: "\(val)")
            }
        }
    }

    /// Count how many training sessions the user has completed since
    /// midnight local time. Used to fill the daily-goal ring.
    private func countSessionsToday() -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        return recentActivities.filter { $0.date >= start }.count
    }

    private func updateTableHeight() {
        // Calculate height based on row count
        let rowHeight: CGFloat = 60
        let estimatedHeight = CGFloat(recentActivities.count) * rowHeight
        activityHeightConstraint.constant = max(estimatedHeight, 60) // Min height for empty state
        view.layoutIfNeeded()
    }

    private func showErrorState(error: Error) {
        // Show brief error message
        let alert = UIAlertController(
            title: "Unable to Load Stats",
            message: "Please try again later.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Celebrate a newly-crossed streak milestone with confetti + an
    /// encouraging alert. The confetti fires from the top of the hero
    /// header so it rains down over the greeting.
    private func celebrateMilestone(_ milestone: Int) {
        let confetti = ConfettiView(frame: view.bounds)
        confetti.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(confetti)
        confetti.fire(duration: 2.5)

        let alert = UIAlertController(
            title: "🔥 \(milestone)-day streak!",
            message: StreakService.shared.milestoneMessage(for: milestone),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep going", style: .default))
        // Delay the alert slightly so confetti has a moment to appear
        // before a modal dims the screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.present(alert, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func didTapStartTraining() {
        NotificationCenter.default.post(name: Notification.Name("startTraining"), object: nil)
    }

    @objc private func didTapLing6() {
        NotificationCenter.default.post(name: Notification.Name("startLing6"), object: nil)
    }

    @objc private func didTapConfusionDrill() {
        let drill = ConfusionDrillViewController()
        navigationController?.pushViewController(drill, animated: true)
    }

    @objc private func didTapReadNewspaper() {
        let quickRead = QuickReadViewController()
        navigationController?.pushViewController(quickRead, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentActivities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ActivitySessionCell.identifier, for: indexPath) as! ActivitySessionCell
        let activity = recentActivities[indexPath.row]
        switch activity {
        case .word(let session):
            cell.configure(with: session)
        case .sound(let session):
            cell.configureSound(with: session)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Future: navigate to session detail if needed
    }
}

// MARK: - ActivitySessionCell

final class ActivitySessionCell: UITableViewCell {

    static let identifier = "ActivitySessionCell"

    private let dateLabel = UILabel()
    private let detailLabel = UILabel()
    private let modeIcon = UIImageView()
    private let accuracyLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildCell()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func buildCell() {
        backgroundColor = .lcCard
        selectionStyle = .gray

        dateLabel.font = UIFont.lcBodyBold()
        dateLabel.textColor = .label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = UIFont.lcCaption()
        detailLabel.textColor = .secondaryLabel
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        modeIcon.translatesAutoresizingMaskIntoConstraints = false
        modeIcon.contentMode = .scaleAspectFit

        accuracyLabel.font = UIFont.lcBodyBold()
        accuracyLabel.textColor = .lcGreen
        accuracyLabel.textAlignment = .right
        accuracyLabel.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [dateLabel, detailLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [modeIcon, leftStack, accuracyLabel])
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LC.cardPadding),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LC.cardPadding),
            modeIcon.widthAnchor.constraint(equalToConstant: 24),
            modeIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(with session: TrainingSession) {
        // Format date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: session.startedAt)

        // Build detail string
        let modeSymbol = modeString(for: session.trainingMode)
        detailLabel.text = "\(session.totalWords) words • \(modeSymbol)"

        // Set mode icon
        let icon = iconForMode(session.trainingMode)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        modeIcon.image = UIImage(systemName: icon, withConfiguration: cfg)
        modeIcon.tintColor = colorForMode(session.trainingMode)

        // Calculate accuracy
        let accuracy = session.totalWords > 0
            ? Int(Double(session.completedWords) / Double(session.totalWords) * 100)
            : 0
        accuracyLabel.text = "\(accuracy)%"
    }

    func configureSound(with session: EnvironmentalSoundSession) {
        // Format date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: session.startedAt)

        // Build detail string
        let envLabel = SoundEnvironment(rawValue: session.environment)?.label ?? session.environment.capitalized
        detailLabel.text = "\(session.totalItems) sounds • \(envLabel)"

        // Set icon for environmental sound
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        modeIcon.image = UIImage(systemName: "waveform.badge.magnifyingglass", withConfiguration: cfg)
        modeIcon.tintColor = .lcGreen

        // Calculate accuracy
        let accuracy = session.totalItems > 0
            ? Int(Double(session.correctItems) / Double(session.totalItems) * 100)
            : 0
        accuracyLabel.text = "\(accuracy)%"
        accuracyLabel.textColor = accuracy >= 80 ? .lcGreen : (accuracy >= 50 ? .lcAmber : .lcRed)
    }

    private func modeString(for mode: TrainingMode) -> String {
        switch mode {
        case .standard:
            return "Standard"
        case .noisyEnvironment:
            return "Noisy"
        case .minimalPairs:
            return "Pairs"
        }
    }

    private func iconForMode(_ mode: TrainingMode) -> String {
        switch mode {
        case .standard:
            return "waveform.circle.fill"
        case .noisyEnvironment:
            return "waveform.circle"
        case .minimalPairs:
            return "waveform.badge.magnifyingglass"
        }
    }

    private func colorForMode(_ mode: TrainingMode) -> UIColor {
        switch mode {
        case .standard:
            return .lcBlue
        case .noisyEnvironment:
            return .lcOrange
        case .minimalPairs:
            return .lcTeal
        }
    }
}

// MARK: - ActionTileView

/// Compact icon + label tile for quick actions on the Home screen.
final class ActionTileView: UIControl {

    init(icon: String, title: String, color: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .lcCard
        layer.cornerRadius = LC.cornerRadius
        lcApplyShadow()

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 76)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }
}
