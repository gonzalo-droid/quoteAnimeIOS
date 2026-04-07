import Foundation
import FirebaseDatabase

final class QuoteRemoteDataSource {
    private let dbRef = Database.database().reference().child("quotes")

    /// Fetches all quotes from Firebase Realtime Database.
    /// Handles both array (`[{...}]`) and dictionary (`{"key": {...}}`) root structures.
    func fetchAllQuotes() async throws -> [QuoteDTO] {
        try await withCheckedThrowingContinuation { continuation in
            dbRef.observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists(), let value = snapshot.value else {
                    continuation.resume(returning: [])
                    return
                }
                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
                    if let dtos = try? JSONDecoder().decode([QuoteDTO].self, from: data) {
                        continuation.resume(returning: dtos)
                    } else if let dict = try? JSONDecoder().decode([String: QuoteDTO].self, from: data) {
                        continuation.resume(returning: Array(dict.values))
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
