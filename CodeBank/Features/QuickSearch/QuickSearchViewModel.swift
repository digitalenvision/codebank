import Foundation
import SwiftUI
import Combine

/// View model for the quick search panel
@MainActor
@Observable
final class QuickSearchViewModel {
    
    // MARK: - Properties
    
    var searchQuery: String = "" {
        didSet {
            searchService.searchQuery = searchQuery
            // Select first result when query changes
            if !searchQuery.isEmpty {
                selectedResultId = results.first?.id
            } else {
                selectedResultId = nil
            }
        }
    }
    
    var selectedResultId: UUID?
    
    var results: [SearchResult] {
        searchService.results
    }
    
    var isSearching: Bool {
        searchService.isSearching
    }
    
    var recentSearches: [String] {
        searchService.recentSearches
    }
    
    // MARK: - Private Properties
    
    private let searchService: SearchService
    
    // MARK: - Initialization
    
    init() {
        self.searchService = SearchService.shared
    }
    
    // MARK: - Computed Properties
    
    var selectedResult: SearchResult? {
        guard let id = selectedResultId else { return nil }
        return results.first { $0.id == id }
    }
    
    var selectedIndex: Int? {
        guard let id = selectedResultId else { return nil }
        return results.firstIndex { $0.id == id }
    }
    
    // MARK: - Navigation
    
    func selectNext() {
        guard !results.isEmpty else { return }
        
        if let currentIndex = selectedIndex {
            let nextIndex = min(currentIndex + 1, results.count - 1)
            selectedResultId = results[nextIndex].id
        } else {
            selectedResultId = results.first?.id
        }
    }
    
    func selectPrevious() {
        guard !results.isEmpty else { return }
        
        if let currentIndex = selectedIndex {
            let prevIndex = max(currentIndex - 1, 0)
            selectedResultId = results[prevIndex].id
        } else {
            selectedResultId = results.last?.id
        }
    }
    
    func selectFirst() {
        selectedResultId = results.first?.id
    }
    
    func selectLast() {
        selectedResultId = results.last?.id
    }
    
    // MARK: - Recent Searches
    
    func addToRecentSearches() {
        searchService.addToRecentSearches(searchQuery)
    }
    
    func clearRecentSearches() {
        searchService.clearRecentSearches()
    }
    
    // MARK: - Clear
    
    func clear() {
        searchQuery = ""
        selectedResultId = nil
    }
}
