import SwiftUI

struct ContentView: View {
    @AppStorage("homePassport.didOnboard") private var didOnboard = false

    var body: some View {
        Group {
            if didOnboard {
                PassportTabs()
            } else {
                WelcomeView(didOnboard: $didOnboard)
            }
        }
        .passportDismissesKeyboardOnTap()
        .preferredColorScheme(.light)
#if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
                didOnboard = false
            }
        }
#endif
    }
}

private struct WelcomeView: View {
    @Binding var didOnboard: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Spacer(minLength: 20)
                    Image("WelcomeHome")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 190)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    Text("Home Passport")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(PassportTheme.ink)
                    Text("The right replacement, right when you need it.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(PassportTheme.teal)
                    Text("Save the exact model, size, and location of the things your home uses up. Your records stay on this device.")
                        .foregroundStyle(PassportTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 20)
                    Button("Get started") { didOnboard = true }
                        .buttonStyle(PassportPrimaryButton())
                        .accessibilityIdentifier("welcomeGetStarted")
                    Text("No account needed · Works offline")
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(26)
                .frame(minHeight: proxy.size.height)
            }
        }
        .background(PassportTheme.canvas.ignoresSafeArea())
    }
}

enum PassportTab: String, CaseIterable {
    case home = "Home"
    case items = "Items"
    case schedule = "Schedule"
    case shopping = "Shopping"
    case settings = "Settings"

    var iconName: String { "Tab\(rawValue)" }
}

private struct PassportTabs: View {
    @State private var selected: PassportTab = .home

    var body: some View {
        TabView(selection: $selected) {
            HomeView()
                .tabItem { tabLabel(.home) }
                .tag(PassportTab.home)
            ItemsView()
                .tabItem { tabLabel(.items) }
                .tag(PassportTab.items)
            ScheduleView()
                .tabItem { tabLabel(.schedule) }
                .tag(PassportTab.schedule)
            ShoppingView()
                .tabItem { tabLabel(.shopping) }
                .tag(PassportTab.shopping)
            SettingsView()
                .tabItem { tabLabel(.settings) }
                .tag(PassportTab.settings)
        }
        .tint(PassportTheme.teal)
    }

    private func tabLabel(_ tab: PassportTab) -> some View {
        VStack(spacing: 4) {
            Image(tab.iconName + (selected == tab ? "Selected" : ""))
                .renderingMode(.original)
            Text(tab.rawValue)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: PassportStore
    @State private var showingAdd = false
    @State private var selectedItemDetail: ItemDetailRoute?

    var body: some View {
        let timeline = ScheduleTimeline(items: store.items, comingUpDays: 14)
        let attention = timeline.overdue + timeline.comingUp
        let summaries = HomeDashboardPresentation.homeSummaries(
            homes: store.homes,
            items: store.items,
            attentionIDs: Set(attention.map(\.id))
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PassportPageTitle(title: "Home Passport")

                    if store.items.isEmpty { emptyHome }
                    else { attentionCard(items: attention) }
                    homeOverview(summaries: summaries)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .passportCollapsingTitle("Home Passport")
            .safeAreaInset(edge: .bottom) {
                if !store.items.isEmpty {
                    HStack {
                        Spacer()
                        PassportFloatingButton(title: "Add item") { showingAdd = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .fullScreenCover(isPresented: $showingAdd) { ItemEditorView() }
            .fullScreenCover(item: $selectedItemDetail) { route in
                ItemDetailScreen(itemID: route.id)
            }
        }
    }

    private var emptyHome: some View {
        VStack(spacing: 18) {
            Image("WelcomeHome")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text("Start with one thing you replace")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PassportTheme.ink)
                Text("Scan an air filter, water filter, bulb, or battery label. Home Passport will keep the exact model, location, and next replacement date together.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PassportTheme.muted)
            }
            Button("Scan or add your first item") { showingAdd = true }
                .buttonStyle(PassportPrimaryButton())
                .accessibilityIdentifier("addFirstItem")
        }
        .padding(.top, 8)
    }

    private func attentionCard(items: [ConsumableItem]) -> some View {
        let visibleItems = Array(items.prefix(3))
        return PassportCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image("EditorPlan")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(items.isEmpty ? "Everything is on schedule" : "\(items.count) item\(items.count == 1 ? "" : "s") need attention")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PassportTheme.ink)
                        Text(items.isEmpty
                             ? "Your next scheduled replacement will appear here."
                             : "See what is overdue and what is coming up next.")
                            .font(.subheadline)
                            .foregroundStyle(PassportTheme.muted)
                    }
                    Spacer()
                }

                if !visibleItems.isEmpty {
                    Divider()
                    ForEach(visibleItems) { item in
                        Button {
                            selectedItemDetail = ItemDetailRoute(id: item.id)
                        } label: {
                            attentionRow(item)
                        }
                        .buttonStyle(.plain)
                        if item.id != visibleItems.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func attentionRow(_ item: ConsumableItem) -> some View {
        HStack(spacing: 12) {
            ItemArtwork(item: item, photo: store.photo(for: item), size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PassportTheme.ink)
                Text([item.size, item.location.isEmpty ? item.room : item.location]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            ReplacementDueStatus(item: item, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private func homeOverview(
        summaries: [HomeDashboardPresentation.HomeSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionEyebrow(title: "Homes")
                Spacer()
                Text("\(store.homes.count) total")
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
            }
            VStack(spacing: 12) {
                ForEach(summaries) { summary in
                    NavigationLink {
                        HomeDashboardView(homeID: summary.id)
                    } label: {
                        HomeOverviewCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("homeCard-\(summary.name)")
                }
            }
        }
    }

}

private struct HomeOverviewCard: View {
    let summary: HomeDashboardPresentation.HomeSummary

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PassportTheme.ink)
                    .lineLimit(2)

                Text("\(summary.roomCount) room\(summary.roomCount == 1 ? "" : "s") · \(summary.itemCount) item\(summary.itemCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(PassportTheme.muted)

                Text(summary.attentionCount > 0
                     ? "\(summary.attentionCount) need attention"
                     : summary.itemCount > 0 ? "Everything is current" : "Ready for your first item")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summary.attentionCount > 0 ? PassportTheme.amber : PassportTheme.teal)

                Text("Open home")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PassportTheme.teal)
                    .padding(.top, 2)
            }

            Spacer(minLength: 4)

            Image("WelcomeHome")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .padding(10)
                .background(PassportTheme.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(PassportTheme.line, lineWidth: 1))
        .shadow(color: PassportTheme.shadow, radius: 12, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens rooms and items in this home")
    }
}

private enum HomeDashboardSection: String, CaseIterable, Identifiable {
    case rooms = "Rooms"
    case items = "All items"

    var id: String { rawValue }
}

private struct HomeDashboardView: View {
    @EnvironmentObject private var store: PassportStore
    let homeID: UUID
    @State private var section: HomeDashboardSection = .rooms
    @State private var selectedItemDetail: ItemDetailRoute?

    var body: some View {
        let home = store.home(id: homeID)
        let items = store.items.filter { $0.homeID == homeID }
        let timeline = ScheduleTimeline(items: items, comingUpDays: 14)
        let attentionIDs = Set((timeline.overdue + timeline.comingUp).map(\.id))
        let rooms = home.map {
            HomeDashboardPresentation.roomSummaries(
                home: $0,
                items: items,
                attentionIDs: attentionIDs
            )
        } ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                homeHeader(home: home, items: items, rooms: rooms, attentionIDs: attentionIDs)

                Picker("Home section", selection: $section) {
                    ForEach(HomeDashboardSection.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                if section == .rooms { roomList(rooms: rooms) }
                else { itemList(items: items) }
            }
            .padding(20)
            .padding(.bottom, 24)
            .passportContentWidth()
        }
        .background(PassportTheme.canvas)
        .navigationTitle(home?.name ?? "Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(item: $selectedItemDetail) { route in
            ItemDetailScreen(itemID: route.id)
        }
    }

    private func homeHeader(
        home: Home?,
        items: [ConsumableItem],
        rooms: [HomeDashboardPresentation.RoomSummary],
        attentionIDs: Set<UUID>
    ) -> some View {
        HStack(spacing: 16) {
            Image("WelcomeHome")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(home?.name ?? "Home")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PassportTheme.ink)
                Text("\(rooms.count) rooms · \(items.count) saved items")
                    .font(.subheadline)
                    .foregroundStyle(PassportTheme.muted)
                let dueCount = items.filter { attentionIDs.contains($0.id) }.count
                Text(dueCount > 0 ? "\(dueCount) need attention" : "Everything is current")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dueCount > 0 ? PassportTheme.amber : PassportTheme.teal)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PassportTheme.pale, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func roomList(rooms: [HomeDashboardPresentation.RoomSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Rooms")
            PassportCard {
                VStack(spacing: 0) {
                    ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                        NavigationLink {
                            RoomItemsView(homeID: homeID, roomName: room.name)
                        } label: {
                            HStack(spacing: 14) {
                                Image("EditorLocation")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                    .padding(8)
                                    .background(PassportTheme.pale, in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(room.name)
                                        .font(.headline)
                                        .foregroundStyle(PassportTheme.ink)
                                    Text(room.attentionCount > 0
                                         ? "\(room.itemCount) items · \(room.attentionCount) due"
                                         : room.itemCount > 0 ? "\(room.itemCount) items · all current" : "No items yet")
                                        .font(.caption)
                                        .foregroundStyle(room.attentionCount > 0 ? PassportTheme.amber : PassportTheme.muted)
                                }
                                Spacer()
                                Text("View")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PassportTheme.teal)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < rooms.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemList(items: [ConsumableItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "All items")
            if items.isEmpty {
                PassportCard {
                    Text("No items have been saved in this home yet.")
                        .foregroundStyle(PassportTheme.muted)
                }
            } else {
                DashboardItemRowsCard(items: items) { item in
                    selectedItemDetail = ItemDetailRoute(id: item.id)
                }
            }
        }
    }
}

private struct RoomItemsView: View {
    @EnvironmentObject private var store: PassportStore
    let homeID: UUID
    let roomName: String
    @State private var selectedItemDetail: ItemDetailRoute?

    var body: some View {
        let items = store.items.filter { $0.homeID == homeID && $0.room == roomName }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(title: "\(items.count) saved item\(items.count == 1 ? "" : "s")")
                if items.isEmpty {
                    PassportCard {
                        Text("Items assigned to this room will appear here.")
                            .foregroundStyle(PassportTheme.muted)
                    }
                } else {
                    DashboardItemRowsCard(items: items) { item in
                        selectedItemDetail = ItemDetailRoute(id: item.id)
                    }
                }
            }
            .padding(20)
            .passportContentWidth()
        }
        .background(PassportTheme.canvas)
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(item: $selectedItemDetail) { route in
            ItemDetailScreen(itemID: route.id)
        }
    }
}

private struct DashboardItemRowsCard: View {
    let items: [ConsumableItem]
    let onSelect: (ConsumableItem) -> Void

    var body: some View {
        PassportCard {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button { onSelect(item) } label: {
                        ItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    if index < items.count - 1 { Divider() }
                }
            }
        }
    }
}
