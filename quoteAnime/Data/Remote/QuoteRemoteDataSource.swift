import Foundation
import FirebaseDatabase

final class QuoteRemoteDataSource {
    private let dbRef = Database.database().reference().child("quotes")

    func fetchAllQuotes() async throws -> [QuoteDTO] {
        try await withCheckedThrowingContinuation { continuation in
            dbRef.observeSingleEvent(of: .value) { snapshot in
                print("[Firebase] snapshot exists: \(snapshot.exists()), childrenCount: \(snapshot.childrenCount)")

                guard snapshot.exists() else {
                    print("[Firebase] nodo /quotes vacío o inexistente")
                    continuation.resume(returning: [])
                    return
                }

                guard let rawValue = snapshot.value else {
                    print("[Firebase] snapshot.value es nil")
                    continuation.resume(returning: [])
                    return
                }

                print("[Firebase] tipo de dato recibido: \(type(of: rawValue))")

                // Caso 1: array plano  →  [{id, quote, author, anime}, ...]
                if let array = rawValue as? [[String: Any]] {
                    let quotes = array.compactMap { QuoteDTO(dict: $0, key: nil) }
                    print("[Firebase] parseado como array → \(quotes.count) frases")
                    continuation.resume(returning: quotes)
                    return
                }

                // Caso 2: diccionario con claves Firebase  →  {"key": {quote, author, anime}, ...}
                // El id puede ser la clave del nodo o un campo dentro del objeto.
                if let dict = rawValue as? [String: Any] {
                    var quotes: [QuoteDTO] = []
                    for (key, value) in dict {
                        if let obj = value as? [String: Any] {
                            if let dto = QuoteDTO(dict: obj, key: key) {
                                quotes.append(dto)
                            } else {
                                print("[Firebase] no se pudo parsear nodo key=\(key): \(obj)")
                            }
                        }
                    }
                    print("[Firebase] parseado como diccionario → \(quotes.count) frases")
                    continuation.resume(returning: quotes)
                    return
                }

                print("[Firebase] estructura de datos no reconocida: \(rawValue)")
                continuation.resume(returning: [])

            } withCancel: { error in
                print("[Firebase] error de red/permisos: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }
}
