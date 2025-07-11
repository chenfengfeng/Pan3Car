//
//  UserModel.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import SwiftyJSON

struct UserModel: Codable {
    let beAuthorized: String             // 是否被授权
    let brandId: Int                     // 品牌ID
    let brandName: String                // 品牌名称
    let createdDate: String              // 创建日期
    let def: Int                         // 默认标识
    let defToNathor: Int                 // 默认授权标识
    let deleteFlag: Int                  // 删除标识
    let id: Int                          // 记录ID
    let imageUrl: String                 // 车辆图片URL
    let isLocking: String                // 锁定状态
    let lastModifiedDate: String         // 最后修改日期
    let modelType: String                // 车型
    let plateLicenseNo: String           // 车牌号
    let seriesName: String               // 车系名称
    let simAuthStatus: Int               // SIM卡认证状态
    let tspFlag: Int                     // TSP标识
    let tspUserId: String                // TSP用户ID
    let userId: String                   // 用户ID
    let userName: String                 // 用户名
    let userNo: String                   // 用户编号
    let version: Int                     // 版本号
    let vin: String                      // 车架号
    
    init(json: JSON) {
        self.beAuthorized = json["beAuthorized"].stringValue
        self.brandId = json["brandId"].intValue
        self.brandName = json["brandName"].stringValue
        self.createdDate = json["createdDate"].stringValue
        self.def = json["def"].intValue
        self.defToNathor = json["defToNathor"].intValue
        self.deleteFlag = json["deleteFlag"].intValue
        self.id = json["id"].intValue
        self.imageUrl = json["imageUrl"].stringValue
        self.isLocking = json["isLocking"].stringValue
        self.lastModifiedDate = json["lastModifiedDate"].stringValue
        self.modelType = json["modelType"].stringValue
        self.plateLicenseNo = json["plateLicenseNo"].stringValue
        self.seriesName = json["seriesName"].stringValue
        self.simAuthStatus = json["simAuthStatus"].intValue
        self.tspFlag = json["tspFlag"].intValue
        self.tspUserId = json["tspUserId"].stringValue
        self.userId = json["userId"].stringValue
        self.userName = json["userName"].stringValue
        self.userNo = json["userNo"].stringValue
        self.version = json["version"].intValue
        self.vin = json["vin"].stringValue
    }
}