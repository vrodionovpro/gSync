import Foundation

/// Управляет прогрессом загрузки файлов.
final class UploadProgressManager {
    // Структура для хранения данных прогресса, поддерживающая Codable
    private struct ProgressData: Codable {
        let totalSize: Int64
        let uploadedSize: Int64
        let sessionUri: String?
    }
    
    private var progress: [String: ProgressData] = [:]
    private let progressFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("upload_progress.json")
    
    static let shared = UploadProgressManager()
    
    public init() { loadProgress() }
    
    func saveProgress(fileName: String, totalSize: Int64, uploadedSize: Int64, sessionUri: String?) {
        progress[fileName] = ProgressData(totalSize: totalSize, uploadedSize: uploadedSize, sessionUri: sessionUri)
        if let data = try? JSONEncoder().encode(progress) { try? data.write(to: progressFileURL) }
    }
    
    func loadProgress() {
        if let data = try? Data(contentsOf: progressFileURL),
           let loaded = try? JSONDecoder().decode([String: ProgressData].self, from: data) {
            progress = loaded
            print("Loaded upload progress: \(progress)")
        }
    }
    
    func getProgress(for fileName: String) -> (totalSize: Int64, uploadedSize: Int64, sessionUri: String?)? {
        if let p = progress[fileName] {
            return (totalSize: p.totalSize, uploadedSize: p.uploadedSize, sessionUri: p.sessionUri)
        }
        return nil
    }
    
    func clearProgress(for fileName: String) {
        progress.removeValue(forKey: fileName)
        if let data = try? JSONEncoder().encode(progress) { try? data.write(to: progressFileURL) }
    }
}
