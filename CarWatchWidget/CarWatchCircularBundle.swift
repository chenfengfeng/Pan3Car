//
//  CarWatchCircularBundle.swift
//  CarWatchWidget
//
//  Created by Feng on 2025/1/25.
//

import WidgetKit
import SwiftUI

@main
struct CarWatchCircularBundle: WidgetBundle {
    var body: some Widget {
        CarWatchWidget()
        CarWatchCircularAC()
        CarWatchCircularLock()
        CarWatchCircularWindow()
    }
}