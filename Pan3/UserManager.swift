//
//  UserManager.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation

// 车辆信息数据结构（与Widget共享）
struct CarInfo: Codable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
    
    static let placeholder = CarInfo(
        remainingMileage: 350,
        soc: 56,
        isLocked: true,
        windowsOpen: false,
        airConditionerOn: false,
        lastUpdated: Date()
    )
}

class UserManager {
    static let shared = UserManager()
    
    private init() {
        loadUserData()
    }
    
    // MARK: - 数据持久化键值
    private let loginModelKey = "saved_login_model"
    private let userModelsKey = "saved_user_models"
    private let carModelKey = "saved_car_model"
    private let firstChargeAgreementKey = "first_charge_agreement_accepted"
    
    // MARK: - 私有存储变量
    private var _loginModel: LoginModel?
    private var _userModels: [UserModel]?
    private var _carModel: CarModel?
    
    // MARK: - 登录信息
    var loginModel: LoginModel? {
        get { return _loginModel }
        set {
            _loginModel = newValue
            // 登录信息变化时保存到本地
            saveLoginModel()
            // 登录信息变化时清空其他信息
            if newValue == nil {
                userModels = nil
                carModel = nil
            }
        }
    }
    
    // MARK: - 用户信息
    var userModels: [UserModel]? {
        get { return _userModels }
        set {
            _userModels = newValue
            saveUserModels()
        }
    }
    
    // MARK: - 车辆信息
    var carModel: CarModel? {
        get { return _carModel }
        set {
            _carModel = newValue
            saveCarModel()
        }
    }
    
    // MARK: - 便捷访问属性
    
    /// 当前用户的timaToken
    var timaToken: String? {
        return loginModel?.token
    }
    
    /// 当前用户的手机号
    var userPhone: String? {
        return loginModel?.phone
    }
    
    /// 当前用户ID
    var userId: String? {
        return String(loginModel?.id ?? 0)
    }
    
    /// TSP用户ID
    var tspUserId: String? {
        return String(loginModel?.tspid ?? 0)
    }
    
    /// AAA用户ID
    var aaaUserId: String? {
        return String(loginModel?.aaaid ?? 0)
    }
    
    /// AAA Token
    var aaaToken: String? {
        return loginModel?.aaaToken
    }
    
    /// 身份参数JSON字符串
    var identityParam: String? {
        guard let aaaToken = aaaToken,
              let tspUserId = tspUserId,
              let phone = userPhone else {
            return nil
        }
        
        let identityDict: [String: Any] = [
            "token": aaaToken,
            "userId": tspUserId,
            "phone": phone
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: identityDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    /// 默认车辆的VIN码
    var defaultVin: String? {
        return userModels?.first(where: { $0.def == 1 })?.vin
    }
    
    /// 所有车辆的VIN码
    var allVins: [String] {
        return userModels?.map { $0.vin } ?? []
    }
    
    // MARK: - 数据持久化方法
    
    /// 保存登录信息到本地
    private func saveLoginModel() {
        if let loginModel = loginModel {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(loginModel) {
                UserDefaults.standard.set(encoded, forKey: loginModelKey)
                
                // 同时保存到App Groups供Intent Extension使用
                if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                    sharedDefaults.set(loginModel.token, forKey: "timaToken")
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: loginModelKey)
            
            // 清除App Groups中的数据
            if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                sharedDefaults.removeObject(forKey: "timaToken")
            }
        }
    }
    
    /// 保存用户信息到本地
    private func saveUserModels() {
        if let userModels = userModels {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(userModels) {
                UserDefaults.standard.set(encoded, forKey: userModelsKey)
                
                // 同时保存默认VIN到App Groups供Intent Extension使用
                if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                    if let defaultVin = userModels.first(where: { $0.def == 1 })?.vin {
                        sharedDefaults.set(defaultVin, forKey: "defaultVin")
                    }
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: userModelsKey)
            
            // 清除App Groups中的数据
            if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                sharedDefaults.removeObject(forKey: "defaultVin")
            }
        }
    }
    
    /// 保存车辆信息到本地
    private func saveCarModel() {
        if let carModel = carModel {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(carModel) {
                UserDefaults.standard.set(encoded, forKey: carModelKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: carModelKey)
        }
    }
    
    /// 从本地加载用户数据
    private func loadUserData() {
        let decoder = JSONDecoder()
        
        // 加载登录信息（直接赋值给私有变量，避免触发didSet）
        if let savedLoginData = UserDefaults.standard.data(forKey: loginModelKey),
           let loadedLoginModel = try? decoder.decode(LoginModel.self, from: savedLoginData) {
            _loginModel = loadedLoginModel
        }
        
        // 加载用户信息
        if let savedUserData = UserDefaults.standard.data(forKey: userModelsKey),
           let loadedUserModels = try? decoder.decode([UserModel].self, from: savedUserData) {
            _userModels = loadedUserModels
        }
        
        // 加载车辆信息
        if let savedCarData = UserDefaults.standard.data(forKey: carModelKey),
           let loadedCarModel = try? decoder.decode(CarModel.self, from: savedCarData) {
            _carModel = loadedCarModel
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
        _loginModel = nil
        _userModels = nil
        _carModel = nil
        
        // 清空本地存储
        UserDefaults.standard.removeObject(forKey: loginModelKey)
        UserDefaults.standard.removeObject(forKey: userModelsKey)
        UserDefaults.standard.removeObject(forKey: carModelKey)
    }
    
    // MARK: - 检查登录状态
    var isLoggedIn: Bool {
        return loginModel != nil
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
}
