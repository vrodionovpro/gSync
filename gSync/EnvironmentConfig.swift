import Foundation

/// Структура для управления переменными окружения.
struct EnvironmentConfig {
    static let shared = EnvironmentConfig()
    private let environment: [String: String]

    private init() {
        self.environment = ProcessInfo.processInfo.environment
        print("EnvironmentConfig initialized")
    }

    var serviceAccountPath: String {
        guard let path = environment["SERVICE_ACCOUNT_PATH"] else {
            fatalError("Missing environment variable: SERVICE_ACCOUNT_PATH")
        }
        return path
    }

    var credentialsPath: String {
        guard let path = environment["CREDENTIALS_PATH"] else {
            fatalError("Missing environment variable: CREDENTIALS_PATH")
        }
        return path
    }

    var oauthConfigPath: String {
        guard let path = environment["OAUTH_CONFIG_PATH"] else {
            fatalError("Missing environment variable: OAUTH_CONFIG_PATH")
        }
        return path
    }

    var pythonAuthScriptPath: String {
        guard let path = environment["PYTHON_AUTH_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_AUTH_SCRIPT_PATH")
        }
        return path
    }

    var pythonListFilesScriptPath: String {
        guard let path = environment["PYTHON_LIST_FILES_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_LIST_FILES_SCRIPT_PATH")
        }
        return path
    }

    var pythonListFoldersScriptPath: String {
        guard let path = environment["PYTHON_LIST_FOLDERS_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_LIST_FOLDERS_SCRIPT_PATH")
        }
        return path
    }

    var pythonUploadScriptPath: String {
        guard let path = environment["PYTHON_UPLOAD_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_UPLOAD_SCRIPT_PATH")
        }
        return path
    }

    var pythonCheckFileExistsScriptPath: String {
        guard let path = environment["PYTHON_CHECK_FILE_EXISTS_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_CHECK_FILE_EXISTS_SCRIPT_PATH")
        }
        return path
    }

    var pythonMD5ScriptPath: String {
        guard let path = environment["PYTHON_MD5"] else {
            fatalError("Missing environment variable: PYTHON_MD5")
        }
        return path
    }

    var pythonCheckMD5ScriptPath: String {
        guard let path = environment["PYTHON_CHECK_MD5_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_CHECK_MD5_SCRIPT_PATH")
        }
        return path
    }

    var pythonQuotaScriptPath: String {
        guard let path = environment["PYTHON_QUOTA_SCRIPT_PATH"] else {
            fatalError("Missing environment variable: PYTHON_QUOTA_SCRIPT_PATH")
        }
        return path
    }
}
