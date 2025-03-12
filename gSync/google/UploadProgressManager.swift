//
//  UploadProgressManager.swift
//  gSync
//
//  Created by 0000 on 13.03.2025.
//

import Foundation

/// Модуль для управления прогрессом загрузки.
/// Сохраняет и восстанавливает состояние загрузки файлов.
final class UploadProgressManager {
    private var progress: [String: (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)] = [:]
    private let progressFileURL: URL
    
    init() {
        progressFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("upload_progress.json")
        loadProgress()
    }
    
    /// Сохраняет прогресс загрузки для файла.
    func saveProgress(fileName: String, totalSize: Int64, uploadedSize: Int64, sessionUri: String?) {
        progress[fileName] = (totalSize, uploadedSize, sessionUri)
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: progressFileURL)
            print("Saved progress for \(fileName): \(uploadedSize) / \(totalSize) bytes")
        }
    }
    
    /// Загружает сохранённый прогресс из файла.
    private func loadProgress() {
        if let data = try? Data(contentsOf: progressFileURL),
           let loaded = try? JSONDecoder().decode([String: (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)].self, from: data) {
            progress = loaded
            print("Loaded upload progress: \(progress)")
        }
    }
    
    /// Возвращает текущий прогресс для файла.
    func getProgress(for fileName: String) -> (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)? {
        progress[fileName]
    }
    
    /// Очищает прогресс для файла.
    func clearProgress(for fileName: String) {
        progress.removeValue(forKey: fileName)
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: progressFileURL)
        }
    }
}
