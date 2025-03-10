import AppKit

/// Менеджер для управления меню приложения.
/// Отвечает за создание и обновление элементов меню для папок и файлов.
class MenuManager {
    static let shared = MenuManager()
    var statusItem: NSStatusItem? // Публичный доступ для других компонентов
    private var foldersMenu: NSMenu?
    private var folderItems: [String: NSMenuItem] = [:]
    private var fileItems: [String: NSMenuItem] = [:] // Храним элементы меню для файлов

    private init() {
        setupStatusItem()
        setupProgressObserver()
    }

    /// Настраивает статусный элемент в системном меню.
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "gSync"
        }
        let menu = NSMenu()
        foldersMenu = NSMenu()
        menu.addItem(withTitle: "Folders", action: nil, keyEquivalent: "")
        menu.setSubmenu(foldersMenu, for: menu.item(withTitle: "Folders")!)
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
            
            // Извлекаем процент прогресса из строки PROGRESS:X%
            let progress = progressLine.replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")
            if let fileItem = self.fileItems[fileName] {
                fileItem.title = "\(fileName) (\(progress)%)" // Обновляем заголовок файла с прогрессом
            }
        }
    }

    /// Добавляет элемент меню для новой папки и её содержимого.
    /// - Parameters:
    ///   - folderName: Название папки.
    ///   - path: Путь к папке.
    func addFolderMenuItem(folderName: String, path: String) {
        let folderItem = NSMenuItem(title: folderName, action: nil, keyEquivalent: "")
        let folderSubmenu = NSMenu()
        folderItem.submenu = folderSubmenu
        folderItems[folderName] = folderItem

        if let localFolder = FolderManager.shared.addFolder(path: path) {
            addFilesToMenu(localFolder: localFolder, folderSubmenu: folderSubmenu)
        }

        foldersMenu?.addItem(folderItem)
    }

    /// Добавляет файлы из локальной папки в подменю.
    /// - Parameters:
    ///   - localFolder: Локальная папка с файлами.
    ///   - folderSubmenu: Подменю для добавления файлов.
    private func addFilesToMenu(localFolder: LocalFolder, folderSubmenu: NSMenu) {
        if let children = localFolder.children {
            for child in children {
                if !child.isDirectory {
                    let fileItem = NSMenuItem(title: child.name, action: nil, keyEquivalent: "")
                    folderSubmenu.addItem(fileItem)
                    fileItems[child.name] = fileItem // Сохраняем элемент для обновления прогресса
                } else if let subChildren = child.children {
                    // Рекурсивно добавляем файлы из подпапок без создания лишнего уровня
                    for subChild in subChildren {
                        if !subChild.isDirectory {
                            let fileItem = NSMenuItem(title: subChild.name, action: nil, keyEquivalent: "")
                            folderSubmenu.addItem(fileItem)
                            fileItems[subChild.name] = fileItem // Сохраняем элемент для обновления прогресса
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
