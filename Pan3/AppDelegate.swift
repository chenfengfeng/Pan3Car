// __CLOSE_PRINT__
//
//  AppDelegate.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import UIKit
import CoreData
import WidgetKit
import AppIntents
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化Core Data + CloudKit
        _ = CoreDataManager.shared
        print("[AppDelegate] Core Data + CloudKit 初始化完成")
        
        // 在Debug模式下运行Core Data测试
        #if DEBUG
        DispatchQueue.global(qos: .background).async {
            CoreDataMigrationTest.testBasicOperations()
            CoreDataMigrationTest.testCloudKitSync()
            CoreDataMigrationTest.testModelCompatibility()
        }
        #endif
        
        // 检查用户登录状态
        if UserManager.shared.isLoggedIn {
            // 已登录，跳转到主界面
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let mainViewController = mainStoryboard.instantiateInitialViewController()
            window?.rootViewController = mainViewController
            
            // 从App Groups加载最新的车辆数据（如果存在）
            // 这确保了通过小组件启动APP时能获取到最新的车辆状态
            if let savedCarModel = UserManager.shared.loadCarModelFromAppGroups() {
                UserManager.shared.updateCarInfo(with: savedCarModel)
                print("[AppDelegate] 已从App Groups恢复车辆数据")
            } else {
                print("[AppDelegate] 未找到App Groups中的车辆数据")
            }
            // 检查是否是通过推送通知启动的APP
            if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
                print("APP通过推送通知启动，处理推送数据...")
                // 延迟处理推送通知，确保APP完全初始化
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.handlePushNotificationUpdate(userInfo: remoteNotification)
                }
            }
        } else {
            // 未登录，显示登录界面
            let loginViewController = LoginViewController()
            let navigationController = UINavigationController(rootViewController: loginViewController)
            window?.rootViewController = navigationController
        }
        
        window?.makeKeyAndVisible()
        UIControl.swizzleSendAction()
        IQKeyboardManager.shared.isEnabled = true
        QMUIConsole.sharedInstance().canShow = false
        IQKeyboardToolbarManager.shared.isEnabled = true
        LiveActivityManager.shared.cleanupAllActivities()
        
        // 检查并重新加载充电实时活动
        checkForPendingTripLiveActivity()
        checkForPendingChargeLiveActivity()
        
        // 当获取到apns的token，发送到服务器
        LiveActivityManager.shared.onPushTokenReceived = { token, type in
            print("收到推送 token：\(token)，类型：\(type.rawValue)")
            self.updateLiveActivityToken(token, type: type)
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
    
    func applicationWillTerminate(_ application: UIApplication) {
        // 应用即将终止时保存Core Data上下文
        CoreDataManager.shared.saveContext()
        print("[AppDelegate] 应用终止前已保存Core Data上下文")
    }
    
    private func updateLiveActivityToken(_ token: String, type: LiveActivityType) {
        NetworkManager.shared.updateLiveActivityToken(token, type: type.rawValue) { result in
            switch result {
            case .success(_):
                print("token更新成功，类型：\(type.rawValue)")
            default:
                break
            }
        }
    }
    
    // MARK: - 充电实时活动检查
    /// 检查是否有待恢复的充电实时活动
    private func checkForPendingChargeLiveActivity() {
        let defaults = UserDefaults.standard
        
        // 检查是否有保存的充电实时活动数据
        guard let liveActivityData = defaults.object(forKey: "ChargeLiveActivityData") as? [String: Any] else {
            print("[AppDelegate] 没有找到待恢复的充电实时活动")
            return
        }
        
        print("[AppDelegate] 发现待恢复的充电实时活动，准备重新启动...")
        
        // 提取保存的数据
        guard let startKm = liveActivityData["startKm"] as? Int,
              let endKm = liveActivityData["endKm"] as? Int,
              let initialSoc = liveActivityData["initialSoc"] as? Int,
              let currentKm = liveActivityData["currentKm"] as? Int,
              let currentSoc = liveActivityData["currentSoc"] as? Int,
              let chargeProgress = liveActivityData["chargeProgress"] as? Int,
              let message = liveActivityData["message"] as? String else {
            print("[AppDelegate] 充电实时活动数据格式不正确")
            return
        }
        
        // 重新创建 ChargeAttributes
        let attributes = ChargeAttributes(
            startKm: startKm,
            endKm: endKm,
            initialSoc: initialSoc
        )
        
        // 重新创建当前状态
        let currentState = ChargeAttributes.ContentState(
            currentKm: currentKm,
            currentSoc: currentSoc,
            chargeProgress: chargeProgress,
            message: message
        )
        
        // 使用 LiveActivityManager 重新启动充电实时活动
        LiveActivityManager.shared.startChargeActivity(attributes: attributes, initialState: currentState)
        
        print("[AppDelegate] 充电实时活动已重新启动，token将自动刷新")
    }
    
    /// 检查并重新加载行程实时活动
    private func checkForPendingTripLiveActivity() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("无法访问App Groups")
            return
        }
        
        // 检查是否有保存的行程实时活动数据
        guard let tripData = groupDefaults.object(forKey: "TripLiveActivityData") as? [String: Any] else {
            print("未找到保存的行程实时活动数据")
            return
        }
        
        print("发现保存的行程实时活动数据，准备重新启动...")
        
        // 提取必要的数据
        guard let attributesDict = tripData["attributes"] as? [String: Any],
              let initialStateDict = tripData["initialState"] as? [String: Any] else {
            print("行程实时活动数据格式不正确")
            return
        }
        
        // 重新创建TripAttributes
        let departureTime = Date(timeIntervalSince1970: attributesDict["departureTime"] as? TimeInterval ?? Date().timeIntervalSince1970)
        let attributes = TripAttributes(
            departureTime: departureTime,
            totalMileageAtStart: attributesDict["totalMileageAtStart"] as? Double ?? 0.0
        )
        
        // 重新创建ContentState
        let initialState = TripAttributes.ContentState(
            actualMileage: initialStateDict["actualMileage"] as? Double ?? 0.0,
            consumedMileage: initialStateDict["consumedMileage"] as? Double ?? 0.0,
            isDriving: initialStateDict["isDriving"] as? Bool ?? true
        )
        
        // 使用LiveActivityManager重新启动实时活动
        LiveActivityManager.shared.startTripActivity(
            attributes: attributes,
            initialState: initialState
        )
        
        print("行程实时活动已重新启动")
    }
    
    // MARK: - 充电任务推送处理
    
    /// 处理充电任务相关的推送通知
    private func handleChargeTaskPushNotification(operationType: String) {
        print("处理充电任务推送通知 - 操作类型: \(operationType)")
        
        if operationType == "time_task_ended" || operationType == "range_task_ended" {
            let defaults = UserDefaults.standard
            // 清除实时活动数据
            defaults.removeObject(forKey: "ChargeLiveActivityData")
            defaults.synchronize()
            
            // 停止实时活动
            LiveActivityManager.shared.closeChargeActivity()
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
        if let operationType = pushData["operation_type"] as? String {
            handleChargeTaskPushNotification(operationType: operationType)
        }
        
        if let car_data = pushData["car_data"] as? [String: Any] {
            // 更新UserManager中的车辆信息
            UserManager.shared.updateCarInfo(from: car_data)
            // 刷新小组件
            WidgetCenter.shared.reloadAllTimelines()
        }
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
        if let operationType = pushData["operation_type"] as? String {
            handleChargeTaskPushNotification(operationType: operationType)
        }
        
        if let car_data = pushData["car_data"] as? [String: Any] {
            // 更新UserManager中的车辆信息
            UserManager.shared.updateCarInfo(from: car_data)
            // 刷新小组件
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        completion(.newData)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // 1. 苹果返回的deviceToken是Data类型，我们需要将它转换成十六进制字符串，才能发送给服务器
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        print("✅ 成功获取到APNs设备Token: \(tokenString)")
        
        // 2. 在这里，将获取到的tokenString保存到App Groups，以便小组件和Watch应用也能访问
        UserDefaults.standard.set(tokenString, forKey: "pushToken")
        UserDefaults.standard.synchronize()
        if let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
            groupDefaults.set(tokenString, forKey: "pushToken")
            groupDefaults.synchronize()
            print("✅ 推送token已保存到App Groups: \(tokenString)")
        } else {
            print("❌ 无法访问App Groups，推送token保存失败")
        }
    }
    
    // MARK: - URL Scheme 处理
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("收到URL Scheme: \(url)")
        
        // 检查是否是我们的 pan3 scheme
        guard url.scheme == "pan3" else {
            return false
        }
        
        // 解析 action 参数
        let action = url.host ?? ""
        print("解析到的action: \(action)")
        
        // 延迟处理，确保APP完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleWidgetAction(action)
        }
        
        return true
    }
    
    private func handleWidgetAction(_ action: String) {
        // 确保用户已登录
        guard UserManager.shared.isLoggedIn else {
            print("用户未登录，无法处理小组件操作")
            return
        }
        
        // 获取当前的根视图控制器
        guard let rootViewController = window?.rootViewController else {
            print("无法获取根视图控制器")
            return
        }
        
        // 查找 HomeViewController
        var homeViewController: HomeViewController?
        
        if let tabBarController = rootViewController as? UITabBarController {
            // 如果是 TabBarController，查找其中的 HomeViewController
            for viewController in tabBarController.viewControllers ?? [] {
                if let navController = viewController as? UINavigationController {
                    if let homeVC = navController.viewControllers.first as? HomeViewController {
                        homeViewController = homeVC
                        break
                    }
                } else if let homeVC = viewController as? HomeViewController {
                    homeViewController = homeVC
                    break
                }
            }
        } else if let navController = rootViewController as? UINavigationController {
            // 如果是 NavigationController，查找其中的 HomeViewController
            if let homeVC = navController.viewControllers.first as? HomeViewController {
                homeViewController = homeVC
            }
        } else if let homeVC = rootViewController as? HomeViewController {
            // 直接是 HomeViewController
            homeViewController = homeVC
        }
        
        // 如果找到了 HomeViewController，处理对应的操作
        if let homeVC = homeViewController {
            homeVC.handleWidgetAction(action)
        } else {
            print("未找到 HomeViewController，无法处理小组件操作")
        }
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
    
    // 当用户点击推送通知时调用（APP被杀死或在后台时）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("用户点击了推送通知: \(response.notification.request.content.userInfo)")
        
        // 处理推送数据更新
        handlePushNotificationUpdate(userInfo: response.notification.request.content.userInfo)
        
        completionHandler()
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
