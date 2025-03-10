import Foundation

class GoogleDriveService: GoogleDriveInterface {
    static let shared = GoogleDriveService()
    private let config = EnvironmentConfig.shared

    private init() {
        print("GoogleDriveService initialized") // Инициализация сервиса
    }

    // MARK: - Helper Methods

    /// Выполняет Python-скрипт с указанными аргументами и возвращает его вывод, статус и прогресс в реальном времени.
    /// - Parameters:
    ///   - scriptPath: Путь к Python-скрипту.
    ///   - arguments: Аргументы для передачи в скрипт.
    ///   - progressHandler: Обработчик прогресса (вызывается при получении строки PROGRESS:X%).
    /// - Returns: Кортеж (вывод скрипта, успех выполнения).
    private func runPythonScript(_ scriptPath: String, arguments: [String], progressHandler: @escaping (String) -> Void) -> (output: String?, success: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = [scriptPath] + arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe // Для захвата ошибок
        task.launch()

        // Чтение вывода в реальном времени
        let outputHandle = pipe.fileHandleForReading
        var outputData = Data()
        let progressQueue = DispatchQueue(label: "progressQueue")

        let readingTask = DispatchSource.makeReadSource(fileDescriptor: outputHandle.fileDescriptor, queue: progressQueue)
        readingTask.setEventHandler {
            let newData = outputHandle.availableData
            if newData.count > 0 {
                outputData.append(newData)
                if let outputString = String(data: newData, encoding: .utf8) {
                    let lines = outputString.components(separatedBy: .newlines)
                    for line in lines {
                        if line.hasPrefix("PROGRESS:") {
                            progressHandler(line) // Передача прогресса
                        }
                    }
                }
            }
        }
        readingTask.resume()

        task.waitUntilExit()
        readingTask.cancel()

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        let success = task.terminationStatus == 0
        return (output, success)
    }

    // MARK: - GoogleDriveInterface Methods

    func authenticate() -> Bool {
        let (output, success) = runPythonScript(config.pythonAuthScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output.replacingOccurrences(of: "ya29.*", with: "[REDACTED]", options: .regularExpression))")
        }
        print("Authentication \(success ? "successful" : "failed")")
        return success
    }

    func listFiles() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFilesScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing files \(success ? "successful" : "failed")")
        return success
    }

    func calculateMD5(filePath: String) -> Bool {
        let (output, success) = runPythonScript(config.pythonMD5ScriptPath, arguments: [filePath]) { _ in }
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

        let (checkOutput, checkSuccess) = runPythonScript(config.pythonCheckFileExistsScriptPath, arguments: [config.serviceAccountPath, fileName, folderId]) { _ in }
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
            let (output, success) = self.runPythonScript(self.config.pythonUploadScriptPath, arguments: [self.config.serviceAccountPath, filePath, fileName, folderId]) { progressLine in
                if progressLine.hasPrefix("PROGRESS:") {
                    print("Received progress: \(progressLine)") // Логируем прогресс
                }
            }
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
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing folders \(success ? "successful" : "failed")")
        return success
    }

    /// Возвращает иерархию папок в виде списка корневых папок.
    /// - Вывод сжат для удобства чтения (количество корневых и общих папок с примерами).
    func fetchFolders() -> [RemoteFolder] {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        print("fetchFolders success: \(success)") // Простая индикация успеха
        guard success, let output = output, let jsonData = output.data(using: .utf8) else {
            print("Failed to parse folder list from Python script")
            return []
        }

        do {
            let decoder = JSONDecoder()
            let folders = try decoder.decode([RemoteFolder].self, from: jsonData)
            let rootCount = folders.count
            let totalCount = countFolders(folders)
            let sampleNames = folders.prefix(3).map { $0.name }.joined(separator: ", ")
            print("fetchFolders output: \(rootCount) root folder(s), \(totalCount) total folder(s) (e.g., \(sampleNames))") // Сжатый вывод
            return folders
        } catch {
            print("Failed to decode folder hierarchy: \(error)")
            return []
        }
    }

    /// Подсчитывает общее количество папок, включая вложенные.
    private func countFolders(_ folders: [RemoteFolder]) -> Int {
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
