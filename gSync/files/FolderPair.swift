import Foundation

/// Структура для пары локальной и удалённой папок
struct FolderPair: Codable {
    var local: LocalFolder
    var remote: RemoteFolder?
}
