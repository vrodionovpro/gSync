import Foundation

final class SyncUploader {
    private let cloudService: CloudServiceInterface
    private let progressManager: UploadProgressManager
    private let maxRetries = 5
    private let chunkSize: Int64 = 64 * 1024 * 1024 // 64 Мб
    private var cancelledUploads: Set<String> = []
    
    init(cloudService: CloudServiceInterface, progressManager: UploadProgressManager = UploadProgressManager.shared) {
        self.cloudService = cloudService
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
    
    func uploadFiles(_ files: [(filePath: String, fileName: String)], toFolderId folderId: String?) {
        guard cloudService.authenticate() else {
            print("Authentication failed")
            return
        }
        
        let group = DispatchGroup()
        for file in files {
            group.enter()
            uploadSingleFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId ?? "", completion: { success in
                group.leave()
            })
        }
        group.notify(queue: .main) {
            print("All uploads completed")
        }
    }
    
    func uploadSingleFile(filePath: String, fileName: String, folderId: String, retryCount: Int = 0, completion: @escaping (Bool) -> Void = { _ in }) {
        guard !cancelledUploads.contains(fileName) else {
            print("Upload of \(fileName) was cancelled")
            completion(false)
            return
        }
        
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            print("Failed to get file size for \(fileName): \(error)")
            completion(false)
            return
        }
        
        let progress = progressManager.getProgress(for: fileName) ?? (totalSize: fileSize, uploadedSize: 0, sessionUri: nil)
        let startOffset = progress.uploadedSize
        
        print("Starting upload for \(fileName) (Attempt \(retryCount + 1) of \(maxRetries + 1)), Total: \(fileSize) bytes, Uploaded: \(startOffset) bytes...")
        
        cloudService.uploadFileInChunks(
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
                    completion(false)
                    return
                }
                switch result {
                case .success:
                    print("Upload of \(fileName) succeeded")
                    self.progressManager.clearProgress(for: fileName)
                    FolderServer.shared.markFileAsUploaded(filePath: filePath)
                    NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": true])
                    completion(true)
                case .failure(let error):
                    print("Upload of \(fileName) failed on attempt \(retryCount + 1): \(error)")
                    if error.localizedDescription.contains("already exists") {
                        print("File \(fileName) already exists in cloud. Aborting retries.")
                        FolderServer.shared.markFileAsUploaded(filePath: filePath)
                        NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": false])
                        completion(false)
                    } else if retryCount < self.maxRetries {
                        if error.localizedDescription.contains("storageQuotaExceeded") {
                            print("Storage quota exceeded. Aborting retries for \(fileName)")
                            NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Storage quota exceeded"])
                            completion(false)
                        } else {
                            print("Retrying upload for \(fileName)...")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                                self.uploadSingleFile(filePath: filePath, fileName: fileName, folderId: folderId, retryCount: retryCount + 1, completion: completion)
                            }
                        }
                    } else {
                        print("Max retries reached for \(fileName). Giving up.")
                        NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": false])
                        completion(false)
                    }
                }
            }
        )
    }
}
