import AppKit

class MenuManager {
    static let shared = MenuManager()
    var statusItem: NSStatusItem?
    private var foldersMenu: NSMenu?
    private var folderItems: [String: NSMenuItem] = [:]
    private var fileItems: [String: NSMenuItem] = [:]
    private var candidateFiles: Set<String> = []

    private init() {
        setupStatusItem()
        setupProgressObserver()
        setupFileObservers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let image = NSImage(named: NSImage.Name("StatusIcon")) {
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "gSync"
            }
        }
        let menu = NSMenu()
        foldersMenu = NSMenu()
        
        // Добавляем пункт "Quit" с явным target
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self // Указываем target как self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }

    private func setupProgressObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UploadProgressUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let progressValue = notification.userInfo?["progress"] as? String,
                  let speedValue = notification.userInfo?["speed"] as? String else { return }
            
            DispatchQueue.main.async {
                if let fileItem = self.fileItems[fileName] {
                    fileItem.title = "\(fileName) (\(progressValue)%) \(speedValue) Mb/s"
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UploadCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let success = notification.userInfo?["success"] as? Bool else { return }
            
            DispatchQueue.main.async {
                if success, let fileItem = self.fileItems[fileName] {
                    fileItem.title = fileName
                    self.candidateFiles.remove(fileName)
                }
            }
        }
    }

    private func setupFileObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewFileDetected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let folderPath = notification.userInfo?["folderPath"] as? String else { return }
            
            if let folderItem = self.folderItems[folderPath],
               let folderMenu = folderItem.submenu,
               self.fileItems[fileName] == nil {
                let candidateName = "[\(fileName)_candidate]"
                let fileItem = NSMenuItem(title: candidateName, action: nil, keyEquivalent: "")
                folderMenu.addItem(fileItem)
                self.fileItems[fileName] = fileItem
                self.candidateFiles.insert(fileName)
                print("Added \(candidateName) to menu for folder \(folderPath)")
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewStableFileDetected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let filePath = notification.userInfo?["filePath"] as? String,
                  let fileName = notification.userInfo?["fileName"] as? String,
                  let folderPath = notification.userInfo?["folderPath"] as? String,
                  let localFolderId = notification.userInfo?["localFolderId"] as? UUID else { return }
            
            DispatchQueue.main.async {
                if let fileItem = self.fileItems[fileName] {
                    fileItem.title = fileName
                    self.candidateFiles.remove(fileName)
                    print("File \(fileName) stabilized and ready for upload")
                }

                if let folderPair = FolderServer.shared.getAllFolderPairs().first(where: { $0.local.id == localFolderId }),
                   let remoteFolderId = folderPair.remote?.id {
                    print("Initiating upload for \(fileName) with folderId: \(remoteFolderId), localFolderId: \(localFolderId)")
                    SyncOrchestrator.shared.uploadSingleFile(filePath: filePath, fileName: fileName, folderId: remoteFolderId)
                } else {
                    print("No folder pair found for localFolderId: \(localFolderId) at path: \(folderPath)")
                }
            }
        }
    }

    func addFolderMenuItem(folderName: String, path: String) {
        let folderMenu = NSMenu()
        let folderItem = NSMenuItem()
        folderItem.submenu = folderMenu
        folderItem.title = folderName

        if let localFolder = FolderManager.shared.addFolder(path: path) {
            FolderServer.shared.addFolderPair(localFolder: localFolder, remoteFolder: nil)
            folderItems[path] = folderItem
        }

        if let menu = statusItem?.menu {
            menu.insertItem(folderItem, at: 0)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
