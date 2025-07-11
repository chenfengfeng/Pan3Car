//
//  CarWidgetControl.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import AppIntents
import WidgetKit
import SwiftUI

// MARK: - 锁车控制
@available(iOSApplicationExtension 18.0, *)
struct LockCarControl: ControlWidget {
    static let kind: String = "LockCarControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: CarLockControlIntent(action: .lock)) {
                Label("锁车", systemImage: "lock.fill")
            }
        }
        .displayName("锁车")
        .description("锁定车辆")
    }
}

// MARK: - 解锁控制
@available(iOSApplicationExtension 18.0, *)
struct UnlockCarControl: ControlWidget {
    static let kind: String = "UnlockCarControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: CarLockControlIntent(action: .unlock)) {
                Label("解锁", systemImage: "lock.open.fill")
            }
        }
        .displayName("解锁")
        .description("解锁车辆")
    }
}

// MARK: - 开车窗控制
@available(iOSApplicationExtension 18.0, *)
struct OpenWindowControl: ControlWidget {
    static let kind: String = "OpenWindowControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: WindowControlIntent(action: .open)) {
                Label("开车窗", systemImage: "car.window.left.badge.exclamationmark")
            }
        }
        .displayName("开车窗")
        .description("打开车窗")
    }
}

// MARK: - 关车窗控制
@available(iOSApplicationExtension 18.0, *)
struct CloseWindowControl: ControlWidget {
    static let kind: String = "CloseWindowControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: WindowControlIntent(action: .close)) {
                Label("关车窗", systemImage: "car.window.left")
            }
        }
        .displayName("关车窗")
        .description("关闭车窗")
    }
}

// MARK: - 开空调控制
@available(iOSApplicationExtension 18.0, *)
struct TurnOnAirConditionerControl: ControlWidget {
    static let kind: String = "TurnOnAirConditionerControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: AirConditionerControlIntent(action: .turnOn)) {
                Label("开空调", systemImage: "air.conditioner.horizontal.fill")
            }
        }
        .displayName("开空调")
        .description("打开空调")
    }
}

// MARK: - 关空调控制
@available(iOSApplicationExtension 18.0, *)
struct TurnOffAirConditionerControl: ControlWidget {
    static let kind: String = "TurnOffAirConditionerControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: AirConditionerControlIntent(action: .turnOff)) {
                Label("关空调", systemImage: "air.conditioner.horizontal")
            }
        }
        .displayName("关空调")
        .description("关闭空调")
    }
}

// MARK: - 找车控制
@available(iOSApplicationExtension 18.0, *)
struct FindCarControl: ControlWidget {
    static let kind: String = "FindCarControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: FindCarIntent()) {
                Label("找车", systemImage: "location.magnifyingglass")
            }
        }
        .displayName("找车")
        .description("定位并寻找车辆")
    }
}

// MARK: - Providers
@available(iOSApplicationExtension 18.0, *)
struct CarLockProvider: AppIntentControlValueProvider {
    struct Value {
        var isLocked: Bool
    }
    
    func previewValue(configuration: CarControlConfiguration) -> Value {
        Value(isLocked: true)
    }
    
    func currentValue(configuration: CarControlConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCurrentCarInfo()
        return Value(isLocked: carInfo?.isLocked ?? true)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct AirConditionerProvider: AppIntentControlValueProvider {
    struct Value {
        var isOn: Bool
    }
    
    func previewValue(configuration: CarControlConfiguration) -> Value {
        Value(isOn: false)
    }
    
    func currentValue(configuration: CarControlConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCurrentCarInfo()
        return Value(isOn: carInfo?.airConditionerOn ?? false)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct WindowProvider: AppIntentControlValueProvider {
    struct Value {
        var isOpen: Bool
    }
    
    func previewValue(configuration: CarControlConfiguration) -> Value {
        Value(isOpen: false)
    }
    
    func currentValue(configuration: CarControlConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCurrentCarInfo()
        return Value(isOpen: carInfo?.windowsOpen ?? false)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct CarControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "车辆控制配置"
}
