import Foundation

/// Represents a project (folder) that contains items
struct Project: Identifiable, Codable, Hashable {
    /// Unique identifier
    let id: UUID
    
    /// Display name of the project
    var name: String
    
    /// SF Symbol icon name
    var icon: String
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Last modification timestamp
    var updatedAt: Date
    
    /// Creates a new project with default values
    init(name: String, icon: String = "folder.fill") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Creates a project with all values specified (for database loading)
    init(id: UUID, name: String, icon: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Sample Data

extension Project {
    static let sample = Project(name: "Backend API", icon: "server.rack")
    
    static let samples: [Project] = [
        Project(name: "Backend API", icon: "server.rack"),
        Project(name: "Frontend App", icon: "macwindow"),
        Project(name: "DevOps", icon: "gearshape.2.fill"),
        Project(name: "Mobile App", icon: "iphone"),
    ]
}
