import Foundation

protocol GoogleDriveInterface {
    func authenticate() -> Bool
    func listFiles() -> Bool
    func listFolders() -> Bool
    func calculateMD5(filePath: String) -> Bool
    func uploadFile(filePath: String, fileName: String, folderId: String?, completion: @escaping (Bool) -> Void)
    func fetchFolders() -> [Folder]
    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool
}
