//
//  FileStabilizer.swift
//  gSync
//
//  Created by 0000 on 11.03.2025.
//

import Foundation

/// Класс для отслеживания стабилизации файла (размер не меняется в течение заданного времени).
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
    private let stabilityThreshold: TimeInterval = 20.0 // 20 секунд
    private let checkInterval: TimeInterval = 5.0 // Проверка каждые 5 секунд
    private let onStabilized: (String, String, String) -> Void // Callback для стабилизированного файла

    init(onStabilized: @escaping (String, String, String) -> Void) {
        self.onStabilized = onStabilized
        startMonitoring()
    }

    /// Добавляет файл для проверки стабилизации.
    func addFile(path: String, name: String, folderPath: String) {
        let fileSize = getFileSize(at: path)
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

    /// Запускает таймер для проверки стабилизации.
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkStabilization()
        }
    }

    /// Проверяет стабилизацию файлов.
    private func checkStabilization() {
        let fileManager = FileManager.default
        var filesToRemove: [String] = []

        for (path, var pendingFile) in pendingFiles {
            // Проверяем, существует ли файл
            guard fileManager.fileExists(atPath: path) else {
                filesToRemove.append(path)
                continue
            }

            let currentSize = getFileSize(at: path)
            let currentTime = Date()
            let timeSinceLastCheck = currentTime.timeIntervalSince(pendingFile.lastCheckTime)

            if currentSize == pendingFile.lastSize {
                pendingFile.stableDuration += timeSinceLastCheck
            } else {
                pendingFile.stableDuration = 0
                pendingFile.lastSize = currentSize
            }
            pendingFile.lastCheckTime = currentTime

            if pendingFile.stableDuration >= stabilityThreshold {
                onStabilized(pendingFile.path, pendingFile.name, pendingFile.folderPath)
                filesToRemove.append(path)
            } else {
                pendingFiles[path] = pendingFile
            }
        }

        for path in filesToRemove {
            pendingFiles.removeValue(forKey: path)
        }
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

    deinit {
        timer?.invalidate()
    }
}
