//
//  AppDelegate.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var shouldPasteAndTranslate = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Quick Actions
        configureQuickActions()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if launched from quick action
        if let shortcutItem = options.shortcutItem,
           shortcutItem.type == "com.lingko.app.pasteAndTranslate" {
            AppDelegate.shouldPasteAndTranslate = true
        }

        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    private func configureQuickActions() {
        let pasteAction = UIApplicationShortcutItem(
            type: "com.lingko.app.pasteAndTranslate",
            localizedTitle: "Paste & Translate",
            localizedSubtitle: "Translate clipboard text",
            icon: UIApplicationShortcutIcon(systemImageName: "doc.on.clipboard"),
            userInfo: nil
        )

        UIApplication.shared.shortcutItems = [pasteAction]
    }
}

// MARK: - Scene Delegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.lingko.app.pasteAndTranslate" {
            AppDelegate.shouldPasteAndTranslate = true
            NotificationCenter.default.post(name: NSNotification.Name("PasteAndTranslate"), object: nil)
        }
        completionHandler(true)
    }
}
#endif
