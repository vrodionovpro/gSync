import Foundation

/// Протокол для интерфейса работы с Google Drive.
protocol GoogleDriveInterface {
    func authenticate() -> Bool
    func listFiles() -> Bool
    func calculateMD5(filePath: String) -> Bool
    func uploadFile(filePath: String, fileName: String, folderId: String?, progressHandler: ((String) -> Void)?, completion: @escaping (Bool) -> Void)
    func listFolders() -> Bool
    func fetchFolders() -> [RemoteFolder]
    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool
}
