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
            makeTab(root: MoreViewController(),
                    title: "More",    image: "ellipsis.circle",    selectedImage: "ellipsis.circle.fill",  tag: 4),
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
    @objc private func handleStartLing6() {
        // CI Hub is now inside the More tab — navigate into it
        selectedIndex = 4
        if let moreNav = viewControllers?[4] as? UINavigationController,
           let more = moreNav.viewControllers.first as? MoreViewController {
            moreNav.popToRootViewController(animated: false)
            // Push CIHub after a brief delay so the More tab is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                moreNav.pushViewController(CIHubViewController(), animated: true)
            }
        }
    }

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
