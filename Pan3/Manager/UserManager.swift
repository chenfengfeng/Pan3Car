//
//  UserManager.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import WatchConnectivity
import SwiftyJSON

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
    var carModel: CarModel? {
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
    func updateCarInfo(with newCarModel: CarModel) {
        guard var currentAuth = authResponse else { return }
        
        // 更新认证响应中的车辆信息
        currentAuth.data.info = newCarModel
        
        // 直接赋值给私有变量，避免触发didSet
        _authResponse = currentAuth
        
        // 手动保存到本地
        saveAuthResponse()
        
        // 发送认证数据到Watch
        WatchConnectivityManager.shared.sendAuthDataToWatch(
            token: timaToken,
            vin: defaultVin
        )
    }
    
    /// 更新车辆信息 - 重载方法，接受推送数据字典参数
    func updateCarInfo(from pushData: [String: Any]) {
        // 从推送数据创建新的CarModel
        let json = JSON(pushData)
        let newCarModel = CarModel(json: json)
        
        // 调用原有的更新方法
        updateCarInfo(with: newCarModel)
        
        // 发送通知更新UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .carDataDidUpdate, object: nil)
        }
    }
}
