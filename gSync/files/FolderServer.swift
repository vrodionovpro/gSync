import Foundation

/// Сервер для управления парами локальных и удалённых папок.
/// Отвечает за добавление, удаление и синхронизацию папок.
class FolderServer {
    static let shared = FolderServer()
    private var folderPairs: [(local: LocalFolder, remote: RemoteFolder?)] = []
    private var timer: Timer?
    private let checkInterval: TimeInterval = 5.0 // Проверка каждые 5 секунд
    private var fileStabilizer: FileStabilizer?

    private init() {
        setupFileStabilizer()
        startMonitoring()
    }

    /// Настраивает FileStabilizer для обработки новых файлов.
    private func setupFileStabilizer() {
        fileStabilizer = FileStabilizer { [weak self] filePath, fileName, folderPath in
            guard let self = self else { return }
            print("Stabilized file: \(fileName) at \(filePath) in folder \(folderPath)")
            // MARK: - Изменение: Передаём localFolderId через уведомление
            if let localFolder = FolderManager.shared.getFolder(at: folderPath) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewStableFileDetected"),
                    object: nil,
                    userInfo: [
                        "filePath": filePath,
                        "fileName": fileName,
                        "folderPath": folderPath,
                        "localFolderId": localFolder.id // Передаём ID для точного соответствия
                    ]
                )
            }
        }
    }

    /// Запускает периодическую проверку папок.
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkForNewFiles()
        }
    }

    /// Проверяет все добавленные папки на новые файлы.
    private func checkForNewFiles() {
        print("Checking for new files in \(folderPairs.count) folder pairs")
        for (index, pair) in folderPairs.enumerated() {
            let currentFolder = pair.local
            print("Checking folder at path: \(currentFolder.path), id: \(currentFolder.id)")
            // MARK: - Изменение: Используем getContents для получения только содержимого
            if let updatedContents = FolderManager.shared.getContents(for: currentFolder.path) {
                let newFiles = findNewFiles(current: currentFolder, updated: updatedContents)
                print("Found \(newFiles.count) new files in \(currentFolder.path)")
                
                // MARK: - Изменение: Обновляем только содержимое, не пересоздаём LocalFolder
                folderPairs[index].local.children = updatedContents.children
                print("Updated folder contents at index \(index): local.id = \(folderPairs[index].local.id), remote = \(String(describing: pair.remote?.id))")

                for newFile in newFiles {
                    fileStabilizer?.addFile(path: newFile.path, name: newFile.name, folderPath: currentFolder.path)
                }
            } else {
                print("Failed to update folder at path: \(currentFolder.path)")
            }
        }
    }

    /// Находит новые файлы, сравнивая текущую и обновлённую структуры папок.
    private func findNewFiles(current: LocalFolder, updated: LocalFolder) -> [LocalFolder] {
        var newFiles: [LocalFolder] = []

        guard let updatedChildren = updated.children else { return newFiles }
        
        let currentFileNames = (current.children ?? []).filter { !$0.isDirectory }.map { $0.name }
        for child in updatedChildren {
            if !child.isDirectory {
                if !currentFileNames.contains(child.name) {
                    newFiles.append(child)
                }
            }
        }

        return newFiles
    }

    func addFolderPair(localFolder: LocalFolder, remoteFolder: RemoteFolder?) {
        print("Adding folder pair: localFolder.id = \(localFolder.id), remoteFolder = \(String(describing: remoteFolder?.id))")
        folderPairs.append((local: localFolder, remote: remoteFolder))
    }

    func getAllFolderPairs() -> [(local: LocalFolder, remote: RemoteFolder?)] {
        print("Returning folder pairs count: \(folderPairs.count)")
        for pair in folderPairs {
            print("Pair: local.id = \(pair.local.id), remote = \(String(describing: pair.remote?.id))")
        }
        return folderPairs
    }

    func removeFolderPair(localFolderId: UUID) {
        folderPairs.removeAll { $0.local.id == localFolderId }
    }

    deinit {
        timer?.invalidate()
    }
}
