import Foundation
import Testing
@testable import quoteAnime

/// The anime selection is the one preference that changes *what content the app shows*, so
/// the filter is pinned here. Semantics mirror Android's `selectedCategoryIds`: an empty set
/// means "all animes", never "no animes".
@Suite("Filtro por animes (feed)")
struct QuoteCategoryFilterTests {

    private static let catalogue: [(anime: String, count: Int)] = [
        ("Naruto", 3),
        ("One Piece", 2),
        ("Vinland Saga", 4),
    ]

    private static func makeUseCase() -> (GetAllQuotesUseCase, FakeQuoteRepository) {
        let repository = FakeQuoteRepository.withCatalogue(catalogue)
        return (GetAllQuotesUseCase(repository: repository), repository)
    }

    // MARK: - Happy path

    @Test("sin selección devuelve todo el catálogo")
    func emptySelectionReturnsEverything() async throws {
        let (useCase, _) = Self.makeUseCase()

        let quotes = try await useCase.execute(filteredBy: [])

        #expect(quotes.count == 9)
        #expect(Set(quotes.map(\.anime)) == ["Naruto", "One Piece", "Vinland Saga"])
    }

    @Test("el parámetro por defecto equivale a 'sin selección'")
    func defaultArgumentMeansEverything() async throws {
        let (useCase, _) = Self.makeUseCase()

        #expect(try await useCase.execute().count == 9)
    }

    @Test(
        "con selección devuelve sólo esos animes",
        arguments: [
            (selection: Set(["Naruto"]), expectedCount: 3),
            (selection: Set(["One Piece"]), expectedCount: 2),
            (selection: Set(["Naruto", "One Piece"]), expectedCount: 5),
            (selection: Set(["Naruto", "One Piece", "Vinland Saga"]), expectedCount: 9),
        ]
    )
    func selectionKeepsOnlyChosenAnimes(selection: Set<String>, expectedCount: Int) async throws {
        let (useCase, _) = Self.makeUseCase()

        let quotes = try await useCase.execute(filteredBy: selection)

        #expect(quotes.count == expectedCount)
        #expect(Set(quotes.map(\.anime)).isSubset(of: selection))
    }

    // MARK: - Boundaries

    @Test("una categoría inexistente no rompe: devuelve vacío")
    func unknownCategoryReturnsEmpty() async throws {
        let (useCase, _) = Self.makeUseCase()

        let quotes = try await useCase.execute(filteredBy: ["Anime Que No Existe"])

        #expect(quotes.isEmpty)
    }

    @Test("una categoría inexistente no descarta las que sí existen")
    func unknownCategoryMixedWithKnownOne() async throws {
        let (useCase, _) = Self.makeUseCase()

        let quotes = try await useCase.execute(filteredBy: ["Naruto", "Anime Que No Existe"])

        #expect(quotes.count == 3)
        #expect(quotes.allSatisfy { $0.anime == "Naruto" })
    }

    @Test("catálogo vacío devuelve vacío con y sin selección")
    func emptyCatalogue() async throws {
        let useCase = GetAllQuotesUseCase(repository: FakeQuoteRepository(quotes: []))

        #expect(try await useCase.execute(filteredBy: []).isEmpty)
        #expect(try await useCase.execute(filteredBy: ["Naruto"]).isEmpty)
    }

    @Test("el filtro distingue mayúsculas: el id es el nombre exacto del anime")
    func filterIsCaseSensitive() async throws {
        let (useCase, _) = Self.makeUseCase()

        #expect(try await useCase.execute(filteredBy: ["naruto"]).isEmpty)
    }

    // MARK: - Error branch

    @Test("si el repositorio falla, el error se propaga")
    func repositoryErrorPropagates() async throws {
        let repository = FakeQuoteRepository.withCatalogue(Self.catalogue)
        repository.fetchError = FakeQuoteRepositoryError()
        let useCase = GetAllQuotesUseCase(repository: repository)

        await #expect(throws: FakeQuoteRepositoryError.self) {
            _ = try await useCase.execute(filteredBy: ["Naruto"])
        }
    }

    // MARK: - The shared rule

    @Test("filtrar dos veces da lo mismo que filtrar una (es idempotente)")
    func filterIsIdempotent() async throws {
        let (useCase, _) = Self.makeUseCase()
        let selection: Set<String> = ["Naruto", "One Piece"]

        let once = try await useCase.execute(filteredBy: selection)
        let twice = GetAllQuotesUseCase.filtered(once, by: selection)

        #expect(once.map(\.id) == twice.map(\.id))
    }
}
