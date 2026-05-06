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
        TabView(selection: $selectedTab) {
            NavigationStack {
                VehicleDashboardView(snapshot: .mock)
            }
            .tabItem {
                Label(AppTab.vehicle.title, systemImage: AppTab.vehicle.systemImage)
            }
            .tag(AppTab.vehicle)

            NavigationStack {
                TripsPlaceholderView()
            }
            .tabItem {
                Label(AppTab.trips.title, systemImage: AppTab.trips.systemImage)
            }
            .tag(AppTab.trips)

            NavigationStack {
                ChargePlaceholderView()
            }
            .tabItem {
                Label(AppTab.charge.title, systemImage: AppTab.charge.systemImage)
            }
            .tag(AppTab.charge)

            NavigationStack {
                ProfilePlaceholderView()
            }
            .tabItem {
                Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage)
            }
            .tag(AppTab.profile)
        }
        .accessibilityIdentifier("main.tabView")
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
            "car.fill"
        case .trips:
            "map.fill"
        case .charge:
            "bolt.car.fill"
        case .profile:
            "person.crop.circle.fill"
        }
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
