//
//  CarWidgetStatus.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - 锁车控制
@available(iOSApplicationExtension 18.0, *)
struct LockCarStatus: ControlWidget {
    static let kind: String = "LockCarStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectLockStatusIntent(action: .lock)) {
                Label("🪄锁车状态", systemImage: "lock.fill")
            }
        }
        .displayName("锁车")
    }
}

// MARK: - 解锁控制
@available(iOSApplicationExtension 18.0, *)
struct UnlockCarStatus: ControlWidget {
    static let kind: String = "UnlockCarStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectLockStatusIntent(action: .unlock)) {
                Label("🪄解锁状态", systemImage: "lock.open.fill")
            }
        }
        .displayName("解锁")
    }
}

// MARK: - 开车窗控制
@available(iOSApplicationExtension 18.0, *)
struct OpenWindowStatus: ControlWidget {
    static let kind: String = "OpenWindowStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectWindowStatusIntent(action: .open)) {
                Label("🪄打开车窗状态", systemImage: "dock.arrow.down.rectangle")
            }
        }
        .displayName("开窗")
    }
}

// MARK: - 关车窗控制
@available(iOSApplicationExtension 18.0, *)
struct CloseWindowStatus: ControlWidget {
    static let kind: String = "CloseWindowStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectWindowStatusIntent(action: .close)) {
                Label("🪄关闭车窗状态", systemImage: "dock.arrow.up.rectangle")
            }
        }
        .displayName("关窗")
    }
}

// MARK: - 开空调控制
@available(iOSApplicationExtension 18.0, *)
struct TurnOnAirConditionerStatus: ControlWidget {
    static let kind: String = "TurnOnAirConditionerStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectACStatusIntent(action: .turnOn)) {
                Label("🪄开空调状态", systemImage: "air.conditioner.horizontal.fill")
            }
        }
        .displayName("开空调")
    }
}

// MARK: - 关空调控制
@available(iOSApplicationExtension 18.0, *)
struct TurnOffAirConditionerStatus: ControlWidget {
    static let kind: String = "TurnOffAirConditionerStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetSelectACStatusIntent(action: .turnOff)) {
                Label("🪄关空调状态", systemImage: "air.conditioner.horizontal")
            }
        }
        .displayName("关空调")
    }
}

// MARK: - 找车控制
@available(iOSApplicationExtension 18.0, *)
struct FindCarStatus: ControlWidget {
    static let kind: String = "FindCarStatus"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetButton(action: GetFindCarStatusIntent()) {
                Label("🪄找车状态", systemImage: "location.magnifyingglass")
            }
        }
        .displayName("找车")
    }
}

// MARK: - Providers
@available(iOSApplicationExtension 18.0, *)
struct CarLockProvider: AppIntentControlValueProvider {
    struct Value {
        var isLocked: Bool
    }

    func previewValue(configuration: CarStatusConfiguration) -> Value {
        Value(isLocked: true)
    }

    func currentValue(configuration: CarStatusConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCachedCarInfo()
        return Value(isLocked: carInfo?.isLocked ?? true)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct AirConditionerProvider: AppIntentControlValueProvider {
    struct Value {
        var isOn: Bool
    }

    func previewValue(configuration: CarStatusConfiguration) -> Value {
        Value(isOn: false)
    }

    func currentValue(configuration: CarStatusConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCachedCarInfo()
        return Value(isOn: carInfo?.airConditionerOn ?? false)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct WindowProvider: AppIntentControlValueProvider {
    struct Value {
        var isOpen: Bool
    }

    func previewValue(configuration: CarStatusConfiguration) -> Value {
        Value(isOpen: false)
    }

    func currentValue(configuration: CarStatusConfiguration) async throws -> Value {
        let carInfo = WidgetDataManager.shared.getCachedCarInfo()
        return Value(isOpen: carInfo?.windowsOpen ?? false)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct CarStatusConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "车辆配置状态"
}
