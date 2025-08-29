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
        isLocked: false,
        windowsOpen: true,
        isCharge: false,
        airConditionerOn: true,
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
    private let localModificationKey = "widgetLocalModification"
    private let localModificationTimeKey = "widgetLocalModificationTime"
    
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
    }
    
    // 标记本地状态已被修改
    func markLocalModification() {
        userDefaults?.set(true, forKey: localModificationKey)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: localModificationTimeKey)
        print("[Widget Debug] 标记本地状态已修改")
    }
    
    // 清除本地修改标记
    func clearLocalModification() {
        userDefaults?.removeObject(forKey: localModificationKey)
        userDefaults?.removeObject(forKey: localModificationTimeKey)
        print("[Widget Debug] 清除本地修改标记")
    }
    
    // 检查是否有本地修改且在指定时间内
    func hasRecentLocalModification(withinSeconds seconds: TimeInterval = 10) -> Bool {
        guard let hasModification = userDefaults?.bool(forKey: localModificationKey),
              hasModification,
              let modificationTime = userDefaults?.double(forKey: localModificationTimeKey) else {
            return false
        }
        
        let timeSinceModification = Date().timeIntervalSince1970 - modificationTime
        let hasRecentModification = timeSinceModification <= seconds
        
        print("[Widget Debug] 检查本地修改: 有修改=\(hasModification), 时间差=\(timeSinceModification)秒, 是否最近=\(hasRecentModification)")
        
        return hasRecentModification
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
        // 获取当前状态并切换到相反状态
        guard let currentCarInfo = WidgetDataManager.shared.getCachedCarInfo() else {
            return .result(dialog: "无法获取车辆状态")
        }
        
        let newLockStatus = !currentCarInfo.isLocked
        let operation = newLockStatus ? 1 : 2
        
        // 标记本地状态已被修改
        WidgetDataManager.shared.markLocalModification()
        
        // 立即更新本地状态
        let updatedCarInfo = currentCarInfo.updatingLockStatus(newLockStatus)
        WidgetDataManager.shared.updateCarInfo(updatedCarInfo)
        
        // 刷新小组件
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWatchWidget")
        
        // 异步发送网络请求
        Task {
            SharedNetworkManager.shared.energyLock(operation: operation) { result in
                // 网络请求完成后可以选择性地再次更新状态或处理错误
                switch result {
                case .success(_):
                    // 网络请求成功，状态已经在本地更新了
                    WidgetDataManager.shared.clearLocalModification()
                    break
                case .failure(_):
                    // 网络请求失败，可以选择回滚状态或显示错误
                    // 这里暂时不做处理，保持本地状态
                    break
                }
            }
        }
        
        let actionText = newLockStatus ? "锁车" : "解锁"
        return .result(dialog: "\(actionText)操作已执行")
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
        // 获取当前状态并切换到相反状态
        guard let currentCarInfo = WidgetDataManager.shared.getCachedCarInfo() else {
            return .result(dialog: "无法获取车辆状态")
        }
        
        let newACStatus = !currentCarInfo.airConditionerOn
        let operation = newACStatus ? 2 : 1
        let temperature = 26 // 默认温度
        let duringTime = 30 // 默认持续时间30分钟
        
        // 标记本地状态已被修改
        WidgetDataManager.shared.markLocalModification()
        
        // 立即更新本地状态
        let updatedCarInfo = currentCarInfo.updatingAirConditioner(newACStatus)
        WidgetDataManager.shared.updateCarInfo(updatedCarInfo)
        
        // 刷新小组件
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
        
        // 异步发送网络请求
        Task {
            SharedNetworkManager.shared.energyAirConditioner(operation: operation, temperature: temperature, duringTime: duringTime) { result in
                // 网络请求完成后可以选择性地再次更新状态或处理错误
                switch result {
                case .success(_):
                    // 网络请求成功，状态已经在本地更新了
                    WidgetDataManager.shared.clearLocalModification()
                    break
                case .failure(_):
                    // 网络请求失败，可以选择回滚状态或显示错误
                    // 这里暂时不做处理，保持本地状态
                    break
                }
            }
        }
        
        let actionText = newACStatus ? "开启空调" : "关闭空调"
        return .result(dialog: "\(actionText)操作已执行")
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
        // 获取当前状态并切换到相反状态
        guard let currentCarInfo = WidgetDataManager.shared.getCachedCarInfo() else {
            return .result(dialog: "无法获取车辆状态")
        }
        
        let newWindowStatus = !currentCarInfo.windowsOpen
        let operation = newWindowStatus ? 2 : 1
        let openLevel = newWindowStatus ? 2 : 0 // 2=完全打开，0=关闭
        
        // 标记本地状态已被修改
        WidgetDataManager.shared.markLocalModification()
        
        // 立即更新本地状态
        let updatedCarInfo = currentCarInfo.updatingWindows(newWindowStatus)
        WidgetDataManager.shared.updateCarInfo(updatedCarInfo)
        
        // 刷新小组件
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
        
        // 异步发送网络请求
        Task {
            SharedNetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel) { result in
                // 网络请求完成后可以选择性地再次更新状态或处理错误
                switch result {
                case .success(_):
                    // 网络请求成功，状态已经在本地更新了
                    WidgetDataManager.shared.clearLocalModification()
                    break
                case .failure(_):
                    // 网络请求失败，可以选择回滚状态或显示错误
                    // 这里暂时不做处理，保持本地状态
                    break
                }
            }
        }
        
        let actionText = newWindowStatus ? "打开车窗" : "关闭车窗"
        return .result(dialog: "\(actionText)操作已执行")
    }
}

/// 小组件寻车Intent
struct GetWidgetFindCarStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "小组件寻车状态"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.findCar { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: .result(dialog: "请注意观察车辆鸣笛和闪灯状态"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "检查失败：\(error.localizedDescription)"))
                }
            }
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "车辆小组件配置" }
    static var description: IntentDescription { "配置车辆信息小组件" }
}
