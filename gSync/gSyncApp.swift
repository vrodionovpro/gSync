import SwiftUI

/// Главный модуль приложения `gSync`.
@main
struct gSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var orchestrator = SyncOrchestrator.shared // Заменили GoogleDriveOrchestrator
    
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
        _ = StatusOverlay.shared
        _ = GoogleDriveService.shared
        
        print("Application launched")
        MessageReceiver.shared.startReceivingMessages()
    }
    
    func application(_ app: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            print("Handling URL: \(url.absoluteString)")
        }
    }
}
