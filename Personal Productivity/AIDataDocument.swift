import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct AIDataDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.json] }

    var snapshot: AIDataSnapshot

    init(snapshot: AIDataSnapshot = .captureFromUserDefaults()) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.snapshot = try JSONDecoder().decode(AIDataSnapshot.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(snapshot)
        return .init(regularFileWithContents: data)
    }
}
