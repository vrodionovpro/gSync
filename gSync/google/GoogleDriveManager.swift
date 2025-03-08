import Foundation

/// Менеджер для управления операциями с Google Drive.
/// Использует полиморфизм через протокол GoogleDriveInterface для выполнения операций.
class GoogleDriveManager: ObservableObject {
    static let shared = GoogleDriveManager()
    private let driveService: GoogleDriveInterface
    private var filesToUpload: [(filePath: String, fileName: String)] = []
    private var windowController: FolderSelectionWindowController?

    init(driveService: GoogleDriveInterface = GoogleDriveService.shared) {
        self.driveService = driveService
    }

    /// Возвращает доступ к сервису для выполнения операций.
    var service: GoogleDriveInterface {
        driveService
    }

    /// Запускает процесс авторизации и выполняет последующие операции с Google Drive.
    /// - Parameter filesToUpload: Массив кортежей (путь к файлу, имя файла), которые нужно загрузить.
    func performGoogleDriveOperations(filesToUpload: [(filePath: String, fileName: String)]) {
        print("Performing Google Drive operations with files: \(filesToUpload)")
        self.filesToUpload = filesToUpload
        let authSuccess = driveService.authenticate()
        if authSuccess {
            print("Proceeding with Google Drive operations...")
            if let localId = windowController?.localFolderId {
                if let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localId })?.local {
                    let files = getFilesFromLocalFolder(localFolder)
                    self.filesToUpload = files
                }
            }
            windowController = FolderSelectionWindowController(driveManager: self, localFolderId: windowController?.localFolderId)
            windowController?.showWindow(nil)
            setFolderId("") // Запускаем с пустым ID, чтобы начать процесс
        } else {
            print("Failed to authenticate with Google Drive")
        }
    }

    /// Устанавливает ID папки и запускает загрузку.
    func setFolderId(_ folderId: String) {
        print("setFolderId called with folderId: \(folderId), filesToUpload: \(filesToUpload)")
        if !folderId.isEmpty && !filesToUpload.isEmpty {
            let group = DispatchGroup()
            for file in filesToUpload {
                group.enter()
                print("Starting upload for \(file.fileName)...")
                driveService.uploadFile(filePath: file.filePath, fileName: file.fileName, folderId: folderId) { success in
                    print("Upload of \(file.fileName) \(success ? "succeeded" : "failed")")
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                print("All uploads completed")
                self?.windowController?.close()
            }
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
