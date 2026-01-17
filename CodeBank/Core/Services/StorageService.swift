import Foundation
import SQLite

/// Storage constants
private enum StorageConstants {
    static let bundleIdentifier = "com.digitalenvision.codebank"
    static let databaseFileName = "codebank.db"
    static let exportSchemaVersion = "1.0"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

/// Errors that can occur during storage operations
enum StorageError: LocalizedError {
    case databaseNotOpen
    case databaseAlreadyExists
    case migrationFailed(String)
    case operationFailed(String)
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .databaseAlreadyExists:
            return "Database already exists"
        case .migrationFailed(let reason):
            return "Database migration failed: \(reason)"
        case .operationFailed(let reason):
            return "Database operation failed: \(reason)"
        case .notFound:
            return "Record not found"
        case .invalidData:
            return "Invalid data"
        }
    }
}

/// Handles all database operations using SQLite
/// 
/// Data stored in the database is encrypted at the field level using AES-256-GCM
/// before being stored, providing encryption at rest.
@MainActor
final class StorageService {
    
    // MARK: - Singleton
    
    static let shared = StorageService()
    
    // MARK: - Properties
    
    private var db: Connection?
    private var encryptionKey: Data?
    
    // MARK: - Table Definitions
    
    private let projects = Table("projects")
    private let items = Table("items")
    private let tags = Table("tags")
    private let itemTags = Table("item_tags")
    private let settings = Table("settings")
    
    // Common columns
    private let id = Expression<String>("id")
    private let createdAt = Expression<Date>("created_at")
    private let updatedAt = Expression<Date>("updated_at")
    
    // Project columns
    private let projectName = Expression<String>("name")
    private let projectIcon = Expression<String>("icon")
    
    // Item columns
    private let itemName = Expression<String>("name")
    private let itemType = Expression<String>("type")
    private let itemProjectId = Expression<String?>("project_id")
    private let itemEncryptedData = Expression<Data>("encrypted_data")
    private let itemIsFavorite = Expression<Bool>("is_favorite")
    
    // Tag columns
    private let tagName = Expression<String>("name")
    private let tagColor = Expression<String>("color")
    
    // Item-Tag columns
    private let itemTagItemId = Expression<String>("item_id")
    private let itemTagTagId = Expression<String>("tag_id")
    
    // Settings columns
    private let settingKey = Expression<String>("key")
    private let settingValue = Expression<String>("value")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Database Lifecycle
    
    /// Opens or creates the database
    /// - Parameter key: The encryption key for data encryption
    func open(with key: Data) throws {
        let dbPath = getDatabasePath()
        
        do {
            db = try Connection(dbPath.path)
            encryptionKey = key
            
            // Enable foreign keys
            try db?.execute("PRAGMA foreign_keys = ON")
            
            // Create tables if needed
            try createTablesIfNeeded()
            
            // Run migrations
            try runMigrations()
        } catch {
            throw StorageError.operationFailed(error.localizedDescription)
        }
    }
    
    /// Closes the database connection
    func close() {
        db = nil
        encryptionKey = nil
    }
    
    /// Checks if the database exists
    var databaseExists: Bool {
        FileManager.default.fileExists(atPath: getDatabasePath().path)
    }
    
    /// Gets the database file path
    func getDatabasePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent(StorageConstants.bundleIdentifier)
        
        // Create app folder if it doesn't exist
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent(StorageConstants.databaseFileName)
    }
    
    /// Deletes the database file
    func deleteDatabase() throws {
        let path = getDatabasePath()
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Schema Creation
    
    private func createTablesIfNeeded() throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        // Projects table
        try db.run(projects.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(projectName)
            t.column(projectIcon, defaultValue: "folder.fill")
            t.column(createdAt)
            t.column(updatedAt)
        })
        
        // Items table
        try db.run(items.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(itemName)
            t.column(itemType)
            t.column(itemProjectId)
            t.column(itemEncryptedData)
            t.column(createdAt)
            t.column(updatedAt)
            t.foreignKey(itemProjectId, references: projects, id, delete: .setNull)
        })
        
        // Tags table
        try db.run(tags.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(tagName, unique: true)
            t.column(tagColor, defaultValue: "blue")
            t.column(createdAt)
            t.column(updatedAt)
        })
        
        // Item-Tags junction table
        try db.run(itemTags.create(ifNotExists: true) { t in
            t.column(itemTagItemId)
            t.column(itemTagTagId)
            t.primaryKey(itemTagItemId, itemTagTagId)
            t.foreignKey(itemTagItemId, references: items, id, delete: .cascade)
            t.foreignKey(itemTagTagId, references: tags, id, delete: .cascade)
        })
        
        // Settings table
        try db.run(settings.create(ifNotExists: true) { t in
            t.column(settingKey, primaryKey: true)
            t.column(settingValue)
        })
        
        // Create indexes
        try db.run(items.createIndex(itemProjectId, ifNotExists: true))
        try db.run(items.createIndex(itemType, ifNotExists: true))
        try db.run(items.createIndex(itemName, ifNotExists: true))
    }
    
    private func runMigrations() throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        // Get current schema version
        let currentVersion = try getSetting(key: "schema_version").flatMap { Int($0) } ?? 0
        
        // Run migrations based on version
        if currentVersion < 1 {
            // Initial schema - nothing to migrate
            try setSetting(key: "schema_version", value: "1")
        }
        
        // Migration 2: Add isFavorite column
        if currentVersion < 2 {
            // Check if column exists first
            let tableInfo = try db.prepare("PRAGMA table_info(items)")
            let columnExists = tableInfo.contains { row in
                (row[1] as? String) == "is_favorite"
            }
            
            if !columnExists {
                try db.run("ALTER TABLE items ADD COLUMN is_favorite INTEGER DEFAULT 0")
            }
            try setSetting(key: "schema_version", value: "2")
        }
    }
    
    // MARK: - Settings Operations
    
    func getSetting(key: String) throws -> String? {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = settings.filter(settingKey == key)
        return try db.pluck(query)?[settingValue]
    }
    
    func setSetting(key: String, value: String) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        try db.run(settings.insert(or: .replace,
            settingKey <- key,
            settingValue <- value
        ))
    }
    
    // MARK: - Project Operations
    
    func createProject(_ project: Project) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        try db.run(projects.insert(
            id <- project.id.uuidString,
            projectName <- project.name,
            projectIcon <- project.icon,
            createdAt <- project.createdAt,
            updatedAt <- project.updatedAt
        ))
    }
    
    func updateProject(_ project: Project) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = projects.filter(id == project.id.uuidString)
        try db.run(query.update(
            projectName <- project.name,
            projectIcon <- project.icon,
            updatedAt <- Date()
        ))
    }
    
    func deleteProject(id projectId: UUID) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = projects.filter(id == projectId.uuidString)
        try db.run(query.delete())
    }
    
    func fetchProject(id projectId: UUID) throws -> Project? {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = projects.filter(id == projectId.uuidString)
        guard let row = try db.pluck(query) else { return nil }
        
        return Project(
            id: UUID(uuidString: row[id])!,
            name: row[projectName],
            icon: row[projectIcon],
            createdAt: row[createdAt],
            updatedAt: row[updatedAt]
        )
    }
    
    func fetchAllProjects() throws -> [Project] {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        var result: [Project] = []
        for row in try db.prepare(projects.order(projectName.asc)) {
            result.append(Project(
                id: UUID(uuidString: row[id])!,
                name: row[projectName],
                icon: row[projectIcon],
                createdAt: row[createdAt],
                updatedAt: row[updatedAt]
            ))
        }
        return result
    }
    
    // MARK: - Item Operations
    
    func createItem(_ item: Item) throws {
        guard let db = db, let key = encryptionKey else { throw StorageError.databaseNotOpen }
        
        // Encrypt the item data
        let encryptedData = try EncryptionEngine.encrypt(item.data, key: key)
        
        try db.run(items.insert(
            id <- item.id.uuidString,
            itemName <- item.name,
            itemType <- item.type.rawValue,
            itemProjectId <- item.projectId?.uuidString,
            itemEncryptedData <- encryptedData,
            itemIsFavorite <- item.isFavorite,
            createdAt <- item.createdAt,
            updatedAt <- item.updatedAt
        ))
        
        // Add tags
        for tagId in item.tagIds {
            try db.run(itemTags.insert(
                itemTagItemId <- item.id.uuidString,
                itemTagTagId <- tagId.uuidString
            ))
        }
    }
    
    func updateItem(_ item: Item) throws {
        guard let db = db, let key = encryptionKey else { throw StorageError.databaseNotOpen }
        
        // Encrypt the item data
        let encryptedData = try EncryptionEngine.encrypt(item.data, key: key)
        
        let query = items.filter(id == item.id.uuidString)
        try db.run(query.update(
            itemName <- item.name,
            itemType <- item.type.rawValue,
            itemProjectId <- item.projectId?.uuidString,
            itemEncryptedData <- encryptedData,
            itemIsFavorite <- item.isFavorite,
            updatedAt <- Date()
        ))
        
        // Update tags - remove existing and add new
        let tagQuery = itemTags.filter(itemTagItemId == item.id.uuidString)
        try db.run(tagQuery.delete())
        
        for tagId in item.tagIds {
            try db.run(itemTags.insert(
                itemTagItemId <- item.id.uuidString,
                itemTagTagId <- tagId.uuidString
            ))
        }
    }
    
    func deleteItem(id itemId: UUID) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = items.filter(id == itemId.uuidString)
        try db.run(query.delete())
    }
    
    func fetchItem(id itemId: UUID) throws -> Item? {
        guard let db = db, let key = encryptionKey else { throw StorageError.databaseNotOpen }
        
        let query = items.filter(id == itemId.uuidString)
        guard let row = try db.pluck(query) else { return nil }
        
        // Decrypt the item data
        let decryptedData = try EncryptionEngine.decrypt(row[itemEncryptedData], key: key, as: ItemData.self)
        
        // Fetch tag IDs
        let tagIdsQuery = itemTags.filter(itemTagItemId == itemId.uuidString)
        var fetchedTagIds: [UUID] = []
        for tagRow in try db.prepare(tagIdsQuery) {
            if let uuid = UUID(uuidString: tagRow[itemTagTagId]) {
                fetchedTagIds.append(uuid)
            }
        }
        
        // Handle missing isFavorite column for older databases
        let isFavorite = (try? row.get(itemIsFavorite)) ?? false
        
        return Item(
            id: UUID(uuidString: row[id])!,
            name: row[itemName],
            type: ItemType(rawValue: row[itemType]) ?? .secureNote,
            projectId: row[itemProjectId].flatMap { UUID(uuidString: $0) },
            data: decryptedData,
            tagIds: fetchedTagIds,
            isFavorite: isFavorite,
            createdAt: row[createdAt],
            updatedAt: row[updatedAt]
        )
    }
    
    func fetchItems(projectId: UUID?) throws -> [Item] {
        guard let db = db, let key = encryptionKey else { throw StorageError.databaseNotOpen }
        
        var query = items.order(itemName.asc)
        if let projectId = projectId {
            query = query.filter(itemProjectId == projectId.uuidString)
        }
        
        var result: [Item] = []
        for row in try db.prepare(query) {
            let itemId = row[id]
            
            // Decrypt the item data
            let decryptedData = try EncryptionEngine.decrypt(row[itemEncryptedData], key: key, as: ItemData.self)
            
            // Fetch tag IDs
            let tagIdsQuery = itemTags.filter(itemTagItemId == itemId)
            var fetchedTagIds: [UUID] = []
            for tagRow in try db.prepare(tagIdsQuery) {
                if let uuid = UUID(uuidString: tagRow[itemTagTagId]) {
                    fetchedTagIds.append(uuid)
                }
            }
            
            // Handle missing isFavorite column for older databases
            let isFavorite = (try? row.get(itemIsFavorite)) ?? false
            
            result.append(Item(
                id: UUID(uuidString: itemId)!,
                name: row[itemName],
                type: ItemType(rawValue: row[itemType]) ?? .secureNote,
                projectId: row[itemProjectId].flatMap { UUID(uuidString: $0) },
                data: decryptedData,
                tagIds: fetchedTagIds,
                isFavorite: isFavorite,
                createdAt: row[createdAt],
                updatedAt: row[updatedAt]
            ))
        }
        return result
    }
    
    func fetchAllItems() throws -> [Item] {
        try fetchItems(projectId: nil)
    }
    
    func searchItems(query searchQuery: String) throws -> [Item] {
        guard let db = db, let key = encryptionKey else { throw StorageError.databaseNotOpen }
        
        let searchPattern = "%\(searchQuery.lowercased())%"
        let query = items.filter(itemName.lowercaseString.like(searchPattern))
                         .order(itemName.asc)
        
        var result: [Item] = []
        for row in try db.prepare(query) {
            let itemIdStr = row[id]
            
            // Decrypt the item data
            let decryptedData = try EncryptionEngine.decrypt(row[itemEncryptedData], key: key, as: ItemData.self)
            
            // Fetch tag IDs
            let tagIdsQuery = itemTags.filter(itemTagItemId == itemIdStr)
            var fetchedTagIds: [UUID] = []
            for tagRow in try db.prepare(tagIdsQuery) {
                if let uuid = UUID(uuidString: tagRow[itemTagTagId]) {
                    fetchedTagIds.append(uuid)
                }
            }
            
            result.append(Item(
                id: UUID(uuidString: itemIdStr)!,
                name: row[itemName],
                type: ItemType(rawValue: row[itemType]) ?? .secureNote,
                projectId: row[itemProjectId].flatMap { UUID(uuidString: $0) },
                data: decryptedData,
                tagIds: fetchedTagIds,
                createdAt: row[createdAt],
                updatedAt: row[updatedAt]
            ))
        }
        return result
    }
    
    // MARK: - Tag Operations
    
    func createTag(_ tag: Tag) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        try db.run(tags.insert(
            id <- tag.id.uuidString,
            tagName <- tag.name,
            tagColor <- tag.color,
            createdAt <- tag.createdAt,
            updatedAt <- tag.updatedAt
        ))
    }
    
    func updateTag(_ tag: Tag) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = tags.filter(id == tag.id.uuidString)
        try db.run(query.update(
            tagName <- tag.name,
            tagColor <- tag.color,
            updatedAt <- Date()
        ))
    }
    
    func deleteTag(id tagId: UUID) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = tags.filter(id == tagId.uuidString)
        try db.run(query.delete())
    }
    
    func fetchAllTags() throws -> [Tag] {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        var result: [Tag] = []
        for row in try db.prepare(tags.order(tagName.asc)) {
            result.append(Tag(
                id: UUID(uuidString: row[id])!,
                name: row[tagName],
                color: row[tagColor],
                createdAt: row[createdAt],
                updatedAt: row[updatedAt]
            ))
        }
        return result
    }
    
    func fetchTag(id tagId: UUID) throws -> Tag? {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        let query = tags.filter(id == tagId.uuidString)
        guard let row = try db.pluck(query) else { return nil }
        
        return Tag(
            id: UUID(uuidString: row[id])!,
            name: row[tagName],
            color: row[tagColor],
            createdAt: row[createdAt],
            updatedAt: row[updatedAt]
        )
    }
    
    // MARK: - Export/Import Support
    
    /// Exports all data for backup
    func exportAllData() throws -> ExportData {
        let allProjects = try fetchAllProjects()
        let allItems = try fetchAllItems()
        let allTags = try fetchAllTags()
        
        return ExportData(
            version: StorageConstants.exportSchemaVersion,
            exportDate: Date(),
            appVersion: StorageConstants.appVersion,
            projects: allProjects,
            items: allItems,
            tags: allTags
        )
    }
    
    /// Imports data from backup, replacing existing data
    func importData(_ data: ExportData) throws {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        // Clear existing data
        try db.run(itemTags.delete())
        try db.run(items.delete())
        try db.run(tags.delete())
        try db.run(projects.delete())
        
        // Import projects
        for project in data.projects {
            try createProject(project)
        }
        
        // Import tags
        for tag in data.tags {
            try createTag(tag)
        }
        
        // Import items
        for item in data.items {
            try createItem(item)
        }
    }
    
    /// Gets item count for a project
    func getItemCount(for projectId: UUID?) throws -> Int {
        guard let db = db else { throw StorageError.databaseNotOpen }
        
        if let projectId = projectId {
            return try db.scalar(items.filter(itemProjectId == projectId.uuidString).count)
        } else {
            return try db.scalar(items.count)
        }
    }
}

// MARK: - Export Data Structure

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
    let projects: [Project]
    let items: [Item]
    let tags: [Tag]
}
