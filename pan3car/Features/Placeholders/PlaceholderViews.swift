//
//  PlaceholderViews.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct TripsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("行程", systemImage: "map", description: Text("行程页面稍后接入"))
            .navigationTitle("行程")
            .accessibilityIdentifier("trips.placeholder")
    }
}

struct ChargePlaceholderView: View {
    var body: some View {
        ContentUnavailableView("充电", systemImage: "bolt.car", description: Text("充电页面稍后接入"))
            .navigationTitle("充电")
            .accessibilityIdentifier("charge.placeholder")
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        ContentUnavailableView("我的", systemImage: "person.crop.circle", description: Text("个人中心稍后接入"))
            .navigationTitle("我的")
            .accessibilityIdentifier("profile.placeholder")
    }
}

#Preview("Placeholders") {
    TabView {
        NavigationStack {
            TripsPlaceholderView()
        }

        NavigationStack {
            ChargePlaceholderView()
        }

        NavigationStack {
            ProfilePlaceholderView()
        }
    }
}
