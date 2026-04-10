// MainTabBarController.swift
// LangCI

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        styleTabBar()
        listenForQuickActions()
    }

    // MARK: - Setup

    private func setupTabs() {
        viewControllers = [
            makeTab(root: HomeViewController(),
                    title: "Home",    image: "house",              selectedImage: "house.fill",            tag: 0),
            makeTab(root: TrainViewController(),
                    title: "Train",   image: "brain.head.profile", selectedImage: "brain.head.profile",    tag: 1),
            makeTab(root: LibraryViewController(),
                    title: "Library", image: "books.vertical",     selectedImage: "books.vertical.fill",   tag: 2),
            makeTab(root: RecordViewController(),
                    title: "Record",  image: "mic",                selectedImage: "mic.fill",              tag: 3),
            makeTab(root: ReportsViewController(),
                    title: "Reports", image: "chart.bar",          selectedImage: "chart.bar.fill",        tag: 4),
            makeTab(root: CIHubViewController(),
                    title: "CI Hub",  image: "waveform.path.ecg",  selectedImage: "waveform.path.ecg",     tag: 5),
            makeTab(root: SettingsViewController(),
                    title: "Settings",image: "gearshape",          selectedImage: "gearshape.fill",        tag: 6),
            makeTab(root: AVTViewController(),
                    title: "AVT",     image: "ear.and.waveform",   selectedImage: "ear.and.waveform",      tag: 7)
        ]
    }

    private func makeTab(root: UIViewController, title: String,
                         image: String, selectedImage: String, tag: Int) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: image),
            selectedImage: UIImage(systemName: selectedImage)
        )
        nav.tabBarItem.tag     = tag
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    // MARK: - Quick-action notifications from Home tab

    private func listenForQuickActions() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleStartTraining),
            name: Notification.Name("startTraining"), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleStartLing6),
            name: Notification.Name("startLing6"), object: nil)
    }

    @objc private func handleStartTraining() { selectedIndex = 1 }
    @objc private func handleStartLing6()    { selectedIndex = 5 }

    // MARK: - Styling

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        let item = UITabBarItemAppearance()
        item.selected.iconColor = .lcBlue
        item.selected.titleTextAttributes = [.foregroundColor: UIColor.lcBlue]
        item.normal.iconColor   = .secondaryLabel
        item.normal.titleTextAttributes   = [.foregroundColor: UIColor.secondaryLabel]

        appearance.stackedLayoutAppearance = item
        tabBar.standardAppearance   = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
