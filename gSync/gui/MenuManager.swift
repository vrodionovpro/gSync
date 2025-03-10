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
            if let image = NSImage(named: NSImage.Name("StatusIcon")) { // Используем иконку
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "gSync" // Фallback, если иконки нет
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
            
            let progress = progressLine.replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")
            if let fileItem = self.fileItems[fileName] {
                DispatchQueue.main.async { // Гарантируем обновление на главном потоке
                    fileItem.title = "\(fileName) (\(progress)%)"
                }
            }
        }
    }

    /// Добавляет элемент меню для новой папки как топ-уровневый элемент с файлами внутри.
    /// - Parameters:
    ///   - folderName: Название папки.
    ///   - path: Путь к папке.
    func addFolderMenuItem(folderName: String, path: String) {
        let folderMenu = NSMenu()
        let folderItem = NSMenuItem()
        folderItem.submenu = folderMenu
        folderItem.title = folderName

        if let localFolder = FolderManager.shared.addFolder(path: path) {
            addFilesToMenu(localFolder: localFolder, folderMenu: folderMenu)
        }

        if let menu = statusItem?.menu {
            menu.insertItem(folderItem, at: 0) // Добавляем папку как топ-уровневый элемент перед Quit
        }
    }

    /// Добавляет файлы из локальной папки в подменю папки.
    /// - Parameters:
    ///   - localFolder: Локальная папка с файлами.
    ///   - folderMenu: Подменю для добавления файлов.
    private func addFilesToMenu(localFolder: LocalFolder, folderMenu: NSMenu) {
        if let children = localFolder.children {
            for child in children {
                if !child.isDirectory {
                    let fileItem = NSMenuItem(title: child.name, action: nil, keyEquivalent: "")
                    folderMenu.addItem(fileItem)
                    fileItems[child.name] = fileItem // Сохраняем для обновления прогресса
                } else if let subChildren = child.children {
                    for subChild in subChildren {
                        if !subChild.isDirectory {
                            let fileItem = NSMenuItem(title: subChild.name, action: nil, keyEquivalent: "")
                            folderMenu.addItem(fileItem)
                            fileItems[subChild.name] = fileItem // Сохраняем для обновления прогресса
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
