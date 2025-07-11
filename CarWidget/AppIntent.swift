//
//  AppIntent.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import WidgetKit
import AppIntents

// 车辆信息数据结构（与主应用共享）
struct CarInfo: Codable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let isCharge: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
    
    static let placeholder = CarInfo(
        remainingMileage: 505,
        soc: 100,
        isLocked: true,
        windowsOpen: false,
        isCharge: false,
        airConditionerOn: false,
        lastUpdated: Date()
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
            lastUpdated: Date()
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
            lastUpdated: Date()
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
            lastUpdated: Date()
        )
    }
}

// Widget数据管理器
class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
    private let carInfoKey = "widgetCarInfo"
    
    private init() {}
    
    // 获取当前CarInfo
    func getCurrentCarInfo() -> CarInfo? {
        guard let data = userDefaults?.data(forKey: carInfoKey),
              let carInfo = try? JSONDecoder().decode(CarInfo.self, from: data) else {
            return nil
        }
        return carInfo
    }
    
    // 保存CarInfo并刷新Widget
    func updateCarInfo(_ carInfo: CarInfo) {
        guard let data = try? JSONEncoder().encode(carInfo) else { return }
        userDefaults?.set(data, forKey: carInfoKey)
        
        // 刷新Widget
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
    }
    
    // 更新车锁状态
    func updateLockStatus(_ isLocked: Bool) {
        if let currentInfo = getCurrentCarInfo() {
            let updatedInfo = currentInfo.updatingLockStatus(isLocked)
            updateCarInfo(updatedInfo)
        }
    }
    
    // 更新空调状态
    func updateAirConditionerStatus(_ isOn: Bool) {
        if let currentInfo = getCurrentCarInfo() {
            let updatedInfo = currentInfo.updatingAirConditioner(isOn)
            updateCarInfo(updatedInfo)
        }
    }
    
    // 更新车窗状态
    func updateWindowStatus(_ areOpen: Bool) {
        if let currentInfo = getCurrentCarInfo() {
            let updatedInfo = currentInfo.updatingWindows(areOpen)
            updateCarInfo(updatedInfo)
        }
    }
}

// MARK: - AppEnum 定义

enum CarLockAction: String, AppEnum {
    case lock = "lock"
    case unlock = "unlock"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "车锁操作")
    static var caseDisplayRepresentations: [CarLockAction: DisplayRepresentation] = [
        .lock: "锁车",
        .unlock: "解锁"
    ]
}

enum WindowAction: String, AppEnum {
    case open = "open"
    case close = "close"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "车窗操作")
    static var caseDisplayRepresentations: [WindowAction: DisplayRepresentation] = [
        .open: "开窗",
        .close: "关窗"
    ]
}

enum AirConditionerAction: String, AppEnum {
    case turnOn = "turnOn"
    case turnOff = "turnOff"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "空调操作")
    static var caseDisplayRepresentations: [AirConditionerAction: DisplayRepresentation] = [
        .turnOn: "开启",
        .turnOff: "关闭"
    ]
}

// MARK: - Widget AppIntents

struct CarLockControlIntent: AppIntent {
    static var title: LocalizedStringResource = "车锁控制"
    static var description = IntentDescription("控制车辆锁定状态")
    
    @Parameter(title: "操作")
    var action: CarLockAction
    
    init() {}
    
    init(action: CarLockAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult {
        let operation = action == .lock ? 1 : 2
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlCarLock(operation: operation) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    let newLockStatus = (operation == 1) // 1=锁车, 2=解锁
                    WidgetDataManager.shared.updateLockStatus(newLockStatus)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct AirConditionerControlIntent: AppIntent {
    static var title: LocalizedStringResource = "空调控制"
    static var description = IntentDescription("控制车辆空调开关")
    
    @Parameter(title: "操作")
    var action: AirConditionerAction
    
    init() {}
    
    init(action: AirConditionerAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult {
        let operation = action == .turnOn ? 2 : 1
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlAirConditioner(operation: operation, temperature: 26, duringTime: 30) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    let newAcStatus = (operation == 2) // 2=开启, 1=关闭
                    WidgetDataManager.shared.updateAirConditionerStatus(newAcStatus)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct WindowControlIntent: AppIntent {
    static var title: LocalizedStringResource = "车窗控制"
    static var description = IntentDescription("控制车窗开关状态")
    
    @Parameter(title: "操作")
    var action: WindowAction
    
    init() {}
    
    init(action: WindowAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult {
        let operation = action == .open ? 2 : 1
        let openLevel = action == .open ? 2 : 0
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    let newWindowStatus = (operation == 2) // 2=开启, 1=关闭
                    WidgetDataManager.shared.updateWindowStatus(newWindowStatus)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct FindCarIntent: AppIntent {
    static var title: LocalizedStringResource = "寻车鸣笛"
    static var description = IntentDescription("让车辆发出鸣笛声以方便定位")
    
    func perform() async throws -> some IntentResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.findCar { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct GetCarInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "获取车辆信息"
    static var description = IntentDescription("获取最新的车辆状态信息")
    static var isDiscoverable: Bool = false
    
    func perform() async throws -> some IntentResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let carData):
                    // 解析并保存最新的车辆数据
                    let socString = carData["soc"] as? String ?? "0"
                    let soc = Int(socString) ?? 0
                    let remainingMileage = carData["acOnMile"] as? Int ?? 0
                    let mainLockStatus = carData["mainLockStatus"] as? Int ?? 0
                    let acStatus = carData["acStatus"] as? Int ?? 0
                    let lfWindow = carData["lfWindowOpen"] as? Int ?? 0
                    let rfWindow = carData["rfWindowOpen"] as? Int ?? 0
                    let lrWindow = carData["lrWindowOpen"] as? Int ?? 0
                    let rrWindow = carData["rrWindowOpen"] as? Int ?? 0
                    let topWindow = carData["topWindowOpen"] as? Int ?? 0
                    let isCharge = carData["chgStatus"] as? Int ?? 2
                    
                    let carInfo = CarInfo(
                        remainingMileage: remainingMileage,
                        soc: soc,
                        isLocked: mainLockStatus == 0,
                        windowsOpen: lfWindow == 1 || rfWindow == 1 || lrWindow == 1 || rrWindow == 1 || topWindow == 1,
                        isCharge: isCharge != 2,
                        airConditionerOn: acStatus == 1,
                        lastUpdated: Date()
                    )
                    
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

struct RefreshCarInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新车辆信息"
    static var description = IntentDescription("获取最新的车辆状态信息")
    
    func perform() async throws -> some IntentResult {
        // 调用GetCarInfoIntent来获取最新信息
        let getCarInfoIntent = GetCarInfoIntent()
        _ = try await getCarInfoIntent.perform()
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "车辆小组件配置" }
    static var description: IntentDescription { "配置车辆信息小组件" }
}

// MARK: - Control Widget SetValueIntents

struct CarLockToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource = "车锁控制"
    static var description = IntentDescription("控制车辆锁定状态")
    
    @Parameter(title: "锁定状态")
    var value: Bool
    
    init() {}
    
    init(value: Bool) {
        self.value = value
    }
    
    func perform() async throws -> some IntentResult {
        let operation = value ? 1 : 2 // true=锁车(1), false=解锁(2)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlCarLock(operation: operation) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    WidgetDataManager.shared.updateLockStatus(self.value)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct AirConditionerToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource = "空调控制"
    static var description = IntentDescription("控制车辆空调开关")
    
    @Parameter(title: "空调状态")
    var value: Bool
    
    init() {}
    
    init(value: Bool) {
        self.value = value
    }
    
    func perform() async throws -> some IntentResult {
        let operation = value ? 2 : 1 // true=开启(2), false=关闭(1)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlAirConditioner(operation: operation, temperature: 26, duringTime: 30) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    WidgetDataManager.shared.updateAirConditionerStatus(self.value)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct WindowToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource = "车窗控制"
    static var description = IntentDescription("控制车窗开关状态")
    
    @Parameter(title: "车窗状态")
    var value: Bool
    
    init() {}
    
    init(value: Bool) {
        self.value = value
    }
    
    func perform() async throws -> some IntentResult {
        let operation = value ? 2 : 1 // true=开启(2), false=关闭(1)
        let openLevel = value ? 2 : 0
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, Never>, Error>) in
            WidgetNetworkManager.shared.controlWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    // 操作成功后，直接更新本地数据
                    WidgetDataManager.shared.updateWindowStatus(self.value)
                    continuation.resume(returning: .result())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
