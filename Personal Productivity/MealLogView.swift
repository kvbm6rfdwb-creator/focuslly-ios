import SwiftUI

// MARK: - MealLogView

struct MealLogView: View {
    @ObservedObject private var store = MealStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: MealEntry.MealType = .lunch
    @State private var selectedTime: Date = Date()
    @State private var notes: String = ""
    @State private var showTimePicker = false
    @FocusState private var notesFocused: Bool

    private var todayEntries: [MealEntry] { store.todayEntries() }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Add new meal ────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {

                        // Meal type chips
                        HStack(spacing: 8) {
                            ForEach(MealEntry.MealType.allCases) { type in
                                Button {
                                    selectedType = type
                                    // Smart default time per meal type
                                    if notes.isEmpty {
                                        let h: Int
                                        switch type {
                                        case .breakfast: h = 8
                                        case .lunch:     h = 13
                                        case .snack:     h = 16
                                        case .dinner:    h = 19
                                        }
                                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                        comps.hour = h; comps.minute = 0
                                        selectedTime = Calendar.current.date(from: comps) ?? Date()
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedType == type
                                                      ? Color.brg.opacity(0.18)
                                                      : Color(.tertiarySystemFill))
                                                .frame(height: 48)
                                            Image(systemName: type.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(selectedType == type ? Color.brgBright : .secondary)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedType == type ? Color.brg.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                        )
                                        Text(type.rawValue)
                                            .font(.system(size: 11, weight: selectedType == type ? .semibold : .regular))
                                            .foregroundStyle(selectedType == type ? Color.brgBright : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Time row
                        Button { showTimePicker.toggle() } label: {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                                Text("Time")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(selectedTime, style: .time)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.brgBright)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if showTimePicker {
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                        }

                        // Notes field
                        TextField("Notes (optional)", text: $notes)
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .focused($notesFocused)

                        // Log button
                        Button {
                            HapticManager.impact(.medium)
                            store.add(MealEntry(date: selectedTime, type: selectedType, notes: notes))
                            notes = ""
                            showTimePicker = false
                        } label: {
                            Label("Log \(selectedType.rawValue)", systemImage: selectedType.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.brg)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // ── Today's log ────────────────────────────────
                    if !todayEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("TODAY'S MEALS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .kerning(0.4)
                                Spacer()
                                // Break insight pill
                                if store.isInPostLunchDip {
                                    HStack(spacing: 4) {
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 9))
                                        Text("Post-lunch dip active")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.75))
                                    .clipShape(Capsule())
                                } else if let mins = store.minutesSinceLastMeal {
                                    Text("\(mins < 60 ? "\(mins)m" : "\(mins/60)h") since last meal")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                            ForEach(Array(todayEntries.enumerated()), id: \.element.id) { idx, entry in
                                if idx > 0 { Divider().padding(.leading, 56) }
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.brg.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: entry.type.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.brgBright)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.type.rawValue)
                                            .font(.system(size: 14, weight: .semibold))
                                        if !entry.notes.isEmpty {
                                            Text(entry.notes)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(entry.date, style: .time)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                                    Button {
                                        withAnimation { store.delete(entry) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .padding(.bottom, 8)
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    // ── Break insight banner ───────────────────────
                    breakInsightBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Meals Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brgBright)
                }
            }
        }
        .floatingKeyboardDismiss(isVisible: notesFocused)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var breakInsightBanner: some View {
        if store.isHungry {
            insightBanner(
                icon: "fork.knife",
                color: .orange,
                title: "You might be hungry",
                message: "It's been over 4 hours since your last meal. Eating something before your next focus session will improve concentration."
            )
        } else if store.isInPostLunchDip {
            insightBanner(
                icon: "moon.fill",
                color: .indigo,
                title: "Post-lunch dip window",
                message: "Your break suggestions are adjusted for lower energy. Light movement or a short meditation will help more than coffee right now."
            )
        } else if store.hasNotEatenToday {
            insightBanner(
                icon: "exclamationmark.circle.fill",
                color: .yellow,
                title: "No meals logged yet",
                message: "Log your meals so break suggestions can account for your energy levels and the post-lunch dip."
            )
        }
    }

    private func insightBanner(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
