import Foundation

/// Утилитарный класс для работы с иерархией локальных файлов и папок.
/// Предоставляет методы для построения дерева, поиска и обработки содержимого папок.
/// Не занимается хранением данных — это функция FolderServer.
class FolderManager {
    static let shared = FolderManager()
    private var logger = Logger.shared // Для логирования операций
    // MARK: - Изменение: Добавлен кэш для хранения LocalFolder с неизменными ID
    private var folderCache: [String: LocalFolder] = [:] // Кэш для стабильных объектов по пути

    private init() {
        logger.log("FolderManager инициализирован")
    }

    /// Добавляет папку и строит иерархию её содержимого.
    /// - Parameter path: Полный путь к локальной папке.
    /// - Returns: Корневой узел иерархии или nil при ошибке.
    func addFolder(path: String) -> LocalFolder? {
        // MARK: - Изменение: Проверяем кэш перед созданием нового объекта
        if let cachedFolder = folderCache[path] {
            logger.log("Папка \(path) найдена в кэше, возвращаем существующий объект с id: \(cachedFolder.id)")
            return cachedFolder
        }

        let rootNode = buildFileTree(at: path)
        if let rootNode = rootNode {
            logger.log("Иерархия для папки \(path): \(rootNode)")
            folderCache[path] = rootNode // Сохраняем в кэш
            return rootNode
        } else {
            logger.log("Ошибка при построении иерархии для пути: \(path)")
            return nil
        }
    }

    /// Возвращает иерархию содержимого для указанной папки.
    /// - Parameter path: Полный путь к папке.
    /// - Returns: Корневой узел иерархии или nil, если папка не найдена или ошибка.
    func getContents(for path: String) -> LocalFolder? {
        return buildFileTree(at: path)
    }

    /// Возвращает существующий объект LocalFolder из кэша.
    /// - Parameter path: Полный путь к папке.
    /// - Returns: Существующий LocalFolder или nil, если не найден.
    // MARK: - Изменение: Добавлен метод для получения объекта из кэша
    func getFolder(at path: String) -> LocalFolder? {
        return folderCache[path]
    }

    /// Рекурсивно строит дерево локальных файлов и папок.
    /// - Parameter path: Путь к текущей папке или файлу.
    /// - Returns: Узел иерархии или nil при ошибке.
    private func buildFileTree(at path: String) -> LocalFolder? {
        let fileManager = FileManager.default
        guard let isDirectory = try? fileManager.attributesOfItem(atPath: path)[.type] as? FileAttributeType == .typeDirectory else {
            logger.log("Не удалось определить тип элемента для пути: \(path)")
            return nil
        }
        let name = (path as NSString).lastPathComponent

        // MARK: - Исправление: Убрано использование id в конструкторе, так как id генерируется автоматически
        var node = LocalFolder(name: name, path: path, isDirectory: isDirectory)

        if isDirectory {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                var children: [LocalFolder] = []
                for item in contents {
                    let itemPath = (path as NSString).appendingPathComponent(item)
                    if let childNode = buildFileTree(at: itemPath) {
                        children.append(childNode)
                        folderCache[itemPath] = childNode // Сохраняем дочерние элементы в кэш
                    }
                }
                node.children = children.isEmpty ? nil : children
            } catch {
                logger.log("Ошибка при чтении содержимого папки \(path): \(error)")
                return nil
            }
        }

        return node
    }

    /// Поиск файла или папки по имени в иерархии.
    /// - Parameters:
    ///   - name: Имя файла или папки для поиска.
    ///   - root: Корневой узел, в котором ведётся поиск.
    /// - Returns: Первый найденный узел с указанным именем или nil.
    func findNode(byName name: String, in root: LocalFolder?) -> LocalFolder? {
        guard let root = root else { return nil }
        if root.name == name { return root }
        if let children = root.children {
            for child in children {
                if let found = findNode(byName: name, in: child) {
                    return found
                }
            }
        }
        return nil
    }
}
