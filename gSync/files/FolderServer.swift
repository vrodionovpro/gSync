import Foundation

class FolderServer {
    static let shared = FolderServer()
    private var folderPairs: [UUID: FolderPair] = [:]
    private var timer: Timer?
    private let checkInterval: TimeInterval = 5.0
    private var fileStabilizer: FileStabilizer?
    
    private init() {
        setupFileStabilizer()
        startMonitoring()
    }

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

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkForNewFiles()
        }
    }

    private func checkForNewFiles() {
        print("Checking for new files in \(folderPairs.count) folder pairs")
        for (localId, pair) in folderPairs {
            let currentFolder = pair.local
            print("Checking folder at path: \(currentFolder.path), id: \(localId)")
            if let updatedContents = FolderManager.shared.getContents(for: currentFolder.path) {
                let newFiles = findNewOrUpdatedFiles(current: currentFolder, updated: updatedContents)
                print("Found \(newFiles.count) new or updated files in \(currentFolder.path)")
                
                var updatedPair = pair
                if var currentChildren = updatedPair.local.children {
                    for newFile in newFiles {
                        if let index = currentChildren.firstIndex(where: { $0.path == newFile.path }) {
                            currentChildren[index] = newFile // Обновляем существующий файл
                        } else {
                            currentChildren.append(newFile) // Добавляем новый файл
                        }
                    }
                    updatedPair.local.children = currentChildren
                } else {
                    updatedPair.local.children = newFiles
                }
                folderPairs[localId] = updatedPair
                print("Updated folder contents for id \(localId): local.id = \(folderPairs[localId]?.local.id ?? UUID()), remote = \(String(describing: folderPairs[localId]?.remote?.id))")

                for newFile in newFiles {
                    print("Processing new file: \(newFile.name) at \(newFile.path)")
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

    private func findNewOrUpdatedFiles(current: LocalFolder, updated: LocalFolder) -> [LocalFolder] {
        var newFiles: [LocalFolder] = []
        guard let updatedChildren = updated.children else { return newFiles }
        let currentFiles = current.children ?? []
        let currentFilePaths = currentFiles.filter { !$0.isDirectory }.map { $0.path }
        
        for var child in updatedChildren {
            if !child.isDirectory {
                // Фильтр для исключения системных файлов, начинающихся с точки
                if child.name.starts(with: ".") {
                    print("Skipping system file: \(child.name)")
                    continue
                }
                if !currentFilePaths.contains(child.path) { // Новый файл
                    child.md5Checksum = computeMD5(for: child.path)
                    newFiles.append(child)
                } else if let currentFile = currentFiles.first(where: { $0.path == child.path }) {
                    let currentMD5 = currentFile.md5Checksum ?? computeMD5(for: currentFile.path)
                    let updatedMD5 = computeMD5(for: child.path)
                    child.md5Checksum = updatedMD5
                    if currentFile.isUploaded {
                        if currentMD5 != updatedMD5 {
                            print("File \(child.name) has changed, will re-upload")
                            child.isUploaded = false
                            newFiles.append(child)
                        }
                    } else {
                        newFiles.append(child)
                    }
                }
            }
        }
        return newFiles
    }

    private func computeMD5(for path: String) -> String? {
        let process = Process()
        process.launchPath = "/sbin/md5"
        process.arguments = ["-q", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
    }

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
        folderPairs[localFolder.id] = FolderPair(local: localFolder, remote: remoteFolder)
        if let children = localFolder.children {
            for child in children where !child.isDirectory && !child.name.starts(with: ".") { // Исключаем системные файлы
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

    func getAllFolderPairs() -> [FolderPair] {
        print("Returning folder pairs count: \(folderPairs.count)")
        return folderPairs.map { $0.value }
    }

    func removeFolderPair(localFolderId: UUID) {
        folderPairs.removeValue(forKey: localFolderId)
    }

    func updateRemoteFolder(localFolderId: UUID, remoteFolderId: String) {
        if var pair = folderPairs[localFolderId] {
            pair.remote = RemoteFolder(id: remoteFolderId, name: "RemoteFolder", children: nil)
            folderPairs[localFolderId] = pair
            print("Updated folder pair for localFolderId: \(localFolderId) with remoteFolderId: \(remoteFolderId)")
        }
    }

    func markFileAsUploaded(filePath: String) {
        for (localId, pair) in folderPairs {
            let localFolder = pair.local
            if var children = localFolder.children {
                if let index = children.firstIndex(where: { $0.path == filePath }) {
                    var updatedChild = children[index]
                    updatedChild.isUploaded = true
                    updatedChild.md5Checksum = computeMD5(for: filePath)
                    children[index] = updatedChild
                    var updatedPair = pair
                    updatedPair.local.children = children
                    folderPairs[localId] = updatedPair
                    print("Marked file as uploaded: \(filePath)")
                    break
                }
            }
        }
    }

    private func findLocalFolder(byPath path: String) -> LocalFolder? {
        return folderPairs.first(where: { $0.value.local.path == path })?.value.local
    }

    deinit {
        timer?.invalidate()
    }
}
