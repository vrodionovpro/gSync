import Foundation

/// Главный менеджер для операций с Google Drive.
class GoogleDriveManager {
    static let shared = GoogleDriveManager()
    private let authenticator: GoogleDriveAuthenticator
    private let quotaChecker: GoogleDriveQuotaChecker
    private let uploader: GoogleDriveUploader
    private let progressManager: UploadProgressManager

    private init() {
        let driveService = GoogleDriveService.shared
        self.progressManager = UploadProgressManager()
        self.authenticator = GoogleDriveAuthenticator(driveService: driveService)
        self.quotaChecker = GoogleDriveQuotaChecker(driveService: driveService)
        self.uploader = GoogleDriveUploader(driveService: driveService, progressManager: progressManager)
    }

    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        guard authenticator.authenticate() else { return }
        startUploads(filesToUpload: filesToUpload, folderId: nil)
    }

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
                        "message": "Insufficient storage space on Google Drive. Free: \(free / (1024 * 1024 * 1024)) GB, Required: \(totalFileSize / (1024 * 1024 * 1024)) GB"
                    ])
                    return
                }
                let group = DispatchGroup()
                for file in filesToUpload {
                    group.enter()
                    self.uploader.uploadFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId ?? "")
                    group.leave() // Оставляем управление завершением uploader'у
                }
            case .failure(let error):
                print("Failed to check quota: \(error)")
                NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Failed to check storage quota: \(error)"])
            }
        }
    }

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

/// Модуль авторизации.
class GoogleDriveAuthenticator {
    private let driveService: GoogleDriveInterface

    init(driveService: GoogleDriveInterface) {
        self.driveService = driveService
    }

    func authenticate() -> Bool {
        driveService.authenticate()
    }
}

/// Модуль проверки квоты.
class GoogleDriveQuotaChecker {
    private let driveService: GoogleDriveInterface

    init(driveService: GoogleDriveInterface) {
        self.driveService = driveService
    }

    func checkQuota(completion: @escaping (Result<(total: Int64, used: Int64, free: Int64), Error>) -> Void) {
        driveService.checkStorageQuota { result in
            switch result {
            case .success(let (total, used)):
                completion(.success((total, used, total - used)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

/// Модуль загрузки файлов.
class GoogleDriveUploader {
    private let driveService: GoogleDriveInterface
    private let progressManager: UploadProgressManager
    private let maxRetries = 5
    private let chunkSize: Int64 = 256 * 1024 * 1024 // 256 Мб
    private var cancelledUploads: Set<String> = []

    init(driveService: GoogleDriveInterface, progressManager: UploadProgressManager) {
        self.driveService = driveService
        self.progressManager = progressManager
        setupCancelObserver()
    }

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
                    "speed": "N/A"
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
}

/// Модуль управления прогрессом.
class UploadProgressManager {
    private var progress: [String: (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)] = [:]
    private let progressFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("upload_progress.json")

    init() { loadProgress() }

    func saveProgress(fileName: String, totalSize: Int64, uploadedSize: Int64, sessionUri: String?) {
        progress[fileName] = (totalSize, uploadedSize, sessionUri)
        if let data = try? JSONEncoder().encode(progress) { try? data.write(to: progressFileURL) }
    }

    func loadProgress() {
        if let data = try? Data(contentsOf: progressFileURL),
           let loaded = try? JSONDecoder().decode([String: (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)].self, from: data) {
            progress = loaded
            print("Loaded upload progress: \(progress)")
        }
    }

    func getProgress(for fileName: String) -> (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)? {
        progress[fileName]
    }

    func clearProgress(for fileName: String) {
        progress.removeValue(forKey: fileName)
        if let data = try? JSONEncoder().encode(progress) { try? data.write(to: progressFileURL) }
    }
}
