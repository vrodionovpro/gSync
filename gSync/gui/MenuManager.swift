import Cocoa

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

    private func setupStatusBarAppearance() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "gSync Settings")
            button.imagePosition = .imageLeading
        }
    }

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

    private func buildSubMenu(from node: FileNode, into menu: NSMenu) {
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
    func menuWillOpen(_ menu: NSMenu) {
        while statusMenu.items.count > 2 {
            statusMenu.removeItem(at: 1)
        }

        for folderPair in FolderService.shared.folders.values { // Исправлено на "folders"
            addFolderMenuItem(folderName: (folderPair.localPath as NSString).lastPathComponent, path: folderPair.localPath)
        }
    }
}
