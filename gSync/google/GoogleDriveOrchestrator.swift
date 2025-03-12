import Foundation

/// Оркестратор операций с Google Drive.
/// Координирует работу модулей авторизации, проверки квоты и загрузки.
final class GoogleDriveOrchestrator {
    static let shared = GoogleDriveOrchestrator()
    private let authenticator: GoogleDriveAuthenticator
    private let quotaChecker: GoogleDriveQuotaChecker
    private let uploader: GoogleDriveUploader
    
    private init() {
        let driveService = GoogleDriveService.shared
        let progressManager = UploadProgressManager()
        self.authenticator = GoogleDriveAuthenticator(driveService: driveService)
        self.quotaChecker = GoogleDriveQuotaChecker(driveService: driveService)
        self.uploader = GoogleDriveUploader(driveService: driveService, progressManager: progressManager)
    }
    
    /// Запускает операции с Google Drive для списка файлов.
    /// - Parameter filesToUpload: Список файлов для загрузки.
    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        guard authenticator.authenticate() else { return }
        startUploads(filesToUpload: filesToUpload, folderId: nil)
    }
    
    /// Устанавливает ID удалённой папки и начинает загрузку файлов из локальной папки.
    /// - Parameters:
    ///   - folderId: ID папки на Google Drive.
    ///   - localFolderId: ID локальной папки.
    func setFolderId(_ folderId: String, localFolderId: UUID?) {
        guard !folderId.isEmpty, let localId = localFolderId,
              let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local else {
            print("Invalid folderId or localFolderId")
            return
        }
        
        FolderServer.shared.updateRemoteFolder(localFolderId: localId, remoteFolderId: folderId)
        let filesToUpload = getFilesFromLocalFolder(localFolder)
        startUploads(filesToUpload: filesToUpload, folderId: folderId)
    }
    
    /// Координирует процесс загрузки с проверкой квоты.
    private func startUploads(filesToUpload: [(filePath: String, fileName: String)], folderId: String?) {
        print("Starting uploads for: \(filesToUpload)")
        guard authenticator.authenticate() else { return }
        
        quotaChecker.checkQuota { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (total, used, free)):
                let totalFileSize = filesToUpload.reduce(0) { $0 + (try? FileManager.default.attributesOfItem(atPath: $1.filePath)[.size] as? Int64 ?? 0) ?? 0 }
                if free < totalFileSize {
                    print("Insufficient space: \(free) bytes free, \(totalFileSize) bytes needed")
                    NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: [
                        "message": "Insufficient storage space. Free: \(free / (1024 * 1024 * 1024)) GB, Required: \(totalFileSize / (1024 * 1024 * 1024)) GB"
                    ])
                    return
                }
                for file in filesToUpload {
                    guard let folderId = folderId else {
                        print("No folder ID provided for \(file.fileName)")
                        continue
                    }
                    self.uploader.uploadFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId)
                }
            case .failure(let error):
                print("Failed to check quota: \(error)")
                NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Failed to check quota: \(error)"])
            }
        }
    }
    
    /// Извлекает файлы из локальной папки, исключая скрытые.
    private func getFilesFromLocalFolder(_ folder: LocalFolder) -> [(filePath: String, fileName: String)] {
        var files: [(filePath: String, fileName: String)] = []
        if let children = folder.children {
            for child in children where !child.isDirectory && !child.name.starts(with: ".") {
                files.append((filePath: child.path, fileName: child.name))
            }
        }
        return files
    }
}
