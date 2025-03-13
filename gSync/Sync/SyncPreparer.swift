import Foundation

/// Подготавливает данные для синхронизации: проверяет квоту и собирает файлы.
final class SyncPreparer {
    private let cloudService: CloudServiceInterface
    
    init(cloudService: CloudServiceInterface) {
        self.cloudService = cloudService
    }
    
    func prepareFiles(localFolder: LocalFolder, completion: @escaping (Result<[(filePath: String, fileName: String)], Error>) -> Void) {
        let filesToUpload: [(filePath: String, fileName: String)] = getFilesFromLocalFolder(localFolder) // Явно указан тип
        prepareFiles(filesToUpload: filesToUpload, completion: completion)
    }
    
    func prepareFiles(filesToUpload: [(filePath: String, fileName: String)], completion: @escaping (Result<[(filePath: String, fileName: String)], Error>) -> Void) {
        cloudService.calculateTotalFileSize(files: filesToUpload) { sizeResult in
            switch sizeResult {
            case .success(let totalFileSize):
                self.cloudService.checkStorageQuota { quotaResult in
                    switch quotaResult {
                    case .success(let (total, used)):
                        let free = total - used
                        if free < totalFileSize {
                            let error = NSError(domain: "gSync", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Insufficient storage space. Free: \(free / (1024 * 1024 * 1024)) GB, Required: \(totalFileSize / (1024 * 1024 * 1024)) GB"
                            ])
                            NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": error.localizedDescription])
                            completion(.failure(error))
                        } else {
                            completion(.success(filesToUpload))
                        }
                    case .failure(let error):
                        NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Failed to check quota: \(error)"])
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                NotificationCenter.default.post(name: NSNotification.Name("UploadError"), object: nil, userInfo: ["message": "Failed to calculate file size: \(error)"])
                completion(.failure(error))
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
