import Foundation

/// Модуль для загрузки файлов на Google Drive.
/// Отвечает за выполнение и управление процессом загрузки.
final class GoogleDriveUploader {
    private let driveService: GoogleDriveInterface
    private let progressManager: UploadProgressManager
    private let maxRetries = 5
    private let chunkSize: Int64 = 256 * 1024 * 1024 // 256 Мб
    private var cancelledUploads: Set<String> = []
    
    init(driveService: GoogleDriveInterface = GoogleDriveService.shared, progressManager: UploadProgressManager) {
        self.driveService = driveService
        self.progressManager = progressManager
        setupCancelObserver()
    }
    
    /// Настраивает наблюдение за отменой загрузок.
    private func setupCancelObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CancelUpload"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let fileName = notification.userInfo?["fileName"] as? String else { return }
            self.cancelledUploads.insert(fileName)
            self.progressManager.clearProgress(for: fileName)
            print("Upload cancelled for \(fileName)")
        }
    }
    
    /// Загружает файл с поддержкой чанков и повторных попыток.
    /// - Parameters:
    ///   - filePath: Локальный путь к файлу.
    ///   - fileName: Имя файла.
    ///   - folderId: ID папки на Google Drive.
    ///   - retryCount: Текущая попытка загрузки (для рекурсии).
    func uploadFile(filePath: String, fileName: String, folderId: String, retryCount: Int = 0) {
        guard !cancelledUploads.contains(fileName) else {
            print("Upload of \(fileName) was cancelled")
            return
        }
        
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            print("Failed to get file size for \(fileName): \(error)")
            return
        }
        
        let progress = progressManager.getProgress(for: fileName) ?? (totalSize: fileSize, uploadedSize: 0, sessionUri: nil)
        let startOffset = progress.uploadedSize
        
        print("Starting upload for \(fileName) (Attempt \(retryCount + 1) of \(maxRetries + 1)), Total: \(fileSize) bytes, Uploaded: \(startOffset) bytes...")
        
        driveService.uploadFileInChunks(
            filePath: filePath,
            fileName: fileName,
            folderId: folderId,
            chunkSize: chunkSize,
            startOffset: startOffset,
            totalSize: fileSize,
            sessionUri: progress.sessionUri,
            progressHandler: { [weak self] uploadedBytes, totalBytes, sessionUri in
                guard let self = self, !self.cancelledUploads.contains(fileName) else { return }
                self.progressManager.saveProgress(fileName: fileName, totalSize: totalBytes, uploadedSize: uploadedBytes, sessionUri: sessionUri)
                let progressPercent = Int((Double(uploadedBytes) / Double(totalBytes)) * 100)
                NotificationCenter.default.post(name: NSNotification.Name("UploadProgressUpdate"), object: nil, userInfo: [
                    "fileName": fileName,
                    "progress": String(progressPercent),
                    "speed": "N/A" // Скорость из Python-скрипта
                ])
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                if self.cancelledUploads.contains(fileName) {
                    print("Upload of \(fileName) was cancelled")
                    return
                }
                switch result {
                case .success:
                    print("Upload of \(fileName) succeeded")
                    self.progressManager.clearProgress(for: fileName)
                    NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": true])
                case .failure(let error):
                    print("Upload of \(fileName) failed on attempt \(retryCount + 1): \(error)")
                    if retryCount < self.maxRetries {
                        if error.localizedDescription.contains("storageQuotaExceeded") {
                            print("Storage quota exceeded. Aborting retries for \(fileName)")
                            NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Storage quota exceeded"])
                        } else {
                            print("Retrying upload for \(fileName)...")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                                self.uploadFile(filePath: filePath, fileName: fileName, folderId: folderId, retryCount: retryCount + 1)
                            }
                        }
                    } else {
                        print("Max retries reached for \(fileName). Giving up.")
                        NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": false])
                    }
                }
            }
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
