import Foundation

public struct ClaudeUsageClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw QuotaError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw QuotaError.badResponse("non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            do { return try UsageResponse.decode(data) }
            catch { throw QuotaError.badResponse("decode failed: \(error)") }
        case 401, 403:
            throw QuotaError.tokenExpired
        default:
            throw QuotaError.badResponse("HTTP \(http.statusCode)")
        }
    }
}
