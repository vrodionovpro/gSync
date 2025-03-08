import Foundation

/// Представляет узел в иерархии удалённых папок (например, с Google Drive, Dropbox и т.д.).
/// Используется для отображения иерархии папок в `FolderSelectionView`.
struct RemoteFolder: Identifiable, Codable {
    let id: String
    let name: String
    let children: [RemoteFolder]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case children
    }
}
