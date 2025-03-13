import Foundation
import SwiftUI

/// Координирует процесс синхронизации с облачным хранилищем.
final class SyncOrchestrator: ObservableObject {
    static let shared = SyncOrchestrator()
    private let cloudService: CloudServiceInterface
    private let preparer: SyncPreparer
    private let uploader: SyncUploader
    
    init(cloudService: CloudServiceInterface = GoogleDriveService.shared) {
        self.cloudService = cloudService
        self.preparer = SyncPreparer(cloudService: cloudService)
        self.uploader = SyncUploader(cloudService: cloudService)
    }
    
    
    /// Возвращает список удалённых папок из облачного сервиса.
    func fetchFolders() -> [RemoteFolder] {
        return cloudService.fetchFolders()
    }
    
    /// Выполняет операции с Google Drive (аналог performGoogleDriveOperations).
    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        guard cloudService.authenticate() else {
            print("Authentication failed")
            return
        }
        let windowController = FolderSelectionWindowController(
            driveManager: self,
            localFolderId: filesToUpload.first?.filePath != nil ? UUID() : nil,
            localFolderPath: filesToUpload.first?.filePath ?? ""
        )
        windowController.showWindow(nil)
    }
    
    /// Устанавливает ID удалённой папки и запускает загрузку (аналог setFolderId).
    func setFolderId(_ folderId: String, localFolderId: UUID?) {
        guard !folderId.isEmpty, let localId = localFolderId,
              let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local else {
            print("Invalid folderId or localFolderId")
            return
        }
        FolderServer.shared.updateRemoteFolder(localFolderId: localId, remoteFolderId: folderId)
        preparer.prepareFiles(localFolder: localFolder) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let filesToUpload):
                self.uploader.uploadFiles(filesToUpload, toFolderId: folderId)
            case .failure(let error):
                print("Preparation failed: \(error)")
            }
        }
    }
    
    /// Загружает один файл независимо.
    func uploadSingleFile(filePath: String, fileName: String, folderId: String) {
        uploader.uploadSingleFile(filePath: filePath, fileName: fileName, folderId: folderId)
    }
}
