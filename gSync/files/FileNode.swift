//
//  FileNode.swift
//  gSync
//
//  Created by 0000 on 08.03.2025.
//

import Foundation

/// Представляет узел в иерархии файлов и папок.
struct FileNode {
    let name: String // Имя файла или папки
    let path: String // Полный путь к файлу или папке
    let isDirectory: Bool // Это папка (true) или файл (false)?
    var children: [FileNode]? // Дочерние элементы (для папок)

    init(name: String, path: String, isDirectory: Bool, children: [FileNode]? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}
