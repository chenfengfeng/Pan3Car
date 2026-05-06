//
//  pan3carApp.swift
//  pan3car
//
//  Created by Feng on 2026/5/4.
//

import SwiftUI

@main
struct pan3carApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(session)
        }
    }
}
