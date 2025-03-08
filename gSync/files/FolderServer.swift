import Foundation

/// Синглтон для управления парами локальных и удалённых папок.
/// Не зависит от GUI, меню или конкретных сервисов (Google Drive, Dropbox и т.д.).
/// Знает только о локальных папках (с их иерархией) и их связях с удалёнными папками.
class FolderServer {
    static let shared = FolderServer()
    private var folderPairs: [UUID: (local: LocalFolder, remoteId: String?)] = [:] // Словарь для хранения пар
    private var logger = Logger.shared // Для логирования

    private init() {
        logger.log("FolderServer инициализирован")
    }

    /// Добавляет новую пару локальной и удалённой папки.
    /// - Parameters:
    ///   - localFolder: Локальная папка с иерархией.
    ///   - remoteId: Идентификатор удалённой папки (может быть nil, если не связана).
    func addFolderPair(localFolder: LocalFolder, remoteId: String? = nil) {
        guard !localFolder.path.isEmpty else {
            logger.log("Ошибка: Путь локальной папки пустой, пара не добавлена")
            return
        }
        if folderPairs[localFolder.id] == nil {
            folderPairs[localFolder.id] = (local: localFolder, remoteId: remoteId)
            logger.log("Добавлена пара: \(localFolder.path) -> \(remoteId ?? "не связана")")
        } else {
            logger.log("Пара для пути \(localFolder.path) уже существует")
        }
    }

    /// Удаляет пару по идентификатору локальной папки.
    /// - Parameter localId: Идентификатор локальной папки.
    func removeFolderPair(withLocalId localId: UUID) {
        if folderPairs[localId] != nil {
            folderPairs.removeValue(forKey: localId)
            logger.log("Удалена пара с идентификатором \(localId)")
        } else {
            logger.log("Пара с идентификатором \(localId) не найдена для удаления")
        }
    }

    /// Возвращает все пары локальных и удалённых папок.
    /// - Returns: Массив кортежей (localFolder, remoteId).
    func getAllFolderPairs() -> [(local: LocalFolder, remoteId: String?)] {
        return Array(folderPairs.values)
    }

    /// Возвращает удалённый идентификатор для заданной локальной папки.
    /// - Parameter localId: Идентификатор локальной папки.
    /// - Returns: Идентификатор удалённой папки или nil, если не связана.
    func getRemoteId(forLocalId localId: UUID) -> String? {
        return folderPairs[localId]?.remoteId
    }
}
