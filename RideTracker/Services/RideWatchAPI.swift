import Foundation
import UIKit

/// Service for communicating with the ride-watch backend for push notification registration
actor RideWatchAPI {
    static let shared = RideWatchAPI()

    private let baseURL = "https://ride-watch-292473931748.us-west1.run.app"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Device Registration

    /// Register a device for push notifications
    /// - Parameters:
    ///   - token: The FCM token to register
    ///   - deviceName: Optional device name for identification
    /// - Returns: DeviceRegistrationResponse on success
    func registerDevice(token: String, deviceName: String? = nil) async throws -> DeviceRegistrationResponse {
        guard let url = URL(string: "\(baseURL)/devices") else {
            print("[RideWatchAPI] ❌ Register device failed: Invalid URL")
            throw RideWatchAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = DeviceRegistrationRequest(
            token: token,
            platform: "ios",
            deviceName: deviceName ?? UIDevice.current.name
        )

        request.httpBody = try JSONEncoder().encode(body)

        print("[RideWatchAPI] → POST \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[RideWatchAPI] ❌ Register device failed: Invalid response")
            throw RideWatchAPIError.invalidResponse
        }

        print("[RideWatchAPI] ← Response: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200, 201:
            let result = try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data)
            print("[RideWatchAPI] ✓ Register device succeeded")
            return result
        case 400:
            print("[RideWatchAPI] ❌ Register device failed: Bad request (400)")
            throw RideWatchAPIError.badRequest
        case 401, 403:
            print("[RideWatchAPI] ❌ Register device failed: Unauthorized (\(httpResponse.statusCode))")
            throw RideWatchAPIError.unauthorized
        case 500..<600:
            print("[RideWatchAPI] ❌ Register device failed: Server error (\(httpResponse.statusCode))")
            throw RideWatchAPIError.serverError(httpResponse.statusCode)
        default:
            print("[RideWatchAPI] ❌ Register device failed: Unexpected status (\(httpResponse.statusCode))")
            throw RideWatchAPIError.invalidResponse
        }
    }

    /// Register device with retry and exponential backoff
    /// - Parameters:
    ///   - token: The FCM token to register
    ///   - deviceName: Optional device name
    ///   - maxRetries: Maximum number of retry attempts (default 3)
    /// - Returns: DeviceRegistrationResponse on success
    func registerDeviceWithRetry(
        token: String,
        deviceName: String? = nil,
        maxRetries: Int = 3
    ) async throws -> DeviceRegistrationResponse {
        var lastError: Error?
        var delay: UInt64 = 2_000_000_000 // Start with 2 seconds

        for attempt in 0...maxRetries {
            do {
                return try await registerDevice(token: token, deviceName: deviceName)
            } catch let error as RideWatchAPIError {
                lastError = error

                // Don't retry on client errors (bad request, unauthorized)
                switch error {
                case .badRequest, .unauthorized, .invalidURL:
                    throw error
                default:
                    break
                }

                if attempt < maxRetries {
                    print("Device registration attempt \(attempt + 1) failed: \(error.localizedDescription). Retrying in \(delay / 1_000_000_000)s...")
                    try await Task.sleep(nanoseconds: delay)
                    delay *= 2 // Exponential backoff
                }
            } catch {
                lastError = error

                if attempt < maxRetries {
                    print("Device registration attempt \(attempt + 1) failed: \(error.localizedDescription). Retrying in \(delay / 1_000_000_000)s...")
                    try await Task.sleep(nanoseconds: delay)
                    delay *= 2
                }
            }
        }

        throw lastError ?? RideWatchAPIError.networkError(NSError(domain: "RideWatchAPI", code: -1))
    }

    // MARK: - Device Unregistration

    /// Unregister a device from push notifications
    /// - Parameter token: The FCM token to unregister
    func unregisterDevice(token: String) async throws {
        guard let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/devices/\(encodedToken)") else {
            print("[RideWatchAPI] ❌ Unregister device failed: Invalid URL")
            throw RideWatchAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        print("[RideWatchAPI] → DELETE \(baseURL)/devices/[token]")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[RideWatchAPI] ❌ Unregister device failed: Invalid response")
            throw RideWatchAPIError.invalidResponse
        }

        print("[RideWatchAPI] ← Response: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200, 204:
            print("[RideWatchAPI] ✓ Unregister device succeeded")
            return // Success
        case 404:
            // Device not found - consider this success since it's already unregistered
            print("[RideWatchAPI] ✓ Unregister device succeeded (device not found, already unregistered)")
            return
        case 500..<600:
            print("[RideWatchAPI] ❌ Unregister device failed: Server error (\(httpResponse.statusCode))")
            throw RideWatchAPIError.serverError(httpResponse.statusCode)
        default:
            print("[RideWatchAPI] ❌ Unregister device failed: Unexpected status (\(httpResponse.statusCode))")
            throw RideWatchAPIError.invalidResponse
        }
    }
}

// MARK: - Request/Response Models

struct DeviceRegistrationRequest: Codable {
    let token: String
    let platform: String
    let deviceName: String?
}

struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Errors

enum RideWatchAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badRequest
    case unauthorized
    case serverError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Bad request - check token format"
        case .unauthorized:
            return "Unauthorized request"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
