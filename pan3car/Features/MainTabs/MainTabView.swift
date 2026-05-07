//
//  MainTabView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = AppTab.vehicle

    var body: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.vehicle.title, systemImage: AppTab.vehicle.systemImage, value: AppTab.vehicle) {
                tabContent(for: .vehicle)
            }

            Tab(AppTab.trips.title, systemImage: AppTab.trips.systemImage, value: AppTab.trips) {
                tabContent(for: .trips)
            }

            Tab(AppTab.charge.title, systemImage: AppTab.charge.systemImage, value: AppTab.charge) {
                tabContent(for: .charge)
            }

            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: AppTab.profile) {
                tabContent(for: .profile)
            }
        }
        .pan3TabBarBehavior()
        .accessibilityIdentifier("main.tabView")
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            tabContent(for: .vehicle)
            .tabItem {
                Label(AppTab.vehicle.title, systemImage: AppTab.vehicle.systemImage)
            }
            .tag(AppTab.vehicle)

            tabContent(for: .trips)
            .tabItem {
                Label(AppTab.trips.title, systemImage: AppTab.trips.systemImage)
            }
            .tag(AppTab.trips)

            tabContent(for: .charge)
            .tabItem {
                Label(AppTab.charge.title, systemImage: AppTab.charge.systemImage)
            }
            .tag(AppTab.charge)

            tabContent(for: .profile)
            .tabItem {
                Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage)
            }
            .tag(AppTab.profile)
        }
        .accessibilityIdentifier("main.tabView")
    }

    private func tabContent(for tab: AppTab) -> some View {
        NavigationStack {
            tabRoot(for: tab)
        }
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .vehicle:
            VehicleDashboardView(snapshot: .mock)
        case .trips:
            TripsPlaceholderView()
        case .charge:
            ChargePlaceholderView()
        case .profile:
            ProfilePlaceholderView()
        }
    }
}

private enum AppTab: Hashable {
    case vehicle
    case trips
    case charge
    case profile

    var title: String {
        switch self {
        case .vehicle:
            "车辆"
        case .trips:
            "行程"
        case .charge:
            "充电"
        case .profile:
            "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .vehicle:
            "gauge.with.dots.needle.33percent"
        case .trips:
            "car.rear.road.lane.dashed"
        case .charge:
            "ev.charger"
        case .profile:
            "person.crop.circle.fill"
        }
    }
}

private struct Pan3TabBarBehaviorModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.automatic)
        } else {
            content
        }
    }
}

private extension View {
    func pan3TabBarBehavior() -> some View {
        modifier(Pan3TabBarBehaviorModifier())
    }
}

#Preview("Tabs Light") {
    MainTabView()
        .environment(AppSession())
}

#Preview("Tabs Dark") {
    MainTabView()
        .environment(AppSession())
        .preferredColorScheme(.dark)
}
