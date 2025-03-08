import Foundation

/// Представляет узел в иерархии локальных файлов и папок.
/// Хранит информацию о локальной структуре для синхронизации с удалённым хранилищем.
struct LocalFolder: Identifiable {
    let id = UUID() // Уникальный идентификатор для каждой локальной папки
    let name: String // Имя папки или файла
    let path: String // Полный путь к файлу или папке
    let isDirectory: Bool // Указывает, является ли это папкой (true) или файлом (false)
    var children: [LocalFolder]? // Дочерние элементы для папок

    init(name: String, path: String, isDirectory: Bool, children: [LocalFolder]? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}
