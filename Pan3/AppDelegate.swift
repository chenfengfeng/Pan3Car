// __CLOSE_PRINT__
//
//  AppDelegate.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import GRDB
import UIKit
import QMUIKit
import WidgetKit
import AppIntents
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // 检查用户登录状态
        if UserManager.shared.isLoggedIn {
            // 已登录，跳转到主界面
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let mainViewController = mainStoryboard.instantiateInitialViewController()
            window?.rootViewController = mainViewController
        } else {
            // 未登录，显示登录界面
            let loginViewController = LoginViewController()
            let navigationController = UINavigationController(rootViewController: loginViewController)
            window?.rootViewController = navigationController
        }
        // 在 App 启动时，调用数据库设置方法
        do {
            try AppDatabase.setup(for: application)
        } catch {
            // 如果数据库初始化失败，这是一个严重错误，您可以在这里记录日志或提示用户
            fatalError("数据库初始化失败: \(error)")
        }
        
        window?.makeKeyAndVisible()
        UIControl.swizzleSendAction()
        IQKeyboardManager.shared.isEnabled = true
        QMUIConsole.sharedInstance().canShow = false
        IQKeyboardToolbarManager.shared.isEnabled = true
        LiveActivityManager.shared.cleanupAllActivities()
        
        // 当获取到apns的token，发送到服务器
        LiveActivityManager.shared.onPushTokenReceived = { token in
            print("收到推送 token：\(token)")
            self.updateLiveActivityToken(token)
        }
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("推送权限请求完成。用户是否同意: \(granted)")
            
            if granted {
                // 如果用户同意，就执行第二步
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        return true
    }
    
    private func updateLiveActivityToken(_ token: String) {
        NetworkManager.shared.updateLiveActivityToken(newToken: token) { result in
            switch result {
            case .success(_):
                print("token更新成功")
            default:
                break
            }
        }
    }
    
    // MARK: - 充电任务推送处理
    
    /// 处理充电任务相关的推送通知
    private func handleChargeTaskPushNotification(extData: [String: Any], operationType: String) {
        print("处理充电任务推送通知 - 操作类型: \(operationType)")
        print("推送ext数据: \(extData)")
        
        guard let vin = extData["vin"] as? String,
              let status = extData["status"] as? String else {
            print("充电任务推送数据格式错误，缺少必要字段")
            return
        }
        
        // 发送通知给ChargeViewController处理数据库更新
        let userInfo: [String: Any] = [
            "vin": vin,
            "status": status,
            "operationType": operationType,
            "extData": extData
        ]
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ChargeTaskPushReceived"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        // 根据操作类型处理不同的逻辑
        switch operationType {
        case "charge_task_completed":
            print("充电任务完成 - VIN: \(vin)")
            // 清理相关的Live Activity
            LiveActivityManager.shared.cleanupActivitiesForVin(vin)
            
        case "charge_task_failed":
            print("充电任务失败 - VIN: \(vin)")
            // 清理相关的Live Activity
            LiveActivityManager.shared.cleanupActivitiesForVin(vin)
            
        case "charge_task_cancelled":
            print("充电任务取消 - VIN: \(vin)")
            // 清理相关的Live Activity
            LiveActivityManager.shared.cleanupActivitiesForVin(vin)
            
        default:
            print("未知的充电任务操作类型: \(operationType)")
        }
    }
    
    // MARK: - 推送数据更新处理
    
    /// 处理推送数据更新 - 前台版本
    private func handlePushNotificationUpdate(userInfo: [AnyHashable: Any]) {
        print("处理前台推送数据更新")
        
        // 将推送数据转换为字符串键的字典
        let pushData = userInfo.reduce(into: [String: Any]()) { result, element in
            if let key = element.key as? String {
                result[key] = element.value
            }
        }
        
        // 检查是否包含充电任务相关的ext信息
        if let extData = pushData["ext"] as? [String: Any],
           let operationType = pushData["operation_type"] as? String {
            handleChargeTaskPushNotification(extData: extData, operationType: operationType)
        }
        
        // 更新UserManager中的车辆信息
        UserManager.shared.updateCarInfo(from: pushData)
        
        // 刷新小组件
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 处理推送数据更新 - 后台版本
    private func handlePushNotificationUpdate(userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("处理后台推送数据更新")
        
        // 将推送数据转换为字符串键的字典
        let pushData = userInfo.reduce(into: [String: Any]()) { result, element in
            if let key = element.key as? String {
                result[key] = element.value
            }
        }
        
        // 检查是否包含充电任务相关的ext信息
        if let extData = pushData["ext"] as? [String: Any],
           let operationType = pushData["operationType"] as? String {
            handleChargeTaskPushNotification(extData: extData, operationType: operationType)
        }
        
        // 更新UserManager中的车辆信息
        UserManager.shared.updateCarInfo(from: pushData)
        
        // 刷新小组件
        WidgetCenter.shared.reloadAllTimelines()
        
        completion(.newData)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // 1. 苹果返回的deviceToken是Data类型，我们需要将它转换成十六进制字符串，才能发送给服务器
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        print("✅ 成功获取到APNs设备Token: \(tokenString)")
        
        // 2. 在这里，将获取到的tokenString保存起来，以备后用
        UserDefaults.standard.set(tokenString, forKey: "pushToken")
        UserDefaults.standard.synchronize()
    }
}

extension UIControl {
    static func swizzleSendAction() {
        let originalSelector = #selector(UIControl.sendAction(_:to:for:))
        let swizzledSelector = #selector(UIControl.swizzled_sendAction(_:to:for:))
        
        guard
            let originalMethod = class_getInstanceMethod(UIControl.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIControl.self, swizzledSelector)
        else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc private func swizzled_sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        // 仅对 UIButton 或其子类生效
        if self is UIButton {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        
        // 调用原始实现（现在是 swizzled_sendAction）
        swizzled_sendAction(action, to: target, for: event)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // 这个方法只会在App处于前台时，收到推送通知时被调用
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("App在前台收到了推送: \(notification.request.content.userInfo)")
        
        // 处理推送数据更新
        handlePushNotificationUpdate(userInfo: notification.request.content.userInfo)
        
        completionHandler([.banner, .sound])
    }
    
    /**
     * 当App收到远程推送通知时（无论在前台还是后台），此方法都会被调用
     * 特别是对于包含 "content-available": 1 的推送，它会在后台唤醒App并执行
     */
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("App在后台收到推送并被唤醒，准备执行后台任务...")
        print("收到的推送内容: \(userInfo)")
        
        // 处理推送数据更新
        handlePushNotificationUpdate(userInfo: userInfo) { result in
            // 任务完成后，必须调用completionHandler，告知系统后台任务的结果
            // .newData: 表示您成功获取到了新数据
            // .noData: 表示本次没有新数据
            // .failed: 表示获取数据失败
            // 这有助于系统智能地调度您App的后台活动，节约电量
            completionHandler(result)
        }
    }
}
