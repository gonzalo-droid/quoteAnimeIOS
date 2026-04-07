import Foundation

// Categories are derived dynamically from the unique `anime` values of quotes.
// This DTO is provided for completeness if the backend ever returns explicit categories.
struct CategoryDTO: Codable {
    let id: String
    let name: String

    func toDomain() -> Category {
        Category(id: id, name: name)
    }
}
