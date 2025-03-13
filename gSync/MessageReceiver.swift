import Foundation

/// Класс для получения и обработки уведомлений о новых путях к папкам в `gSync`.
/// - Логика: Этот модуль выступает как центральный обработчик внешних уведомлений о путях к локальным папкам, получаемых через `DistributedNotificationCenter`. Он инициализирует мониторинг путей, передаёт их в `FolderServer` и `MenuManager`, а также открывает окно выбора удалённой папки через `FolderSelectionWindowController`. Не зависит от GUI напрямую, но запускает его через вызовы других модулей.
/// - Особенности: Использует синглтон (`shared`) для глобального доступа. Работает с уведомлениями от внешних скриптов (например, через `com.nato.gSync.newPath`). Асинхронно взаимодействует с `FolderServer` и `GoogleDriveService` для синхронизации.
class MessageReceiver {
    
    /// Синглтон-инстанс получателя сообщений, доступный через `MessageReceiver.shared`.
    static let shared = MessageReceiver()
    
    /// Центр распределённых уведомлений для получения сообщений от внешних процессов.
    private let notificationCenter = DistributedNotificationCenter.default()
    
    /// Контроллер окна выбора удалённой папки, сохраняется для управления окном.
    /// - Может быть `nil`, если окно не открыто или закрыто.
    private var windowController: FolderSelectionWindowController?
    
    /// Приватный инициализатор для создания синглтона.
    /// - Настраивает наблюдение за уведомлениями и закрытием окна.
    private init() {
        setupNotifications()
        setupWindowCloseObserver()
    }
    
    /// Запускает приём уведомлений о новых путях.
    /// - Логирует старт процесса для отладки через `print`.
    func startReceivingMessages() {
        print("MessageReceiver начал прием уведомлений")
    }
    
    /// Настраивает наблюдение за уведомлениями от внешнего скрипта.
    /// - Слушает уведомление `com.nato.gSync.newPath` и вызывает `processPath` при его получении.
    private func setupNotifications() {
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.nato.gSync.newPath"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let path = notification.userInfo?["path"] as? String {
                Logger.shared.log("Получен путь: \(path)") // Логирование полученного пути
                self.processPath(path) // Обработка пути
            }
        }
    }
    
    /// Настраивает наблюдение за закрытием окна выбора удалённой папки.
    /// - Слушает уведомление `FolderSelectionWindowClosed` и очищает `windowController` при его получении.
    private func setupWindowCloseObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FolderSelectionWindowClosed"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.windowController = nil
            Logger.shared.log("FolderSelectionWindowController очищен")
        }
    }
    
    /// Обрабатывает полученный путь к локальной папке.
    /// - Parameter path: Полный путь к папке, переданный через уведомление.
    /// - Логика: Извлекает имя папки, добавляет её в меню через `MenuManager`, регистрирует в `FolderServer` и открывает окно выбора удалённой папки.
    func processPath(_ path: String) {
        let folderName = (path as NSString).lastPathComponent // Извлечение имени папки из пути
        MenuManager.shared.addFolderMenuItem(folderName: folderName, path: path) // Добавление в меню приложения
        if let localFolder = FolderManager.shared.addFolder(path: path) {
            print("Processed path \(path) with localFolder.id: \(localFolder.id)") // Отладка
            FolderServer.shared.addFolderPair(localFolder: localFolder, remoteFolder: nil) // Регистрация пары папок
            showFolderSelectionWindow(for: localFolder) // Открытие окна выбора
        } else {
            Logger.shared.log("Не удалось построить иерархию для пути: \(path)") // Логирование ошибки
        }
    }
    
    /// Открывает окно выбора удалённой папки для заданной локальной папки.
    /// - Parameter localFolder: Локальная папка, для которой выбирается удалённая пара.
    /// - Логика: Проверяет аутентификацию через `GoogleDriveService` и открывает окно, если она успешна.
    private func showFolderSelectionWindow(for localFolder: LocalFolder) {
        if GoogleDriveService.shared.authenticate() { // Проверка авторизации
            windowController = FolderSelectionWindowController(
                driveManager: SyncOrchestrator.shared, // Использование синхронизатора для управления Google Drive
                localFolderId: localFolder.id,
                localFolderPath: localFolder.path
            )
            windowController?.showWindow(nil) // Отображение окна
            print("FolderSelectionWindow opened for localFolder: \(localFolder.path)") // Отладка
        } else {
            Logger.shared.log("Ошибка авторизации перед открытием окна выбора папки") // Логирование ошибки
        }
    }
    
    /// Деинициализатор для очистки ресурсов.
    /// - Удаляет наблюдателей из центров уведомлений при уничтожении объекта.
    deinit {
        notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
