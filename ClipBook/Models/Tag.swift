import Foundation

struct Tag: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    var color: String

    init(id: Int = 0, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }
}
