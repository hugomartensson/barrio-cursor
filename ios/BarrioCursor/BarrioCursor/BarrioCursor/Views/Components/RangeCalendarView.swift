import SwiftUI

/// Hotel-style single-month date range picker.
/// - First tap selects the start date.
/// - Second tap selects the end date (must be >= start).
/// - Tapping before current start resets start and waits for a new end tap.
struct RangeCalendarView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    /// true = waiting for the user to pick the end date; false = next tap picks start.
    @State private var selectingEnd: Bool = false

    @State private var displayMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols: [String] = {
        var cal = Calendar.current
        cal.locale = Locale.current
        let syms = cal.shortStandaloneWeekdaySymbols
        let firstWeekday = cal.firstWeekday - 1
        return Array(syms[firstWeekday...] + syms[..<firstWeekday])
            .map { String($0.prefix(2)) }
    }()

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayMonth)
    }

    private var daysInGrid: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let calFirstWeekday = calendar.firstWeekday
        let offset = (firstWeekday - calFirstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(d)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.portalForeground)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)

                Spacer()

                Button {
                    displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.portalForeground)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Weekday header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { idx, date in
                    if let date = date {
                        RangeCalendarDayCell(
                            date: date,
                            startDate: startDate,
                            endDate: endDate,
                            calendar: calendar
                        ) {
                            handleTap(date)
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private func handleTap(_ date: Date) {
        let tapped = calendar.startOfDay(for: date)
        if selectingEnd {
            if tapped >= calendar.startOfDay(for: startDate) {
                endDate = tapped
                selectingEnd = false
            } else {
                startDate = tapped
                endDate = tapped
            }
        } else {
            startDate = tapped
            endDate = tapped
            selectingEnd = true
        }
    }
}

struct RangeCalendarDayCell: View {
    let date: Date
    let startDate: Date
    let endDate: Date
    let calendar: Calendar
    let onTap: () -> Void

    private var isStart: Bool { calendar.isDate(date, inSameDayAs: startDate) }
    private var isEnd: Bool { calendar.isDate(date, inSameDayAs: endDate) }
    private var isInRange: Bool {
        let d = calendar.startOfDay(for: date)
        let s = calendar.startOfDay(for: startDate)
        let e = calendar.startOfDay(for: endDate)
        return d >= s && d <= e
    }
    private var isSingleDay: Bool { calendar.isDate(startDate, inSameDayAs: endDate) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                if isInRange && !isSingleDay {
                    let leadingPad: CGFloat = isStart ? w / 2 : 0
                    let trailingPad: CGFloat = isEnd ? w / 2 : 0
                    Color.portalPrimary.opacity(0.18)
                        .frame(height: 36)
                        .padding(.leading, leadingPad)
                        .padding(.trailing, trailingPad)
                }

                Circle()
                    .fill(isStart || isEnd ? Color.portalPrimary : Color.clear)
                    .frame(width: 36, height: 36)

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: (isStart || isEnd) ? .bold : .regular))
                    .foregroundColor(isStart || isEnd ? .white : .portalForeground)
            }
            .frame(width: w, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .frame(height: 44)
    }
}
