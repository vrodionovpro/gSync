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

    /// Настраивает FileStabilizer для обработки всех файлов.
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

    /// Проверяет все добавленные папки на новые или изменённые файлы.
    private func checkForNewFiles() {
        print("Checking for new files in \(folderPairs.count) folder pairs")
        for (localId, pair) in folderPairs {
            let currentFolder = pair.local
            print("Checking folder at path: \(currentFolder.path), id: \(localId)")
            if let updatedContents = FolderManager.shared.getContents(for: currentFolder.path) {
                let newFiles = findNewOrUpdatedFiles(current: currentFolder, updated: updatedContents)
                print("Found \(newFiles.count) new or updated files in \(currentFolder.path)")
                
                folderPairs[localId]?.local.children = updatedContents.children
                print("Updated folder contents for id \(localId): local.id = \(folderPairs[localId]?.local.id ?? UUID()), remote = \(String(describing: folderPairs[localId]?.remote?.id))")

                // Уведомляем о новых файлах как кандидатах
                for newFile in newFiles {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewFileDetected"),
                        object: nil,
                        userInfo: [
                            "filePath": newFile.path,
                            "fileName": newFile.name,
                            "folderPath": currentFolder.path,
                            "localFolderId": localId
                        ]
                    )
                    fileStabilizer?.addFile(path: newFile.path, name: newFile.name, folderPath: currentFolder.path)
                }
            } else {
                print("Failed to update folder at path: \(currentFolder.path)")
            }
        }
    }

    /// Находит новые или изменённые файлы, сравнивая текущую и обновлённую структуры папок.
    private func findNewOrUpdatedFiles(current: LocalFolder, updated: LocalFolder) -> [LocalFolder] {
        var newFiles: [LocalFolder] = []
        guard let updatedChildren = updated.children else { return newFiles }
        let currentFiles = current.children ?? []
        let currentFilePaths = currentFiles.filter { !$0.isDirectory }.map { $0.path }
        
        for child in updatedChildren {
            if !child.isDirectory {
                if !currentFilePaths.contains(child.path) { // Новый файл
                    newFiles.append(child)
                } else if let currentFile = currentFiles.first(where: { $0.path == child.path }),
                          getFileSize(at: child.path) != getFileSize(at: currentFile.path) { // Изменённый файл
                    newFiles.append(child)
                }
            }
        }
        return newFiles
    }

    /// Возвращает размер файла в байтах.
    private func getFileSize(at path: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            print("Failed to get file size for \(path): \(error)")
            return 0
        }
    }

    func addFolderPair(localFolder: LocalFolder, remoteFolder: RemoteFolder?) {
        print("Adding folder pair: localFolder.id = \(localFolder.id), remoteFolder = \(String(describing: remoteFolder?.id))")
        folderPairs[localFolder.id] = (local: localFolder, remote: remoteFolder)
        // Отправляем все существующие файлы на стабилизацию при добавлении
        if let children = localFolder.children {
            for child in children where !child.isDirectory {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewFileDetected"),
                    object: nil,
                    userInfo: [
                        "filePath": child.path,
                        "fileName": child.name,
                        "folderPath": localFolder.path,
                        "localFolderId": localFolder.id
                    ]
                )
                fileStabilizer?.addFile(path: child.path, name: child.name, folderPath: localFolder.path)
            }
        }
    }

    func getAllFolderPairs() -> [(local: LocalFolder, remote: RemoteFolder?)] {
        print("Returning folder pairs count: \(folderPairs.count)")
        for (_, pair) in folderPairs {
            print("Pair: local.id = \(pair.local.id), remote = \(String(describing: pair.remote?.id))")
        }
        return folderPairs.map { $0.value }
    }

    func removeFolderPair(localFolderId: UUID) {
        folderPairs.removeValue(forKey: localFolderId)
    }

    /// Обновляет remoteFolderId для пары после выбора папки.
    func updateRemoteFolder(localFolderId: UUID, remoteFolderId: String) {
        if var pair = folderPairs[localFolderId] {
            pair.remote = RemoteFolder(id: remoteFolderId, name: "RemoteFolder", children: nil)
            folderPairs[localFolderId] = pair
            print("Updated folder pair for localFolderId: \(localFolderId) with remoteFolderId: \(remoteFolderId)")
        }
    }

    private func findLocalFolder(byPath path: String) -> LocalFolder? {
        return folderPairs.first(where: { $0.value.local.path == path })?.value.local
    }

    deinit {
        timer?.invalidate()
    }
}
