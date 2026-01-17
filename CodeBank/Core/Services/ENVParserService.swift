import Foundation

/// Service for parsing .env files and detecting item types with intelligent grouping
final class ENVParserService {
    
    static let shared = ENVParserService()
    
    private init() {}
    
    // MARK: - Raw Parsed Variable
    
    struct ParsedVariable {
        let key: String
        let value: String
        let prefix: String
        let suffix: String
    }
    
    // MARK: - Grouped Parsed Item
    
    struct ParsedEnvItem: Identifiable {
        let id = UUID()
        var name: String
        var variables: [ParsedVariable]
        var suggestedType: ItemType
        var isSelected: Bool = true
        
        /// Primary secret value (API key, password, etc.)
        var primarySecret: String? {
            // Look for the main secret in the group
            let secretSuffixes = ["API_KEY", "APIKEY", "SECRET", "SECRET_KEY", "PASSWORD", 
                                  "TOKEN", "ACCESS_KEY", "PRIVATE_KEY", "KEY"]
            for suffix in secretSuffixes {
                if let variable = variables.first(where: { $0.suffix.uppercased().contains(suffix) }) {
                    return variable.value
                }
            }
            // If only one variable, use it
            if variables.count == 1 {
                return variables.first?.value
            }
            return nil
        }
        
        /// Service name extracted from prefix
        var serviceName: String {
            // Convert OPENROUTER to "OpenRouter", STRIPE to "Stripe"
            return name
        }
        
        /// All variables formatted as key=value pairs
        var formattedContent: String {
            variables.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        }
        
        /// Additional metadata (non-secret values)
        var metadata: [(key: String, value: String)] {
            let secretSuffixes = ["API_KEY", "APIKEY", "SECRET", "SECRET_KEY", "PASSWORD",
                                  "TOKEN", "ACCESS_KEY", "PRIVATE_KEY", "KEY"]
            return variables.compactMap { variable in
                let isSecret = secretSuffixes.contains { variable.suffix.uppercased().contains($0) }
                if !isSecret {
                    return (key: variable.suffix.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: variable.value)
                }
                return nil
            }
        }
    }
    
    // MARK: - Parsing
    
    /// Parse an ENV file content and return intelligently grouped items
    func parse(_ content: String) -> [ParsedEnvItem] {
        // First pass: parse all variables
        var allVariables: [ParsedVariable] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            guard let equalsIndex = trimmed.firstIndex(of: "=") else {
                continue
            }
            
            let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            
            // Remove quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            
            if value.isEmpty { continue }
            
            let (prefix, suffix) = extractPrefixSuffix(from: key)
            allVariables.append(ParsedVariable(key: key, value: value, prefix: prefix, suffix: suffix))
        }
        
        // Second pass: group by prefix
        var groupedByPrefix: [String: [ParsedVariable]] = [:]
        var ungrouped: [ParsedVariable] = []
        
        for variable in allVariables {
            if variable.prefix.isEmpty {
                ungrouped.append(variable)
            } else {
                groupedByPrefix[variable.prefix, default: []].append(variable)
            }
        }
        
        // Third pass: create items from groups
        var items: [ParsedEnvItem] = []
        
        // Process grouped variables
        for (prefix, variables) in groupedByPrefix.sorted(by: { $0.key < $1.key }) {
            let item = createGroupedItem(prefix: prefix, variables: variables)
            items.append(item)
        }
        
        // Process ungrouped variables individually
        for variable in ungrouped {
            let item = createSingleItem(variable: variable)
            items.append(item)
        }
        
        return items
    }
    
    // MARK: - Prefix/Suffix Extraction
    
    private func extractPrefixSuffix(from key: String) -> (prefix: String, suffix: String) {
        // Common patterns:
        // OPENROUTER_API_KEY -> prefix: OPENROUTER, suffix: API_KEY
        // STRIPE_SECRET_KEY -> prefix: STRIPE, suffix: SECRET_KEY
        // DATABASE_URL -> prefix: DATABASE, suffix: URL (or treat as single)
        // NEXT_PUBLIC_STRIPE_KEY -> prefix: STRIPE, suffix: KEY (skip NEXT_PUBLIC)
        
        var workingKey = key
        
        // Remove common framework prefixes
        let frameworkPrefixes = ["NEXT_PUBLIC_", "REACT_APP_", "VITE_", "NUXT_", "VUE_APP_", "EXPO_PUBLIC_"]
        for fwPrefix in frameworkPrefixes {
            if workingKey.hasPrefix(fwPrefix) {
                workingKey = String(workingKey.dropFirst(fwPrefix.count))
                break
            }
        }
        
        let parts = workingKey.components(separatedBy: "_")
        
        // If only one part, no prefix
        if parts.count == 1 {
            return ("", workingKey)
        }
        
        // Known service prefixes (first part is the service)
        let knownServices = ["OPENROUTER", "STRIPE", "AWS", "AZURE", "GCP", "GOOGLE", "FIREBASE",
                            "SUPABASE", "PRISMA", "MONGODB", "POSTGRES", "MYSQL", "REDIS",
                            "SENDGRID", "MAILGUN", "TWILIO", "SLACK", "DISCORD", "GITHUB",
                            "GITLAB", "BITBUCKET", "VERCEL", "NETLIFY", "HEROKU", "DOCKER",
                            "OPENAI", "ANTHROPIC", "COHERE", "HUGGINGFACE", "REPLICATE",
                            "CLOUDFLARE", "DIGITALOCEAN", "LINODE", "VULTR", "SENTRY",
                            "DATADOG", "NEWRELIC", "LOGFLARE", "AMPLITUDE", "MIXPANEL",
                            "SEGMENT", "INTERCOM", "ZENDESK", "HUBSPOT", "SALESFORCE",
                            "PAYPAL", "SQUARE", "BRAINTREE", "PLAID", "ALGOLIA", "ELASTICSEARCH",
                            "MEILISEARCH", "TYPESENSE", "PINECONE", "WEAVIATE", "QDRANT",
                            "AUTH0", "OKTA", "CLERK", "NEXTAUTH", "SUPERTOKENS", "RESEND",
                            "POSTMARK", "PUSHER", "ABLY", "LIVEKIT", "AGORA", "DAILY",
                            "UPLOADTHING", "CLOUDINARY", "IMGIX", "SANITY", "CONTENTFUL",
                            "STRAPI", "DIRECTUS", "APPWRITE", "NEON", "PLANETSCALE", "TURSO",
                            "UPSTASH", "CONVEX", "FAUNA", "COCKROACH", "TIMESCALE", "QUESTDB"]
        
        // Check if first part is a known service
        if knownServices.contains(parts[0].uppercased()) {
            let prefix = parts[0]
            let suffix = parts.dropFirst().joined(separator: "_")
            return (prefix, suffix)
        }
        
        // Check if first two parts form a known service pattern
        if parts.count >= 2 {
            let twoPartPrefix = "\(parts[0])_\(parts[1])"
            // e.g., OPEN_AI, DIGITAL_OCEAN
            if knownServices.contains(twoPartPrefix.uppercased().replacingOccurrences(of: "_", with: "")) {
                let suffix = parts.dropFirst(2).joined(separator: "_")
                return (twoPartPrefix, suffix.isEmpty ? parts[1] : suffix)
            }
        }
        
        // Heuristic: if key ends with known suffixes, use first part(s) as prefix
        let knownSuffixes = ["API_KEY", "SECRET_KEY", "ACCESS_KEY", "PRIVATE_KEY", "PUBLIC_KEY",
                            "CLIENT_ID", "CLIENT_SECRET", "APP_ID", "APP_SECRET", "APP_KEY",
                            "DATABASE_URL", "CONNECTION_STRING", "DSN", "URI", "URL",
                            "HOST", "PORT", "USER", "USERNAME", "PASSWORD", "NAME",
                            "TOKEN", "SECRET", "KEY", "ID", "REGION", "BUCKET", "PROJECT",
                            "WEBHOOK_SECRET", "SIGNING_SECRET", "ENCRYPTION_KEY"]
        
        for suffix in knownSuffixes {
            if workingKey.hasSuffix(suffix) {
                let prefixPart = String(workingKey.dropLast(suffix.count + 1)) // +1 for underscore
                if !prefixPart.isEmpty {
                    return (prefixPart, suffix)
                }
            }
        }
        
        // Default: first part is prefix, rest is suffix
        let prefix = parts[0]
        let suffix = parts.dropFirst().joined(separator: "_")
        return (prefix, suffix)
    }
    
    // MARK: - Item Creation
    
    private func createGroupedItem(prefix: String, variables: [ParsedVariable]) -> ParsedEnvItem {
        let name = formatServiceName(prefix)
        let type = detectGroupType(variables: variables)
        
        return ParsedEnvItem(
            name: name,
            variables: variables,
            suggestedType: type
        )
    }
    
    private func createSingleItem(variable: ParsedVariable) -> ParsedEnvItem {
        let name = formatServiceName(variable.key)
        let type = detectSingleType(variable: variable)
        
        return ParsedEnvItem(
            name: name,
            variables: [variable],
            suggestedType: type
        )
    }
    
    private func detectGroupType(variables: [ParsedVariable]) -> ItemType {
        // Check if group contains database URL
        for v in variables {
            if let _ = parseDatabaseURL(v.value) {
                return .database
            }
        }
        
        // Check if group contains API key or secret
        let secretSuffixes = ["API_KEY", "APIKEY", "SECRET", "SECRET_KEY", "PASSWORD",
                              "TOKEN", "ACCESS_KEY", "PRIVATE_KEY", "KEY"]
        for v in variables {
            for suffix in secretSuffixes {
                if v.suffix.uppercased().contains(suffix) || v.key.uppercased().contains(suffix) {
                    return .apiKey
                }
            }
        }
        
        // Check if group contains host/server info
        let serverSuffixes = ["HOST", "SERVER", "ENDPOINT", "URL", "URI"]
        let hasServer = variables.contains { v in
            serverSuffixes.contains { v.suffix.uppercased().contains($0) }
        }
        if hasServer {
            return .server
        }
        
        // Default to secure note for grouped config
        return .secureNote
    }
    
    private func detectSingleType(variable: ParsedVariable) -> ItemType {
        let upperKey = variable.key.uppercased()
        let value = variable.value
        
        // Database URL
        if let _ = parseDatabaseURL(value) {
            return .database
        }
        
        // API Key / Secret
        let secretPatterns = ["API_KEY", "APIKEY", "SECRET", "TOKEN", "PASSWORD", 
                              "ACCESS_KEY", "PRIVATE_KEY", "AUTH"]
        for pattern in secretPatterns {
            if upperKey.contains(pattern) {
                return .apiKey
            }
        }
        
        // Server/Host
        let serverPatterns = ["HOST", "SERVER", "ENDPOINT", "URL", "URI"]
        for pattern in serverPatterns {
            if upperKey.contains(pattern) {
                return .server
            }
        }
        
        // Looks like a secret value
        if looksLikeSecret(value) {
            return .apiKey
        }
        
        return .secureNote
    }
    
    // MARK: - URL Parsing
    
    private func parseDatabaseURL(_ urlString: String) -> DatabaseData? {
        let dbPrefixes = ["postgres://", "postgresql://", "mysql://", "mongodb://",
                         "mongodb+srv://", "redis://", "rediss://", "mariadb://"]
        
        var workingString = urlString
        var detectedType: String?
        
        for prefix in dbPrefixes {
            if urlString.lowercased().hasPrefix(prefix) {
                detectedType = prefix.replacingOccurrences(of: "://", with: "")
                workingString = String(urlString.dropFirst(prefix.count))
                break
            }
        }
        
        guard detectedType != nil else { return nil }
        
        var username = ""
        var password = ""
        var host = ""
        var port = 5432
        var database = ""
        
        let atParts = workingString.components(separatedBy: "@")
        
        if atParts.count == 2 {
            let credentials = atParts[0].components(separatedBy: ":")
            username = credentials[0]
            if credentials.count > 1 {
                password = credentials[1]
            }
            workingString = atParts[1]
        } else {
            workingString = atParts[0]
        }
        
        if let queryIndex = workingString.firstIndex(of: "?") {
            workingString = String(workingString[..<queryIndex])
        }
        
        let slashParts = workingString.components(separatedBy: "/")
        let hostPort = slashParts[0]
        if slashParts.count > 1 {
            database = slashParts[1]
        }
        
        let colonParts = hostPort.components(separatedBy: ":")
        host = colonParts[0]
        if colonParts.count > 1, let parsedPort = Int(colonParts[1]) {
            port = parsedPort
        }
        
        return DatabaseData(
            host: host,
            port: port,
            username: username,
            password: password,
            databaseName: database,
            connectionString: urlString
        )
    }
    
    // MARK: - Helpers
    
    private func looksLikeSecret(_ value: String) -> Bool {
        guard value.count >= 20 else { return false }
        guard !value.contains(" ") else { return false }
        
        let hasLetters = value.contains(where: { $0.isLetter })
        let hasNumbers = value.contains(where: { $0.isNumber })
        
        let secretPrefixes = ["sk_", "pk_", "api_", "key_", "secret_", "token_", 
                              "whsec_", "rk_", "ac_", "sig_"]
        for prefix in secretPrefixes {
            if value.lowercased().hasPrefix(prefix) {
                return true
            }
        }
        
        return hasLetters && hasNumbers
    }
    
    private func formatFieldName(_ suffix: String) -> String {
        // Convert API_KEY to "API Key", SECRET_KEY to "Secret Key", etc.
        let specialCases: [String: String] = [
            "API_KEY": "API Key",
            "APIKEY": "API Key",
            "SECRET_KEY": "Secret Key",
            "SECRETKEY": "Secret Key",
            "SECRET": "Secret",
            "PUBLISHABLE_KEY": "Publishable Key",
            "PUBLIC_KEY": "Public Key",
            "PRIVATE_KEY": "Private Key",
            "ACCESS_KEY": "Access Key",
            "ACCESS_KEY_ID": "Access Key ID",
            "WEBHOOK_SECRET": "Webhook Secret",
            "SIGNING_SECRET": "Signing Secret",
            "CLIENT_ID": "Client ID",
            "CLIENT_SECRET": "Client Secret",
            "APP_ID": "App ID",
            "APP_KEY": "App Key",
            "APP_SECRET": "App Secret",
            "BASE_URL": "Base URL",
            "SITE_URL": "Site URL",
            "APP_URL": "App URL",
            "CALLBACK_URL": "Callback URL",
            "REDIRECT_URL": "Redirect URL",
            "WEBHOOK_URL": "Webhook URL",
            "APP_NAME": "App Name",
            "PROJECT_ID": "Project ID",
            "REGION": "Region",
            "BUCKET": "Bucket",
            "TOKEN": "Token",
            "PASSWORD": "Password",
            "USERNAME": "Username",
            "HOST": "Host",
            "PORT": "Port",
            "URL": "URL",
            "URI": "URI",
            "DSN": "DSN",
            "KEY": "Key",
            "ID": "ID",
        ]
        
        // Check for exact match first
        if let special = specialCases[suffix.uppercased()] {
            return special
        }
        
        // Otherwise, convert SOME_FIELD to "Some Field"
        return suffix
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func isSecretField(_ suffix: String, value: String? = nil) -> Bool {
        // First, check if the VALUE looks like a URL - URLs are never secrets
        if let value = value {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasPrefix("http://") || 
               trimmed.hasPrefix("https://") ||
               trimmed.hasPrefix("ftp://") ||
               trimmed.hasPrefix("sftp://") ||
               trimmed.hasPrefix("ws://") ||
               trimmed.hasPrefix("wss://") {
                return false
            }
        }
        
        let secretPatterns = ["API_KEY", "APIKEY", "SECRET", "PASSWORD", "TOKEN",
                              "ACCESS_KEY", "PRIVATE_KEY", "KEY", "CREDENTIAL"]
        let upperSuffix = suffix.uppercased()
        
        for pattern in secretPatterns {
            if upperSuffix.contains(pattern) {
                return true
            }
        }
        
        // URL, ID, NAME, HOST, PORT, REGION are not secrets
        let nonSecretPatterns = ["URL", "URI", "HOST", "PORT", "NAME", "ID", "REGION", "BUCKET", "PROJECT", "ENDPOINT", "SITE", "APP", "DOMAIN"]
        for pattern in nonSecretPatterns {
            if upperSuffix.contains(pattern) {
                return false
            }
        }
        
        // Default to secret for unknown fields
        return true
    }
    
    /// Check if a value looks like a URL
    private func isURLValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("http://") || 
               trimmed.hasPrefix("https://") ||
               trimmed.hasPrefix("ftp://") ||
               trimmed.hasPrefix("sftp://") ||
               trimmed.hasPrefix("ws://") ||
               trimmed.hasPrefix("wss://")
    }
    
    private func formatServiceName(_ name: String) -> String {
        // Handle special cases
        let specialCases: [String: String] = [
            "OPENROUTER": "OpenRouter",
            "OPENAI": "OpenAI",
            "GITHUB": "GitHub",
            "GITLAB": "GitLab",
            "BITBUCKET": "Bitbucket",
            "POSTGRESQL": "PostgreSQL",
            "MONGODB": "MongoDB",
            "MYSQL": "MySQL",
            "DIGITALOCEAN": "DigitalOcean",
            "CLOUDFLARE": "Cloudflare",
            "SENDGRID": "SendGrid",
            "MAILGUN": "Mailgun",
            "HUBSPOT": "HubSpot",
            "SALESFORCE": "Salesforce",
            "ELASTICSEARCH": "Elasticsearch",
            "MEILISEARCH": "Meilisearch",
            "APPWRITE": "Appwrite",
            "SUPABASE": "Supabase",
            "FIREBASE": "Firebase",
            "VERCEL": "Vercel",
            "NETLIFY": "Netlify",
            "HEROKU": "Heroku",
            "NEXTAUTH": "NextAuth",
            "LIVEKIT": "LiveKit",
        ]
        
        let upperName = name.uppercased().replacingOccurrences(of: "_", with: "")
        if let special = specialCases[upperName] {
            return special
        }
        
        // Convert SOME_SERVICE to "Some Service"
        return name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    // MARK: - Item Creation from Parsed Item
    
    /// Create an Item from a parsed env item
    func createItem(from parsed: ParsedEnvItem, projectId: UUID?) -> Item {
        var item = Item(
            name: parsed.name,
            type: parsed.suggestedType,
            projectId: projectId
        )
        
        switch parsed.suggestedType {
        case .apiKey:
            // Convert all variables to credential fields
            var fields: [CredentialField] = []
            
            for variable in parsed.variables {
                let fieldName = formatFieldName(variable.suffix)
                let isSecret = isSecretField(variable.suffix, value: variable.value)
                fields.append(CredentialField(
                    name: fieldName,
                    value: variable.value,
                    isSecret: isSecret
                ))
            }
            
            item.data = .apiKey(APIKeyData(
                key: "",  // Legacy field, use fields array instead
                service: parsed.serviceName,
                environment: nil,
                fields: fields,
                notes: nil
            ))
            
        case .database:
            // Find the database URL variable
            var dbData: DatabaseData?
            for v in parsed.variables {
                if let data = parseDatabaseURL(v.value) {
                    dbData = data
                    break
                }
            }
            if let data = dbData {
                item.data = .database(data)
            } else {
                // Fallback to secure note with all vars
                item.data = .secureNote(SecureNoteData(content: parsed.formattedContent))
            }
            
        case .server:
            // Try to extract server info
            var hostname = ""
            var port = 443
            var username = ""
            
            for v in parsed.variables {
                let upperSuffix = v.suffix.uppercased()
                if upperSuffix.contains("HOST") || upperSuffix.contains("URL") {
                    // Parse URL if present
                    var value = v.value
                    // Remove protocol
                    for prefix in ["https://", "http://", "wss://", "ws://"] {
                        if value.lowercased().hasPrefix(prefix) {
                            value = String(value.dropFirst(prefix.count))
                            break
                        }
                    }
                    // Remove path
                    if let idx = value.firstIndex(of: "/") {
                        value = String(value[..<idx])
                    }
                    // Split host:port
                    let parts = value.components(separatedBy: ":")
                    hostname = parts[0]
                    if parts.count > 1, let p = Int(parts[1]) {
                        port = p
                    }
                } else if upperSuffix.contains("PORT") {
                    if let p = Int(v.value) {
                        port = p
                    }
                } else if upperSuffix.contains("USER") {
                    username = v.value
                }
            }
            
            item.data = .server(ServerData(
                hostname: hostname,
                port: port,
                username: username,
                notes: parsed.formattedContent
            ))
            
        case .ssh:
            item.data = .ssh(SSHData(
                user: "",
                host: parsed.variables.first?.value ?? "",
                port: 22
            ))
            
        case .command:
            item.data = .command(CommandData(
                command: parsed.variables.first?.value ?? "",
                shell: ShellType.zsh.rawValue
            ))
            
        case .secureNote:
            // Store all variables as formatted content
            item.data = .secureNote(SecureNoteData(content: parsed.formattedContent))
        }
        
        return item
    }
}

