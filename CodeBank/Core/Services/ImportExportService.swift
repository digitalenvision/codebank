import Foundation
import UniformTypeIdentifiers

/// Import/Export constants
private enum ExportConstants {
    static let schemaVersion = "1.0"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let fileExtension = "codebank"
}

/// Errors that can occur during import/export
enum ImportExportError: LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case invalidFormat
    case versionMismatch(String)
    case passwordRequired
    case invalidPassword
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .invalidFormat:
            return "Invalid file format"
        case .versionMismatch(let version):
            return "Unsupported export version: \(version)"
        case .passwordRequired:
            return "Password is required to decrypt this file"
        case .invalidPassword:
            return "Invalid password"
        case .fileNotFound:
            return "File not found"
        }
    }
}

/// File format for CodeBank exports
struct ExportFile: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
    let encrypted: Bool
    
    // For encrypted exports
    var salt: Data?
    var iv: Data?
    var encryptedData: Data?
    
    // For plaintext exports
    var projects: [Project]?
    var items: [Item]?
    var tags: [Tag]?
}

/// Handles importing and exporting vault data
@MainActor
final class ImportExportService {
    
    // MARK: - Singleton
    
    static let shared = ImportExportService()
    
    // MARK: - Properties
    
    private let storageService: StorageService
    
    // MARK: - UTType for CodeBank files
    
    static let codeBankUTType = UTType(exportedAs: "com.digitalenvision.codebank.export", conformingTo: .data)
    
    // MARK: - Initialization
    
    private init() {
        self.storageService = StorageService.shared
    }
    
    // MARK: - Export
    
    /// Exports the vault to an encrypted file
    /// - Parameters:
    ///   - url: The destination URL
    ///   - password: The password to encrypt the export
    func exportEncrypted(to url: URL, password: String) async throws {
        // Get all data
        let exportData = try storageService.exportAllData()
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(exportData)
        
        // Generate salt and derive key
        let salt = KeyDerivation.generateSalt()
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        // Encrypt
        let encryptedData = try EncryptionEngine.encrypt(jsonData, key: key)
        
        // Create export file
        let exportFile = ExportFile(
            version: ExportConstants.schemaVersion,
            exportDate: Date(),
            appVersion: ExportConstants.appVersion,
            encrypted: true,
            salt: salt,
            encryptedData: encryptedData
        )
        
        // Write to file
        let fileData = try encoder.encode(exportFile)
        try fileData.write(to: url)
    }
    
    /// Exports the vault to a plaintext file (with security warning)
    /// - Parameter url: The destination URL
    func exportPlaintext(to url: URL) async throws {
        // Get all data
        let exportData = try storageService.exportAllData()
        
        // Create export file
        let exportFile = ExportFile(
            version: ExportConstants.schemaVersion,
            exportDate: Date(),
            appVersion: ExportConstants.appVersion,
            encrypted: false,
            projects: exportData.projects,
            items: exportData.items,
            tags: exportData.tags
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let fileData = try encoder.encode(exportFile)
        
        try fileData.write(to: url)
    }
    
    // MARK: - Import
    
    /// Checks if an export file is encrypted
    /// - Parameter url: The file URL
    /// - Returns: Whether the file is encrypted
    func isEncrypted(at url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportFile = try decoder.decode(ExportFile.self, from: data)
        return exportFile.encrypted
    }
    
    /// Imports from an encrypted file
    /// - Parameters:
    ///   - url: The source URL
    ///   - password: The password to decrypt the file
    ///   - replace: Whether to replace existing data or merge
    func importEncrypted(from url: URL, password: String, replace: Bool = true) async throws {
        // Read file
        let data = try Data(contentsOf: url)
        
        // Decode export file
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportFile = try decoder.decode(ExportFile.self, from: data)
        
        // Validate
        guard exportFile.encrypted else {
            throw ImportExportError.invalidFormat
        }
        
        guard let salt = exportFile.salt, let encryptedData = exportFile.encryptedData else {
            throw ImportExportError.invalidFormat
        }
        
        // Check version compatibility
        try validateVersion(exportFile.version)
        
        // Derive key and decrypt
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        let decryptedData: Data
        do {
            decryptedData = try EncryptionEngine.decrypt(encryptedData, key: key)
        } catch {
            throw ImportExportError.invalidPassword
        }
        
        // Decode the export data
        let exportData = try decoder.decode(ExportData.self, from: decryptedData)
        
        // Import
        if replace {
            try storageService.importData(exportData)
        } else {
            try mergeImportData(exportData)
        }
    }
    
    /// Imports from a plaintext file
    /// - Parameters:
    ///   - url: The source URL
    ///   - replace: Whether to replace existing data or merge
    func importPlaintext(from url: URL, replace: Bool = true) async throws {
        // Read file
        let data = try Data(contentsOf: url)
        
        // Decode export file
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportFile = try decoder.decode(ExportFile.self, from: data)
        
        // Validate
        guard !exportFile.encrypted else {
            throw ImportExportError.passwordRequired
        }
        
        // Check version compatibility
        try validateVersion(exportFile.version)
        
        // Extract data
        guard let projects = exportFile.projects,
              let items = exportFile.items,
              let tags = exportFile.tags else {
            throw ImportExportError.invalidFormat
        }
        
        let exportData = ExportData(
            version: exportFile.version,
            exportDate: exportFile.exportDate,
            appVersion: exportFile.appVersion,
            projects: projects,
            items: items,
            tags: tags
        )
        
        // Import
        if replace {
            try storageService.importData(exportData)
        } else {
            try mergeImportData(exportData)
        }
    }
    
    // MARK: - Version Validation
    
    private func validateVersion(_ version: String) throws {
        let currentComponents = ExportConstants.schemaVersion.split(separator: ".").compactMap { Int($0) }
        let importComponents = version.split(separator: ".").compactMap { Int($0) }
        
        guard currentComponents.count >= 1, importComponents.count >= 1 else {
            throw ImportExportError.versionMismatch(version)
        }
        
        // Major version must match or import must be older
        if importComponents[0] > currentComponents[0] {
            throw ImportExportError.versionMismatch(version)
        }
    }
    
    // MARK: - Merge Import
    
    /// Merges imported data with existing data (keeps both, renames conflicts)
    private func mergeImportData(_ data: ExportData) throws {
        // Get existing data
        let existingProjects = try storageService.fetchAllProjects()
        let existingTags = try storageService.fetchAllTags()
        
        // Create lookup sets
        let existingProjectNames = Set(existingProjects.map { $0.name })
        
        // Import projects (rename if conflict)
        var projectIdMapping: [UUID: UUID] = [:]
        for var project in data.projects {
            let originalId = project.id
            project = Project(
                id: UUID(),
                name: makeUniqueName(project.name, existing: existingProjectNames),
                icon: project.icon,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt
            )
            projectIdMapping[originalId] = project.id
            try storageService.createProject(project)
        }
        
        // Import tags (skip duplicates)
        var tagIdMapping: [UUID: UUID] = [:]
        for var tag in data.tags {
            let originalId = tag.id
            
            // Check if tag with same name exists
            if let existingTag = existingTags.first(where: { $0.name == tag.name }) {
                tagIdMapping[originalId] = existingTag.id
            } else {
                tag = Tag(
                    id: UUID(),
                    name: tag.name,
                    color: tag.color,
                    createdAt: tag.createdAt,
                    updatedAt: tag.updatedAt
                )
                tagIdMapping[originalId] = tag.id
                try storageService.createTag(tag)
            }
        }
        
        // Import items
        for var item in data.items {
            // Map project ID
            let newProjectId = item.projectId.flatMap { projectIdMapping[$0] }
            
            // Map tag IDs
            let newTagIds = item.tagIds.compactMap { tagIdMapping[$0] }
            
            item = Item(
                id: UUID(),
                name: item.name,
                type: item.type,
                projectId: newProjectId,
                data: item.data,
                tagIds: newTagIds,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
            try storageService.createItem(item)
        }
    }
    
    /// Creates a unique name by appending a number if needed
    private func makeUniqueName(_ name: String, existing: Set<String>) -> String {
        if !existing.contains(name) {
            return name
        }
        
        var counter = 2
        var newName = "\(name) (\(counter))"
        while existing.contains(newName) {
            counter += 1
            newName = "\(name) (\(counter))"
        }
        return newName
    }
    
    // MARK: - File Type Helpers
    
    /// Generates a default export filename
    func generateExportFilename(encrypted: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = formatter.string(from: Date())
        let suffix = encrypted ? "encrypted" : "plaintext"
        return "CodeBank_Export_\(dateString)_\(suffix).\(ExportConstants.fileExtension)"
    }
}
