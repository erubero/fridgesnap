import Foundation
import Supabase

@MainActor
protocol GenerationServicing: AnyObject {
    func generate(
        scanID: String,
        ingredients: [GenerateRequestIngredient],
        level: LazinessLevel,
        servings: Int
    ) async throws -> [Recipe]
}

@MainActor
final class SupabaseGenerationService: GenerationServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func generate(
        scanID: String,
        ingredients: [GenerateRequestIngredient],
        level: LazinessLevel,
        servings: Int
    ) async throws -> [Recipe] {
        struct Request: Encodable {
            let scan_id: String
            let ingredients: [GenerateRequestIngredient]
            let level: String
            let servings: Int
        }
        do {
            let response: GenerateResponse = try await client.functions.invoke(
                "generate",
                options: FunctionInvokeOptions(body: Request(
                    scan_id: scanID,
                    ingredients: ingredients,
                    level: level.rawValue,
                    servings: servings
                ))
            )
            return response.recipes
        } catch {
            throw error.asServiceError
        }
    }
}

@MainActor
final class MockGenerationService: GenerationServicing {
    private var generationsPerScan: [String: Int] = [:]

    func generate(
        scanID: String,
        ingredients _: [GenerateRequestIngredient],
        level: LazinessLevel,
        servings _: Int
    ) async throws -> [Recipe] {
        // Mirror the backend limit (1 initial + 5 regenerations) so the
        // rate-limit UI is exercised in Simulator too.
        let used = generationsPerScan[scanID, default: 0]
        guard used < 6 else {
            throw ServiceError.rateLimited("Regeneration limit reached for this scan.")
        }
        generationsPerScan[scanID] = used + 1

        try? await Task.sleep(for: .seconds(1.5))
        var response = try JSONDecoder().decode(GenerateResponse.self, from: Data(MockData.generateResponseJSON.utf8))
        for index in response.recipes.indices {
            response.recipes[index].level = level
            response.recipes[index].id = UUID().uuidString
        }
        return response.recipes
    }
}
