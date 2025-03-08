import Foundation

class GoogleDriveService: GoogleDriveInterface {
    static let shared = GoogleDriveService()
    private let config = EnvironmentConfig.shared

    private init() {
        print("GoogleDriveService initialized")
    }

    // MARK: - Helper Methods

    /// Выполняет Python-скрипт с указанными аргументами и возвращает его вывод и статус выполнения.
    /// - Parameters:
    ///   - scriptPath: Путь к Python-скрипту.
    ///   - arguments: Аргументы для передачи в скрипт.
    /// - Returns: Кортеж (вывод скрипта, успех выполнения).
    private func runPythonScript(_ scriptPath: String, arguments: [String]) -> (output: String?, success: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = [scriptPath] + arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        let success = task.terminationStatus == 0
        return (output, success)
    }

    // MARK: - GoogleDriveInterface Methods

    func authenticate() -> Bool {
        let (output, success) = runPythonScript(config.pythonAuthScriptPath, arguments: [config.serviceAccountPath])
        if let output = output {
            print("Python output: \(output.replacingOccurrences(of: "ya29.*", with: "[REDACTED]", options: .regularExpression))")
        }
        print("Authentication \(success ? "successful" : "failed")")
        return success
    }

    func listFiles() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFilesScriptPath, arguments: [config.serviceAccountPath])
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing files \(success ? "successful" : "failed")")
        return success
    }

    func calculateMD5(filePath: String) -> Bool {
        let (output, success) = runPythonScript(config.pythonMD5ScriptPath, arguments: [filePath])
        if let output = output {
            print("MD5 calculation output: \(output)")
        }
        print("MD5 calculation \(success ? "successful" : "failed")")
        return success
    }

    func uploadFile(filePath: String, fileName: String, folderId: String?, completion: @escaping (Bool) -> Void) {
        guard let folderId = folderId else {
            print("No folder ID provided")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let (checkOutput, checkSuccess) = runPythonScript(config.pythonCheckFileExistsScriptPath, arguments: [config.serviceAccountPath, fileName, folderId])
        if let checkOutput = checkOutput {
            print("File existence check output: \(checkOutput)")
            if checkOutput.contains("already exists") {
                print("Skipping upload: File \(fileName) already exists in folder \(folderId)")
                DispatchQueue.main.async { completion(false) }
                return
            }
        } else if !checkSuccess {
            print("Failed to get file existence check output")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let (output, success) = self.runPythonScript(self.config.pythonUploadScriptPath, arguments: [self.config.serviceAccountPath, filePath, fileName, folderId])
            if let output = output {
                print("Python output: \(output)")
            }
            print("Upload \(success ? "successful" : "failed")")
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func listFolders() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath])
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing folders \(success ? "successful" : "failed")")
        return success
    }

    /// Возвращает иерархию папок в виде списка корневых папок.
    func fetchFolders() -> [Folder] {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath])
        print("fetchFolders output: \(String(describing: output))")
        print("fetchFolders success: \(success)")
        guard success, let output = output, let jsonData = output.data(using: .utf8) else {
            print("Failed to parse folder list from Python script")
            return []
        }

        do {
            let decoder = JSONDecoder()
            let folders = try decoder.decode([Folder].self, from: jsonData)
            print("Parsed folders: \(folders)")
            print("Total root folders: \(folders.count)")
            let totalFolders = countFolders(folders)
            print("Total folders including children: \(totalFolders)")
            return folders
        } catch {
            print("Failed to decode folder hierarchy: \(error)")
            return []
        }
    }

    /// Подсчитывает общее количество папок, включая вложенные.
    private func countFolders(_ folders: [Folder]) -> Int {
        var count = folders.count
        for folder in folders {
            if let children = folder.children {
                count += countFolders(children)
            }
        }
        return count
    }

    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool {
        return false
    }
}
