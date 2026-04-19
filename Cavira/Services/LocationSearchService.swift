import Foundation
import MapKit
import Observation

/// One row in the location picker. `latitude` / `longitude` stay `0` until `resolveSelection(id:)` runs (MapKit search).
struct LocationResult: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    /// Apple `MKMapItem.identifier` string when available (iOS 16+).
    var mapKitPlaceID: String?
}

/// Instagram-style flow on iOS: **`MKLocalSearchCompleter`** suggestions, then **`MKLocalSearch.Request(completion:)`** to resolve coordinates (no third-party maps API required for v1).
@MainActor
@Observable
final class LocationSearchService: NSObject {
    private(set) var results: [LocationResult] = []
    private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var completionByID: [UUID: MKLocalSearchCompletion] = [:]
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = .includingAll
    }

    /// Debounced query into the system completer (best-effort cancellation when the query changes).
    func search(query: String) async {
        debounceTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            clear()
            return
        }
        isSearching = true
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard let self, !Task.isCancelled else { return }
            self.completer.queryFragment = q
        }
    }

    func clear() {
        debounceTask?.cancel()
        debounceTask = nil
        completer.cancel()
        completer.queryFragment = ""
        results = []
        completionByID.removeAll(keepingCapacity: false)
        isSearching = false
    }

    /// Call when the user selects a suggestion row — fills coordinates and `mapKitPlaceID` when MapKit provides them.
    func resolveSelection(id: UUID) async -> LocationResult? {
        guard let completion = completionByID[id] else { return nil }
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let name = item.name ?? completion.title
            let coordinate = item.placemark.coordinate
            let placeID: String?
            if #available(iOS 18.0, *) {
                placeID = item.identifier?.rawValue
            } else {
                placeID = nil
            }
            return LocationResult(
                id: id,
                name: name,
                subtitle: completion.subtitle,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                mapKitPlaceID: placeID
            )
        } catch {
            return nil
        }
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.applyCompleterResults(completer.results)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            self.results = []
        }
    }

    private func applyCompleterResults(_ completions: [MKLocalSearchCompletion]) {
        completionByID.removeAll(keepingCapacity: false)
        var rows: [LocationResult] = []
        rows.reserveCapacity(min(completions.count, 24))
        for c in completions.prefix(24) {
            let id = UUID()
            completionByID[id] = c
            rows.append(
                LocationResult(
                    id: id,
                    name: c.title,
                    subtitle: c.subtitle,
                    latitude: 0,
                    longitude: 0,
                    mapKitPlaceID: nil
                )
            )
        }
        results = rows
        isSearching = false
    }
}
