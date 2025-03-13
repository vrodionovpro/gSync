import Foundation

/// Класс для получения и обработки уведомлений о новых путях к папкам.
/// Отвечает за инициализацию мониторинга и передачу путей в другие модули.
/// Не зависит от GUI или конкретных сервисов.
class MessageReceiver {
    static let shared = MessageReceiver()
    private let notificationCenter = DistributedNotificationCenter.default()
    private var windowController: FolderSelectionWindowController?

    private init() {
        setupNotifications()
        setupWindowCloseObserver()
    }

    /// Запускает прием уведомлений.
    /// Логирует старт для отладки.
    func startReceivingMessages() {
        print("MessageReceiver начал прием уведомлений")
    }

    /// Настраивает наблюдение за уведомлениями от внешнего скрипта.
    /// При получении пути вызывает обработку.
    private func setupNotifications() {
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.nato.gSync.newPath"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let path = notification.userInfo?["path"] as? String {
                Logger.shared.log("Получен путь: \(path)")
                self.processPath(path)
            }
        }
    }

    /// Настраивает наблюдение за закрытием окна FolderSelectionWindow.
    private func setupWindowCloseObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FolderSelectionWindowClosed"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.windowController = nil
            Logger.shared.log("FolderSelectionWindowController очищен")
        }
    }

    /// Обрабатывает полученный путь к папке.
    /// - Parameter path: Полный путь к локальной папке.
    /// Вызывает окно выбора удалённой папки и сохраняет связь.
    func processPath(_ path: String) {
        let folderName = (path as NSString).lastPathComponent
        MenuManager.shared.addFolderMenuItem(folderName: folderName, path: path)
        if let localFolder = FolderManager.shared.addFolder(path: path) {
            print("Processed path \(path) with localFolder.id: \(localFolder.id)") // Отладка
            FolderServer.shared.addFolderPair(localFolder: localFolder, remoteFolder: nil)
            showFolderSelectionWindow(for: localFolder)
        } else {
            Logger.shared.log("Не удалось построить иерархию для пути: \(path)")
        }
    }

    /// Показывает окно выбора удалённой папки.
    /// - Parameter localFolder: Локальная папка, для которой выбирается удалённая.
    private func showFolderSelectionWindow(for localFolder: LocalFolder) {
        if GoogleDriveService.shared.authenticate() {
            windowController = FolderSelectionWindowController(
                driveManager: SyncOrchestrator.shared, // Заменили GoogleDriveManager
                localFolderId: localFolder.id,
                localFolderPath: localFolder.path
            )
            windowController?.showWindow(nil)
            print("FolderSelectionWindow opened for localFolder: \(localFolder.path)")
        } else {
            Logger.shared.log("Ошибка авторизации перед открытием окна выбора папки")
        }
    }

    deinit {
        notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
