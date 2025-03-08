import Foundation

class MessageReceiver {
    static let shared = MessageReceiver()
    private let notificationCenter = DistributedNotificationCenter.default()

    private init() {
        setupNotifications()
    }

    func startReceivingMessages() {
        print("MessageReceiver начал прием уведомлений")
    }

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

    func processPath(_ path: String) {
        let folderName = (path as NSString).lastPathComponent
        MenuManager.shared.addFolderMenuItem(folderName: folderName, path: path) // Передаём полный путь
        FolderManager.shared.addFolder(path: path) // Строим иерархию файлов и папок

        // Добавляем папку в FolderService
        let folderPair = FolderPair(localPath: path, googleDriveFolderId: nil)
        FolderService.shared.addFolderPair(folderPair)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }
}
