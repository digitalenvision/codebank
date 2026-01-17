import Foundation

extension String {
    /// Expands tilde (~) to the user's home directory
    var expandingTildeInPath: String {
        if hasPrefix("~") {
            return (self as NSString).expandingTildeInPath
        }
        return self
    }
    
    /// Abbreviates the home directory path to tilde
    var abbreviatingWithTildeInPath: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
    
    /// Checks if the string is a valid file path
    var isValidFilePath: Bool {
        let expanded = expandingTildeInPath
        return FileManager.default.fileExists(atPath: expanded)
    }
    
    /// Returns the string as a URL if it's a valid path
    var fileURL: URL? {
        let expanded = expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }
    
    /// Masks a secret string, showing only the first and last few characters
    func masked(visibleChars: Int = 4) -> String {
        guard count > visibleChars * 2 else {
            return String(repeating: "•", count: count)
        }
        
        let prefix = self.prefix(visibleChars)
        let suffix = self.suffix(visibleChars)
        let maskLength = count - (visibleChars * 2)
        let mask = String(repeating: "•", count: min(maskLength, 8))
        
        return "\(prefix)\(mask)\(suffix)"
    }
    
    /// Truncates the string to a maximum length with ellipsis
    func truncated(to length: Int, trailing: String = "…") -> String {
        guard count > length else { return self }
        return String(prefix(length - trailing.count)) + trailing
    }
    
    /// Validates as a hostname
    var isValidHostname: Bool {
        // Basic hostname validation
        let pattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Validates as an IP address
    var isValidIPAddress: Bool {
        // IPv4 pattern
        let ipv4Pattern = "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"
        // IPv6 pattern (simplified)
        let ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"
        
        return range(of: ipv4Pattern, options: .regularExpression) != nil ||
               range(of: ipv6Pattern, options: .regularExpression) != nil
    }
    
    /// Validates as a port number
    var isValidPort: Bool {
        guard let port = Int(self) else { return false }
        return port >= 1 && port <= 65535
    }
}

// MARK: - Connection String Parsing

extension String {
    /// Parses a database connection string into components
    func parseConnectionString() -> (host: String?, port: Int?, username: String?, password: String?, database: String?)? {
        // Pattern: protocol://username:password@host:port/database
        let pattern = "^(\\w+)://(?:([^:]+):([^@]+)@)?([^:/]+)(?::(\\d+))?(?:/(.+))?$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else {
            return nil
        }
        
        func group(_ index: Int) -> String? {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: self) else {
                return nil
            }
            let str = String(self[range])
            return str.isEmpty ? nil : str
        }
        
        return (
            host: group(4),
            port: group(5).flatMap { Int($0) },
            username: group(2),
            password: group(3),
            database: group(6)
        )
    }
}

// MARK: - Shell Command Helpers

extension String {
    /// Splits a command string into arguments (respecting quotes)
    func splitShellArguments() -> [String] {
        var arguments: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        var escaped = false
        
        for char in self {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }
            
            if char == "\\" {
                escaped = true
                continue
            }
            
            if char == "\"" || char == "'" {
                if inQuotes {
                    if char == quoteChar {
                        inQuotes = false
                        continue
                    }
                } else {
                    inQuotes = true
                    quoteChar = char
                    continue
                }
            }
            
            if char == " " && !inQuotes {
                if !current.isEmpty {
                    arguments.append(current)
                    current = ""
                }
                continue
            }
            
            current.append(char)
        }
        
        if !current.isEmpty {
            arguments.append(current)
        }
        
        return arguments
    }
}
