import Foundation

/// Менеджер для управления операциями с Google Drive.
/// Использует полиморфизм через протокол GoogleDriveInterface для выполнения операций.
class GoogleDriveManager: ObservableObject {
    static let shared = GoogleDriveManager()
    private let driveService: GoogleDriveInterface
    private var filesToUpload: [(filePath: String, fileName: String)] = []

    init(driveService: GoogleDriveInterface = GoogleDriveService.shared) {
        self.driveService = driveService
    }

    /// Возвращает доступ к сервису для выполнения операций.
    var service: GoogleDriveInterface {
        driveService
    }

    /// Запускает процесс авторизации и отображает окно выбора папки.
    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        print("Performing Google Drive operations with files: \(filesToUpload)")
        self.filesToUpload = filesToUpload
        let authSuccess = driveService.authenticate()
        if authSuccess {
            print("Proceeding with Google Drive operations...")
            let windowController = FolderSelectionWindowController(driveManager: self)
            windowController.showWindow(nil)
        } else {
            print("Failed to authenticate with Google Drive")
        }
    }

    /// Устанавливает ID папки и запускает загрузку.
    func setFolderId(_ folderId: String, localFolderId: UUID?) {
        print("setFolderId called with folderId: \(folderId), localFolderId: \(String(describing: localFolderId))")
        if !folderId.isEmpty, let localId = localFolderId {
            // Собираем файлы из локальной папки
            if let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local {
                filesToUpload = getFilesFromLocalFolder(localFolder)
                print("Files to upload: \(filesToUpload)")
                if !filesToUpload.isEmpty {
                    let totalFiles = filesToUpload.count
                    var uploadedFiles = 0
                    let group = DispatchGroup()
                    for file in filesToUpload {
                        group.enter()
                        print("Starting upload for \(file.fileName)...")
                        driveService.uploadFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId) { success in
                            if success {
                                uploadedFiles += 1
                            }
                            print("Upload progress: \(uploadedFiles)/\(totalFiles)")
                            print("Upload of \(file.fileName) \(success ? "succeeded" : "failed")")
                            group.leave()
                        }
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

    /// Собирает список файлов из локальной папки.
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
}
