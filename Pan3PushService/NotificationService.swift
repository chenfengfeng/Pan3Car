//
//  NotificationService.swift
//  Pan3PushService
//
//  Created by Mac on 2025/10/19.
//

import WidgetKit
import SwiftyJSON
import ActivityKit
import UserNotifications
import WatchConnectivity

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
//        let mainLockStatus: Int = (carData["mainLockStatus"] ?? 100) as! Int
//        content.body = "车锁状态 \(mainLockStatus == 0 ? "已锁定" : "已解锁")"
        
        // 2. 保存数据到 App Groups
        saveCarDataToAppGroups(carData: carData)
        
        // 3. 刷新小组件
        refreshWidgets(content: content)
        
        // 4. 发送数据到手表
//        sendDataToWatch(carData: carData)
        
        // 5. 可选：修改通知内容
//        enhanceNotificationContent(content: content)
    }
    
    // MARK: - 提取推送数据
    private func extractCarDataFromPush(request: UNNotificationRequest) -> [String: Any]? {
        let userInfo = request.content.userInfo
        
        // 方式1：检查是否有 car_data 字段（后端新格式）
        if let carData = userInfo["car_data"] as? [String: Any] {
            print("[NotificationService] 找到 car_data 字段")
            return carData
        }
        
        // 方式2：检查是否有直接的 carData 字段（兼容旧格式）
        if let carData = userInfo["carData"] as? [String: Any] {
            print("[NotificationService] 找到 carData 字段")
            return carData
        }
        
        // 方式3：检查是否有 aps 字段中的自定义数据
        if let aps = userInfo["aps"] as? [String: Any] {
            if let carData = aps["car_data"] as? [String: Any] {
                print("[NotificationService] 在 aps 中找到 car_data 字段")
                return carData
            }
            if let carData = aps["carData"] as? [String: Any] {
                print("[NotificationService] 在 aps 中找到 carData 字段")
                return carData
            }
        }
        
        // 方式4：检查根级别的车辆状态字段
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
        
        print("[NotificationService] 开始保存车辆数据到 App Groups...")
        
        // 使用与 UserManager 相同的逻辑保存数据
        // 创建 SharedCarModel 并转换为字典格式
        let json = JSON(carData)
        let sharedCarModel = SharedCarModel(json: json)
        let carModelDict = sharedCarModel.toDictionary()
        
        // 保存完整的 SharedCarModel 数据
        userDefaults.set(carModelDict, forKey: "CarModelData")
        
        // 检测解锁汽车条件并启动实时活动
        if sharedCarModel.keyStatus == 2 && sharedCarModel.mainLockStatus == 1 {
            print("[NotificationService] 检测到解锁汽车并且车辆还没启动，启动实时活动")
            startTripLiveActivity(sharedCarModel: sharedCarModel)
        }
        
        // 设置本地修改标记，供小组件检测
        let currentTime = Date().timeIntervalSince1970
        userDefaults.set(true, forKey: "widgetLocalModification")
        userDefaults.set(currentTime, forKey: "widgetLocalModificationTime")
        
        // 添加推送数据更新标记，用于强制刷新
        userDefaults.set(true, forKey: "pushDataUpdated")
        userDefaults.set(currentTime, forKey: "pushDataUpdateTime")
        
        // 强制同步并验证数据写入
        let syncSuccess = userDefaults.synchronize()
        print("[NotificationService] 数据同步结果: \(syncSuccess)")
        
        // 验证数据是否正确保存
        if let savedData = userDefaults.object(forKey: "CarModelData") as? [String: Any] {
            print("[NotificationService] 数据保存验证成功，SOC: \(savedData["soc"] ?? "未知")")
        } else {
            print("[NotificationService] 警告：数据保存验证失败")
        }
        
        print("[NotificationService] 车辆数据保存完成，时间戳: \(currentTime)")
    }
    
    // MARK: - 刷新小组件
    private func refreshWidgets(content: UNMutableNotificationContent) {
        print("[NotificationService] 开始刷新小组件...")
        
        // 添加短暂延迟确保数据完全写入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[NotificationService] 执行小组件刷新...")
            WidgetCenter.shared.reloadAllTimelines()
            print("[NotificationService] 小组件刷新请求已发送")
            
            // 添加重试机制
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("[NotificationService] 执行小组件刷新重试...")
                WidgetCenter.shared.reloadAllTimelines()
                print("[NotificationService] 小组件刷新重试完成")
            }
        }
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
    private func enhanceNotificationContent(content: UNMutableNotificationContent) {
        // 调试标识
        content.title = "[NotificationService] 标题模式"
        
        print("[NotificationService] 已增强通知内容 - 标题: \(content.title), 内容: \(content.body)")
    }
    
    // MARK: - 启动行程实时活动
    @available(iOS 16.1, *)
    private func startTripLiveActivity(sharedCarModel: SharedCarModel) {
        // 创建 TripAttributes
        let attributes = TripAttributes(
            departureTime: Date(),
            totalMileageAtStart: Double(sharedCarModel.totalMileage) ?? 0.0
        )
        
        // 创建初始状态
        let initialState = TripAttributes.ContentState(
            actualMileage: 0,
            consumedMileage: 0,
            isDriving: false
        )
        
        print("[NotificationService] 启动行程实时活动 - 总里程: \(sharedCarModel.totalMileage)")
        
        // 使用 LiveActivityManager 启动行程实时活动
        LiveActivityManager.shared.startTripActivity(
            attributes: attributes,
            initialState: initialState
        )
        
        // 保存行程实时活动数据到App Groups
        saveTripLiveActivityData(
            attributes: attributes,
            initialState: initialState
        )
    }
    
    // MARK: - 保存行程实时活动数据到App Groups
    func saveTripLiveActivityData(
        attributes: TripAttributes,
        initialState: TripAttributes.ContentState
    ) {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("无法访问App Groups")
            return
        }
        
        let tripData: [String: Any] = [
            "attributes": [
                "departureTime": attributes.departureTime.timeIntervalSince1970,
                "totalMileageAtStart": attributes.totalMileageAtStart
            ],
            "initialState": [
                "actualMileage": initialState.actualMileage,
                "consumedMileage": initialState.consumedMileage,
                "isDriving": initialState.isDriving
            ],
            "createdAt": Date().timeIntervalSince1970
        ]
        
        groupDefaults.set(tripData, forKey: "TripLiveActivityData")
        groupDefaults.synchronize()
        
        print("行程实时活动数据已保存到App Groups")
    }
}
