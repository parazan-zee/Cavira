import Observation
import SwiftUI

/// Bundles app-wide services for dependency injection (SwiftUI environment).
/// Phase 3 views use `@Environment(\.appServices)` instead of singletons.
///
/// Intentionally **not** `@Observable`: Observation on the container can cause early
/// environment reads during `TabView` construction before modifiers apply, tripping
/// `EnvironmentValues.appServices`’s precondition. Individual services remain `@Observable`.
@MainActor
final class AppServices {
    let photoLibrary: PhotoLibraryService
    let photoImageLoader: PhotoImageLoader
    let photoStorage: any PhotoStorageServing
    let locationSearch: LocationSearchService
    let contacts: ContactsService

    init(
        photoLibrary: PhotoLibraryService? = nil,
        photoImageLoader: PhotoImageLoader? = nil,
        photoStorage: (any PhotoStorageServing)? = nil,
        locationSearch: LocationSearchService? = nil,
        contacts: ContactsService? = nil
    ) {
        let library = photoLibrary ?? PhotoLibraryService()
        self.photoLibrary = library
        self.photoImageLoader = photoImageLoader ?? PhotoImageLoader(photoLibrary: library)
        self.photoStorage = photoStorage ?? NoOpPhotoStorage()
        self.locationSearch = locationSearch ?? LocationSearchService()
        self.contacts = contacts ?? ContactsService()
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue: AppServices? = nil
}

extension EnvironmentValues {
    /// Injected from `RootView` / previews via `.environment(\.appServices, instance)`.
    ///
    /// **Must stay optional (`AppServices?`)** so the `EnvironmentKey` storage type matches SwiftUI’s
    /// environment merge rules. A non-optional façade + `preconditionFailure` was tripping during
    /// `TabView` construction before the merged environment was visible on some OS versions.
    var appServices: AppServices? {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

extension View {
    func appServices(_ services: AppServices) -> some View {
        environment(\.appServices, Optional(services))
    }
}
