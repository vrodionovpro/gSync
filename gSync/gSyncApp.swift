import SwiftUI

/// Главный модуль приложения `gSync`, точка входа в приложение.
/// - Логика: Этот модуль определяет основную сцену приложения с использованием SwiftUI и инициализирует ключевые компоненты через делегат `AppDelegate`. Не содержит активного UI, кроме настроек, и передаёт управление другим модулям (`FolderServer`, `MenuManager`, и т.д.) при запуске.
/// - Особенности: Использует `@main` для обозначения точки входа. Делегат `AppDelegate` отвечает за инициализацию синглтонов и обработку запуска. Зависит от `SyncOrchestrator` для управления синхронизацией.
@main
struct gSyncApp: App {
    
    /// Делегат приложения для обработки событий жизненного цикла.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /// Объект синхронизатора, наблюдаемый через `@StateObject`.
    /// - Используется для управления процессом синхронизации с Google Drive.
    @StateObject private var orchestrator = SyncOrchestrator.shared
    
    /// Определение сцены приложения.
    /// - Возвращает настройки приложения без активного UI.
    var body: some Scene {
        Settings {
            EmptyView() // Пустое представление для настроек (заглушка)
        }
        .commands {
            CommandGroup(replacing: .appInfo) { // Замена стандартного меню "About"
                Button("About gSync") { // Кнопка для вызова окна "О программе"
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }
    }
}

/// Делегат приложения для обработки событий запуска и открытия URL.
/// - Инициализирует ключевые модули и запускает приём сообщений.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// Вызывается после завершения запуска приложения.
    /// - Parameter notification: Уведомление о запуске (не используется напрямую).
    /// - Логика: Инициализирует синглтоны и запускает `MessageReceiver` для обработки путей.
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = FolderServer.shared // Инициализация сервера папок
        _ = MenuManager.shared // Инициализация менеджера меню
        _ = MessageReceiver.shared // Инициализация получателя сообщений
        _ = StatusOverlay.shared // Инициализация оверлея статуса
        _ = GoogleDriveService.shared // Инициализация сервиса Google Drive
        
        print("Application launched") // Отладка
        MessageReceiver.shared.startReceivingMessages() // Старт приёма уведомлений
    }
    
    /// Обрабатывает открытие приложения через URL.
    /// - Parameters:
    ///   - app: Экземпляр приложения.
    ///   - urls: Массив URL, переданных приложению.
    /// - Логика: Логирует первый URL для отладки (заглушка для будущей функциональности).
    func application(_ app: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            print("Handling URL: \(url.absoluteString)")
        }
    }
}
