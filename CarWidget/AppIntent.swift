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
struct CarInfo: Codable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let isCharge: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
    let chgLeftTime: Int
    
    static let placeholder = CarInfo(
        remainingMileage: 505,
        soc: 100,
        isLocked: true,
        windowsOpen: false,
        isCharge: false,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 0
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
    static var description = IntentDescription("获取最新的车辆状态信息")
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

@available(iOSApplicationExtension 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "车辆小组件配置" }
    static var description: IntentDescription { "配置车辆信息小组件" }
}

// MARK: - Control Widget SetValueIntents

//struct CarLockToggleIntent: SetValueIntent {
//    static var title: LocalizedStringResource = "车锁控制"
//    static var description = IntentDescription("控制车辆锁定状态")
//
//    @Parameter(title: "锁定状态")
//    var value: Bool
//
//    init() {}
//
//    init(value: Bool) {
//        self.value = value
//    }
//
//    func perform() async throws -> some IntentResult {
//        let operation = value ? 1 : 2 // true=锁车(1), false=解锁(2)
//
//        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
//            WidgetNetworkManager.shared.controlCarLock(operation: operation) { result in
//                switch result {
//                case .success(_):
//                    // 操作成功后，直接更新本地数据
//                    WidgetDataManager.shared.updateLockStatus(self.value)
//                    continuation.resume(returning: .result())
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//    }
//}
//
//struct AirConditionerToggleIntent: SetValueIntent {
//    static var title: LocalizedStringResource = "空调控制"
//    static var description = IntentDescription("控制车辆空调开关")
//
//    @Parameter(title: "空调状态")
//    var value: Bool
//
//    init() {}
//
//    init(value: Bool) {
//        self.value = value
//    }
//
//    func perform() async throws -> some IntentResult {
//        let operation = value ? 2 : 1 // true=开启(2), false=关闭(1)
//
//        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
//            WidgetNetworkManager.shared.controlAirConditioner(operation: operation, temperature: 26, duringTime: 30) { result in
//                switch result {
//                case .success(_):
//                    // 操作成功后，直接更新本地数据
//                    WidgetDataManager.shared.updateAirConditionerStatus(self.value)
//                    continuation.resume(returning: .result())
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//    }
//}
//
//struct WindowToggleIntent: SetValueIntent {
//    static var title: LocalizedStringResource = "车窗控制"
//    static var description = IntentDescription("控制车窗开关状态")
//
//    @Parameter(title: "车窗状态")
//    var value: Bool
//
//    init() {}
//
//    init(value: Bool) {
//        self.value = value
//    }
//
//    func perform() async throws -> some IntentResult {
//        let operation = value ? 2 : 1 // true=开启(2), false=关闭(1)
//        let openLevel = value ? 2 : 0
//
//        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
//            WidgetNetworkManager.shared.controlWindow(operation: operation, openLevel: openLevel) { result in
//                switch result {
//                case .success(_):
//                    // 操作成功后，直接更新本地数据
//                    WidgetDataManager.shared.updateWindowStatus(self.value)
//                    continuation.resume(returning: .result())
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//    }
//}
