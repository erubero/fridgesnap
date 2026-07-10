import Foundation
import Supabase

@MainActor
protocol ScanServicing: AnyObject {
    // Takes compressed JPEG data (ImagePipeline output), returns the scan.
    func scan(images: [Data]) async throws -> ScanResponse
}

@MainActor
final class SupabaseScanService: ScanServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func scan(images: [Data]) async throws -> ScanResponse {
        guard let session = try? await client.auth.session else { throw ServiceError.notSignedIn }
        let userID = session.user.id.uuidString.lowercased()

        var paths: [String] = []
        for jpeg in images.prefix(5) {
            let path = "\(userID)/\(UUID().uuidString.lowercased()).jpg"
            try await client.storage
                .from("scan-images")
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
            paths.append(path)
        }

        struct Request: Encodable {
            let image_paths: [String]
        }
        do {
            return try await client.functions.invoke(
                "scan",
                options: FunctionInvokeOptions(body: Request(image_paths: paths))
            )
        } catch {
            throw error.asServiceError
        }
    }
}

@MainActor
final class MockScanService: ScanServicing {
    func scan(images _: [Data]) async throws -> ScanResponse {
        try? await Task.sleep(for: .seconds(1.2))
        return try JSONDecoder().decode(ScanResponse.self, from: Data(MockData.scanResponseJSON.utf8))
    }
}

private struct FunctionErrorBody: Decodable {
    let error: String?
    let message: String?
}

extension Error {
    // Maps edge function HTTP errors (402 free limit, 429 rate limit) to
    // user-facing ServiceError cases.
    var asServiceError: Error {
        guard let functionsError = self as? FunctionsError else { return self }
        if case .httpError(let code, let data) = functionsError {
            let body = try? JSONDecoder().decode(FunctionErrorBody.self, from: data)
            if code == 402 || body?.error == "free_limit_reached" {
                return ServiceError.freeLimitReached
            }
            if code == 429 {
                return ServiceError.rateLimited(body?.message ?? "Slow down a little. Try again soon.")
            }
            if let message = body?.error {
                return ServiceError.network(message)
            }
        }
        return self
    }
}
