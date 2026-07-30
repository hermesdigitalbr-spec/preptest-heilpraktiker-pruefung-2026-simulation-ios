import SwiftUI

struct MainTabView: View {
    @Environment(AppSession.self) private var session

    @State private var selection: Int

    init(initialTab: Int = 0) {
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label(session.strings.tabs.home, systemImage: "house.fill") }
                .tag(0)

            StudyView()
                .tabItem { Label(session.strings.tabs.study, systemImage: "book.fill") }
                .tag(1)

            ReviewView()
                .tabItem { Label(session.strings.tabs.review, systemImage: "clock.arrow.circlepath") }
                .tag(2)

            StatsView()
                .tabItem { Label(session.strings.tabs.stats, systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label(session.strings.tabs.settings, systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppColor.accent)
        .onChange(of: session.pendingDailyLaunch) { _, pending in
            if pending { selection = 0 } // jump to Home; HomeView consumes the flag
        }
        .alert(session.strings.stats.freezeUsedTitle,
               isPresented: Binding(get: { session.justFrozenDay != nil },
                                    set: { if !$0 { session.justFrozenDay = nil } })) {
            Button(session.strings.common.ok) { session.justFrozenDay = nil }
        } message: {
            Text(session.strings.stats.freezeUsedMessage)
        }
    }
}
