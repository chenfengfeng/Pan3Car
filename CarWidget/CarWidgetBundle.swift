//
//  CarWidgetBundle.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import WidgetKit
import SwiftUI

@main
struct CarWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarWidgetLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            CarWidget()
            FindCarControl()
            LockCarControl()
            UnlockCarControl()
            OpenWindowControl()
            CloseWindowControl()
            TurnOnAirConditionerControl()
            TurnOffAirConditionerControl()
        }
    }
}
