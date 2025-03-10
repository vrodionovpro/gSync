import AppKit

/// Менеджер для управления меню приложения.
/// Отвечает за создание и обновление элементов меню для папок и файлов.
class MenuManager {
    static let shared = MenuManager()
    var statusItem: NSStatusItem?
    private var foldersMenu: NSMenu?
    private var folderItems: [String: NSMenuItem] = [:]
    private var fileItems: [String: NSMenuItem] = [:] // Храним элементы меню для файлов

    private init() {
        setupStatusItem()
        setupProgressObserver()
    }

    /// Настраивает статусный элемент в системном меню с иконкой.
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let image = NSImage(named: NSImage.Name("StatusIcon")) {
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "gSync"
            }
        }
        let menu = NSMenu()
        foldersMenu = NSMenu()
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    /// Настраивает наблюдение за уведомлениями о прогрессе загрузки.
    private func setupProgressObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UploadProgressUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let progressLine = notification.userInfo?["progress"] as? String else { return }
            
            let components = progressLine.split(separator: " ")
            if components.count == 2 {
                let progressValue = components[0].replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")
                let speedValue = components[1].replacingOccurrences(of: "SPEED:", with: "")
                if let fileItem = self.fileItems[fileName] {
                    DispatchQueue.main.async {
                        fileItem.title = "\(fileName) (\(progressValue)%) \(speedValue) Mb/s"
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UploadCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let success = notification.userInfo?["success"] as? Bool else { return }
            
            if success, let fileItem = self.fileItems[fileName] {
                DispatchQueue.main.async {
                    fileItem.title = "\(fileName) (100%) 0 Mb/s"
                }
            }
        }
    }

    /// Добавляет элемент меню для новой папки как топ-уровневый элемент с файлами внутри.
    func addFolderMenuItem(folderName: String, path: String) {
        let folderMenu = NSMenu()
        let folderItem = NSMenuItem()
        folderItem.submenu = folderMenu
        folderItem.title = folderName

        if let localFolder = FolderManager.shared.addFolder(path: path) {
            addFilesToMenu(localFolder: localFolder, folderMenu: folderMenu)
        }

        if let menu = statusItem?.menu {
            menu.insertItem(folderItem, at: 0)
        }
    }

    /// Добавляет файлы из локальной папки в подменю папки.
    private func addFilesToMenu(localFolder: LocalFolder, folderMenu: NSMenu) {
        if let children = localFolder.children {
            for child in children {
                if !child.isDirectory {
                    let fileItem = NSMenuItem(title: child.name, action: nil, keyEquivalent: "")
                    folderMenu.addItem(fileItem)
                    fileItems[child.name] = fileItem
                } else if let subChildren = child.children {
                    for subChild in subChildren {
                        if !subChild.isDirectory {
                            let fileItem = NSMenuItem(title: subChild.name, action: nil, keyEquivalent: "")
                            folderMenu.addItem(fileItem)
                            fileItems[subChild.name] = fileItem
                        }
                    }
                }
            }
        }
    }

    /// Завершает работу приложения.
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
