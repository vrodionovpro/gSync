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
        setupNewFileObserver()
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
                  let progressValue = notification.userInfo?["progress"] as? String,
                  let speedValue = notification.userInfo?["speed"] as? String else { return }
            
            if let fileItem = self.fileItems[fileName] {
                DispatchQueue.main.async {
                    fileItem.title = "\(fileName) (\(progressValue)%) \(speedValue) Mb/s"
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
                    fileItem.title = "\(fileName) (100%)"
                }
            }
        }
    }

    /// Настраивает наблюдение за новыми стабилизированными файлами.
    private func setupNewFileObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewStableFileDetected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let filePath = notification.userInfo?["filePath"] as? String,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let folderPath = notification.userInfo?["folderPath"] as? String,
                  let localFolderId = notification.userInfo?["localFolderId"] as? UUID else { return }
            
            // MARK: - Изменение: Добавляем файл в меню, если он ещё не добавлен
            if let folderItem = self.folderItems[folderPath],
               let folderMenu = folderItem.submenu,
               self.fileItems[fileName] == nil { // Проверяем, не добавлен ли уже файл
                let fileItem = NSMenuItem(title: fileName, action: nil, keyEquivalent: "")
                folderMenu.addItem(fileItem)
                self.fileItems[fileName] = fileItem
                print("Added \(fileName) to menu for folder \(folderPath)")
            }

            // Инициируем загрузку после стабилизации
            if let folderPair = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localFolderId }),
               let remoteFolderId = folderPair.remote?.id {
                print("Initiating upload for \(fileName) with folderId: \(remoteFolderId), localFolderId: \(localFolderId)")
                GoogleDriveManager.shared.setFolderId(remoteFolderId, localFolderId: localFolderId)
            } else {
                print("No folder pair found for localFolderId: \(localFolderId) at path: \(folderPath)")
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
            // MARK: - Изменение: Добавляем файлы в меню сразу, но отправляем их на стабилизацию
            addFilesToMenu(localFolder: localFolder, folderMenu: folderMenu)
            
            // Отправляем все файлы на стабилизацию перед загрузкой
            if let children = localFolder.children {
                for child in children where !child.isDirectory {
                    FileStabilizer.shared.addFile(path: child.path, name: child.name, folderPath: path)
                }
            }
            
            FolderServer.shared.addFolderPair(localFolder: localFolder, remoteFolder: nil)
            folderItems[path] = folderItem
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
                    // MARK: - Изменение: Добавляем файл в меню сразу
                    let fileItem = NSMenuItem(title: child.name, action: nil, keyEquivalent: "")
                    folderMenu.addItem(fileItem)
                    fileItems[child.name] = fileItem
                    print("Initially added \(child.name) to menu for folder \(localFolder.path)")
                } else if let subChildren = child.children {
                    for subChild in subChildren {
                        if !subChild.isDirectory {
                            let fileItem = NSMenuItem(title: subChild.name, action: nil, keyEquivalent: "")
                            folderMenu.addItem(fileItem)
                            fileItems[subChild.name] = fileItem
                            print("Initially added \(subChild.name) to menu for folder \(localFolder.path)")
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

// MARK: - FileStabilizer синглтон (оставлен без изменений)
extension FileStabilizer {
    static let shared = FileStabilizer { filePath, fileName, folderPath in
        NotificationCenter.default.post(
            name: NSNotification.Name("NewStableFileDetected"),
            object: nil,
            userInfo: [
                "filePath": filePath,
                "fileName": fileName,
                "folderPath": folderPath
            ]
        )
    }
}
