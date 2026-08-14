import SwiftUI

struct SessionRatingSheet: View {

    let taskTitle: String
    let taskId: UUID
    let sessionStartDate: Date
    let onRate: (String) -> Void

    static let ratingsKey = "focus_session_ratings_v1"

    /// Stable key that doesn't depend on log.id being committed yet.
    static func ratingKey(taskId: UUID, startDate: Date) -> String {
        "\(taskId.uuidString)_\(Int(startDate.timeIntervalSince1970))"
    }

    private let options: [(label: String, icon: String, color: Color)] = [
        ("Went well",  "hand.thumbsup.fill",               .green),
        ("Distracted", "eye.slash.fill",                   .orange),
        ("Too long",   "clock.badge.exclamationmark.fill",  .red)
    ]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("How was that session?")
                    .font(.system(size: 16, weight: .semibold))
                Text(taskTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 20)

            HStack(spacing: 10) {
                ForEach(options, id: \.label) { opt in
                    Button {
                        save(opt.label)
                        onRate(opt.label)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(opt.color)
                            Text(opt.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(opt.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }

    private func save(_ label: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: Self.ratingsKey) as? [String: String]) ?? [:]
        dict[Self.ratingKey(taskId: taskId, startDate: sessionStartDate)] = label
        UserDefaults.standard.set(dict, forKey: Self.ratingsKey)
    }
}

