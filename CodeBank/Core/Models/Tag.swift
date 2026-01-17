import Foundation
import SwiftUI

/// Represents a tag that can be applied to items
struct Tag: Identifiable, Codable, Hashable {
    /// Unique identifier
    let id: UUID
    
    /// Display name of the tag
    var name: String
    
    /// Color identifier (one of the predefined colors)
    var color: String
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Last modification timestamp
    var updatedAt: Date
    
    /// Creates a new tag with default values
    init(name: String, color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Creates a tag with all values specified (for database loading)
    init(id: UUID, name: String, color: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Returns the SwiftUI Color for this tag
    var swiftUIColor: Color {
        Tag.colorMap[color] ?? .blue
    }
}

// MARK: - Available Colors

extension Tag {
    /// Available color options for tags
    static let availableColors: [String] = [
        "red", "orange", "yellow", "green", "mint",
        "teal", "cyan", "blue", "indigo", "purple",
        "pink", "brown", "gray"
    ]
    
    /// Maps color names to SwiftUI colors
    static let colorMap: [String: Color] = [
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "mint": .mint,
        "teal": .teal,
        "cyan": .cyan,
        "blue": .blue,
        "indigo": .indigo,
        "purple": .purple,
        "pink": .pink,
        "brown": .brown,
        "gray": .gray
    ]
}

// MARK: - Sample Data

extension Tag {
    static let sample = Tag(name: "production", color: "red")
    
    static let samples: [Tag] = [
        Tag(name: "production", color: "red"),
        Tag(name: "staging", color: "orange"),
        Tag(name: "development", color: "green"),
        Tag(name: "database", color: "purple"),
        Tag(name: "api", color: "blue"),
    ]
}
