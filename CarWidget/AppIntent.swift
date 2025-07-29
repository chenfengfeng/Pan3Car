//
//  AppIntent.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import WidgetKit
import AppIntents
import Foundation

// 导入共享的网络管理器和AppIntent
// 注意：确保在项目设置中将Shared文件夹添加到CarWidget Target

// 车辆信息数据结构
struct CarInfo: Codable, Hashable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let isCharge: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
    let chgLeftTime: Int
    
    static let placeholder = CarInfo(
        remainingMileage: 330,
        soc: 60,
        isLocked: true,
        windowsOpen: false,
        isCharge: false,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 0
    )
    
    static let placeholder1 = CarInfo(
        remainingMileage: 435,
        soc: 80,
        isLocked: true,
        windowsOpen: false,
        isCharge: false,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 0
    )
    
    static let placeholder2 = CarInfo(
        remainingMileage: 505,
        soc: 100,
        isLocked: false,
        windowsOpen: false,
        isCharge: true,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 127
    )
    
    // 创建更新后的CarInfo实例
    func updatingLockStatus(_ isLocked: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: self.isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingAirConditioner(_ isOn: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: self.isCharge,
            airConditionerOn: isOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingWindows(_ areOpen: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: areOpen,
            isCharge: self.isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingChargingStatus(_ isCharge: Bool, chgLeftTime: Int) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: chgLeftTime
        )
    }
    
    // 通用的解析CarInfo方法
    static func parseCarInfo(from carData: [String: Any]) -> CarInfo {
        let socString = carData["soc"] as? String ?? "0"
        let soc = Int(socString) ?? 0
        let remainingMileage = carData["acOnMile"] as? Int ?? 0
        let mainLockStatus = carData["mainLockStatus"] as? Int ?? 0
        let acStatus = carData["acStatus"] as? Int ?? 0
        let lfWindow = carData["lfWindowOpen"] as? Int ?? 0
        let rfWindow = carData["rfWindowOpen"] as? Int ?? 0
        let lrWindow = carData["lrWindowOpen"] as? Int ?? 0
        let rrWindow = carData["rrWindowOpen"] as? Int ?? 0
        let isCharge = carData["chgStatus"] as? Int ?? 2
        let chgLeftTime = carData["quickChgLeftTime"] as? Int ?? 0
        
        return CarInfo(
            remainingMileage: remainingMileage,
            soc: soc,
            isLocked: mainLockStatus == 0,
            windowsOpen: lfWindow == 100 || rfWindow == 100 || lrWindow == 100 || rrWindow == 100,
            isCharge: isCharge != 2,
            airConditionerOn: acStatus == 1,
            lastUpdated: Date(),
            chgLeftTime: chgLeftTime
        )
    }
}

// Widget数据管理器 - 仅用于缓存，不依赖主APP数据
class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
    private let carInfoKey = "widgetCarInfo"
    
    private init() {}
    
    // 获取缓存的CarInfo（仅作为备用）
    func getCachedCarInfo() -> CarInfo? {
        print("获取缓存的CarInfo（仅作为备用）")
        guard let data = userDefaults?.data(forKey: carInfoKey),
              let carInfo = try? JSONDecoder().decode(CarInfo.self, from: data) else {
            return nil
        }
        return carInfo
    }
    
    // 保存CarInfo
    func updateCarInfo(_ carInfo: CarInfo) {
        guard let data = try? JSONEncoder().encode(carInfo) else { return }
        userDefaults?.set(data, forKey: carInfoKey)
        
        // 移除自动刷新Widget，避免循环调用
        // WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
    }
    
    // 获取车辆信息的方法，使用SharedNetworkManager
    func getCarInfo() {
        SharedNetworkManager.shared.getCarInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    let carInfo = CarInfo.parseCarInfo(from: data)
                    self?.updateCarInfo(carInfo)
                case .failure(let error):
                    print("[Widget Debug] 获取车辆信息失败: \(error.localizedDescription)")
                    // 保持现有缓存数据，不更新错误信息到界面
                }
            }
        }
    }
}

// MARK: - Widget AppIntents
struct GetWidgetCarInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "获取车辆信息"
    static var isDiscoverable: Bool = false
    
    func perform() async throws -> some IntentResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            SharedNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let carData):
                    // 解析并保存最新的车辆数据
                    let carInfo = CarInfo.parseCarInfo(from: carData)
                    
                    // 保存到本地并刷新Widget
                    WidgetDataManager.shared.updateCarInfo(carInfo)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// 选择车锁状态Intent
struct GetWidgetSelectLockStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "小组件获取锁车状态"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    
    @Parameter(title: "选择操作")
    var action: LockStatusAction
    
    init() {}
    
    init(action: LockStatusAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .lock ? 1 : 2
        // 小组件设置状态
        LoadingStateManager.shared.setLoading(true, for: .lock)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyLock(operation: operation) { result in
                switch result {
                case .success(_):
                    let actionText = action == .lock ? "锁车" : "解锁"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
                // 小组件设置状态
                DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                    LoadingStateManager.shared.setLoading(false, for: .lock)
                })
            }
        }
    }
}

/// 选择空调状态Intent
struct GetWidgetSelectACStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "小组件获取空调状态"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    
    @Parameter(title: "选择操作")
    var action: ACStatusAction
    
    init() {}
    
    init(action: ACStatusAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .turnOn ? 2 : 1
        let temperature = 26 // 默认温度
        let duringTime = 30 // 默认持续时间10分钟
        // 小组件设置状态
        LoadingStateManager.shared.setLoading(true, for: .airConditioner)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyAirConditioner(operation: operation, temperature: temperature, duringTime: duringTime) { result in
                switch result {
                case .success(_):
                    let actionText = action == .turnOn ? "开启空调" : "关闭空调"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
                // 小组件设置状态
                DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                    LoadingStateManager.shared.setLoading(false, for: .airConditioner)
                })
            }
        }
    }
}

/// 选择车窗状态Intent
struct GetWidgetSelectWindowStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "小组件获取车窗状态"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    
    @Parameter(title: "选择操作")
    var action: WindowStatusAction
    
    init() {}
    
    init(action: WindowStatusAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .open ? 2 : 1
        let openLevel = action == .open ? 2 : 0 // 2=完全打开，0=关闭
        // 小组件设置状态
        LoadingStateManager.shared.setLoading(true, for: .window)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    let actionText = action == .open ? "开启车窗" : "关闭车窗"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
                // 小组件设置状态
                DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                    LoadingStateManager.shared.setLoading(false, for: .window)
                })
            }
        }
    }
}
/// 小组件寻车Intent
struct GetWidgetFindCarStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "小组件寻车状态"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 小组件设置状态
        LoadingStateManager.shared.setLoading(true, for: .findCar)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.findCar { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: .result(dialog: "请注意观察车辆鸣笛和闪灯状态"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "检查失败：\(error.localizedDescription)"))
                }
                DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                    LoadingStateManager.shared.setLoading(false, for: .findCar)
                })
            }
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "车辆小组件配置" }
    static var description: IntentDescription { "配置车辆信息小组件" }
}
