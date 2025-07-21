//
//  AuthResponseModel.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import SwiftyJSON

// MARK: - 认证响应模型
struct AuthResponseModel: Codable {
    let code: Int
    var data: AuthDataModel
    
    init(json: JSON) {
        self.code = json["code"].intValue
        self.data = AuthDataModel(json: json["data"])
    }
}

// MARK: - 认证数据模型
struct AuthDataModel: Codable {
    let vin: String                      // 车架号
    let token: String                    // 认证令牌
    var info: CarModel                   // 车辆详细信息（可变）
    let user: AuthUserModel              // 用户信息
    
    init(json: JSON) {
        self.vin = json["vin"].stringValue
        self.token = json["token"].stringValue
        self.info = CarModel(json: json["info"])
        self.user = AuthUserModel(json: json["user"])
    }
}

// MARK: - 认证用户模型
struct AuthUserModel: Codable {
    let userName: String                 // 用户名
    let headUrl: String                  // 头像URL
    let realPhone: String                // 脱敏手机号
    let plateLicenseNo: String           // 车牌号
    let no: String                       // 用户编号
    
    init(json: JSON) {
        self.userName = json["userName"].stringValue
        self.headUrl = json["headUrl"].stringValue
        self.realPhone = json["realPhone"].stringValue
        self.plateLicenseNo = json["plateLicenseNo"].stringValue
        self.no = json["no"].stringValue
    }
}
