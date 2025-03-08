import Foundation

/// Модуль `FolderService` отвечает за управление списком папок, которые синхронизируются с облаком.
/// Сейчас вся логика работы с папками упрощена до минимума: только добавление пути и базовое логирование.
/// Основная задача: хранить пути папок и предоставлять их список.
/// В будущем здесь будет управление парами папок (локальный путь + ID в облаке) и их синхронизация.
class FolderService {
    static let shared = FolderService()
    private var folderPaths: [String] = [] // Упрощённое хранение путей вместо FolderPair

    private init() {
        Logger.shared.log("FolderService инициализирован")
    }

    /// Добавляет путь папки в список.
    /// Проверяет, что путь не пустой, и добавляет его, если он ещё не существует.
    func addFolderPair(_ path: String) {
        guard !path.isEmpty else {
            Logger.shared.log("Ошибка: Путь пустой, папка не добавлена")
            return
        }
        if !folderPaths.contains(path) {
            folderPaths.append(path)
            Logger.shared.log("Добавлена папка: \(path)")
        } else {
            Logger.shared.log("Папка с путём \(path) уже существует")
        }
    }

    /// Удаляет путь папки из списка.
    /// Сейчас не используется, но оставлен для будущей логики.
    func removeFolderPair(atPath path: String) {
        if let index = folderPaths.firstIndex(of: path) {
            folderPaths.remove(at: index)
            Logger.shared.log("Удалена папка: \(path)")
        } else {
            Logger.shared.log("Папка с путём \(path) не найдена")
        }
    }

    /// Возвращает список всех добавленных путей папок.
    func getAllFolders() -> [String] {
        return folderPaths
    }
}
