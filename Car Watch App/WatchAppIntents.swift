//
//  WatchAppIntents.swift
//  Car Watch App
//
//  Created by AI Assistant on 2025
//

import Foundation
import AppIntents
import WidgetKit

// MARK: - 车锁控制 Intent

@available(watchOS 10.0, *)
struct WatchLockControlIntent: AppIntent {
    static var title: LocalizedStringResource = "车锁控制"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "操作")
    var operation: Int
    
    init() {
        self.operation = 1
    }
    
    init(operation: Int) {
        self.operation = operation
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyLock(operation: operation) { result in
                switch result {
                case .success(_):
                    // 刷新 Watch Widget
                    WidgetCenter.shared.reloadAllTimelines()
                    
                    let message = operation == 1 ? "锁车成功" : "解锁成功"
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "操作失败: \(error.localizedDescription)")))
                }
            }
        }
    }
}

// MARK: - 车窗控制 Intent

@available(watchOS 10.0, *)
struct WatchWindowControlIntent: AppIntent {
    static var title: LocalizedStringResource = "车窗控制"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "操作")
    var operation: Int
    
    @Parameter(title: "开窗等级")
    var openLevel: Int
    
    init() {
        self.operation = 1
        self.openLevel = 0
    }
    
    init(operation: Int, openLevel: Int) {
        self.operation = operation
        self.openLevel = openLevel
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    // 刷新 Watch Widget
                    WidgetCenter.shared.reloadAllTimelines()
                    
                    let message = operation == 2 ? "开窗成功" : "关窗成功"
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "操作失败: \(error.localizedDescription)")))
                }
            }
        }
    }
}

// MARK: - 空调控制 Intent

@available(watchOS 10.0, *)
struct WatchACControlIntent: AppIntent {
    static var title: LocalizedStringResource = "空调控制"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "操作")
    var operation: Int
    
    @Parameter(title: "温度")
    var temperature: Int?
    
    @Parameter(title: "持续时间")
    var duringTime: Int
    
    init() {
        self.operation = 1
        self.temperature = nil
        self.duringTime = 30
    }
    
    init(operation: Int, temperature: Int? = nil, duringTime: Int = 30) {
        self.operation = operation
        self.temperature = temperature
        self.duringTime = duringTime
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyAirConditioner(
                operation: operation,
                temperature: temperature,
                duringTime: duringTime
            ) { result in
                switch result {
                case .success(_):
                    // 刷新 Watch Widget
                    WidgetCenter.shared.reloadAllTimelines()
                    
                    let message = operation == 2 ? "空调已开启" : "空调已关闭"
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "操作失败: \(error.localizedDescription)")))
                }
            }
        }
    }
}

// MARK: - 寻车 Intent

@available(watchOS 10.0, *)
struct WatchFindCarIntent: AppIntent {
    static var title: LocalizedStringResource = "寻车"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.findCar { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "请注意观察车辆鸣笛和闪灯")))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "寻车失败: \(error.localizedDescription)")))
                }
            }
        }
    }
}

