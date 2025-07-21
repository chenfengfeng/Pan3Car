//
//  CarWidgetBundle.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import SwiftUI
import WidgetKit

@main
struct CarWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarWidgetLiveActivity()
        
        // iOS 16兼容的只读小组件
        CarWidgetLegacy()
        
        // iOS 17+的 accessoryRectangular 样式小组件（锁屏用）
        if #available(iOSApplicationExtension 17.0, *) {
            CarWidgetRectangular()
        }
        
        // iOS 17+的交互式小组件
        if #available(iOSApplicationExtension 17.0, *) {
            CarWidget()
        }
        
        // iOS 18+的控制中心小组件
        if #available(iOSApplicationExtension 18.0, *) {
            LockCarStatus()
            UnlockCarStatus()
            OpenWindowStatus()
            CloseWindowStatus()
            TurnOnAirConditionerStatus()
            TurnOffAirConditionerStatus()
            FindCarStatus()
        }
    }
}
