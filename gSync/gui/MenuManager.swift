import AppKit

/// Менеджер для управления меню приложения.
/// Отвечает за создание и обновление элементов меню для папок и файлов.
class MenuManager {
    static let shared = MenuManager()
    var statusItem: NSStatusItem?
    private var foldersMenu: NSMenu?
    private var folderItems: [String: NSMenuItem] = [:]
    private var fileItems: [String: NSMenuItem] = [:] // Храним элементы меню для файлов
    private var candidateFiles: Set<String> = [] // Отслеживаем файлы-кандидаты

    private init() {
        setupStatusItem()
        setupProgressObserver()
        setupFileObservers()
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
                    fileItem.title = fileName // Убираем прогресс после успешной загрузки
                }
                self.candidateFiles.remove(fileName) // Файл больше не кандидат
            }
        }
    }

    /// Настраивает наблюдение за новыми, стабилизированными и удалёнными файлами.
    private func setupFileObservers() {
        // Обработка новых файлов (кандидатов)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewFileDetected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let folderPath = notification.userInfo?["folderPath"] as? String else { return }
            
            if let folderItem = self.folderItems[folderPath],
               let folderMenu = folderItem.submenu,
               self.fileItems[fileName] == nil { // Добавляем только если ещё не в меню
                let candidateName = "[\(fileName)_candidate]"
                let fileItem = NSMenuItem(title: candidateName, action: nil, keyEquivalent: "")
                folderMenu.addItem(fileItem)
                self.fileItems[fileName] = fileItem
                self.candidateFiles.insert(fileName)
                print("Added \(candidateName) to menu for folder \(folderPath)")
            }
        }

        // Обработка стабилизированных файлов
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
            
            if let fileItem = self.fileItems[fileName] {
                DispatchQueue.main.async {
                    fileItem.title = fileName // Убираем [file_candidate]
                    print("File \(fileName) stabilized and ready for upload")
                }
                self.candidateFiles.remove(fileName)
            }

            // Инициируем проверку и загрузку
            if let folderPair = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localFolderId }),
               let remoteFolderId = folderPair.remote?.id {
                print("Initiating upload for \(fileName) with folderId: \(remoteFolderId), localFolderId: \(localFolderId)")
                GoogleDriveManager.shared.uploadSingleFile(filePath: filePath, fileName: fileName, folderId: remoteFolderId)
            } else {
                print("No folder pair found for localFolderId: \(localFolderId) at path: \(folderPath)")
            }
        }

        // Обработка удалённых файлов
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FileRemoved"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let folderPath = notification.userInfo?["folderPath"] as? String else { return }
            
            if let fileItem = self.fileItems[fileName],
               let folderItem = self.folderItems[folderPath],
               let folderMenu = folderItem.submenu {
                DispatchQueue.main.async {
                    folderMenu.removeItem(fileItem)
                    self.fileItems.removeValue(forKey: fileName)
                    self.candidateFiles.remove(fileName)
                    print("Removed \(fileName) from menu for folder \(folderPath)")
                }
                // Уведомляем GoogleDriveManager об отмене загрузки
                NotificationCenter.default.post(
                    name: NSNotification.Name("CancelUpload"),
                    object: nil,
                    userInfo: ["fileName": fileName]
                )
            }
        }
    }

    /// Добавляет элемент меню для новой папки как топ-уровневый элемент.
    func addFolderMenuItem(folderName: String, path: String) {
        let folderMenu = NSMenu()
        let folderItem = NSMenuItem()
        folderItem.submenu = folderMenu
        folderItem.title = folderName

        if let localFolder = FolderManager.shared.addFolder(path: path) {
            FolderServer.shared.addFolderPair(localFolder: localFolder, remoteFolder: nil)
            folderItems[path] = folderItem
        }

        if let menu = statusItem?.menu {
            menu.insertItem(folderItem, at: 0)
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

// MARK: - FileStabilizer синглтон
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
