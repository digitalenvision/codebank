import Foundation

/// Container for type-specific item data
/// This is stored encrypted in the database
enum ItemData: Codable, Hashable {
    case apiKey(APIKeyData)
    case database(DatabaseData)
    case server(ServerData)
    case ssh(SSHData)
    case command(CommandData)
    case secureNote(SecureNoteData)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "apiKey":
            let data = try container.decode(APIKeyData.self, forKey: .data)
            self = .apiKey(data)
        case "database":
            let data = try container.decode(DatabaseData.self, forKey: .data)
            self = .database(data)
        case "server":
            let data = try container.decode(ServerData.self, forKey: .data)
            self = .server(data)
        case "ssh":
            let data = try container.decode(SSHData.self, forKey: .data)
            self = .ssh(data)
        case "command":
            let data = try container.decode(CommandData.self, forKey: .data)
            self = .command(data)
        case "secureNote":
            let data = try container.decode(SecureNoteData.self, forKey: .data)
            self = .secureNote(data)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown item type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .apiKey(let data):
            try container.encode("apiKey", forKey: .type)
            try container.encode(data, forKey: .data)
        case .database(let data):
            try container.encode("database", forKey: .type)
            try container.encode(data, forKey: .data)
        case .server(let data):
            try container.encode("server", forKey: .type)
            try container.encode(data, forKey: .data)
        case .ssh(let data):
            try container.encode("ssh", forKey: .type)
            try container.encode(data, forKey: .data)
        case .command(let data):
            try container.encode("command", forKey: .type)
            try container.encode(data, forKey: .data)
        case .secureNote(let data):
            try container.encode("secureNote", forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
    
    /// Returns the primary copiable value for this item
    var primaryValue: String? {
        switch self {
        case .apiKey(let data):
            return data.key
        case .database(let data):
            return data.connectionString ?? data.password
        case .server(let data):
            return data.hostname
        case .ssh(let data):
            return "\(data.user)@\(data.host)"
        case .command(let data):
            return data.command
        case .secureNote(let data):
            return data.content
        }
    }
}

// MARK: - Credential Field

/// A single credential field (key-value pair)
struct CredentialField: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var value: String
    var isSecret: Bool
    
    init(id: UUID = UUID(), name: String = "", value: String = "", isSecret: Bool = true) {
        self.id = id
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? true
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, value, isSecret
    }
    
    /// Common field presets
    static func apiKey(_ value: String = "") -> CredentialField {
        CredentialField(name: "API Key", value: value, isSecret: true)
    }
    
    static func secretKey(_ value: String = "") -> CredentialField {
        CredentialField(name: "Secret Key", value: value, isSecret: true)
    }
    
    static func publishableKey(_ value: String = "") -> CredentialField {
        CredentialField(name: "Publishable Key", value: value, isSecret: false)
    }
    
    static func webhookSecret(_ value: String = "") -> CredentialField {
        CredentialField(name: "Webhook Secret", value: value, isSecret: true)
    }
    
    static func baseURL(_ value: String = "") -> CredentialField {
        CredentialField(name: "Base URL", value: value, isSecret: false)
    }
    
    static func url(name: String, value: String = "") -> CredentialField {
        CredentialField(name: name, value: value, isSecret: false)
    }
}

// MARK: - API Key Data

struct APIKeyData: Codable, Hashable {
    var key: String  // Legacy: primary API key for backward compatibility
    var service: String
    var environment: String?
    var fields: [CredentialField]  // Multiple credential fields
    var notes: String?
    
    init(key: String = "", service: String = "", environment: String? = nil, fields: [CredentialField] = [], notes: String? = nil) {
        self.key = key
        self.service = service
        self.environment = environment
        self.fields = fields
        self.notes = notes
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        service = try container.decodeIfPresent(String.self, forKey: .service) ?? ""
        environment = try container.decodeIfPresent(String.self, forKey: .environment)
        fields = try container.decodeIfPresent([CredentialField].self, forKey: .fields) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case key, service, environment, fields, notes
    }
    
    /// All fields including the legacy key field (for display)
    var allFields: [CredentialField] {
        var result: [CredentialField] = []
        
        // Add legacy key as first field if it has a value and no fields exist
        if !key.isEmpty && fields.isEmpty {
            result.append(.apiKey(key))
        }
        
        // Add all custom fields
        result.append(contentsOf: fields)
        
        return result
    }
    
    /// Primary secret value (first secret field)
    var primarySecret: String? {
        if !key.isEmpty { return key }
        return fields.first(where: { $0.isSecret })?.value
    }
}

// MARK: - Database Data

struct DatabaseData: Codable, Hashable {
    var host: String
    var port: Int
    var username: String
    var password: String
    var databaseName: String
    var connectionString: String?
    var databaseType: String?  // postgresql, mysql, mongodb, redis, etc.
    var sslMode: String?  // disable, require, verify-ca, verify-full
    var customFields: [CredentialField]  // Additional fields like read replica, admin creds, etc.
    var notes: String?
    
    init(
        host: String = "",
        port: Int = 5432,
        username: String = "",
        password: String = "",
        databaseName: String = "",
        connectionString: String? = nil,
        databaseType: String? = nil,
        sslMode: String? = nil,
        customFields: [CredentialField] = [],
        notes: String? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.databaseName = databaseName
        self.connectionString = connectionString
        self.databaseType = databaseType
        self.sslMode = sslMode
        self.customFields = customFields
        self.notes = notes
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 5432
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        databaseName = try container.decodeIfPresent(String.self, forKey: .databaseName) ?? ""
        connectionString = try container.decodeIfPresent(String.self, forKey: .connectionString)
        databaseType = try container.decodeIfPresent(String.self, forKey: .databaseType)
        sslMode = try container.decodeIfPresent(String.self, forKey: .sslMode)
        customFields = try container.decodeIfPresent([CredentialField].self, forKey: .customFields) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case host, port, username, password, databaseName, connectionString, databaseType, sslMode, customFields, notes
    }
    
    /// Generates a connection string based on the fields
    func generateConnectionString(type: DatabaseType = .postgresql) -> String {
        switch type {
        case .postgresql:
            return "postgresql://\(username):\(password)@\(host):\(port)/\(databaseName)"
        case .mysql:
            return "mysql://\(username):\(password)@\(host):\(port)/\(databaseName)"
        case .mongodb:
            return "mongodb://\(username):\(password)@\(host):\(port)/\(databaseName)"
        case .redis:
            if username.isEmpty {
                return "redis://:\(password)@\(host):\(port)"
            }
            return "redis://\(username):\(password)@\(host):\(port)"
        }
    }
    
    enum DatabaseType: String, CaseIterable {
        case postgresql = "PostgreSQL"
        case mysql = "MySQL"
        case mongodb = "MongoDB"
        case redis = "Redis"
    }
}

// MARK: - Server Data

struct ServerData: Codable, Hashable {
    var hostname: String
    var ipAddress: String?
    var port: Int  // Primary port (SSH by default)
    var httpPort: Int?
    var httpsPort: Int?
    var username: String
    var password: String?
    var rootPassword: String?
    var adminUrl: String?
    var customFields: [CredentialField]  // Additional fields like API keys, certificates, etc.
    var notes: String?
    
    init(
        hostname: String = "",
        ipAddress: String? = nil,
        port: Int = 22,
        httpPort: Int? = nil,
        httpsPort: Int? = nil,
        username: String = "",
        password: String? = nil,
        rootPassword: String? = nil,
        adminUrl: String? = nil,
        customFields: [CredentialField] = [],
        notes: String? = nil
    ) {
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.httpPort = httpPort
        self.httpsPort = httpsPort
        self.username = username
        self.password = password
        self.rootPassword = rootPassword
        self.adminUrl = adminUrl
        self.customFields = customFields
        self.notes = notes
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        httpPort = try container.decodeIfPresent(Int.self, forKey: .httpPort)
        httpsPort = try container.decodeIfPresent(Int.self, forKey: .httpsPort)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password)
        rootPassword = try container.decodeIfPresent(String.self, forKey: .rootPassword)
        adminUrl = try container.decodeIfPresent(String.self, forKey: .adminUrl)
        customFields = try container.decodeIfPresent([CredentialField].self, forKey: .customFields) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case hostname, ipAddress, port, httpPort, httpsPort, username, password, rootPassword, adminUrl, customFields, notes
    }
}

// MARK: - SSH Data

struct SSHData: Codable, Hashable {
    var user: String
    var host: String
    var port: Int
    var password: String?
    var identityKeyPath: String?
    var passphrase: String?  // For encrypted SSH keys
    var jumpHost: String?  // ProxyJump host
    var jumpUser: String?
    var localPortForward: String?  // e.g., "8080:localhost:80"
    var remotePortForward: String?
    var customFields: [CredentialField]  // Additional fields
    var notes: String?
    
    init(
        user: String = "",
        host: String = "",
        port: Int = 22,
        password: String? = nil,
        identityKeyPath: String? = nil,
        passphrase: String? = nil,
        jumpHost: String? = nil,
        jumpUser: String? = nil,
        localPortForward: String? = nil,
        remotePortForward: String? = nil,
        customFields: [CredentialField] = [],
        notes: String? = nil
    ) {
        self.user = user
        self.host = host
        self.port = port
        self.password = password
        self.identityKeyPath = identityKeyPath
        self.passphrase = passphrase
        self.jumpHost = jumpHost
        self.jumpUser = jumpUser
        self.localPortForward = localPortForward
        self.remotePortForward = remotePortForward
        self.customFields = customFields
        self.notes = notes
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        password = try container.decodeIfPresent(String.self, forKey: .password)
        identityKeyPath = try container.decodeIfPresent(String.self, forKey: .identityKeyPath)
        passphrase = try container.decodeIfPresent(String.self, forKey: .passphrase)
        jumpHost = try container.decodeIfPresent(String.self, forKey: .jumpHost)
        jumpUser = try container.decodeIfPresent(String.self, forKey: .jumpUser)
        localPortForward = try container.decodeIfPresent(String.self, forKey: .localPortForward)
        remotePortForward = try container.decodeIfPresent(String.self, forKey: .remotePortForward)
        customFields = try container.decodeIfPresent([CredentialField].self, forKey: .customFields) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case user, host, port, password, identityKeyPath, passphrase, jumpHost, jumpUser, localPortForward, remotePortForward, customFields, notes
    }
    
    /// Generates the SSH command string
    func sshCommand() -> String {
        var command = "ssh"
        
        if port != 22 {
            command += " -p \(port)"
        }
        
        if let keyPath = identityKeyPath, !keyPath.isEmpty {
            command += " -i \"\(keyPath)\""
        }
        
        // Add jump host if specified
        if let jump = jumpHost, !jump.isEmpty {
            let jumpTarget = jumpUser.map { "\($0)@\(jump)" } ?? jump
            command += " -J \(jumpTarget)"
        }
        
        // Add port forwarding
        if let local = localPortForward, !local.isEmpty {
            command += " -L \(local)"
        }
        
        if let remote = remotePortForward, !remote.isEmpty {
            command += " -R \(remote)"
        }
        
        command += " \(user)@\(host)"
        
        return command
    }
}

// MARK: - Command Data

struct CommandData: Codable, Hashable {
    var command: String
    var shell: String
    var workingDirectory: String?
    var environmentVariables: [CredentialField]  // Env vars needed for this command
    var customFields: [CredentialField]  // Related commands, scripts, etc.
    var requiresConfirmation: Bool
    var isDangerous: Bool
    var notes: String?
    
    init(
        command: String = "",
        shell: String = ShellType.zsh.rawValue,
        workingDirectory: String? = nil,
        environmentVariables: [CredentialField] = [],
        customFields: [CredentialField] = [],
        requiresConfirmation: Bool = false,
        isDangerous: Bool = false,
        notes: String? = nil
    ) {
        self.command = command
        self.shell = shell
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.customFields = customFields
        self.requiresConfirmation = requiresConfirmation
        self.isDangerous = isDangerous
        self.notes = notes
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        shell = try container.decodeIfPresent(String.self, forKey: .shell) ?? ShellType.zsh.rawValue
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        environmentVariables = try container.decodeIfPresent([CredentialField].self, forKey: .environmentVariables) ?? []
        customFields = try container.decodeIfPresent([CredentialField].self, forKey: .customFields) ?? []
        requiresConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? false
        isDangerous = try container.decodeIfPresent(Bool.self, forKey: .isDangerous) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case command, shell, workingDirectory, environmentVariables, customFields, requiresConfirmation, isDangerous, notes
    }
    
    /// Returns the full command with working directory change if specified
    func fullCommand() -> String {
        var result = ""
        
        // Add environment variables
        for envVar in environmentVariables where !envVar.name.isEmpty && !envVar.value.isEmpty {
            result += "\(envVar.name)=\"\(envVar.value)\" "
        }
        
        if let dir = workingDirectory, !dir.isEmpty {
            result += "cd \"\(dir)\" && "
        }
        
        result += command
        return result
    }
}

// MARK: - Secure Note Data

struct SecureNoteData: Codable, Hashable {
    var content: String
    var notes: String?
    
    init(content: String = "", notes: String? = nil) {
        self.content = content
        self.notes = notes
    }
}

// MARK: - Factory Methods

extension ItemData {
    /// Creates empty item data for the specified type
    static func empty(for type: ItemType) -> ItemData {
        switch type {
        case .apiKey:
            return .apiKey(APIKeyData())
        case .database:
            return .database(DatabaseData())
        case .server:
            return .server(ServerData())
        case .ssh:
            return .ssh(SSHData())
        case .command:
            return .command(CommandData())
        case .secureNote:
            return .secureNote(SecureNoteData())
        }
    }
}
