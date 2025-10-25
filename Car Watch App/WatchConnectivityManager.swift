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
        
        // 更新UI
        DispatchQueue.main.async {
            self.lastUpdateTime = Date()
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