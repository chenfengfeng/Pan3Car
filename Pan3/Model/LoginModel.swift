//
//  LoginModel.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import SwiftyJSON

struct LoginModel: Codable {
    let id: Int                          // 用户ID
    let no: String                       // 用户编号
    let userName: String                 // 用户名
    let userCode: String                 // 用户代码
    let password: String                 // 密码
    let phone: String                    // 手机号
    let realPhone: String                // 脱敏手机号
    let userStatus: Int                  // 用户状态
    let authenticationStatus: Int        // 认证状态
    let initUser: Int                    // 初始用户标识
    let headUrl: String                  // 头像URL
    let userType: String                 // 用户类型
    let token: String                    // 访问令牌
    let refreshToken: String             // 刷新令牌
    let attribute4: String               // 扩展属性4
    let attribute5: String               // 扩展属性5
    let identityType: Int                // 身份类型
    let createdDate: Int64               // 创建时间
    let lastModifiedDate: Int64          // 最后修改时间
    let version: Int                     // 版本号
    let deleteFlag: String               // 删除标识
    let aaaToken: String                 // AAA令牌
    let aaaid: Int                       // AAA用户ID
    let tspid: Int                       // TSP用户ID
    
    init(json: JSON) {
        self.id = json["id"].intValue
        self.no = json["no"].stringValue
        self.userName = json["userName"].stringValue
        self.userCode = json["userCode"].stringValue
        self.password = json["password"].stringValue
        self.phone = json["phone"].stringValue
        self.realPhone = json["realPhone"].stringValue
        self.userStatus = json["userStatus"].intValue
        self.authenticationStatus = json["authenticationStatus"].intValue
        self.initUser = json["initUser"].intValue
        self.headUrl = json["headUrl"].stringValue
        self.userType = json["userType"].stringValue
        self.token = json["token"].stringValue
        self.refreshToken = json["refreshToken"].stringValue
        self.attribute4 = json["attribute4"].stringValue
        self.attribute5 = json["attribute5"].stringValue
        self.identityType = json["identityType"].intValue
        self.createdDate = json["createdDate"].int64Value
        self.lastModifiedDate = json["lastModifiedDate"].int64Value
        self.version = json["version"].intValue
        self.deleteFlag = json["deleteFlag"].stringValue
        self.aaaToken = json["aaaToken"].stringValue
        self.aaaid = json["aaaid"].intValue
        self.tspid = json["tspid"].intValue
    }
}