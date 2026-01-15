import Foundation
import CoreLocation

struct EntityResponse: Codable {
    let id: String
    let name: String
    let children: [Entity]
}

struct Entity: Codable, Identifiable {
    let id: String
    let name: String
    let entityType: EntityType
    let location: EntityLocation?

    enum CodingKeys: String, CodingKey {
        case id, name, entityType, location
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let location = location else { return nil }
        return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
}

struct EntityLocation: Codable {
    let latitude: Double
    let longitude: Double
}

enum EntityType: String, Codable, CaseIterable {
    case attraction = "ATTRACTION"
    case show = "SHOW"
    case restaurant = "RESTAURANT"

    var displayName: String {
        switch self {
        case .attraction: return "Attractions"
        case .show: return "Shows"
        case .restaurant: return "Restaurants"
        }
    }

    var icon: String {
        switch self {
        case .attraction: return "roller.coaster"
        case .show: return "theatermasks"
        case .restaurant: return "fork.knife"
        }
    }
}
