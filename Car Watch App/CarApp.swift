//
//  CarApp.swift
//  Car Watch App
//
//  Created by Feng on 2025/8/14.
//

import SwiftUI

@main
struct Car_Watch_AppApp: App {
    
    // 初始化WatchConnectivityManager
    let watchConnectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivityManager)
        }
    }
}
