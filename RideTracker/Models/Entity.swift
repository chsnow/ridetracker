import Foundation
import CoreLocation

struct EntityResponse: Codable {
    let id: String
    let name: String
    let children: [Entity]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Decode children, filtering out entities with unknown types
        var childrenContainer = try container.nestedUnkeyedContainer(forKey: .children)
        var validChildren: [Entity] = []

        while !childrenContainer.isAtEnd {
            if let entity = try? childrenContainer.decode(Entity.self) {
                validChildren.append(entity)
            } else {
                // Skip invalid entities by decoding as a throwaway type
                _ = try? childrenContainer.decode(DiscardedEntity.self)
            }
        }
        children = validChildren
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, children
    }
}

// Used to skip over entities we can't decode
private struct DiscardedEntity: Codable {}

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
        case .attraction: return "wand.and.stars"
        case .show: return "theatermasks"
        case .restaurant: return "fork.knife"
        }
    }
}
