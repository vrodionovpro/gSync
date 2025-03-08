import Foundation

// MARK: - GoogleDriveAuthManager
/// Модуль зарезервирован для будущих функций работы с Google Drive.
/// Пока не используется для авторизации.
class GoogleDriveAuthManager {
    static let shared = GoogleDriveAuthManager()

    private init() {
        Logger.shared.log("GoogleDriveAuthManager инициализирован")
    }
}
