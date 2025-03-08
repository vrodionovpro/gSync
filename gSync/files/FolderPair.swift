import Foundation

struct FolderPair: Identifiable {
    let id = UUID()
    let localPath: String
    let googleDriveFolderId: String
    var syncingFiles: [SyncingFile]?

    init(localPath: String, googleDriveFolderId: String) {
        self.localPath = localPath
        self.googleDriveFolderId = googleDriveFolderId
    }
}

struct SyncingFile {
    let fileName: String
    let progress: Int
}
