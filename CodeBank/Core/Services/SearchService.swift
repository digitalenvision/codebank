import Foundation
import Combine

/// Represents a search result
struct SearchResult: Identifiable, Hashable {
    let id: UUID
    let item: Item
    let project: Project?
    let matchScore: Double
    let matchedField: String?
    
    init(item: Item, project: Project?, matchScore: Double = 1.0, matchedField: String? = nil) {
        self.id = item.id
        self.item = item
        self.project = project
        self.matchScore = matchScore
        self.matchedField = matchedField
    }
}

/// Handles searching across the vault
@MainActor
@Observable
final class SearchService {
    
    // MARK: - Singleton
    
    static let shared = SearchService()
    
    // MARK: - Properties
    
    /// Current search query
    var searchQuery: String = "" {
        didSet {
            searchDebouncer.send(searchQuery)
        }
    }
    
    /// Search results
    private(set) var results: [SearchResult] = []
    
    /// Whether a search is in progress
    private(set) var isSearching: Bool = false
    
    /// Recent searches (for quick access)
    private(set) var recentSearches: [String] = []
    
    // MARK: - Private Properties
    
    private var searchDebouncer = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let storageService: StorageService
    
    // MARK: - Initialization
    
    private init() {
        self.storageService = StorageService.shared
        
        // Load recent searches
        if let recent = UserDefaults.standard.array(forKey: "recent_searches") as? [String] {
            recentSearches = recent
        }
        
        // Setup debounced search
        searchDebouncer
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Operations
    
    /// Performs a search with the given query
    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Fetch all items and projects
            let allItems = try storageService.fetchAllItems()
            let allProjects = try storageService.fetchAllProjects()
            
            // Create project lookup
            let projectMap = Dictionary(uniqueKeysWithValues: allProjects.map { ($0.id, $0) })
            
            // Score and filter items
            var scoredResults: [SearchResult] = []
            
            for item in allItems {
                let (score, matchedField) = calculateMatchScore(item: item, query: trimmedQuery)
                
                if score > 0 {
                    let project = item.projectId.flatMap { projectMap[$0] }
                    scoredResults.append(SearchResult(
                        item: item,
                        project: project,
                        matchScore: score,
                        matchedField: matchedField
                    ))
                }
            }
            
            // Sort by score (highest first), then by name
            results = scoredResults.sorted { a, b in
                if a.matchScore != b.matchScore {
                    return a.matchScore > b.matchScore
                }
                return a.item.name.localizedCaseInsensitiveCompare(b.item.name) == .orderedAscending
            }
            
        } catch {
            results = []
        }
    }
    
    /// Calculates a match score for an item against a query
    private func calculateMatchScore(item: Item, query: String) -> (Double, String?) {
        var maxScore: Double = 0
        var matchedField: String? = nil
        
        // Check name (highest priority)
        let nameScore = scoreMatch(item.name.lowercased(), against: query)
        if nameScore > maxScore {
            maxScore = nameScore * 1.5 // Boost name matches
            matchedField = "name"
        }
        
        // Check type-specific fields
        switch item.data {
        case .apiKey(let data):
            let serviceScore = scoreMatch(data.service.lowercased(), against: query)
            if serviceScore > maxScore {
                maxScore = serviceScore
                matchedField = "service"
            }
            if let env = data.environment {
                let envScore = scoreMatch(env.lowercased(), against: query)
                if envScore > maxScore {
                    maxScore = envScore
                    matchedField = "environment"
                }
            }
            
        case .database(let data):
            let hostScore = scoreMatch(data.host.lowercased(), against: query)
            if hostScore > maxScore {
                maxScore = hostScore
                matchedField = "host"
            }
            let dbScore = scoreMatch(data.databaseName.lowercased(), against: query)
            if dbScore > maxScore {
                maxScore = dbScore
                matchedField = "database"
            }
            
        case .server(let data):
            let hostScore = scoreMatch(data.hostname.lowercased(), against: query)
            if hostScore > maxScore {
                maxScore = hostScore
                matchedField = "hostname"
            }
            
        case .ssh(let data):
            let hostScore = scoreMatch(data.host.lowercased(), against: query)
            if hostScore > maxScore {
                maxScore = hostScore
                matchedField = "host"
            }
            let userScore = scoreMatch(data.user.lowercased(), against: query)
            if userScore > maxScore {
                maxScore = userScore
                matchedField = "user"
            }
            
        case .command(let data):
            let cmdScore = scoreMatch(data.command.lowercased(), against: query) * 0.8 // Slightly lower priority
            if cmdScore > maxScore {
                maxScore = cmdScore
                matchedField = "command"
            }
            
        case .secureNote(let data):
            let contentScore = scoreMatch(data.content.lowercased(), against: query) * 0.5 // Lower priority for content
            if contentScore > maxScore {
                maxScore = contentScore
                matchedField = "content"
            }
        }
        
        // Check notes (lowest priority)
        if let notes = getNotes(from: item.data) {
            let notesScore = scoreMatch(notes.lowercased(), against: query) * 0.3
            if notesScore > maxScore {
                maxScore = notesScore
                matchedField = "notes"
            }
        }
        
        return (maxScore, matchedField)
    }
    
    /// Scores how well a text matches a query
    private func scoreMatch(_ text: String, against query: String) -> Double {
        guard !text.isEmpty else { return 0 }
        
        // Exact match
        if text == query {
            return 1.0
        }
        
        // Starts with query
        if text.hasPrefix(query) {
            return 0.9
        }
        
        // Contains query
        if text.contains(query) {
            // Score higher if the match is earlier in the string
            if let range = text.range(of: query) {
                let position = text.distance(from: text.startIndex, to: range.lowerBound)
                let positionScore = 1.0 - (Double(position) / Double(text.count))
                return 0.5 + (0.3 * positionScore)
            }
            return 0.5
        }
        
        // Fuzzy match - check if all query characters appear in order
        var textIndex = text.startIndex
        var matchCount = 0
        
        for queryChar in query {
            while textIndex < text.endIndex {
                if text[textIndex] == queryChar {
                    matchCount += 1
                    textIndex = text.index(after: textIndex)
                    break
                }
                textIndex = text.index(after: textIndex)
            }
        }
        
        if matchCount == query.count {
            return Double(matchCount) / Double(text.count) * 0.3
        }
        
        return 0
    }
    
    /// Extracts notes from item data
    private func getNotes(from data: ItemData) -> String? {
        switch data {
        case .apiKey(let d): return d.notes
        case .database(let d): return d.notes
        case .server(let d): return d.notes
        case .ssh(let d): return d.notes
        case .command(let d): return d.notes
        case .secureNote(let d): return d.notes
        }
    }
    
    // MARK: - Recent Searches
    
    /// Adds a query to recent searches
    func addToRecentSearches(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0 == trimmed }
        
        // Add to front
        recentSearches.insert(trimmed, at: 0)
        
        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        // Persist
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
    
    /// Clears recent searches
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recent_searches")
    }
    
    // MARK: - Clear
    
    /// Clears the current search
    func clear() {
        searchQuery = ""
        results = []
    }
}
