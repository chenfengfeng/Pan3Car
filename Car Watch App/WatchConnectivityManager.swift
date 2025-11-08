import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isConnected = false
    @Published var lastUpdateTime: Date?
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    /// 保存认证数据到App Groups
    private func saveAuthDataToAppGroups(timaToken: String?, defaultVin: String?, presetTemperature: Int?) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return
        }
        
        if let token = timaToken {
            userDefaults.set(token, forKey: "timaToken")
            print("[Watch] 已保存timaToken到App Groups")
        }
        
        if let vin = defaultVin {
            userDefaults.set(vin, forKey: "defaultVin")
            print("[Watch] 已保存defaultVin到App Groups")
        }
        
        if let temperature = presetTemperature {
            userDefaults.set(temperature, forKey: "PresetTemperature")
            print("[Watch] 已保存PresetTemperature到App Groups: \(temperature)°C")
        }
        
        userDefaults.synchronize()
    }
    
    /// 保存SharedCarModel数据到App Groups
    private func saveSharedCarModelToAppGroups(_ carModelDict: [String: Any]) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return
        }
        
        // 保存完整的SharedCarModel数据
        userDefaults.set(carModelDict, forKey: "SharedCarModelData")
        
        // 保存时间戳
        userDefaults.set(Date().timeIntervalSince1970, forKey: "SharedCarModelLastUpdate")
        
        userDefaults.synchronize()
        
        print("[Watch] 已保存SharedCarModel数据到App Groups")
        
        // 更新UI - 确保在主线程更新
        DispatchQueue.main.async {
            self.lastUpdateTime = Date()
            print("[Watch Debug] 已更新lastUpdateTime，触发UI刷新")
            
            // 发送通知，确保UI能够响应
            NotificationCenter.default.post(name: NSNotification.Name("WatchCarDataDidUpdate"), object: nil)
        }
    }
    
    /// 从App Groups读取SharedCarModel数据
    func loadSharedCarModelFromAppGroups() -> SharedCarModel? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return nil
        }
        
        guard let carModelDict = userDefaults.object(forKey: "SharedCarModelData") as? [String: Any] else {
            print("[Watch] 未找到App Groups中的SharedCarModel数据")
            return nil
        }
        
        // 使用SharedCarModel的字典构造器
        guard let carModel = SharedCarModel(dictionary: carModelDict) else {
            print("[Watch] 从App Groups数据创建SharedCarModel失败")
            return nil
        }
        
        print("[Watch] 成功从App Groups加载SharedCarModel数据")
        return carModel
    }
    
    /// 获取最后更新时间
    func getLastUpdateTime() -> Date? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            return nil
        }
        
        let timestamp = userDefaults.double(forKey: "SharedCarModelLastUpdate")
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    /// 从App Groups获取当前的timaToken
    func getCurrentToken() -> String? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return nil
        }
        return userDefaults.string(forKey: "timaToken")
    }
    
    /// 从App Groups获取当前的defaultVin
    func getCurrentVin() -> String? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return nil
        }
        return userDefaults.string(forKey: "defaultVin")
    }
    
    /// 向iOS端请求认证数据
    func requestAuthDataFromiOS() {
        guard WCSession.default.activationState == .activated else {
            print("[Watch] WCSession未激活，无法请求认证数据")
            return
        }
        
        let message = ["action": "requestAuthData"]
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("[Watch] 收到iOS响应: \(reply)")
            
            // 处理返回的认证数据
            DispatchQueue.main.async {
                let timaToken = reply["timaToken"] as? String
                let defaultVin = reply["defaultVin"] as? String
                let presetTemperature = reply["PresetTemperature"] as? Int
                
                self.saveAuthDataToAppGroups(timaToken: timaToken, defaultVin: defaultVin, presetTemperature: presetTemperature)
            }
        }, errorHandler: { error in
            print("[Watch] 请求认证数据失败: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
        
        if let error = error {
            print("[Watch] WCSession激活失败: \(error)")
        } else {
            print("[Watch] WCSession激活成功，状态: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("[Watch] 收到Application Context: \(applicationContext.keys)")
        
        // 检查是否包含认证数据（timaToken、defaultVin、PresetTemperature）
        if applicationContext["timaToken"] != nil || applicationContext["defaultVin"] != nil || applicationContext["PresetTemperature"] != nil {
            let timaToken = applicationContext["timaToken"] as? String
            let defaultVin = applicationContext["defaultVin"] as? String
            let presetTemperature = applicationContext["PresetTemperature"] as? Int
            saveAuthDataToAppGroups(timaToken: timaToken, defaultVin: defaultVin, presetTemperature: presetTemperature)
        }
        
        // 检查是否是SharedCarModel数据
        if let type = applicationContext["type"] as? String, type == "sharedCarModel" {
            // 移除元数据，保留车辆数据
            var carModelDict = applicationContext
            carModelDict.removeValue(forKey: "type")
            carModelDict.removeValue(forKey: "timestamp")
            
            saveSharedCarModelToAppGroups(carModelDict)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("[Watch] 收到User Info: \(userInfo.keys)")
        
        // 检查是否包含认证数据（timaToken、defaultVin、PresetTemperature）
        if userInfo["timaToken"] != nil || userInfo["defaultVin"] != nil || userInfo["PresetTemperature"] != nil {
            let timaToken = userInfo["timaToken"] as? String
            let defaultVin = userInfo["defaultVin"] as? String
            let presetTemperature = userInfo["PresetTemperature"] as? Int
            saveAuthDataToAppGroups(timaToken: timaToken, defaultVin: defaultVin, presetTemperature: presetTemperature)
        }
        
        // 检查是否是SharedCarModel数据
        if let type = userInfo["type"] as? String, type == "sharedCarModel" {
            // 移除元数据，保留车辆数据
            var carModelDict = userInfo
            carModelDict.removeValue(forKey: "type")
            carModelDict.removeValue(forKey: "timestamp")
            
            saveSharedCarModelToAppGroups(carModelDict)
        }
    }
}