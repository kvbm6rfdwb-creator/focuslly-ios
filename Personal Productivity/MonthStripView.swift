import SwiftUI
import Foundation

private struct MonthStripView: View {
    let baseDate: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let itemWidth: CGFloat = 44
    private let spacing: CGFloat = 6

    @State private var didInitialScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.element) { index, day in
                        Button {
                            withAnimation(.easeInOut) {
                                selectedDate = day
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(shortWeekday(day))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(
                                        calendar.isDate(day, inSameDayAs: selectedDate)
                                        ? .white
                                        : .primary
                                    )
                                    .frame(width: 30, height: 30)
                                    .background(
                                        calendar.isDate(day, inSameDayAs: selectedDate)
                                        ? Color.accentColor
                                        : Color.clear
                                    )
                                    .clipShape(Circle())
                            }
                            .frame(width: itemWidth)
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, itemWidth * 2)
                // 👇 SIGNAL DA JE LAYOUT GOTOV
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                guard !didInitialScroll, geo.size.width > 0 else { return }
                                didInitialScroll = true
                                scrollToSelected(proxy)
                            }
                    }
                )
            }
            .frame(height: 52)
            .onChange(of: selectedDate) { _ in
                scrollToSelected(proxy)
            }
        }
    }

    // MARK: - Scrolling logic

    private func scrollToSelected(_ proxy: ScrollViewProxy) {
        guard let index = daysInMonth.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: selectedDate)
        }) else { return }

        let targetIndex = max(index - 2, 0)

        withAnimation(.easeInOut) {
            proxy.scrollTo(targetIndex, anchor: .leading)
        }
    }

    // MARK: - Helpers

    private var daysInMonth: [Date] {
        // Use startOfDay to get a timezone-safe anchor for the beginning of the month.
        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate),
              let range = calendar.range(of: .day, in: .month, for: baseDate)
        else { return [] }

        let monthStart = calendar.startOfDay(for: monthInterval.start)

        return range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EE"
        return df.string(from: date)
    }
}
