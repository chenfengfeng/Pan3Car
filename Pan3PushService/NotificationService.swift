//
//  NotificationService.swift
//  Pan3PushService
//
//  Created by Mac on 2025/10/19.
//

import UserNotifications
import WidgetKit
import WatchConnectivity
import SwiftyJSON

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        print("[NotificationService] 收到推送通知，开始处理...")
        
        // 处理推送数据
        processPushNotification(request: request, content: bestAttemptContent)
        
        // 返回处理后的通知内容
        contentHandler(bestAttemptContent)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        print("[NotificationService] Extension 即将超时，返回当前内容")
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    // MARK: - 处理推送通知
    private func processPushNotification(request: UNNotificationRequest, content: UNMutableNotificationContent) {
        // 1. 解析推送数据
        guard let carData = extractCarDataFromPush(request: request) else {
            print("[NotificationService] 无法从推送中提取车辆数据")
            return
        }
        
        print("[NotificationService] 成功提取车辆数据: \(carData)")
        
        // 2. 保存数据到 App Groups
        saveCarDataToAppGroups(carData: carData)
        
        // 3. 刷新小组件
        refreshWidgets()
        
        // 4. 发送数据到手表
        sendDataToWatch(carData: carData)
        
        // 5. 可选：修改通知内容
        enhanceNotificationContent(content: content, carData: carData)
    }
    
    // MARK: - 提取推送数据
    private func extractCarDataFromPush(request: UNNotificationRequest) -> [String: Any]? {
        let userInfo = request.content.userInfo
        
        // 方式1：检查是否有直接的 carData 字段
        if let carData = userInfo["carData"] as? [String: Any] {
            print("[NotificationService] 找到 carData 字段")
            return carData
        }
        
        // 方式2：检查是否有 aps 字段中的自定义数据
        if let aps = userInfo["aps"] as? [String: Any],
           let carData = aps["carData"] as? [String: Any] {
            print("[NotificationService] 在 aps 中找到 carData 字段")
            return carData
        }
        
        // 方式3：检查根级别的车辆状态字段
        let potentialCarFields = ["soc", "acOnMile", "mainLockStatus", "acStatus", "chgStatus"]
        let hasCarFields = potentialCarFields.contains { userInfo[$0] != nil }
        
        if hasCarFields {
            print("[NotificationService] 在根级别找到车辆状态字段")
            return userInfo as? [String : Any]
        }
        
        print("[NotificationService] 推送数据结构: \(userInfo)")
        return nil
    }
    
    // MARK: - 保存数据到 App Groups
    private func saveCarDataToAppGroups(carData: [String: Any]) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[NotificationService] 无法访问 App Groups")
            return
        }
        
        // 使用与 UserManager 相同的逻辑保存数据
        // 创建 CarModel 并转换为字典格式
        let json = JSON(carData)
        let carModel = CarModel(json: json)
        let carModelDict = carModel.toDictionary()
        
        // 保存完整的 CarModel 数据
        userDefaults.set(carModelDict, forKey: "CarModelData")
        
        // 设置本地修改标记，供小组件检测
        userDefaults.set(true, forKey: "widgetLocalModification")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "widgetLocalModificationTime")
        
        // 强制同步
        userDefaults.synchronize()
        
        print("[NotificationService] 已保存车辆数据到 App Groups")
    }
    
    // MARK: - 刷新小组件
    private func refreshWidgets() {
        print("[NotificationService] 开始刷新小组件...")
        WidgetCenter.shared.reloadAllTimelines()
        print("[NotificationService] 小组件刷新请求已发送")
    }
    
    // MARK: - 发送数据到手表
    private func sendDataToWatch(carData: [String: Any]) {
        // 检查 WatchConnectivity 是否可用
        guard WCSession.isSupported() else {
            print("[NotificationService] WatchConnectivity 不支持")
            return
        }
        
        let session = WCSession.default
        
        // 如果会话未激活，先激活
        if session.activationState != .activated {
            print("[NotificationService] WCSession 未激活，跳过手表数据发送")
            return
        }
        
        // 检查手表是否配对和可达
        guard session.isPaired else {
            print("[NotificationService] Apple Watch 未配对")
            return
        }
        
        // 发送车辆信息到手表
        do {
            try session.updateApplicationContext(["carInfo": carData])
            print("[NotificationService] 已发送车辆数据到 Apple Watch")
        } catch {
            print("[NotificationService] 发送数据到 Apple Watch 失败: \(error.localizedDescription)")
            
            // 如果 updateApplicationContext 失败，尝试使用 transferUserInfo
            session.transferUserInfo(["carInfo": carData])
            print("[NotificationService] 已通过 transferUserInfo 发送数据到 Apple Watch")
        }
    }
    
    // MARK: - 增强通知内容
    private func enhanceNotificationContent(content: UNMutableNotificationContent, carData: [String: Any]) {
        // 解析关键车辆信息
        let soc = carData["soc"] as? Int ?? 0
        let isCharging = (carData["chgStatus"] as? Int ?? 2) != 2
        let isLocked = (carData["mainLockStatus"] as? Int ?? 1) == 0
        let acStatus = (carData["acStatus"] as? Int ?? 0) == 1
        
        // 构建状态描述
        var statusParts: [String] = []
        
        if isCharging {
            statusParts.append("充电中")
        }
        
        if !isLocked {
            statusParts.append("未锁车")
        }
        
        if acStatus {
            statusParts.append("空调开启")
        }
        
        // 更新通知内容
        if !statusParts.isEmpty {
            let statusText = statusParts.joined(separator: " • ")
            content.body = "电量 \(soc)% • \(statusText)"
        } else {
            content.body = "电量 \(soc)%"
        }
        
        // 添加副标题
        content.subtitle = "车辆状态已更新"
        
        print("[NotificationService] 已增强通知内容: \(content.body)")
    }
}

// MARK: - CarModel 扩展（临时定义，用于数据转换）
// 注意：这里需要与主应用中的 CarModel 保持一致
private struct CarModel {
    let soc: Int
    let acOnMile: Int
    let mainLockStatus: Int
    let acStatus: Int
    let chgStatus: Int
    let quickChgLeftTime: Int
    let temperatureInCar: Int
    let lfWindowOpen: Int
    let rfWindowOpen: Int
    let lrWindowOpen: Int
    let rrWindowOpen: Int
    
    init(json: JSON) {
        self.soc = json["soc"].intValue
        self.acOnMile = json["acOnMile"].intValue
        self.mainLockStatus = json["mainLockStatus"].intValue
        self.acStatus = json["acStatus"].intValue
        self.chgStatus = json["chgStatus"].intValue
        self.quickChgLeftTime = json["quickChgLeftTime"].intValue
        self.temperatureInCar = json["temperatureInCar"].intValue
        self.lfWindowOpen = json["lfWindowOpen"].intValue
        self.rfWindowOpen = json["rfWindowOpen"].intValue
        self.lrWindowOpen = json["lrWindowOpen"].intValue
        self.rrWindowOpen = json["rrWindowOpen"].intValue
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "soc": soc,
            "acOnMile": acOnMile,
            "mainLockStatus": mainLockStatus,
            "acStatus": acStatus,
            "chgStatus": chgStatus,
            "quickChgLeftTime": quickChgLeftTime,
            "temperatureInCar": temperatureInCar,
            "lfWindowOpen": lfWindowOpen,
            "rfWindowOpen": rfWindowOpen,
            "lrWindowOpen": lrWindowOpen,
            "rrWindowOpen": rrWindowOpen,
            "lastUpdated": Date().timeIntervalSince1970
        ]
    }
}
