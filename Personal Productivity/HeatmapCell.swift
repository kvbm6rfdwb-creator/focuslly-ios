import Foundation

struct HeatmapCell: Identifiable {
    let id = UUID()
    let day: Int        // 0 = Monday
    let hour: Int       // 0–23
    let score: Double   // 0.0–1.0
}

