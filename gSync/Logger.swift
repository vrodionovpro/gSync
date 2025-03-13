import Foundation

/// Класс для логирования сообщений в файл `/tmp/gSync.log`.
/// - Логика: Этот модуль предоставляет синглтон для записи отладочных сообщений в текстовый файл с временными метками. Использует асинхронную очередь для безопасной работы с файлом в многопоточной среде. Если файл логов не существует, он создаётся автоматически.
/// - Особенности: Не зависит от других модулей приложения, кроме стандартной библиотеки Foundation. Логи записываются в `/tmp`, что делает их временными и доступными только во время работы системы до перезагрузки.
class Logger {
    
    /// Синглтон-инстанс логгера, доступный через `Logger.shared`.
    static let shared = Logger()
    
    /// URL файла логов, куда записываются сообщения.
    /// - Значение: Фиксированный путь `/tmp/gSync.log`, используется для временного хранения логов.
    private let logFile: URL
    
    /// Очередь для асинхронной записи в файл.
    /// - Используется для предотвращения конфликтов при одновременной записи из разных потоков.
    private let fileQueue = DispatchQueue(label: "com.gSync.loggerQueue")
    
    /// Приватный инициализатор для создания синглтона.
    /// - Устанавливает путь к файлу логов в `/tmp/gSync.log`.
    private init() {
        logFile = URL(fileURLWithPath: "/tmp/gSync.log", isDirectory: false)
    }
    
    /// Записывает сообщение в лог-файл с временной меткой.
    /// - Parameter message: Строка сообщения для записи.
    /// - Логика: Форматирует сообщение с текущей датой и временем, затем асинхронно записывает его в файл. Если файла нет, создаёт его.
    func log(_ message: String) {
        fileQueue.async {
            // Форматирование даты и времени для временной метки.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Формат: "ГГГГ-ММ-ДД ЧЧ:ММ:СС".
            let timestamp = formatter.string(from: Date())
            
            // Формирование записи лога с временной меткой и сообщением.
            let logEntry = "\(timestamp): \(message)\n"
            
            // Попытка открыть файл для записи.
            if let fileHandle = try? FileHandle(forWritingTo: self.logFile) {
                fileHandle.seekToEndOfFile() // Перемещение курсора в конец файла.
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data) // Запись данных в файл.
                }
                try? fileHandle.close() // Закрытие файла после записи.
            } else {
                // Создание файла, если он не существует.
                if FileManager.default.createFile(atPath: self.logFile.path, contents: nil, attributes: nil) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFile) {
                        if let data = logEntry.data(using: .utf8) {
                            fileHandle.write(data) // Запись первой строки в новый файл.
                        }
                        try? fileHandle.close() // Закрытие файла.
                    }
                }
            }
        }
    }
}
