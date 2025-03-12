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
    
    /// Проверяет квоту хранения на Google Drive.
    func checkStorageQuota(completion: @escaping (Result<(total: Int64, used: Int64), Error>) -> Void)
    
    /// Загружает файл по чанкам с возможностью возобновления.
    func uploadFileInChunks(filePath: String, fileName: String, folderId: String, chunkSize: Int64, startOffset: Int64, totalSize: Int64, sessionUri: String?, progressHandler: @escaping (Int64, Int64, String?) -> Void, completion: @escaping (Result<Void, Error>) -> Void)
}
