import Foundation

class FileStabilizer {
    struct PendingFile {
        let path: String
        let name: String
        let folderPath: String
        var lastSize: Int64
        var lastCheckTime: Date
        var stableDuration: TimeInterval
    }

    private var pendingFiles: [String: PendingFile] = [:]
    private var timer: Timer?
    private let stabilityThreshold: TimeInterval = 20.0
    private let checkInterval: TimeInterval = 5.0
    private let onStabilized: (String, String, String) -> Void

    init(onStabilized: @escaping (String, String, String) -> Void) {
        self.onStabilized = onStabilized
        startMonitoring()
    }

    func addFile(path: String, name: String, folderPath: String) {
        let fileSize = getFileSize(at: path)
        print("Added file to stabilization: \(name) at \(path), size: \(fileSize) bytes")
        // Если файл уже есть, не сбрасываем его stableDuration
        if pendingFiles[path] != nil {
            print("File \(name) already in stabilization with duration \(pendingFiles[path]!.stableDuration)")
            return
        }
        let pendingFile = PendingFile(
            path: path,
            name: name,
            folderPath: folderPath,
            lastSize: fileSize,
            lastCheckTime: Date(),
            stableDuration: 0
        )
        pendingFiles[path] = pendingFile
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkStabilization()
        }
    }

    private func checkStabilization() {
        let fileManager = FileManager.default
        var filesToRemove: [String] = []

        for (path, var pendingFile) in pendingFiles {
            guard fileManager.fileExists(atPath: path) else {
                print("File \(pendingFile.name) at \(path) no longer exists, removing from stabilization")
                filesToRemove.append(path)
                continue
            }

            let currentSize = getFileSize(at: path)
            let currentTime = Date()
            let timeSinceLastCheck = currentTime.timeIntervalSince(pendingFile.lastCheckTime)
            print("Checking \(pendingFile.name) at \(path): currentSize = \(currentSize), lastSize = \(pendingFile.lastSize), duration = \(pendingFile.stableDuration)")

            if currentSize == pendingFile.lastSize {
                pendingFile.stableDuration += timeSinceLastCheck // Накапливаем длительность
            } else {
                print("Size changed for \(pendingFile.name) at \(path): \(currentSize) != \(pendingFile.lastSize)")
                pendingFile.stableDuration = 0
                pendingFile.lastSize = currentSize
            }
            pendingFile.lastCheckTime = currentTime

            if pendingFile.stableDuration >= stabilityThreshold {
                if let localFolder = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.path == pendingFile.folderPath })?.local,
                   let child = localFolder.children?.first(where: { $0.path == path }),
                   child.isUploaded {
                    let currentMD5 = computeMD5(for: path)
                    if currentMD5 == child.md5Checksum {
                        print("File \(pendingFile.name) at \(path) already uploaded and unchanged, skipping...")
                        filesToRemove.append(path)
                        continue
                    } else {
                        print("File \(pendingFile.name) at \(path) has changed, will re-upload")
                    }
                }
                print("File \(pendingFile.name) at \(path) stabilized after \(pendingFile.stableDuration) seconds")
                onStabilized(pendingFile.path, pendingFile.name, pendingFile.folderPath)
                filesToRemove.append(path)
            } else {
                print("File \(pendingFile.name) still stabilizing, current duration: \(pendingFile.stableDuration)")
                pendingFiles[path] = pendingFile
            }
        }

        for path in filesToRemove {
            pendingFiles.removeValue(forKey: path)
        }
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

    deinit {
        timer?.invalidate()
    }
}
