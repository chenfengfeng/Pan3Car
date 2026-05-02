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

// MARK: - 刷新车辆信息 Intent（用于 Widget 主动刷新）

@available(watchOS 10.0, *)
struct WatchRefreshCarInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新车辆信息"
    static var description = IntentDescription("从服务器获取最新的车辆信息")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            // 检查认证信息
            guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3"),
                  let timaToken = userDefaults.string(forKey: "timaToken"),
                  let defaultVin = userDefaults.string(forKey: "defaultVin") else {
                print("[WatchRefreshCarInfoIntent] 缺少认证信息，无法刷新")
                continuation.resume(returning: .result())
                return
            }
            
            // 检查数据新鲜度（如果数据在5分钟内，不刷新）
            let lastUpdateTimestamp = userDefaults.double(forKey: "SharedCarModelLastUpdate")
            if lastUpdateTimestamp > 0 {
                let lastUpdate = Date(timeIntervalSince1970: lastUpdateTimestamp)
                let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
                if timeSinceLastUpdate < 300 { // 5分钟
                    print("[WatchRefreshCarInfoIntent] 数据仍然新鲜（\(Int(timeSinceLastUpdate))秒前更新），跳过刷新")
                    continuation.resume(returning: .result())
                    return
                }
            }
            
            print("[WatchRefreshCarInfoIntent] 开始从服务器获取车辆信息")
            
            // 调用网络请求获取车辆信息
            SharedNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let data):
                    print("[WatchRefreshCarInfoIntent] 成功获取车辆信息")
                    
                    // 将数据转换为 SharedCarModel
                    if let sharedCarModel = SharedCarModel(dictionary: data) {
                        // 保存到 App Groups
                        let carModelDict = sharedCarModel.toDictionary()
                        userDefaults.set(carModelDict, forKey: "SharedCarModelData")
                        userDefaults.set(Date().timeIntervalSince1970, forKey: "SharedCarModelLastUpdate")
                        userDefaults.synchronize()
                        
                        print("[WatchRefreshCarInfoIntent] 已保存车辆信息到 App Groups")
                        
                        // 刷新 Widget
                        WidgetCenter.shared.reloadAllTimelines()
                        print("[WatchRefreshCarInfoIntent] 已刷新 Widget")
                    } else {
                        print("[WatchRefreshCarInfoIntent] 数据转换失败")
                    }
                    
                    continuation.resume(returning: .result())
                    
                case .failure(let error):
                    print("[WatchRefreshCarInfoIntent] 获取车辆信息失败: \(error.localizedDescription)")
                    // 即使失败也返回成功，因为可能使用缓存数据
                    continuation.resume(returning: .result())
                }
            }
        }
    }
}