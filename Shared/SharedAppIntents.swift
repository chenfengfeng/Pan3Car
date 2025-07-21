//
//  SharedAppIntents.swift
//  Pan3Car
//
//  Created by AI Assistant on 2024
//

import Foundation
import AppIntents

// MARK: - AppEnum定义

/// 车锁状态选择
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum LockStatusAction: String, AppEnum {
    case lock = "lock"
    case unlock = "unlock"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "选择状态")
    }
    
    static var caseDisplayRepresentations: [LockStatusAction: DisplayRepresentation] {
        [
            .lock: DisplayRepresentation(title: "锁车", subtitle: ""),
            .unlock: DisplayRepresentation(title: "解锁", subtitle: "")
        ]
    }
}

/// 空调状态选择
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ACStatusAction: String, AppEnum {
    case turnOn = "turnOn"
    case turnOff = "turnOff"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "选择状态")
    }
    
    static var caseDisplayRepresentations: [ACStatusAction: DisplayRepresentation] {
        [
            .turnOn: DisplayRepresentation(title: "开启空调", subtitle: ""),
            .turnOff: DisplayRepresentation(title: "关闭空调", subtitle: "")
        ]
    }
}

/// 车窗状态选择
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum WindowStatusAction: String, AppEnum {
    case open = "open"
    case close = "close"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "选择状态")
    }
    
    static var caseDisplayRepresentations: [WindowStatusAction: DisplayRepresentation] {
        [
            .open: DisplayRepresentation(title: "开启车窗", subtitle: ""),
            .close: DisplayRepresentation(title: "关闭车窗", subtitle: "")
        ]
    }
}

/// 信息查询选择
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum CarInfoType: String, AppEnum {
    case batteryLevel = "batteryLevel"
    case remainingMileage = "remainingMileage"
    case chargingStatus = "chargingStatus"
    case remainingChargeTime = "remainingChargeTime"
    case lockStatus = "lockStatus"
    case windowStatus = "windowStatus"
    case airConditionerStatus = "airConditionerStatus"
    case location = "location"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "车辆状态类型")
    }
    
    static var caseDisplayRepresentations: [CarInfoType: DisplayRepresentation] {
        [
            .batteryLevel: DisplayRepresentation(title: "当前电量百分比"),
            .remainingMileage: DisplayRepresentation(title: "剩余里程"),
            .chargingStatus: DisplayRepresentation(title: "是否正在充电"),
            .remainingChargeTime: DisplayRepresentation(title: "剩余充电时间"),
            .lockStatus: DisplayRepresentation(title: "车锁状态"),
            .windowStatus: DisplayRepresentation(title: "车窗状态"),
            .airConditionerStatus: DisplayRepresentation(title: "空调状态"),
            .location: DisplayRepresentation(title: "车辆位置坐标")
        ]
    }
}

// MARK: - AppIntent定义

/// 寻车Intent
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetFindCarStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "🪄寻车状态"
    static var description = IntentDescription("检查寻车状态")
    
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

/// 选择车锁状态Intent
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetSelectLockStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "🪄选择锁车状态"
    static var description = IntentDescription("选择车辆锁定或解锁状态")
    
    @Parameter(title: "选择操作")
    var action: LockStatusAction
    
    init() {}
    
    init(action: LockStatusAction) {
        self.init()
        self.action = action
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .lock ? 1 : 2
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyLock(operation: operation) { result in
                switch result {
                case .success(_):
                    let actionText = action == .lock ? "锁车" : "解锁"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
            }
        }
    }
}

/// 选择空调状态Intent
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetSelectACStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "🪄选择空调状态"
    static var description = IntentDescription("选择车辆空调开启或关闭状态")
    
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
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyAirConditioner(operation: operation, temperature: temperature, duringTime: duringTime) { result in
                switch result {
                case .success(_):
                    let actionText = action == .turnOn ? "开启空调" : "关闭空调"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
            }
        }
    }
}

/// 选择车窗状态Intent
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetSelectWindowStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "🪄选择车窗状态"
    static var description = IntentDescription("选择车窗开启或关闭状态")
    
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
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    let actionText = action == .open ? "开启车窗" : "关闭车窗"
                    continuation.resume(returning: .result(dialog: "\(actionText)指令已发送"))
                case .failure(let error):
                    continuation.resume(returning: .result(dialog: "操作失败：\(error.localizedDescription)"))
                }
            }
        }
    }
}

/// 车辆信息返回值类型
struct CarInfoResult: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "车辆信息结果")
    }
    
    static var defaultQuery = CarInfoResultQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(value)")
    }
    
    @Property(title: "值")
    var value: String
    
    @Property(title: "数值")
    var numericValue: Double?
    
    @Property(title: "布尔值")
    var booleanValue: Bool?
    
    @Property(title: "纬度")
    var latitude: Double?
    
    @Property(title: "经度")
    var longitude: Double?
    
    init(id: String, value: String, numericValue: Double? = nil, booleanValue: Bool? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.value = value
        self.numericValue = numericValue
        self.booleanValue = booleanValue
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct CarInfoResultQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CarInfoResult] {
        return []
    }
    
    func suggestedEntities() async throws -> [CarInfoResult] {
        return []
    }
}

/// 获取车辆信息Intent
struct GetCarInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "车辆当前状态信息"
    static var description = IntentDescription("车辆当前状态信息")
    
    @Parameter(title: "查询状态类型")
    var infoType: CarInfoType
    
    static var parameterSummary: some ParameterSummary {
        Summary("获取\(\.$infoType)")
    }
    
    init() {}
    
    init(infoType: CarInfoType) {
        self.init()
        self.infoType = infoType
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<CarInfoResult> {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<CarInfoResult, Never, Never, IntentDialog>, Error>) in
            SharedNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let data):
                    let message: IntentDialog
                    let resultValue: CarInfoResult
                    
                    switch self.infoType {
                    case .batteryLevel:
                        let soc = data["soc"] as? String ?? "0"
                        let socValue = Double(soc) ?? 0
                        message = "当前电量：\(soc)%"
                        resultValue = CarInfoResult(id: "battery_\(soc)", value: soc, numericValue: socValue)
                        
                    case .remainingMileage:
                        let milesLeft = data["acOnMile"] as? Int ?? 0
                        message = "剩余里程：\(milesLeft)km"
                        resultValue = CarInfoResult(id: "mileage_\(milesLeft)", value: "\(milesLeft)", numericValue: Double(milesLeft))
                        
                    case .chargingStatus:
                        let isCharge = data["chgStatus"] as? Int ?? 2
                        let charging = isCharge != 2
                        message = charging ? "正在充电" : "未充电"
                        resultValue = CarInfoResult(id: "charging_\(charging)", value: charging ? "充电中" : "未充电", booleanValue: charging)
                        
                    case .remainingChargeTime:
                        let isCharge = data["chgStatus"] as? Int ?? 2
                        if isCharge != 2 {
                            let chgLeftTime = data["quickChgLeftTime"] as? Int ?? 0
                            let hours = chgLeftTime / 60
                            let minutes = chgLeftTime % 60
                            if hours > 0 {
                                message = "剩余充电时间：\(hours)小时\(minutes)分钟"
                            } else {
                                message = "剩余充电时间：\(minutes)分钟"
                            }
                            resultValue = CarInfoResult(id: "charge_time_\(chgLeftTime)", value: "\(chgLeftTime)", numericValue: Double(chgLeftTime))
                        } else {
                            message = "当前未在充电"
                            resultValue = CarInfoResult(id: "charge_time_0", value: "0", numericValue: 0)
                        }
                        
                    case .lockStatus:
                        let lockStatus = data["mainLockStatus"] as? Int ?? 0
                        let isLocked = lockStatus == 0
                        message = isLocked ? "车辆已锁定" : "车辆未锁定"
                        resultValue = CarInfoResult(id: "lock_\(isLocked)", value: isLocked ? "已锁定" : "未锁定", booleanValue: isLocked)
                        
                    case .windowStatus:
                        let lfWindow = data["lfWindowOpen"] as? Int ?? 0
                        let rfWindow = data["rfWindowOpen"] as? Int ?? 0
                        let lrWindow = data["lrWindowOpen"] as? Int ?? 0
                        let rrWindow = data["rrWindowOpen"] as? Int ?? 0
                        let allWindowsClosed = lfWindow == 0 && rfWindow == 0 && lrWindow == 0 && rrWindow == 0
                        message = allWindowsClosed ? "车窗已关闭" : "车窗已打开"
                        resultValue = CarInfoResult(id: "window_\(allWindowsClosed)", value: allWindowsClosed ? "已关闭" : "已打开", booleanValue: allWindowsClosed)
                        
                    case .airConditionerStatus:
                        let acStatus = data["acStatus"] as? Int ?? 0
                        let isOn = acStatus == 1
                        message = isOn ? "空调已开启" : "空调已关闭"
                        resultValue = CarInfoResult(id: "ac_\(isOn)", value: isOn ? "已开启" : "已关闭", booleanValue: isOn)
                        
                    case .location:
                        let latitude = data["latitude"] as? String ?? "0"
                        let longitude = data["longtitude"] as? String ?? "0"
                        let latValue = Double(latitude) ?? 0.0
                        let lonValue = Double(longitude) ?? 0.0
                        
                        // 使用高德地图逆地理编码获取格式化地址
                        SharedNetworkManager.shared.getFormattedAddress(latitude: latitude, longitude: longitude) { addressResult in
                            switch addressResult {
                            case .success(let formattedAddress):
                                let message: IntentDialog = "车辆坐标：纬度 \(latitude)°，经度 \(longitude)°\n车辆位置：\(formattedAddress)"
                                let resultValue = CarInfoResult(id: "location_\(latitude)_\(longitude)", value: "\(latitude),\(longitude)", latitude: latValue, longitude: lonValue)
                                continuation.resume(returning: .result(value: resultValue, dialog: message))
                            case .failure(_):
                                // 如果获取地址失败，只显示坐标
                                let message: IntentDialog = "车辆坐标：纬度 \(latitude)°，经度 \(longitude)°"
                                let resultValue = CarInfoResult(id: "location_\(latitude)_\(longitude)", value: "\(latitude),\(longitude)", latitude: latValue, longitude: lonValue)
                                continuation.resume(returning: .result(value: resultValue, dialog: message))
                            }
                        }
                        return // 提前返回，因为异步处理在回调中完成
                    }
                    
                    continuation.resume(returning: .result(value: resultValue, dialog: message))
                    
                case .failure(let error):
                    let errorResult = CarInfoResult(id: "error", value: "获取失败")
                    continuation.resume(returning: .result(value: errorResult, dialog: "获取车辆信息失败：\(error.localizedDescription)"))
                }
            }
        }
    }
}

// MARK: - AppShortcutsProvider
/// 共享的AppShortcuts提供者
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .batteryLevel),
            phrases: ["\(.applicationName) 车辆电池百分比"],
            shortTitle: "车辆电池百分比",
            systemImageName: "battery.100percent"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .remainingMileage),
            phrases: ["\(.applicationName) 车辆剩余里程"],
            shortTitle: "车辆剩余里程",
            systemImageName: "gauge.open.with.lines.needle.33percent"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .remainingChargeTime),
            phrases: ["\(.applicationName) 车辆充电时间"],
            shortTitle: "车辆充电时间",
            systemImageName: "ev.charger.fill"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .lockStatus),
            phrases: ["\(.applicationName) 车锁状态"],
            shortTitle: "车锁状态",
            systemImageName: "car.side.lock.fill"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .windowStatus),
            phrases: ["\(.applicationName) 车窗状态"],
            shortTitle: "车窗状态",
            systemImageName: "arrowtriangle.up.arrowtriangle.down.window.right"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .airConditionerStatus),
            phrases: ["\(.applicationName) 空调状态"],
            shortTitle: "空调状态",
            systemImageName: "air.conditioner.horizontal.fill"
        ),
        AppShortcut(
            intent: GetCarInfoIntent(infoType: .location),
            phrases: ["\(.applicationName) 车辆位置"],
            shortTitle: "车辆位置",
            systemImageName: "location.fill"
        )
    ]
}
