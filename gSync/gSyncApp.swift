import SwiftUI
import Foundation

// MARK: - gSyncApp
/// Главный модуль приложения `gSyncApp` запускает приложение и инициализирует основные компоненты.
/// Логика: инициализирует синглтоны и запускает работу с Google Drive через GoogleDriveManager.
@main
struct gSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var driveManager = GoogleDriveManager()

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About gSync") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = FolderServer.shared
        _ = MenuManager.shared
        _ = MessageReceiver.shared
        _ = StatusOverlay.shared // Инициализируем StatusOverlay как синглтон
        _ = GoogleDriveService.shared
        
        print("Application launched")
        MessageReceiver.shared.startReceivingMessages()

        // Закомментированный код для тестирования оставим как есть
        /*
        // Запускаем операции с Google Drive через GoogleDriveManager
        let manager = GoogleDriveManager()
        let filesToUpload = [
            (filePath: "/Users/a0000/Documents/file1.txt", fileName: "file1.txt"),
            (filePath: "/Users/a0000/Documents/file2.txt", fileName: "file2.txt")
        ] // Замени на реальные пути
        manager.performGoogleDriveOperations(filesToUpload: filesToUpload)
        */
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            print("Handling URL: \(url.absoluteString)")
        }
    }
}
