// __CLOSE_PRINT__
//
//  AppDelegate.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import UIKit
import QMUIKit
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
            let loginStoryboard = UIStoryboard(name: "Login", bundle: nil)
            let loginViewController = loginStoryboard.instantiateInitialViewController()
            window?.rootViewController = loginViewController
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
            self.updateChargeToken(push_token: token)
        }
        return true
    }
    
    private func updateChargeToken(push_token: String) {
        NetworkManager.shared.updateChargeTask(push_token: push_token) { result in
            switch result {
            case .success(_):
                print("token更新成功")
            default:
                break
            }
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
