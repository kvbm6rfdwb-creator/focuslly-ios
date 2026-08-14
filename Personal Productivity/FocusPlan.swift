import Foundation

struct FocusPlan: Identifiable, Codable {
    let id: UUID
    let blocks: [FocusBlock]
    let name: String // Added name property

    init(blocks: [FocusBlock], name: String = "Default Plan") {
        self.id = UUID()
        self.blocks = blocks
        self.name = name
    }

    // Default plan (privremeno, bez AI)
    static func basic() -> FocusPlan {
        FocusPlan(blocks: [
            FocusBlock(duration: 45 * 60, type: .focus),
            FocusBlock(duration: 15 * 60, type: .breakTime),
            FocusBlock(duration: 45 * 60, type: .focus)
        ], name: "Basic Plan")
    }
}
