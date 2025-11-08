//
//  WatchConnectivityManager.swift
//  Pan3
//
//  Created by Feng on 2025/1/18.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - 发送数据到Watch
    
    /// 发送用户认证信息到Watch（使用Application Context，适合最新状态覆盖）
    func sendAuthDataToWatch(token: String?, vin: String?) {
        guard WCSession.default.isReachable || WCSession.default.activationState == .activated else {
            print("[WatchConnectivity] Watch不可达或会话未激活")
            return
        }
        
        var context: [String: Any] = [:]
        
        if let token = token {
            context["timaToken"] = token
        }
        
        if let vin = vin {
            context["defaultVin"] = vin
        }
        
        // 添加shouldEnableDebug状态
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        context["shouldEnableDebug"] = shouldEnableDebug
        
        // 添加空调预设温度
        if let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
            let presetTemperature = groupDefaults.integer(forKey: "PresetTemperature")
            if presetTemperature > 0 {
                context["PresetTemperature"] = presetTemperature
            } else {
                context["PresetTemperature"] = 26 // 默认温度
            }
        }
        
        // 添加时间戳确保数据更新
        context["timestamp"] = Date().timeIntervalSince1970
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("[WatchConnectivity] 成功发送认证数据到Watch，shouldEnableDebug: \(shouldEnableDebug)")
        } catch {
            print("[WatchConnectivity] 发送认证数据失败: \(error)")
        }
    }
    
    /// 发送车辆信息到Watch（使用User Info，确保可靠传输）
    func sendCarInfoToWatch(_ carInfo: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            print("[WatchConnectivity] Watch会话未激活")
            return
        }
        
        var userInfo = carInfo
        userInfo["timestamp"] = Date().timeIntervalSince1970
        userInfo["type"] = "carInfo"
        
        WCSession.default.transferUserInfo(userInfo)
        print("[WatchConnectivity] 成功发送车辆信息到Watch")
    }
    
    /// 发送SharedCarModel到Watch（使用Application Context，适合最新状态覆盖）
    func sendSharedCarModelToWatch(_ sharedCarModel: SharedCarModel) {
        guard WCSession.default.activationState == .activated else {
            print("[WatchConnectivity] Watch会话未激活，无法发送SharedCarModel")
            return
        }
        
        // 将SharedCarModel转换为字典
        let carModelDict = sharedCarModel.toDictionary()
        var context = carModelDict
        context["timestamp"] = Date().timeIntervalSince1970
        context["type"] = "sharedCarModel"
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("[WatchConnectivity] 成功发送SharedCarModel到Watch")
        } catch {
            print("[WatchConnectivity] 发送SharedCarModel失败: \(error)")
        }
    }
    
    /// 发送SharedCarModel到Watch（使用User Info，确保可靠传输）
    func transferSharedCarModelToWatch(_ sharedCarModel: SharedCarModel) {
        guard WCSession.default.activationState == .activated else {
            print("[WatchConnectivity] Watch会话未激活，无法传输SharedCarModel")
            return
        }
        
        // 将SharedCarModel转换为字典
        let carModelDict = sharedCarModel.toDictionary()
        var userInfo = carModelDict
        userInfo["timestamp"] = Date().timeIntervalSince1970
        userInfo["type"] = "sharedCarModel"
        
        WCSession.default.transferUserInfo(userInfo)
        print("[WatchConnectivity] 成功传输SharedCarModel到Watch")
    }
    
    /// 清除Watch端的认证数据
    func clearWatchAuthData() {
        let context: [String: Any] = [
            "timaToken": NSNull(),
            "defaultVin": NSNull(),
            "timestamp": Date().timeIntervalSince1970,
            "action": "clear"
        ]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("[WatchConnectivity] 成功清除Watch端认证数据")
        } catch {
            print("[WatchConnectivity] 清除Watch端认证数据失败: \(error)")
        }
    }
    
    // MARK: - 会话状态检查
    
    var isWatchAppInstalled: Bool {
        return WCSession.default.isWatchAppInstalled
    }
    
    var isWatchReachable: Bool {
        return WCSession.default.isReachable
    }
    
    var sessionActivationState: WCSessionActivationState {
        return WCSession.default.activationState
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("[WatchConnectivity] 会话激活失败: \(error)")
            } else {
                print("[WatchConnectivity] 会话激活成功，状态: \(activationState.rawValue)")
                print("[WatchConnectivity] Watch应用已安装: \(session.isWatchAppInstalled)")
                print("[WatchConnectivity] Watch可达: \(session.isReachable)")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchConnectivity] 会话变为非活跃状态")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchConnectivity] 会话已停用")
        // 重新激活会话
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("[WatchConnectivity] Watch状态改变:")
            print("  - Watch应用已安装: \(session.isWatchAppInstalled)")
            print("  - Watch可达: \(session.isReachable)")
        }
    }
    
    // MARK: - 接收Watch端消息
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("[WatchConnectivity] 收到Watch消息: \(message)")
            
            // 处理Watch端的请求
            if let action = message["action"] as? String {
                switch action {
                case "requestAuthData":
                    // Watch请求最新的认证数据
                    if let userManager = UserManager.shared as? UserManager,
                       let token = userManager.timaToken,
                       let vin = userManager.defaultVin {
                        self.sendAuthDataToWatch(token: token, vin: vin)
                    }
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("[WatchConnectivity] 收到Watch消息（需要回复）: \(message)")
            
            var reply: [String: Any] = ["status": "received"]
            
            if let action = message["action"] as? String {
                switch action {
                case "requestAuthData":
                    // 返回当前的认证数据
                    if let userManager = UserManager.shared as? UserManager {
                        reply["timaToken"] = userManager.timaToken ?? NSNull()
                        reply["defaultVin"] = userManager.defaultVin ?? NSNull()
                        reply["isLoggedIn"] = userManager.isLoggedIn
                        // 添加shouldEnableDebug状态
                        reply["shouldEnableDebug"] = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
                        // 添加预设温度
                        if let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                            let presetTemperature = groupDefaults.integer(forKey: "PresetTemperature")
                            reply["PresetTemperature"] = presetTemperature > 0 ? presetTemperature : 26
                        }
                    }
                default:
                    break
                }
            }
            
            replyHandler(reply)
        }
    }
}
