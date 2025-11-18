//
//  ClassificationConstants.swift
//  File Classification System
//
//  Constants and helper methods for file classification categories,
//  subfolders, and file extension mappings.
//

import Foundation

// MARK: - Classification Constants

struct ClassificationConstants {
    
    // MARK: - Valid Categories
    
    static let validCategories = ["Media", "Projects", "Documents", "Archive"]
    
    // MARK: - Valid Subfolders by Category
    
    static let validSubfolders: [String: [String]] = [
        "Media": ["Photos", "Videos", "Audio", "Screenshots"],
        "Projects": ["Code", "3D", "Design", "Assets", "Web"],
        "Documents": ["General", "Presentations", "Invoices", "Financial", "Reports", "Receipts", "Personal"],
        "Archive": ["Compressed", "Installers", "Backups"]
    ]
    
    // MARK: - File Extension Categories
    
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
        "webp", "svg", "heic", "heif", "ico", "raw", "cr2", "nef"
    ]
    
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm",
        "m4v", "mpg", "mpeg", "3gp", "ogv"
    ]
    
    static let audioExtensions: Set<String> = [
        "mp3", "wav", "aac", "flac", "ogg", "m4a", "wma",
        "opus", "aiff", "ape", "alac"
    ]
    
    static let modelExtensions: Set<String> = [
        "stl", "obj", "fbx", "blend", "3ds", "dae", "gltf",
        "glb", "ply", "max", "c4d"
    ]
    
    static let codeExtensions: Set<String> = [
        "swift", "js", "ts", "py", "java", "cpp", "c", "h",
        "cs", "go", "rs", "rb", "php", "pl", "sh", "bat",
        "ps1", "scala", "kt", "m", "r", "lua", "vim"
    ]
    
    static let webExtensions: Set<String> = [
        "html", "htm", "css", "scss", "sass", "less",
        "jsx", "tsx", "vue", "svelte"
    ]
    
    static let presentationExtensions: Set<String> = [
        "ppt", "pptx", "key", "odp"
    ]
    
    static let spreadsheetExtensions: Set<String> = [
        "xlsx", "xls", "csv", "numbers", "ods", "tsv"
    ]
    
    static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "txt", "rtf", "odt", "pages",
        "md", "tex", "epub", "mobi"
    ]
    
    static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
        "tgz", "tbz2", "zipx", "iso"
    ]
    
    static let installerExtensions: Set<String> = [
        "dmg", "pkg", "exe", "msi", "app", "deb", "rpm",
        "apk", "ipa"
    ]
    
    // MARK: - Helper Methods
    
    static func getValidSubfolders(for category: String?) -> [String: [String]] {
        if let category = category {
            return [category: validSubfolders[category] ?? ["General"]]
        }
        return validSubfolders
    }
    
    static func isValidCategory(_ category: String) -> Bool {
        return validCategories.contains(category)
    }
    
    static func isValidSubfolder(_ subfolder: String, for category: String) -> Bool {
        return validSubfolders[category]?.contains(subfolder) ?? false
    }
    
    static func getCategoryForExtension(_ fileExtension: String) -> String? {
        let ext = fileExtension.lowercased()
        
        if imageExtensions.contains(ext) || videoExtensions.contains(ext) || audioExtensions.contains(ext) {
            return "Media"
        } else if modelExtensions.contains(ext) || codeExtensions.contains(ext) || webExtensions.contains(ext) {
            return "Projects"
        } else if presentationExtensions.contains(ext) || spreadsheetExtensions.contains(ext) || documentExtensions.contains(ext) {
            return "Documents"
        } else if archiveExtensions.contains(ext) || installerExtensions.contains(ext) {
            return "Archive"
        }
        
        return nil
    }
}

