import Foundation

/// Navigation values pushed from Home grid / timeline (standalone photo vs collection).
enum HomeDestination: Hashable {
    case photo(UUID)
    case collection(UUID)
}
