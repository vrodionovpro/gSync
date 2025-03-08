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
        self.filesToUpload = filesToUpload
        let authSuccess = driveService.authenticate()
        if authSuccess {
            print("Proceeding with Google Drive operations...")
            windowController = FolderSelectionWindowController(driveManager: self)
            windowController?.showWindow(nil)
        } else {
            print("Failed to authenticate with Google Drive")
        }
    }

    /// Устанавливает ID папки в переменную окружения для последующих операций.
    func setFolderId(_ folderId: String) {
        // Запускаем загрузку файлов в выбранную папку
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
