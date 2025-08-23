//
//  WatchConnectivityManager.swift
//  Car Watch App
//
//  Created by Feng on 2025/1/18.
//

import Foundation
import WatchConnectivity

// 定义通知名称
extension Notification.Name {
    static let authDataUpdated = Notification.Name("authDataUpdated")
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isConnected = false
    @Published var timaToken: String?
    @Published var defaultVin: String?
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        
        // 从UserDefaults加载已保存的数据
        loadSavedAuthData()
    }
    
    // MARK: - 数据持久化
    
    /// 从UserDefaults加载已保存的认证数据
    private func loadSavedAuthData() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        
        // 从App Group读取
        timaToken = sharedDefaults?.string(forKey: "timaToken")
        defaultVin = sharedDefaults?.string(forKey: "defaultVin")
        
        print("[Watch Debug] 加载已保存的认证数据:")
        print("  - Token: \(timaToken ?? "nil")")
        print("  - VIN: \(defaultVin ?? "nil")")
    }
    
    /// 保存认证数据到UserDefaults
    private func saveAuthData(token: String?, vin: String?) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        
        if let token = token {
            sharedDefaults?.set(token, forKey: "timaToken")
            self.timaToken = token
        } else {
            sharedDefaults?.removeObject(forKey: "timaToken")
            self.timaToken = nil
        }
        
        if let vin = vin {
            sharedDefaults?.set(vin, forKey: "defaultVin")
            self.defaultVin = vin
        } else {
            sharedDefaults?.removeObject(forKey: "defaultVin")
            self.defaultVin = nil
        }
        
        sharedDefaults?.synchronize()
        
        print("[Watch Debug] 保存认证数据到共享UserDefaults:")
        print("  - Token: \(token ?? "nil")")
        print("  - VIN: \(vin ?? "nil")")
    }
    
    /// 清除认证数据
    private func clearAuthData() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        
        // 清除App Group中的数据
        sharedDefaults?.removeObject(forKey: "timaToken")
        sharedDefaults?.removeObject(forKey: "defaultVin")
        sharedDefaults?.synchronize()
        
        DispatchQueue.main.async {
            self.timaToken = nil
            self.defaultVin = nil
        }
        
        print("[Watch Debug] 已清除App Group中的认证数据")
    }
    
    // MARK: - 公共方法
    
    /// 检查是否有有效的认证数据
    var hasValidAuthData: Bool {
        return timaToken != nil && defaultVin != nil
    }
    
    /// 请求iPhone端发送最新的认证数据
    func requestAuthDataFromPhone() {
        guard WCSession.default.isReachable else {
            print("[Watch Debug] iPhone不可达，无法请求认证数据")
            return
        }
        
        let message = ["action": "requestAuthData"]
        
        WCSession.default.sendMessage(message) { reply in
            DispatchQueue.main.async {
                print("[Watch Debug] 收到iPhone回复: \(reply)")
                
                if let token = reply["timaToken"] as? String,
                   let vin = reply["defaultVin"] as? String {
                    self.saveAuthData(token: token, vin: vin)
                }
            }
        } errorHandler: { error in
            print("[Watch Debug] 请求认证数据失败: \(error)")
        }
    }
    
    /// 获取当前的token（优先从内存，其次从UserDefaults）
    func getCurrentToken() -> String? {
        if let token = timaToken {
            return token
        }
        
        // 如果内存中没有，尝试从UserDefaults重新加载
        loadSavedAuthData()
        return timaToken
    }
    
    /// 获取当前的VIN（优先从内存，其次从UserDefaults）
    func getCurrentVin() -> String? {
        if let vin = defaultVin {
            return vin
        }
        
        // 如果内存中没有，尝试从UserDefaults重新加载
        loadSavedAuthData()
        return defaultVin
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated)
            
            if let error = error {
                print("[Watch Debug] WatchConnectivity激活失败: \(error)")
            } else {
                print("[Watch Debug] WatchConnectivity激活成功，状态: \(activationState.rawValue)")
                print("[Watch Debug] iPhone可达: \(session.isReachable)")
                
                // 激活成功后，如果没有认证数据，尝试从iPhone获取
                if !self.hasValidAuthData && session.isReachable {
                    self.requestAuthDataFromPhone()
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("[Watch Debug] iPhone可达性改变: \(session.isReachable)")
            
            // 当iPhone变为可达时，如果没有认证数据，尝试获取
            if session.isReachable && !self.hasValidAuthData {
                self.requestAuthDataFromPhone()
            }
        }
    }
    
    // MARK: - 接收iPhone端数据
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch Debug] 收到iPhone应用上下文: \(applicationContext)")
            
            // 检查是否是清除操作
            if let action = applicationContext["action"] as? String, action == "clear" {
                self.clearAuthData()
                return
            }
            
            // 处理认证数据更新
            var token: String?
            var vin: String?
            
            if let receivedToken = applicationContext["timaToken"] {
                if receivedToken is NSNull {
                    token = nil
                } else {
                    token = receivedToken as? String
                }
            }
            
            if let receivedVin = applicationContext["defaultVin"] {
                if receivedVin is NSNull {
                    vin = nil
                } else {
                    vin = receivedVin as? String
                }
            }
            
            // 只有当数据发生变化时才保存
            if token != self.timaToken || vin != self.defaultVin {
                self.saveAuthData(token: token, vin: vin)
                
                // 发送通知，通知UI刷新数据
                NotificationCenter.default.post(name: .authDataUpdated, object: nil)
                print("[Watch Debug] 已发送认证数据更新通知")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch Debug] 收到iPhone用户信息: \(userInfo)")
            
            // 处理车辆信息等其他数据
            if let type = userInfo["type"] as? String {
                switch type {
                case "carInfo":
                    // 可以在这里处理车辆信息的更新
                    print("[Watch Debug] 收到车辆信息更新")
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("[Watch Debug] 收到iPhone消息: \(message)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("[Watch Debug] 收到iPhone消息（需要回复）: \(message)")
            
            let reply: [String: Any] = [
                "status": "received",
                "hasAuthData": self.hasValidAuthData,
                "timaToken": self.timaToken ?? NSNull(),
                "defaultVin": self.defaultVin ?? NSNull()
            ]
            
            replyHandler(reply)
        }
    }
}