import Contacts
import Foundation
import Observation

struct ContactResult: Identifiable, Sendable {
    let contactIdentifier: String
    var id: String { contactIdentifier }
    var displayName: String
    var thumbnailData: Data?
}

@MainActor
@Observable
final class ContactsService {
    private let store = CNContactStore()

    private(set) var authorizationStatus: CNAuthorizationStatus

    init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAuthorization() async -> CNAuthorizationStatus {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authorizationStatus = granted ? .authorized : CNContactStore.authorizationStatus(for: .contacts)
        } catch {
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        }
        return authorizationStatus
    }

    func search(query: String) async -> [ContactResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]

        let predicate = CNContact.predicateForContacts(matchingName: trimmed)

        do {
            let matches = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            return matches.prefix(50).map { contact in
                let full = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                return ContactResult(
                    contactIdentifier: contact.identifier,
                    displayName: full.isEmpty ? contact.identifier : full,
                    thumbnailData: contact.thumbnailImageData
                )
            }
        } catch {
            return []
        }
    }

    func contact(for identifier: String) async -> ContactResult? {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]
        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
            let full = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            return ContactResult(
                contactIdentifier: contact.identifier,
                displayName: full.isEmpty ? contact.identifier : full,
                thumbnailData: contact.thumbnailImageData
            )
        } catch {
            return nil
        }
    }
}
