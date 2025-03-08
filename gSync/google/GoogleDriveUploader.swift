import Foundation

/// Модуль `GoogleDriveUploader` отвечает за загрузку файлов в Google Drive.
/// Сейчас это заглушка с минимальной функциональностью: логирует начало загрузки.
/// Основная задача: предоставить структуру для будущей реализации загрузки после проверки авторизации.
/// Логика: пока только принимает параметры и записывает их в лог.
class GoogleDriveUploader {
    static let shared = GoogleDriveUploader()

    private init() {
        Logger.shared.log("GoogleDriveUploader инициализирован")
    }

    /// Запускает процесс загрузки файла (заглушка).
    /// В будущем здесь будет интеграция с `GoogleDriveService` для реальной загрузки.
    func startUpload(fileName: String, localPath: String, folderId: String) {
        Logger.shared.log("Начата загрузка \(fileName) из \(localPath) в \(folderId) (заглушка)")
    }

    /// Возвращает прогресс загрузки (заглушка).
    /// Сейчас всегда возвращает 0, в будущем будет отслеживать реальный прогресс.
    func getProgress(forFile fileName: String) -> Int {
        Logger.shared.log("Получен прогресс для \(fileName): 0% (заглушка)")
        return 0
    }
}
