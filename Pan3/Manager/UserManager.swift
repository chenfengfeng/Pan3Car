//
//  UserManager.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import WatchConnectivity
import SwiftyJSON
import WidgetKit

class UserManager {
    static let shared = UserManager()
    
    private init() {
        loadUserData()
    }
    
    // MARK: - 数据持久化键值
    private let authResponseKey = "saved_auth_response"
    private let firstChargeAgreementKey = "first_charge_agreement_accepted"
    
    // MARK: - 私有存储变量
    private var _authResponse: AuthResponseModel?
    
    // MARK: - 认证响应信息
    var authResponse: AuthResponseModel? {
        get { return _authResponse }
        set {
            _authResponse = newValue
            // 认证信息变化时保存到本地
            saveAuthResponse()
        }
    }
    
    // MARK: - 车辆信息（从认证响应中获取）
    var carModel: SharedCarModel? {
        return authResponse?.data.info
    }
    
    // MARK: - 用户信息（从认证响应中获取）
    var userInfo: AuthUserModel? {
        return authResponse?.data.user
    }
    
    // MARK: - 便捷访问属性
    
    /// 当前用户的timaToken
    var timaToken: String? {
        return authResponse?.data.token
    }
    
    /// 默认车辆的VIN码
    var defaultVin: String? {
        return authResponse?.data.vin
    }
    
    /// 用户编号
    var no: String? {
        return authResponse?.data.user.no
    }
    
    // MARK: - 数据持久化方法
    
    /// 保存认证响应到本地
    private func saveAuthResponse() {
        if let authResponse = authResponse {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(authResponse) {
                UserDefaults.standard.set(encoded, forKey: authResponseKey)
                
                // 同时保存到App Groups供Intent Extension使用
                if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                    sharedDefaults.set(authResponse.data.token, forKey: "timaToken")
                    sharedDefaults.set(authResponse.data.vin, forKey: "defaultVin")
                    sharedDefaults.synchronize()
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: authResponseKey)
            
            // 清除App Groups中的数据
            if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                sharedDefaults.removeObject(forKey: "timaToken")
                sharedDefaults.removeObject(forKey: "defaultVin")
                sharedDefaults.removeObject(forKey: "carInfo")
                sharedDefaults.synchronize()
            }
            
            // 清除Watch端的认证数据
            WatchConnectivityManager.shared.clearWatchAuthData()
        }
    }
    
    
    /// 从本地加载用户数据
    private func loadUserData() {
        let decoder = JSONDecoder()
        
        // 加载认证响应信息（直接赋值给私有变量，避免触发didSet）
        if let savedAuthData = UserDefaults.standard.data(forKey: authResponseKey),
           let loadedAuthResponse = try? decoder.decode(AuthResponseModel.self, from: savedAuthData) {
            _authResponse = loadedAuthResponse
        }
    }
    
    /// 获取保存的账户密码
    var savedCredentials: (phone: String, password: String)? {
        let userDefaults = UserDefaults.standard
        guard let phone = userDefaults.string(forKey: "saved_phone"),
              let password = userDefaults.string(forKey: "saved_password") else {
            return nil
        }
        return (phone, password)
    }
    
    // MARK: - 清空数据
    func clearUserData() {
        _authResponse = nil
        
        // 清空本地存储
        UserDefaults.standard.removeObject(forKey: authResponseKey)
        
        // 清除App Groups中的数据
        if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
            sharedDefaults.removeObject(forKey: "timaToken")
            sharedDefaults.removeObject(forKey: "defaultVin")
            sharedDefaults.removeObject(forKey: "carInfo")
            sharedDefaults.synchronize()
        }
    }
    
    // MARK: - 检查登录状态
    var isLoggedIn: Bool {
        return authResponse != nil
    }
    
    // MARK: - 首次充电协议
    /// 检查用户是否已同意充电协议
    var hasAcceptedChargeAgreement: Bool {
        return UserDefaults.standard.bool(forKey: firstChargeAgreementKey)
    }
    
    /// 标记用户已同意充电协议
    func markChargeAgreementAccepted() {
        UserDefaults.standard.set(true, forKey: firstChargeAgreementKey)
    }
    
    // MARK: - 更新车辆信息
    /// 更新车辆信息（从服务器获取最新数据后调用）
    func updateCarInfo(with newCarModel: SharedCarModel) {
        guard var currentAuth = authResponse else { return }
        
        // 更新认证响应中的车辆信息
        currentAuth.data.info = newCarModel
        
        // 直接赋值给私有变量，避免触发didSet
        _authResponse = currentAuth
        
        // 手动保存到本地
        saveAuthResponse()
        
        // 保存完整的CarModel数据到App Groups供小组件使用
        saveCarModelToAppGroups(newCarModel)
        
        // 设置本地修改标记，供小组件检测
        setLocalModificationFlag()
        
        // 刷新小组件
        WidgetCenter.shared.reloadAllTimelines()
        
        // 发送认证数据到Watch
        WatchConnectivityManager.shared.sendAuthDataToWatch(
            token: timaToken,
            vin: defaultVin
        )
        
        // 发送SharedCarModel数据到Watch
        WatchConnectivityManager.shared.sendSharedCarModelToWatch(newCarModel)
    }
    
    /// 更新车辆信息 - 重载方法，接受推送数据字典参数
    func updateCarInfo(from pushData: [String: Any]) {
        // 从推送数据创建新的CarModel
        let json = JSON(pushData)
        let newCarModel = SharedCarModel(json: json)
        
        // 调用原有的更新方法
        updateCarInfo(with: newCarModel)
        
        // 发送通知更新UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .carDataDidUpdate, object: nil)
        }
    }
    
    /// 将CarModel数据保存到App Groups供小组件使用
    private func saveCarModelToAppGroups(_ carModel: SharedCarModel) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[UserManager] 无法访问App Groups")
            return
        }
        
        // 将CarModel转换为字典并保存
        let carModelDict = carModel.toDictionary()
        userDefaults.set(carModelDict, forKey: "CarModelData")
        
        print("[UserManager] 已保存完整CarModel数据到App Groups")
    }
    
    /// 从App Groups读取CarModel数据
    /// 用于APP冷启动时恢复最新的车辆数据
    func loadCarModelFromAppGroups() -> SharedCarModel? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[UserManager] 无法访问App Groups")
            return nil
        }
        
        guard let carModelDict = userDefaults.object(forKey: "CarModelData") as? [String: Any] else {
            print("[UserManager] 未找到App Groups中的CarModel数据")
            return nil
        }
        
        // 使用新的便利构造器从字典创建CarModel
        guard let carModel = SharedCarModel(dictionary: carModelDict) else {
            print("[UserManager] 从App Groups数据创建CarModel失败")
            return nil
        }
        
        print("[UserManager] 成功从App Groups加载CarModel数据")
        return carModel
    }
    
    /// 设置本地修改标记，供小组件检测最近的数据更新
    private func setLocalModificationFlag() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[UserManager] 无法访问App Groups设置本地修改标记")
            return
        }
        
        userDefaults.set(true, forKey: "widgetLocalModification")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "widgetLocalModificationTime")
        userDefaults.synchronize()
        
        print("[UserManager] 已设置本地修改标记，时间: \(Date())")
    }
}
