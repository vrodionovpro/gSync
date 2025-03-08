import Cocoa
import SwiftUI

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
        let contentView = FolderSelectionView()
            .environmentObject(driveManager) // Передаём driveManager как environmentObject
        let hostingController = NSHostingController(rootView: contentView)
        window.contentViewController = hostingController
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
            // Простая связь через FolderServer
            if let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local {
                FolderServer.shared.addFolderPair(localFolder: localFolder, remoteId: remoteId)
                Logger.shared.log("Связана локальная папка \(localId) с remoteId: \(remoteId)")
                // Запускаем загрузку файлов
                driveManager.performGoogleDriveOperations(filesToUpload: getFilesFromLocalFolder(localFolder))
            }
            window?.close()
        }
    }

    /// Извлекает список файлов из локальной папки для загрузки.
    private func getFilesFromLocalFolder(_ folder: LocalFolder) -> [(filePath: String, fileName: String)] {
        var files: [(filePath: String, fileName: String)] = []
        if let children = folder.children {
            for child in children {
                if child.isDirectory {
                    files.append(contentsOf: getFilesFromLocalFolder(child))
                } else {
                    files.append((filePath: child.path, fileName: child.name))
                }
            }
        }
        return files
    }
}

extension FolderSelectionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("FolderSelectionWindowClosed"), object: nil)
    }
}
