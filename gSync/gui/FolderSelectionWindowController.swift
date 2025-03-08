import Cocoa
import SwiftUI // Добавляем импорт SwiftUI для NSHostingController

/// Контроллер окна для выбора удалённой папки.
/// Управляет отображением FolderSelectionView и связыванием с локальной папкой.
class FolderSelectionWindowController: NSWindowController {
    var localFolderId: UUID? // Идентификатор локальной папки для связи
    private let driveManager: GoogleDriveManager

    init(driveManager: GoogleDriveManager) {
        self.driveManager = driveManager
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Select Remote Folder"
        window.contentViewController = NSHostingController(rootView: FolderSelectionView().environmentObject(driveManager))
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }

    /// Сохраняет выбранный remoteId и связывает с локальной папкой.
    func setSelectedFolderId(_ remoteId: String) {
        if let localId = localFolderId {
            driveManager.linkFolders(localFolderId: localId, remoteFolderId: remoteId)
            driveManager.performGoogleDriveOperations(filesToUpload: []) // Запускаем процесс с пустым списком для открытия окна
            window?.close()
        }
    }
}

extension FolderSelectionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Удаляем ссылку на windowController в MessageReceiver через уведомление
        NotificationCenter.default.post(name: NSNotification.Name("FolderSelectionWindowClosed"), object: nil)
    }
}
