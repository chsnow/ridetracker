import Foundation

struct Destination: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let parks: [Park]
}

struct Park: Codable, Identifiable, Hashable {
    let id: String
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Park, rhs: Park) -> Bool {
        lhs.id == rhs.id
    }
}

struct DestinationsResponse: Codable {
    let destinations: [Destination]
}

// Specific parks we care about
enum DisneyPark: String, CaseIterable {
    case disneyland = "Disneyland Park"
    case californiaAdventure = "Disney California Adventure"

    var shortName: String {
        switch self {
        case .disneyland: return "DL"
        case .californiaAdventure: return "DCA"
        }
    }

    var color: String {
        switch self {
        case .disneyland: return "DisneylandBlue"
        case .californiaAdventure: return "DCAOrange"
        }
    }
}
