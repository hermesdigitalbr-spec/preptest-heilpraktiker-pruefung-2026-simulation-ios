import Foundation

struct Subject: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let sfSymbol: String
    /// Shown where the design calls for a pictogram rather than a glyph (the
    /// paywall's progress cards). Optional so older packs keep decoding.
    let emoji: String?
}
