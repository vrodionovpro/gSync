//
//  FolderSelectionWindowController.swift
//  gSync
//
//  Created by 0000 on 08.03.2025.
//

import SwiftUI
import AppKit

class FolderSelectionWindowController: NSWindowController {
    convenience init(driveManager: GoogleDriveManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Select Google Drive Folder"
        self.init(window: window)
        
        let hostingController = NSHostingController(
            rootView: FolderSelectionView()
                .environmentObject(driveManager)
        )
        window.contentViewController = hostingController
    }
}
