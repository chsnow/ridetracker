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
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(DestinationsResponse.self, from: data)
        return decoded.destinations
    }

    func fetchDisneylandResort() async throws -> Destination? {
        let destinations = try await fetchDestinations()
        return destinations.first { $0.slug == "disneylandresort" }
    }

    // MARK: - Park Entities

    func fetchEntities(for parkId: String) async throws -> [Entity] {
        let url = URL(string: "\(baseURL)/entity/\(parkId)/children")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(EntityResponse.self, from: data)
        return decoded.children
    }

    // MARK: - Live Data

    func fetchLiveData(for parkId: String) async throws -> [LiveData] {
        let url = URL(string: "\(baseURL)/entity/\(parkId)/live")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(LiveDataResponse.self, from: data)
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
