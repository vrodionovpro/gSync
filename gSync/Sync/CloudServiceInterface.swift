//
//  CloudServiceInterface.swift
//  gSync
//
//  Created by 0000 on 13.03.2025.
//

import Foundation

/// Универсальный интерфейс для работы с облачными хранилищами (Google Drive, Dropbox и т.д.).
/// Определяет методы для аутентификации, работы с файлами и папками, а также проверки состояния хранилища.
protocol CloudServiceInterface {
    /// Выполняет аутентификацию в облачном сервисе.
    /// - Returns: `true` при успешной аутентификации, `false` при ошибке.
    func authenticate() -> Bool
    
    /// Запрашивает список файлов в облаке (реализация зависит от сервиса).
    /// - Returns: `true` при успешном выполнении, `false` при ошибке.
    func listFiles() -> Bool
    
    /// Вычисляет MD5-хэш локального файла для проверки целостности.
    /// - Parameter filePath: Путь к локальному файлу.
    /// - Returns: `true` при успешном вычислении, `false` при ошибке.
    func calculateMD5(filePath: String) -> Bool
    
    /// Загружает файл в облако.
    /// - Parameters:
    ///   - filePath: Путь к локальному файлу.
    ///   - fileName: Имя файла в облаке.
    ///   - folderId: ID целевой папки (опционально).
    ///   - progressHandler: Обработчик прогресса (опционально).
    ///   - completion: Коллбэк с результатом загрузки.
    func uploadFile(filePath: String, fileName: String, folderId: String?, progressHandler: ((String) -> Void)?, completion: @escaping (Bool) -> Void)
    
    /// Запрашивает список папок в облаке (реализация зависит от сервиса).
    /// - Returns: `true` при успешном выполнении, `false` при ошибке.
    func listFolders() -> Bool
    
    /// Получает иерархию папок из облака.
    /// - Returns: Массив структур `RemoteFolder` с данными о папках.
    func fetchFolders() -> [RemoteFolder]
    
    /// Проверяет существование файла в облаке по его MD5-хэшу.
    /// - Parameters:
    ///   - md5: MD5-хэш файла.
    ///   - folderId: ID папки для проверки.
    /// - Returns: `true`, если файл существует, `false` в противном случае.
    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool
    
    /// Проверяет квоту хранения в облаке.
    /// - Parameter completion: Коллбэк с результатом: кортеж (total, used) или ошибка.
    func checkStorageQuota(completion: @escaping (Result<(total: Int64, used: Int64), Error>) -> Void)
    
    /// Загружает файл в облако по частям (чанкам) с поддержкой возобновления.
    /// - Parameters:
    ///   - filePath: Путь к локальному файлу.
    ///   - fileName: Имя файла в облаке.
    ///   - folderId: ID целевой папки.
    ///   - chunkSize: Размер чанка в байтах.
    ///   - startOffset: Начальный offset для возобновления.
    ///   - totalSize: Общий размер файла.
    ///   - sessionUri: URI сессии для возобновляемой загрузки (опционально).
    ///   - progressHandler: Обработчик прогресса (байты загружено, всего, текущий URI).
    ///   - completion: Коллбэк с результатом: успех или ошибка.
    func uploadFileInChunks(filePath: String, fileName: String, folderId: String, chunkSize: Int64, startOffset: Int64, totalSize: Int64, sessionUri: String?, progressHandler: @escaping (Int64, Int64, String?) -> Void, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Подсчитывает суммарный размер списка файлов через Python-скрипт.
    func calculateTotalFileSize(files: [(filePath: String, fileName: String)], completion: @escaping (Result<Int64, Error>) -> Void)
    
}
