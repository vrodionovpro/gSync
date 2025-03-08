import Cocoa

/// Класс для управления системным меню приложения.
/// Отвечает за отображение иконки, пунктов меню и динамического обновления списка папок.
/// Не зависит от внутренней логики хранения папок.
class MenuManager: NSObject {
    static let shared = MenuManager()
    private var statusMenu: NSMenu!
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupMenu()
        statusItem.menu = statusMenu
        setupStatusBarAppearance()
    }

    /// Инициализирует базовое меню с фиксированными пунктами.
    private func setupMenu() {
        statusMenu = NSMenu(title: "gSync")

        let syncItem = NSMenuItem(title: "Sync with Google Drive", action: #selector(syncWithGoogleDrive), keyEquivalent: "")
        syncItem.target = self
        statusMenu.addItem(syncItem)

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit gSync", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusMenu.delegate = self
    }

    /// Настраивает внешний вид иконки в статус-баре.
    private func setupStatusBarAppearance() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "gSync Settings")
            button.imagePosition = .imageLeading
        }
    }

    /// Добавляет пункт меню для папки с её иерархией.
    /// - Parameters:
    ///   - folderName: Имя папки для отображения.
    ///   - path: Полный путь к папке для получения иерархии.
    func addFolderMenuItem(folderName: String, path: String) {
        if !statusMenu.items.contains(where: { $0.title == folderName }) {
            let menuItem = NSMenuItem(title: folderName, action: nil, keyEquivalent: "")
            if let contents = FolderManager.shared.getContents(for: path) {
                let subMenu = NSMenu(title: folderName)
                buildSubMenu(from: contents, into: subMenu)
                menuItem.submenu = subMenu
            }
            statusMenu.insertItem(menuItem, at: 1)
        }
    }

    /// Рекурсивно строит подменю на основе иерархии локальной папки.
    /// - Parameters:
    ///   - node: Узел иерархии.
    ///   - menu: Меню для добавления пунктов.
    private func buildSubMenu(from node: LocalFolder, into menu: NSMenu) {
        let item = NSMenuItem(title: node.name, action: nil, keyEquivalent: "")
        if node.isDirectory, let children = node.children, !children.isEmpty {
            let subMenu = NSMenu(title: node.name)
            for child in children {
                buildSubMenu(from: child, into: subMenu)
            }
            item.submenu = subMenu
        }
        menu.addItem(item)
    }

    @objc private func syncWithGoogleDrive() {
        NSApp.sendAction(#selector(FolderSelectionWindowController.showWindow(_:)), to: nil, from: self)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }

    var menuStatusItem: NSStatusItem {
        return statusItem
    }
}

extension MenuManager: NSMenuDelegate {
    /// Обновляет меню перед его открытием, добавляя все папки из FolderServer.
    func menuWillOpen(_ menu: NSMenu) {
        while statusMenu.items.count > 2 {
            statusMenu.removeItem(at: 1)
        }

        for pair in FolderServer.shared.getAllFolderPairs() {
            addFolderMenuItem(folderName: pair.local.name, path: pair.local.path)
        }
    }
}
