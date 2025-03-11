import Foundation

/// Менеджер для управления операциями с Google Drive.
/// Использует полиморфизм через протокол GoogleDriveInterface для выполнения операций.
class GoogleDriveManager: ObservableObject {
    static let shared = GoogleDriveManager()
    private let driveService: GoogleDriveInterface
    private var filesToUpload: [(filePath: String, fileName: String)] = []
    private var cancelledUploads: Set<String> = [] // Отслеживаем отменённые загрузки

    init(driveService: GoogleDriveInterface = GoogleDriveService.shared) {
        self.driveService = driveService
        setupCancelObserver()
    }

    var service: GoogleDriveInterface {
        driveService
    }

    /// Настраивает наблюдение за отменой загрузок.
    private func setupCancelObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CancelUpload"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String else { return }
            self.cancelledUploads.insert(fileName)
            print("Upload cancelled for \(fileName)")
        }
    }

    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        print("Performing Google Drive operations with files: \(filesToUpload)")
        self.filesToUpload = filesToUpload
        let authSuccess = driveService.authenticate()
        if authSuccess {
            print("Proceeding with Google Drive operations...")
            let windowController = FolderSelectionWindowController(
                driveManager: self,
                localFolderId: filesToUpload.first?.filePath != nil ? UUID() : nil,
                localFolderPath: filesToUpload.first?.filePath ?? ""
            )
            windowController.showWindow(nil)
        } else {
            print("Failed to authenticate with Google Drive")
        }
    }

    func setFolderId(_ folderId: String, localFolderId: UUID?) {
        print("setFolderId called with folderId: \(folderId), localFolderId: \(String(describing: localFolderId))")
        if !folderId.isEmpty, let localId = localFolderId {
            print("Searching for localFolder with id: \(localId)")
            let pairs = FolderServer.shared.getAllFolderPairs()
            print("Available folder pairs: \(pairs.count)")
            for pair in pairs {
                print("Checking pair: local.id = \(pair.local.id), remote = \(String(describing: pair.remote?.id))")
            }
            if let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local {
                FolderServer.shared.updateRemoteFolder(localFolderId: localId, remoteFolderId: folderId)
                filesToUpload = getFilesFromLocalFolder(localFolder)
                print("Files to upload: \(filesToUpload)")
                if !filesToUpload.isEmpty {
                    let totalFiles = filesToUpload.count
                    var uploadedFiles = 0
                    let group = DispatchGroup()
                    for file in filesToUpload {
                        group.enter()
                        print("Starting upload for \(file.fileName)...")
                        uploadSingleFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId, group: group)
                    }
                    group.notify(queue: .main) {
                        print("All uploads completed: \(uploadedFiles)/\(totalFiles)")
                    }
                } else {
                    print("No files to upload")
                }
            } else {
                print("Could not find local folder with id: \(localId)")
            }
        } else {
            print("Invalid folderId or localFolderId")
        }
    }

    /// Загружает один файл независимо.
    func uploadSingleFile(filePath: String, fileName: String, folderId: String, group: DispatchGroup? = nil) {
        guard !cancelledUploads.contains(fileName) else {
            print("Upload of \(fileName) was cancelled before starting")
            group?.leave()
            return
        }

        print("Starting upload for \(fileName)...")
        driveService.uploadFile(filePath: filePath, fileName: fileName, folderId: folderId, progressHandler: { [weak self] progress in
            guard let self = self, !self.cancelledUploads.contains(fileName) else { return }
            if progress.hasPrefix("PROGRESS:") {
                let components = progress.split(separator: " ")
                if components.count >= 2 {
                    let progressValue = components[0].replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")
                    let speedValue = components[1].replacingOccurrences(of: "SPEED:", with: "")
                    NotificationCenter.default.post(name: NSNotification.Name("UploadProgressUpdate"), object: nil, userInfo: [
                        "fileName": fileName,
                        "progress": progressValue,
                        "speed": speedValue
                    ])
                }
            }
        }, completion: { [weak self] success in
            guard let self = self else { return }
            if self.cancelledUploads.contains(fileName) {
                print("Upload of \(fileName) was cancelled during process")
            } else if success {
                NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil, userInfo: ["fileName": fileName, "success": success])
                print("Upload of \(fileName) succeeded")
            } else {
                print("Upload of \(fileName) failed")
            }
            group?.leave()
        })
    }

    private func getFilesFromLocalFolder(_ folder: LocalFolder) -> [(filePath: String, fileName: String)] {
        var files: [(filePath: String, fileName: String)] = []
        if let children = folder.children {
            for child in children {
                if !child.isDirectory {
                    files.append((filePath: child.path, fileName: child.name))
                }
            }
        }
        return files
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
