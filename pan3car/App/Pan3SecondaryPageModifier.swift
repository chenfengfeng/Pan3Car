//
//  Pan3SecondaryPageModifier.swift
//  pan3car
//
//  Created by Codex on 2026/5/7.
//

import SwiftUI

private struct Pan3SecondaryPageModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content
                .toolbar(.hidden, for: .tabBar)
        }
    }
}

extension View {
    func pan3SecondaryPage() -> some View {
        modifier(Pan3SecondaryPageModifier())
    }
}
