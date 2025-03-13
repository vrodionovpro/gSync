import Foundation

/// Структура для управления переменными окружения приложения `gSync`.
/// - Логика: Этот модуль предоставляет синглтон для доступа к переменным окружения, необходимым для работы с Google Drive и Python-скриптами. Загружает переменные из `ProcessInfo.processInfo.environment` и предоставляет их через свойства с проверкой наличия. Если переменная отсутствует, вызывает `fatalError` для остановки приложения.
/// - Особенности: Использует синглтон-паттерн (`shared`). Зависит только от Foundation и не взаимодействует с другими модулями напрямую. Переменные окружения должны быть установлены внешним скриптом или системой перед запуском приложения.
struct EnvironmentConfig {
    
    /// Синглтон-инстанс конфигурации, доступный через `EnvironmentConfig.shared`.
    static let shared = EnvironmentConfig()
    
    /// Словарь переменных окружения, загруженных из процесса.
    /// - Используется для хранения всех переменных окружения, доступных приложению.
    private let environment: [String: String]
    
    /// Приватный инициализатор для создания синглтона.
    /// - Загружает переменные окружения из `ProcessInfo` и выводит сообщение об инициализации.
    private init() {
        self.environment = ProcessInfo.processInfo.environment
        print("EnvironmentConfig initialized")
    }
    
    /// Путь к файлу сервисного аккаунта Google Drive.
    /// - Возвращает значение переменной `SERVICE_ACCOUNT_PATH` или вызывает `fatalError`, если она не установлена.
    var serviceAccountPath: String {
        guard let path = environment["SERVICE_ACCOUNT_PATH"] else {
            fatalError("Missing environment variable: SERVICE_ACCOUNT_PATH")
        }
        return path
    }
    
    /// Путь к файлу учетных данных OAuth.
    /// - Возвращает значение переменной `CREDENTIALS_PATH` или вызывает `fatalError`, если она не установлена.
    var credentialsPath: String {
        guard let path = environment["CREDENTIALS_PATH"] else {
            fatalError("Missing environment variable: CREDENTIALS_PATH")
        }
        return path
    }
    
    /// Путь к конфигурационному файлу OAuth.
    /// - Возвращает значение переменной `OAUTH_CONFIG_PATH` или вызывает `fatalError`, если она не установлена.
    var oauthConfigPath: String {
        guard let path = environment["OAUTH_CONFIG_PATH"] else {
            fatalError("Missing environment variable: OAUTH_CONFIG_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для аутентификации.
    /// - Возвращает значение переменной `PYTHON_AUTH_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonAuthScriptPath: String {
        guard let path = environment["PYTHON_AUTH_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_AUTH_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для получения списка файлов.
    /// - Возвращает значение переменной `PYTHON_LIST_FILES_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonListFilesScriptPath: String {
        guard let path = environment["PYTHON_LIST_FILES_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_LIST_FILES_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для получения списка папок.
    /// - Возвращает значение переменной `PYTHON_LIST_FOLDERS_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonListFoldersScriptPath: String {
        guard let path = environment["PYTHON_LIST_FOLDERS_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_LIST_FOLDERS_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для загрузки файлов.
    /// - Возвращает значение переменной `PYTHON_UPLOAD_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonUploadScriptPath: String {
        guard let path = environment["PYTHON_UPLOAD_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_UPLOAD_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для проверки существования файла.
    /// - Возвращает значение переменной `PYTHON_CHECK_FILE_EXISTS_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonCheckFileExistsScriptPath: String {
        guard let path = environment["PYTHON_CHECK_FILE_EXISTS_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_CHECK_FILE_EXISTS_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для вычисления MD5.
    /// - Возвращает значение переменной `PYTHON_MD5` или вызывает `fatalError`, если она не установлена.
    var pythonMD5ScriptPath: String {
        guard let path = environment["PYTHON_MD5"] else {
            fatalError("Missing environment variable: PYTHON_MD5")
        }
        return path
    }
    
    /// Путь к Python-скрипту для проверки MD5.
    /// - Возвращает значение переменной `PYTHON_CHECK_MD5_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonCheckMD5ScriptPath: String {
        guard let path = environment["PYTHON_CHECK_MD5_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_CHECK_MD5_SCRIPT_PATH")
        }
        return path
    }
    
    /// Путь к Python-скрипту для проверки квоты.
    /// - Возвращает значение переменной `PYTHON_QUOTA_SCRIPT_PATH` или вызывает `fatalError`, если она не установлена.
    var pythonQuotaScriptPath: String {
        guard let path = environment["PYTHON_QUOTA_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_QUOTA_SCRIPT_PATH")
        }
        return path
    }
}
