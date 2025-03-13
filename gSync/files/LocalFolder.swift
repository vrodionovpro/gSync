import Foundation

struct LocalFolder: Codable {
    let id: UUID
    let path: String
    let name: String
    let isDirectory: Bool
    var children: [LocalFolder]?
    var isUploaded: Bool // Новый флаг
    var md5Checksum: String? // Новый MD5-хэш

    init(id: UUID = UUID(), path: String, name: String, isDirectory: Bool, children: [LocalFolder]? = nil, isUploaded: Bool = false, md5Checksum: String? = nil) {
        self.id = id
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.children = children
        self.isUploaded = isUploaded
        self.md5Checksum = md5Checksum
    }
}
