import SwiftUI

struct MainTabView: View {
    @Environment(AppSession.self) private var session

    @State private var selection: Int

    init(initialTab: Int = 0) {
        _selection = State(initialValue: initialTab)
    }

    /// Phosphor (regular) outline icons from the asset catalog — a single
    /// thin-line family, never swapped for a filled variant when selected.
    private func tab(_ title: String, _ asset: String) -> some View {
        Label {
            Text(title)
        } icon: {
            // Pre-rasterised at 22pt: tab items ignore frame modifiers, so the
            // size has to live in the asset itself.
            Image(asset)
                .renderingMode(.template)
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { tab(session.strings.tabs.home, "tabHome") }
                .tag(0)

            StudyView()
                .tabItem { tab(session.strings.tabs.study, "tabStudy") }
                .tag(1)

            ReviewView()
                .tabItem { tab(session.strings.tabs.review, "tabReview") }
                .tag(2)

            StatsView()
                .tabItem { tab(session.strings.tabs.stats, "tabStats") }
                .tag(3)

            SettingsView()
                .tabItem { tab(session.strings.tabs.settings, "tabSettings") }
                .tag(4)
        }
        .tint(AppColor.accent)
        // Outline glyphs on every tab, selected included — no auto-fill.
        .environment(\.symbolVariants, .none)
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
