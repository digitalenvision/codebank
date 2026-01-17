import Foundation
import SwiftUI

/// Represents a vault item (API key, credential, command, etc.)
struct Item: Identifiable, Codable, Hashable {
    /// Unique identifier
    var id: UUID
    
    /// Display name of the item
    var name: String
    
    /// Type of the item
    var type: ItemType
    
    /// Parent project ID (nil for items not in a project)
    var projectId: UUID?
    
    /// Type-specific encrypted data
    var data: ItemData
    
    /// Associated tag IDs
    var tagIds: [UUID]
    
    /// Whether this item is marked as favorite
    var isFavorite: Bool
    
    /// Creation timestamp
    var createdAt: Date
    
    /// Last modification timestamp
    var updatedAt: Date
    
    /// Creates a new item with default values
    init(name: String, type: ItemType, projectId: UUID? = nil, data: ItemData? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.projectId = projectId
        self.data = data ?? ItemData.empty(for: type)
        self.tagIds = []
        self.isFavorite = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Creates an item with all values specified (for database loading)
    init(
        id: UUID,
        name: String,
        type: ItemType,
        projectId: UUID?,
        data: ItemData,
        tagIds: [UUID],
        isFavorite: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.projectId = projectId
        self.data = data
        self.tagIds = tagIds
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ItemType.self, forKey: .type)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        data = try container.decode(ItemData.self, forKey: .data)
        tagIds = try container.decodeIfPresent([UUID].self, forKey: .tagIds) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, projectId, data, tagIds, isFavorite, createdAt, updatedAt
    }
    
    /// Returns the SF Symbol icon for this item's type
    var icon: String {
        type.icon
    }
    
    /// Returns the color for this item's type
    var color: Color {
        type.color
    }
    
    /// Returns the primary copiable value for this item
    var primaryValue: String? {
        data.primaryValue
    }
}

// MARK: - Convenience Accessors

extension Item {
    /// API Key specific data (nil if not an API key item)
    var apiKeyData: APIKeyData? {
        if case .apiKey(let data) = data {
            return data
        }
        return nil
    }
    
    /// Database specific data (nil if not a database item)
    var databaseData: DatabaseData? {
        if case .database(let data) = data {
            return data
        }
        return nil
    }
    
    /// Server specific data (nil if not a server item)
    var serverData: ServerData? {
        if case .server(let data) = data {
            return data
        }
        return nil
    }
    
    /// SSH specific data (nil if not an SSH item)
    var sshData: SSHData? {
        if case .ssh(let data) = data {
            return data
        }
        return nil
    }
    
    /// Command specific data (nil if not a command item)
    var commandData: CommandData? {
        if case .command(let data) = data {
            return data
        }
        return nil
    }
    
    /// Secure note specific data (nil if not a secure note item)
    var secureNoteData: SecureNoteData? {
        if case .secureNote(let data) = data {
            return data
        }
        return nil
    }
    
    /// Whether this item can be executed (commands and SSH)
    var isExecutable: Bool {
        type == .command || type == .ssh
    }
    
    /// Whether this item is dangerous (for commands)
    var isDangerous: Bool {
        if let commandData = commandData {
            return commandData.isDangerous
        }
        return false
    }
    
    /// Whether this item requires confirmation before execution
    var requiresConfirmation: Bool {
        if let commandData = commandData {
            return commandData.requiresConfirmation || commandData.isDangerous
        }
        return false
    }
}

// MARK: - Mutating Methods

extension Item {
    /// Updates the API key data
    mutating func updateAPIKeyData(_ newData: APIKeyData) {
        guard type == .apiKey else { return }
        data = .apiKey(newData)
        updatedAt = Date()
    }
    
    /// Updates the database data
    mutating func updateDatabaseData(_ newData: DatabaseData) {
        guard type == .database else { return }
        data = .database(newData)
        updatedAt = Date()
    }
    
    /// Updates the server data
    mutating func updateServerData(_ newData: ServerData) {
        guard type == .server else { return }
        data = .server(newData)
        updatedAt = Date()
    }
    
    /// Updates the SSH data
    mutating func updateSSHData(_ newData: SSHData) {
        guard type == .ssh else { return }
        data = .ssh(newData)
        updatedAt = Date()
    }
    
    /// Updates the command data
    mutating func updateCommandData(_ newData: CommandData) {
        guard type == .command else { return }
        data = .command(newData)
        updatedAt = Date()
    }
    
    /// Updates the secure note data
    mutating func updateSecureNoteData(_ newData: SecureNoteData) {
        guard type == .secureNote else { return }
        data = .secureNote(newData)
        updatedAt = Date()
    }
}

// MARK: - Sample Data

extension Item {
    static let sampleAPIKey = Item(
        id: UUID(),
        name: "Stripe API Key",
        type: .apiKey,
        projectId: nil,
        data: .apiKey(APIKeyData(
            key: "your_api_key_here",
            service: "Stripe",
            environment: "Production",
            notes: "Main production key for payment processing"
        )),
        tagIds: [],
        isFavorite: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let sampleDatabase = Item(
        id: UUID(),
        name: "Production PostgreSQL",
        type: .database,
        projectId: nil,
        data: .database(DatabaseData(
            host: "db.example.com",
            port: 5432,
            username: "app_user",
            password: "secret_password_123",
            databaseName: "production_db",
            notes: "Main production database"
        )),
        tagIds: [],
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let sampleSSH = Item(
        id: UUID(),
        name: "Production Server",
        type: .ssh,
        projectId: nil,
        data: .ssh(SSHData(
            user: "deploy",
            host: "server.example.com",
            port: 22,
            identityKeyPath: "~/.ssh/id_rsa",
            notes: "Production application server"
        )),
        tagIds: [],
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let sampleCommand = Item(
        id: UUID(),
        name: "Deploy Production",
        type: .command,
        projectId: nil,
        data: .command(CommandData(
            command: "git pull origin main && docker-compose up -d --build",
            shell: ShellType.zsh.rawValue,
            workingDirectory: "~/projects/backend",
            requiresConfirmation: true,
            isDangerous: true,
            notes: "Deploys the latest code to production"
        )),
        tagIds: [],
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let samples: [Item] = [
        sampleAPIKey,
        sampleDatabase,
        sampleSSH,
        sampleCommand
    ]
}
