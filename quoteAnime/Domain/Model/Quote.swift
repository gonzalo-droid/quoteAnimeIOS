import Foundation

struct Quote: Identifiable, Codable, Hashable {
    let id: String
    let quote: String
    let author: String
    let anime: String
    var isFavorite: Bool = false
}
