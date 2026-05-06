//
//  AppSession.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import Observation

@Observable
final class AppSession {
    var isAuthenticated = false

    func signInForPreview() {
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
    }
}
