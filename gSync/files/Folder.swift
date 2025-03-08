import Foundation

/// Структура для представления папки Google Drive в виде дерева.
/// Используется для отображения иерархии папок в `FolderSelectionView`.
struct Folder: Identifiable, Codable {
    let id: String
    let name: String
    let children: [Folder]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case children
    }
}
