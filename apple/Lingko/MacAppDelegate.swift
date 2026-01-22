//
//  MacAppDelegate.swift
//  Lingko
//
//  macOS-specific app delegate for Services menu, shortcuts, and window management
//

#if os(macOS)
import AppKit
import SwiftUI
import ServiceManagement

extension Notification.Name {
    static let translateText = Notification.Name("translateText")
    static let pasteAndTranslate = Notification.Name("pasteAndTranslate")
    static let importImage = Notification.Name("importImage")
}

class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up services provider
        NSApp.servicesProvider = self

        // Configure app menu
        setupMenuBar()

        // Register global keyboard shortcuts
        setupKeyboardShortcuts()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Bar Setup
    private func setupMenuBar() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // File menu enhancements
        if let fileMenu = mainMenu.item(withTitle: "File")?.submenu {
            let importItem = NSMenuItem(
                title: "Import Image...",
                action: #selector(importImage),
                keyEquivalent: "i"
            )
            importItem.keyEquivalentModifierMask = .command
            fileMenu.insertItem(importItem, at: 1)
        }

        // Edit menu enhancements
        if let editMenu = mainMenu.item(withTitle: "Edit")?.submenu {
            editMenu.addItem(NSMenuItem.separator())
            let copyTranslationItem = NSMenuItem(
                title: "Copy Translation",
                action: #selector(copyTranslation),
                keyEquivalent: "c"
            )
            copyTranslationItem.keyEquivalentModifierMask = [.command, .shift]
            editMenu.addItem(copyTranslationItem)

            let pasteAndTranslateItem = NSMenuItem(
                title: "Paste and Translate",
                action: #selector(pasteAndTranslate),
                keyEquivalent: "v"
            )
            pasteAndTranslateItem.keyEquivalentModifierMask = .command
            editMenu.addItem(pasteAndTranslateItem)
        }

        // View menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = viewMenu

        let historyItem = NSMenuItem(
            title: "History",
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(historyItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        viewMenu.addItem(settingsItem)

        mainMenu.insertItem(viewMenuItem, at: 3)
    }

    // MARK: - Keyboard Shortcuts
    private func setupKeyboardShortcuts() {
        // Shortcuts are handled via menu items' key equivalents
        // Additional global shortcuts can be added here using NSEvent.addLocalMonitorForEvents
    }

    // MARK: - Menu Actions
    @objc private func importImage() {
        NotificationCenter.default.post(name: .importImage, object: nil)
    }

    @objc private func copyTranslation() {
        // This will be handled by the active view
        NotificationCenter.default.post(name: Notification.Name("copyTranslation"), object: nil)
    }

    @objc private func pasteAndTranslate() {
        NotificationCenter.default.post(name: .pasteAndTranslate, object: nil)
    }

    @objc private func showHistory() {
        NotificationCenter.default.post(name: Notification.Name("showHistory"), object: nil)
    }

    @objc private func showSettings() {
        NotificationCenter.default.post(name: Notification.Name("showSettings"), object: nil)
    }

    // MARK: - Services Menu
    @objc func translateText(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let text = pasteboard.string(forType: .string) else { return }

        // Post notification to main view to handle translation
        NotificationCenter.default.post(name: .translateText, object: text)

        // Activate the app to show the translation
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Launch at Login Helper
extension MacAppDelegate {
    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    static func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
#endif
