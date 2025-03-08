import Foundation

protocol FileService {
    func authenticate() async throws
    func fetchFolders() async throws -> [LocalFolder]
    func selectFolder(id: String) async throws -> LocalFolder
    func syncFiles(from localPath: String, to folderId: String) async throws
}

struct LocalFolder {
    let id: String
    let name: String
}

