import Foundation

class FolderManager {
    static let shared = FolderManager()
    private var folderContents: [String: FileNode] = [:] // Хранит иерархию для каждой папки по её пути

    /// Добавляет папку и строит иерархию её содержимого.
    /// - Parameter path: Путь к папке.
    func addFolder(path: String) {
        let rootNode = buildFileTree(at: path)
        folderContents[path] = rootNode
        print("Иерархия для папки \(path): \(rootNode)")
    }

    /// Возвращает иерархию содержимого для указанной папки.
    /// - Parameter path: Путь к папке.
    /// - Returns: Корневой узел иерархии или nil, если папка не найдена.
    func getContents(for path: String) -> FileNode? {
        return folderContents[path]
    }

    /// Рекурсивно строит дерево файлов и папок.
    /// - Parameter path: Путь к текущей папке или файлу.
    /// - Returns: Узел иерархии.
    private func buildFileTree(at path: String) -> FileNode {
        let fileManager = FileManager.default
        let isDirectory = (try? fileManager.attributesOfItem(atPath: path)[.type] as? FileAttributeType) == .typeDirectory
        let name = (path as NSString).lastPathComponent

        var node = FileNode(name: name, path: path, isDirectory: isDirectory)

        if isDirectory {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                var children: [FileNode] = []
                for item in contents {
                    let itemPath = (path as NSString).appendingPathComponent(item)
                    let childNode = buildFileTree(at: itemPath)
                    children.append(childNode)
                }
                node.children = children
            } catch {
                print("Ошибка при чтении содержимого папки \(path): \(error)")
            }
        }

        return node
    }
}
