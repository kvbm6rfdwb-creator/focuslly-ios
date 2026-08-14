import Foundation

enum FocusBlockType: String, Codable {
    case focus
    case breakTime
}

struct FocusBlock: Identifiable, Codable {
    let id: UUID
    let duration: Int      // seconds
    let type: FocusBlockType

    init(duration: Int, type: FocusBlockType) {
        self.id = UUID()
        self.duration = duration
        self.type = type
    }
}

