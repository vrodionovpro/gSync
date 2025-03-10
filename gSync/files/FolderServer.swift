import Foundation

/// Сервер для управления парами локальных и удалённых папок.
/// Отвечает за добавление, удаление и синхронизацию папок.
class FolderServer {
    static let shared = FolderServer()
    private var folderPairs: [UUID: (local: LocalFolder, remote: RemoteFolder?)] = [:] // Используем id как ключ для уникальности
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
            if let localFolder = self.findLocalFolder(byPath: folderPath) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewStableFileDetected"),
                    object: nil,
                    userInfo: [
                        "filePath": filePath,
                        "fileName": fileName,
                        "folderPath": folderPath,
                        "localFolderId": localFolder.id
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
        for (localId, pair) in folderPairs {
            let currentFolder = pair.local
            print("Checking folder at path: \(currentFolder.path), id: \(currentFolder.id)")
            if let updatedContents = FolderManager.shared.getContents(for: currentFolder.path) {
                let newFiles = findNewFiles(current: currentFolder, updated: updatedContents)
                print("Found \(newFiles.count) new files in \(currentFolder.path)")
                
                // Обновляем только содержимое
                folderPairs[localId]?.local.children = updatedContents.children
                print("Updated folder contents for id \(localId): local.id = \(folderPairs[localId]?.local.id ?? UUID()), remote = \(String(describing: folderPairs[localId]?.remote?.id))")

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
            if !child.isDirectory, !currentFileNames.contains(child.name) {
                newFiles.append(child)
            }
        }
        return newFiles
    }

    /// Добавляет пару локальной и удалённой папки.
    func addFolderPair(localFolder: LocalFolder, remoteFolder: RemoteFolder?) {
        print("Adding folder pair: localFolder.id = \(localFolder.id), remoteFolder = \(String(describing: remoteFolder?.id))")
        folderPairs[localFolder.id] = (local: localFolder, remote: remoteFolder)
    }

    /// Возвращает все пары локальных и удалённых папок.
    func getAllFolderPairs() -> [(local: LocalFolder, remote: RemoteFolder?)] {
        print("Returning folder pairs count: \(folderPairs.count)")
        for (id, pair) in folderPairs {
            print("Pair: local.id = \(pair.local.id), remote = \(String(describing: pair.remote?.id))")
        }
        return folderPairs.map { $0.value }
    }

    /// Удаляет пару по идентификатору локальной папки.
    func removeFolderPair(localFolderId: UUID) {
        folderPairs.removeValue(forKey: localFolderId)
    }

    /// Находит локальную папку по пути.
    private func findLocalFolder(byPath path: String) -> LocalFolder? {
        return folderPairs.first(where: { $0.value.local.path == path })?.value.local
    }

    deinit {
        timer?.invalidate()
    }
}
