import Foundation
import FirebaseDatabase

final class AnimeImagesRemoteDataSource {
    private let dbRef = Database.database().reference().child("imagenes")

    /// Fetches /imagenes and returns a map of animeSlug → [imageURL].
    func fetchImages() async throws -> [String: [String]] {
        try await withCheckedThrowingContinuation { continuation in
            dbRef.observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
                    print("[AnimeImagesRemoteDataSource] nodo /imagenes vacío o inexistente")
                    continuation.resume(returning: [:])
                    return
                }
                var result: [String: [String]] = [:]
                for (slug, value) in dict {
                    if let urlArray = value as? [String] {
                        result[slug] = urlArray
                    } else if let urlDict = value as? [String: Any] {
                        // Firebase stores sequential arrays as {"0": url, "1": url, ...}
                        let sorted = urlDict
                            .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
                            .compactMap { $0.value as? String }
                        if !sorted.isEmpty { result[slug] = sorted }
                    }
                }
                print("[AnimeImagesRemoteDataSource] loaded \(result.count) anime image sets")
                continuation.resume(returning: result)
            } withCancel: { error in
                print("[AnimeImagesRemoteDataSource] error: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }
}
