import Foundation

struct Subject: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let sfSymbol: String
}
