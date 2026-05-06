//
//  AppRootView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct AppRootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.snappy(duration: 0.25), value: session.isAuthenticated)
    }
}

#Preview("Logged Out") {
    AppRootView()
        .environment(AppSession())
}

#Preview("Logged In") {
    let session = AppSession()
    session.signInForPreview()

    return AppRootView()
        .environment(session)
}
