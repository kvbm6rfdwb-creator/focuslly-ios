import SwiftUI

struct MonthGridPicker: View {
    @Binding var selectedDate: Date
    @Binding var showMonthGrid: Bool

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let appleRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    private let yearHeaderHeight: CGFloat = 72

    @State private var currentMonth: Date
    @State private var headerMonth: Date
    @State private var lastHeaderYear: Int

    @State private var initialScrollOffset: CGFloat?   // ✅ JEDINO NOVO

    // ✅ 30 godina u oba smjera
    private let monthRange = (-60...60)

    init(selectedDate: Binding<Date>, showMonthGrid: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._showMonthGrid = showMonthGrid

        let comps = calendar.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        let month = calendar.date(from: comps) ?? Date()
        let year = calendar.component(.year, from: month)

        self._currentMonth = State(initialValue: month)
        self._headerMonth = State(initialValue: month)
        self._lastHeaderYear = State(initialValue: year)
    }

    var body: some View {
        VStack(spacing: 0) {

            header
                .frame(height: yearHeaderHeight)
                .background(Color(.systemBackground))
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onEnded { value in
                            if value.translation.height > 80 {
                                showMonthGrid = false
                            }
                        }
                )

            Divider()

            GeometryReader { geo in
                let monthHeight = geo.size.height / 3.2
                let spacing: CGFloat = 1

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {

                        // ⬇️ OFFSET TRACKING (YEAR-ONLY, CENTER-RELATIVE)
                        GeometryReader { scrollGeo in
                            Color.clear
                                .onChange(
                                    of: scrollGeo.frame(in: .named("scroll")).minY
                                ) { offsetY in

                                    // ✅ zapamti centar (samo jednom)
                                    if initialScrollOffset == nil {
                                        initialScrollOffset = offsetY
                                        return
                                    }

                                    let relativeOffset = offsetY - (initialScrollOffset ?? 0)

                                    let index = Int(
                                        round(-relativeOffset / (monthHeight + spacing))
                                    )

                                    let clamped = max(
                                        monthRange.lowerBound,
                                        min(monthRange.upperBound, index)
                                    )

                                    let newMonth = calendar.date(
                                        byAdding: .month,
                                        value: clamped,
                                        to: currentMonth
                                    )!

                                    let newYear = calendar.component(.year, from: newMonth)

                                    if newYear != lastHeaderYear {
                                        lastHeaderYear = newYear
                                        headerMonth = newMonth
                                    }
                                }
                        }
                        .frame(height: 0)

                        VStack(spacing: spacing) {
                            ForEach(monthRange, id: \.self) { offset in
                                let month = calendar.date(
                                    byAdding: .month,
                                    value: offset,
                                    to: currentMonth
                                )!

                                monthSection(for: month)
                                    .frame(height: monthHeight)
                                    .id(offset)
                            }
                        }
                        .padding(.vertical, spacing)
                    }
                    .coordinateSpace(name: "scroll")
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(0, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(.systemBackground))
    }

    // MARK: - Header

    private var header: some View {
        Text(yearString(headerMonth))
            .font(.system(size: 40, weight: .bold))
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .transaction { $0.animation = nil }
    }

    // MARK: - Month Section

    private func monthSection(for month: Date) -> some View {
        let days = daysInMonth(for: month)

        return VStack(alignment: .leading, spacing: 2) {
            Text(monthTitle(month))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    if day == .distantPast {
                        Color.clear.frame(height: 32)
                    } else {
                        Button {
                            selectedDate = day
                            showMonthGrid = false
                        } label: {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.body.weight(.medium))
                                .frame(width: 32, height: 32)
                                .background(isSelected(day) ? appleRed : .clear)
                                .foregroundColor(isSelected(day) ? .white : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isCurrentMonth(day, month: month))
                    }
                }
            }
            .transaction { $0.animation = nil }
        }
    }

    // MARK: - Helpers

    private func daysInMonth(for month: Date) -> [Date] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var days = Array(repeating: Date.distantPast, count: offset)

        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: first)!)
        }

        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: .distantPast, count: 7 - remainder))
        }

        return days
    }

    private func isSelected(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: selectedDate)
    }

    private func isCurrentMonth(_ day: Date, month: Date) -> Bool {
        calendar.isDate(day, equalTo: month, toGranularity: .month)
    }

    private func yearString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df.string(from: date)
    }

    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL"
        return df.string(from: date)
    }
}
