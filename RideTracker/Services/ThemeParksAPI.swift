import Foundation

actor ThemeParksAPI {
    static let shared = ThemeParksAPI()
    private let baseURL = "https://api.themeparks.wiki/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Destinations

    func fetchDestinations() async throws -> [Destination] {
        let url = URL(string: "\(baseURL)/destinations")!

        print("[ThemeParksAPI] → GET \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ThemeParksAPI] ❌ Fetch destinations failed: Invalid response")
            throw APIError.invalidResponse
        }

        print("[ThemeParksAPI] ← Response: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("[ThemeParksAPI] ❌ Fetch destinations failed: Unexpected status (\(httpResponse.statusCode))")
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(DestinationsResponse.self, from: data)
        print("[ThemeParksAPI] ✓ Fetch destinations succeeded (\(decoded.destinations.count) destinations)")
        return decoded.destinations
    }

    func fetchDisneylandResort() async throws -> Destination? {
        let destinations = try await fetchDestinations()
        return destinations.first { $0.slug == "disneylandresort" }
    }

    // MARK: - Park Entities

    func fetchEntities(for parkId: String) async throws -> [Entity] {
        let url = URL(string: "\(baseURL)/entity/\(parkId)/children")!

        print("[ThemeParksAPI] → GET \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ThemeParksAPI] ❌ Fetch entities failed: Invalid response")
            throw APIError.invalidResponse
        }

        print("[ThemeParksAPI] ← Response: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("[ThemeParksAPI] ❌ Fetch entities failed: Unexpected status (\(httpResponse.statusCode))")
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(EntityResponse.self, from: data)
        print("[ThemeParksAPI] ✓ Fetch entities succeeded (\(decoded.children.count) entities)")
        return decoded.children
    }

    // MARK: - Single Entity

    func fetchEntity(id: String) async throws -> EntityDetail {
        let url = URL(string: "\(baseURL)/entity/\(id)")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(EntityDetail.self, from: data)
    }

    // MARK: - Live Data

    func fetchLiveData(for parkId: String) async throws -> [LiveData] {
        let url = URL(string: "\(baseURL)/entity/\(parkId)/live")!

        // Bypass cache to always get fresh wait times
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        print("[ThemeParksAPI] → GET \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ThemeParksAPI] ❌ Fetch live data failed: Invalid response")
            throw APIError.invalidResponse
        }

        print("[ThemeParksAPI] ← Response: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("[ThemeParksAPI] ❌ Fetch live data failed: Unexpected status (\(httpResponse.statusCode))")
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(LiveDataResponse.self, from: data)
        print("[ThemeParksAPI] ✓ Fetch live data succeeded (\(decoded.liveData.count) items)")
        return decoded.liveData
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
