import SwiftUI

// MARK: - Year overview sheet (12-month mini grid)

struct YearOverviewSheet: View {
    @Binding var selectedDate: Date
    @Binding var displayMonth: Date
    @Binding var isPresented: Bool

    @State private var displayYear: Int

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; return c
    }()
    private let appleRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()

    init(selectedDate: Binding<Date>, displayMonth: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._displayMonth = displayMonth
        self._isPresented  = isPresented
        let year = Calendar.current.component(.year, from: displayMonth.wrappedValue)
        self._displayYear = State(initialValue: year)
    }

    // Pre-computed data for a mini month card
    private struct MiniMonthData: Identifiable {
        let id: Int          // 0–11
        let monthStart: Date
        let days: [Date?]    // nil = padding cell
        let rows: Int
    }

    private func buildData(for year: Int) -> [MiniMonthData] {
        (0..<12).compactMap { idx -> MiniMonthData? in
            var c = DateComponents()
            c.year = year; c.month = idx + 1; c.day = 1
            guard let start = calendar.date(from: c),
                  let range = calendar.range(of: .day, in: .month, for: start) else { return nil }
            let lead = (calendar.component(.weekday, from: start) - 2 + 7) % 7
            var days: [Date?] = Array(repeating: nil, count: lead)
            for d in range {
                if let date = calendar.date(byAdding: .day, value: d - 1, to: start) { days.append(date) }
            }
            while days.count % 7 != 0 { days.append(nil) }
            return MiniMonthData(id: idx, monthStart: start, days: days, rows: days.count / 7)
        }
    }

    var body: some View {
        let months = buildData(for: displayYear)
        return NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { displayYear -= 1 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 36)
                    }
                    Spacer()
                    Text(String(displayYear)).font(.title2.weight(.bold))
                    Spacer()
                    Button { withAnimation(.easeInOut(duration: 0.2)) { displayYear += 1 } } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 36)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
                Divider()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 20) {
                        ForEach(months) { data in monthCard(data: data) }
                    }
                    .padding(16)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 40, coordinateSpace: .local)
                        .onEnded { v in
                            let h = abs(v.translation.width)
                            let vert = abs(v.translation.height)
                            guard h > vert * 1.5, h > 60 else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                displayYear += v.translation.width < 0 ? 1 : -1
                            }
                        }
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func monthCard(data: MiniMonthData) -> some View {
        let isActive = calendar.isDate(data.monthStart, equalTo: displayMonth, toGranularity: .month)
        return VStack(spacing: 4) {
            Text(Self.monthNameFormatter.string(from: data.monthStart))
                .font(.caption.weight(.bold))
                .foregroundColor(isActive ? appleRed : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
            VStack(spacing: 1) {
                ForEach(0..<data.rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < data.days.count, let day = data.days[idx] {
                                dayCell(day: day)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 18)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isActive ? appleRed.opacity(0.08) : Color(.secondarySystemBackground)))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { displayMonth = data.monthStart; isPresented = false }
        }
    }

    private func dayCell(day: Date) -> some View {
        let isToday    = calendar.isDate(day, inSameDayAs: Date())
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 10, weight: isToday ? .bold : .regular))
            .foregroundColor(isSelected ? .white : isToday ? appleRed : .primary)
            .frame(maxWidth: .infinity).frame(height: 18)
            .background(Group {
                if isSelected   { Circle().fill(appleRed) }
                else if isToday { Circle().stroke(appleRed, lineWidth: 1) }
                else            { Color.clear }
            })
    }
}
