import Foundation

/// Values pushed from Search results (photo vs Home collection).
enum SearchBrowseDestination: Hashable {
    case photo(UUID)
    case collection(UUID)
}
