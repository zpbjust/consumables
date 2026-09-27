import SwiftUI

enum ScheduleFilter: String, CaseIterable, Identifiable {
    case all
    case overdue
    case comingUp
    case later

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .overdue: "Overdue"
        case .comingUp: "Coming up"
        case .later: "Later"
        }
    }
}

enum ScheduleFilterPresentation {
    static func showsStatusFilters(selectedDate: Date?) -> Bool {
        selectedDate == nil
    }
}

struct ScheduleTimeline {
    let overdue: [ConsumableItem]
    let comingUp: [ConsumableItem]
    let later: [ConsumableItem]

    init(
        items: [ConsumableItem],
        comingUpDays: Int = 30,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        let comingUpCutoff = calendar.date(
            byAdding: .day,
            value: max(0, comingUpDays),
            to: today
        ) ?? today
        let scheduled = items
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }

        var overdueItems: [ConsumableItem] = []
        var comingUpItems: [ConsumableItem] = []
        var laterItems: [ConsumableItem] = []
        for item in scheduled {
            guard let dueDate = item.nextDueDate else { continue }
            if item.isOverdue(on: now, calendar: calendar) {
                overdueItems.append(item)
            } else if calendar.startOfDay(for: dueDate) <= comingUpCutoff {
                comingUpItems.append(item)
            } else {
                laterItems.append(item)
            }
        }
        overdue = overdueItems
        comingUp = comingUpItems
        later = laterItems
    }

    func items(for filter: ScheduleFilter) -> [ConsumableItem] {
        switch filter {
        case .all: overdue + comingUp + later
        case .overdue: overdue
        case .comingUp: comingUp
        case .later: later
        }
    }

    func count(for filter: ScheduleFilter) -> Int {
        switch filter {
        case .all: overdue.count + comingUp.count + later.count
        case .overdue: overdue.count
        case .comingUp: comingUp.count
        case .later: later.count
        }
    }
}

enum ScheduleCalendar {
    typealias ItemIndex = [Date: [ConsumableItem]]

    static func monthDates(containing date: Date, calendar: Calendar = .current) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: monthInterval.start)
        else { return Array(repeating: nil, count: 42) }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dates = Array<Date?>(repeating: nil, count: leadingCount)
        dates.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }.map(Optional.some))
        dates.append(contentsOf: Array(repeating: nil, count: max(0, 42 - dates.count)))
        return Array(dates.prefix(42))
    }

    static func items(
        _ items: [ConsumableItem],
        dueOn date: Date,
        calendar: Calendar = .current
    ) -> [ConsumableItem] {
        items.filter { item in
            guard let dueDate = item.nextDueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }.sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    static func itemIndex(
        for items: [ConsumableItem],
        calendar: Calendar = .current
    ) -> ItemIndex {
        var result: ItemIndex = [:]
        for item in items {
            guard let dueDate = item.nextDueDate else { continue }
            result[calendar.startOfDay(for: dueDate), default: []].append(item)
        }
        return result
    }

    static func isSelectable(
        _ date: Date,
        in index: ItemIndex,
        calendar: Calendar = .current
    ) -> Bool {
        !(index[calendar.startOfDay(for: date)] ?? []).isEmpty
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: PassportStore
    @State private var replacementItemID: UUID?
    @State private var selectedFilter: ScheduleFilter = .all
    @State private var selectedDate: Date?
    @State private var showingDatePicker = false
    @State private var selectedItemDetail: ItemDetailRoute?

    private let calendar = Calendar.current

    var body: some View {
        let timeline = ScheduleTimeline(items: store.items)
        let scheduledItems = timeline.items(for: .all)
        let itemsByDay = ScheduleCalendar.itemIndex(for: scheduledItems, calendar: calendar)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PassportPageTitle(title: "Schedule")

                    if scheduledItems.isEmpty {
                        emptySchedule
                    } else {
                        dateFilterCard(itemsByDay: itemsByDay)
                        if ScheduleFilterPresentation.showsStatusFilters(selectedDate: selectedDate) {
                            filterBar(timeline: timeline)
                        }
                        scheduleResults(timeline: timeline, itemsByDay: itemsByDay)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .passportCollapsingTitle("Schedule")
            .fullScreenCover(isPresented: $showingDatePicker) {
                ScheduleDatePickerView(
                    selectedDate: $selectedDate,
                    items: scheduledItems
                )
            }
            .fullScreenCover(item: $selectedItemDetail) { route in
                ItemDetailScreen(itemID: route.id)
            }
            .fullScreenCover(isPresented: Binding(
                get: { replacementItemID != nil },
                set: { if !$0 { replacementItemID = nil } }
            )) {
                if let replacementItemID {
                    ReplacementView(itemID: replacementItemID)
                }
            }
            .onChange(of: scheduledItems.compactMap(\.nextDueDate)) { _ in
                guard let selectedDate,
                      !ScheduleCalendar.isSelectable(selectedDate, in: itemsByDay, calendar: calendar)
                else { return }
                self.selectedDate = nil
            }
            .onChange(of: selectedDate) { date in
                if date != nil {
                    selectedFilter = .all
                }
            }
        }
        .tint(PassportTheme.teal)
    }

    private func dateFilterCard(itemsByDay: ScheduleCalendar.ItemIndex) -> some View {
        let selectedItems = selectedDate.map {
            itemsByDay[calendar.startOfDay(for: $0), default: []]
        } ?? []

        return PassportCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DUE DATE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(PassportTheme.muted)

                    if let selectedDate, !selectedItems.isEmpty {
                        Text(selectedDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.headline)
                            .foregroundStyle(PassportTheme.ink)
                        Text("\(selectedItems.count) scheduled replacement\(selectedItems.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    } else {
                        Text("Any due date")
                            .font(.headline)
                            .foregroundStyle(PassportTheme.ink)
                        Text("Filter by planned replacement date")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    Button(selectedItems.isEmpty ? "Choose" : "Change") {
                        showingDatePicker = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PassportTheme.teal)

                    if !selectedItems.isEmpty {
                        Button("Clear") {
                            selectedDate = nil
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PassportTheme.muted)
                    }
                }
            }
        }
        .accessibilityIdentifier("scheduleDateFilter")
    }

    private func filterBar(timeline: ScheduleTimeline) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ScheduleFilter.allCases) { filter in
                    let isSelected = selectedDate == nil && selectedFilter == filter
                    Button {
                        selectedDate = nil
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.title)
                            Text("\(timeline.count(for: filter))")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .frame(minHeight: 20)
                                .background(
                                    isSelected ? Color.white.opacity(0.18) : PassportTheme.pale,
                                    in: Capsule()
                                )
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : PassportTheme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(isSelected ? PassportTheme.teal : Color.white, in: Capsule())
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(PassportTheme.line, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(filter.title), \(timeline.count(for: filter)) items")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .accessibilityIdentifier("scheduleFilters")
    }

    @ViewBuilder
    private func scheduleResults(
        timeline: ScheduleTimeline,
        itemsByDay: ScheduleCalendar.ItemIndex
    ) -> some View {
        if let selectedDate,
           let items = itemsByDay[calendar.startOfDay(for: selectedDate)],
           !items.isEmpty {
            scheduleCards(items)
        } else if selectedFilter == .all {
            if !timeline.overdue.isEmpty {
                scheduleSection(.overdue, items: timeline.overdue)
            }
            if !timeline.comingUp.isEmpty {
                scheduleSection(.comingUp, items: timeline.comingUp)
            }
            if !timeline.later.isEmpty {
                scheduleSection(.later, items: timeline.later)
            }
            cadenceInsight
        } else {
            let items = timeline.items(for: selectedFilter)
            if items.isEmpty {
                resultEmptyState(
                    title: "No \(selectedFilter.title.lowercased()) items",
                    message: "This filter will update automatically as replacement dates change."
                )
            } else {
                scheduleCards(items)
            }
        }
    }

    private var emptySchedule: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 12) {
                Image("EditorPlan")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                Text("No replacement schedules yet")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PassportTheme.ink)
                Text("Open an item and turn on its replacement schedule. Due dates and reminders will collect here automatically.")
                    .foregroundStyle(PassportTheme.muted)
            }
        }
    }

    private func resultEmptyState(title: String, message: String) -> some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PassportTheme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PassportTheme.muted)
            }
        }
    }

    private func scheduleSection(_ filter: ScheduleFilter, items: [ConsumableItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(filter.title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(filter == .overdue ? PassportTheme.amber : PassportTheme.muted)
            scheduleCards(items)
        }
    }

    private func scheduleCards(_ items: [ConsumableItem]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { item in
                PassportCard {
                    VStack(spacing: 12) {
                        Button {
                            selectedItemDetail = ItemDetailRoute(id: item.id)
                        } label: {
                            HStack(spacing: 12) {
                                ItemArtwork(item: item, photo: store.photo(for: item), size: 50)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PassportTheme.ink)
                                    Text([item.room, item.location].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(PassportTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                ReplacementDueStatus(item: item, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button("Mark as replaced") { replacementItemID = item.id }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(PassportTheme.teal, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cadenceInsight: some View {
        if let item = store.items.first(where: { $0.averageReplacementDays != nil }),
           let average = item.averageReplacementDays {
            PassportCard {
                HStack(alignment: .top, spacing: 12) {
                    Image("EditorPlan")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your real cadence")
                            .font(.headline)
                            .foregroundStyle(PassportTheme.ink)
                        Text("You replace \(item.name) about every \(average) days. Compare that with the current \(item.intervalDays ?? average)-day schedule before your next change.")
                            .font(.subheadline)
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
            }
        }
    }
}

private struct ScheduleDatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    let items: [ConsumableItem]

    @State private var visibleMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(selectedDate: Binding<Date?>, items: [ConsumableItem]) {
        _selectedDate = selectedDate
        self.items = items
        let referenceDate = selectedDate.wrappedValue ?? Date()
        _visibleMonth = State(
            initialValue: Calendar.current.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        )
    }

    var body: some View {
        let itemsByDay = ScheduleCalendar.itemIndex(for: items, calendar: calendar)

        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Choose due date")
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(PassportTheme.line)
                        .frame(height: 1)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Replacement due date")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PassportTheme.ink)
                            Text("This date is calculated from Last replaced + Replace every. It is not the reminder notification time. Only marked dates have scheduled items.")
                                .font(.subheadline)
                                .foregroundStyle(PassportTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        calendarCard(itemsByDay: itemsByDay)

                        HStack(spacing: 18) {
                            statusKey(color: PassportTheme.amber, label: "Overdue")
                            statusKey(color: PassportTheme.teal, label: "Scheduled")
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                    .passportContentWidth(620)
                }
            }
            .background(PassportTheme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(PassportTheme.teal)
    }

    private func calendarCard(itemsByDay: ScheduleCalendar.ItemIndex) -> some View {
        PassportCard {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button("Previous") { changeMonth(by: -1) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                        .frame(minWidth: 70, alignment: .leading)

                    Spacer(minLength: 4)
                    Text(visibleMonth, format: .dateTime.month(.wide).year())
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 4)

                    Button("Next") { changeMonth(by: 1) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                        .frame(minWidth: 70, alignment: .trailing)
                }

                HStack {
                    Text(monthSummary(itemsByDay: itemsByDay))
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                    Spacer()
                    if !calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month) {
                        Button("Today") { returnToToday() }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PassportTheme.teal)
                    }
                }

                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PassportTheme.muted)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDay(date, itemsByDay: itemsByDay)
                        } else {
                            Color.clear
                                .frame(height: 40)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("scheduleDatePickerCalendar")
    }

    private var monthDates: [Date?] {
        ScheduleCalendar.monthDates(containing: visibleMonth, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let split = max(0, min(symbols.count, calendar.firstWeekday - 1))
        return Array(symbols[split...]) + Array(symbols[..<split])
    }

    private func monthSummary(itemsByDay: ScheduleCalendar.ItemIndex) -> String {
        let count = itemsByDay.reduce(into: 0) { total, entry in
            if calendar.isDate(entry.key, equalTo: visibleMonth, toGranularity: .month) {
                total += entry.value.count
            }
        }
        return "\(count) replacement\(count == 1 ? "" : "s") this month"
    }

    private func calendarDay(
        _ date: Date,
        itemsByDay: ScheduleCalendar.ItemIndex
    ) -> some View {
        let isSelectable = ScheduleCalendar.isSelectable(date, in: itemsByDay, calendar: calendar)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let dueItems = itemsByDay[calendar.startOfDay(for: date), default: []]
        let hasOverdueItem = dueItems.contains { $0.isOverdue() }

        return Button {
            guard isSelectable else { return }
            selectedDate = date
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text(date, format: .dateTime.day())
                    .font(.caption.weight(isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ? Color.white : (isSelectable ? PassportTheme.ink : PassportTheme.muted.opacity(0.38))
                    )
                    .frame(width: 30, height: 28)
                    .background(isSelected ? PassportTheme.teal : Color.clear, in: Circle())
                    .overlay {
                        if isToday && !isSelected {
                            Circle().stroke(PassportTheme.teal, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(isSelected ? Color.white : (hasOverdueItem ? PassportTheme.amber : PassportTheme.teal))
                    .frame(width: 4, height: 4)
                    .opacity(isSelectable ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .accessibilityLabel(calendarDayAccessibilityLabel(date, itemCount: dueItems.count))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func calendarDayAccessibilityLabel(_ date: Date, itemCount: Int) -> String {
        let dateText = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        guard itemCount > 0 else { return "\(dateText), no scheduled replacements" }
        return "\(dateText), \(itemCount) replacement\(itemCount == 1 ? "" : "s") scheduled"
    }

    private func statusKey(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(PassportTheme.muted)
        }
    }

    private func changeMonth(by offset: Int) {
        guard let updatedMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = updatedMonth
        }
    }

    private func returnToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        }
    }
}
