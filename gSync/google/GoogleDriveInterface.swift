import Foundation

/// Протокол для взаимодействия с Google Drive API.
/// Определяет методы для авторизации, получения списков файлов и папок, вычисления MD5,
/// загрузки файлов и проверки существования файлов по MD5.
protocol GoogleDriveInterface {
    func authenticate() -> Bool
    func listFiles() -> Bool
    func listFolders() -> Bool
    func calculateMD5(filePath: String) -> Bool
    func uploadFile(filePath: String, fileName: String, folderId: String?, completion: @escaping (Bool) -> Void)
    func fetchFolders() -> [RemoteFolder] // Изменено с [Folder] на [RemoteFolder]
    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool
}
