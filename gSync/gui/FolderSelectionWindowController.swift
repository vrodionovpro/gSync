import SwiftUI
import AppKit

class FolderSelectionWindowController: NSWindowController {
    let driveManager: SyncOrchestrator // Заменили GoogleDriveManager
    var localFolderId: UUID? // Идентификатор локальной папки для связи
    let localFolderPath: String // Путь к локальной папке для отображения

    init(driveManager: SyncOrchestrator, localFolderId: UUID? = nil, localFolderPath: String = "") {
        self.driveManager = driveManager
        self.localFolderId = localFolderId
        self.localFolderPath = localFolderPath
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Select Google Drive Folder"
        
        let hostingController = NSHostingController(
            rootView: FolderSelectionView(localFolderId: localFolderId, localFolderPath: localFolderPath)
                .environmentObject(driveManager)
        )
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
}

extension FolderSelectionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("FolderSelectionWindowClosed"), object: nil)
    }
}
