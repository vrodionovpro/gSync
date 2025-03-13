import Foundation

class FolderManager {
    static let shared = FolderManager()
    private var logger = Logger.shared
    private var folderCache: [String: LocalFolder] = [:]

    private init() {
        logger.log("FolderManager инициализирован")
    }

    func addFolder(path: String) -> LocalFolder? {
        if let cachedFolder = folderCache[path] {
            logger.log("Папка \(path) найдена в кэше, возвращаем существующий объект с id: \(cachedFolder.id)")
            return cachedFolder
        }

        let rootNode = buildFileTree(at: path)
        if let rootNode = rootNode {
            logger.log("Иерархия для папки \(path): \(rootNode)")
            folderCache[path] = rootNode
            return rootNode
        } else {
            logger.log("Ошибка при построении иерархии для пути: \(path)")
            return nil
        }
    }

    func getContents(for path: String) -> LocalFolder? {
        return buildFileTree(at: path)
    }

    func getFolder(at path: String) -> LocalFolder? {
        return folderCache[path]
    }

    private func buildFileTree(at path: String) -> LocalFolder? {
        let fileManager = FileManager.default
        guard let isDirectory = try? fileManager.attributesOfItem(atPath: path)[.type] as? FileAttributeType == .typeDirectory else {
            logger.log("Не удалось определить тип элемента для пути: \(path)")
            return nil
        }
        let name = (path as NSString).lastPathComponent

        var node = LocalFolder(path: path, name: name, isDirectory: isDirectory)

        if isDirectory {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                var children: [LocalFolder] = []
                for item in contents {
                    let itemPath = (path as NSString).appendingPathComponent(item)
                    if let childNode = buildFileTree(at: itemPath) {
                        children.append(childNode)
                        folderCache[itemPath] = childNode
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
