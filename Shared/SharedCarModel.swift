//
//  SharedCarModel.swift
//  Pan3Car
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftyJSON
import CoreLocation

/**
 3个型号的电池容量(kWh)
 330: 34.5
 405: 41
 505: 51.5
 */
/// 共享车辆数据模型，支持多Target复用（主应用、小组件、Watch等）
/// 使用纯Foundation框架，不依赖第三方库
struct SharedCarModel: Codable {
    // MARK: - 位置信息
    let latitude: Double                 // 纬度
    let longitude: Double                // 经度
    
    // MARK: - 电池信息
    let soc: Int                         // 电池电量百分比
    let quickChgLeftTime: Int            // 快充剩余时间
    let slowChgLeftTime: Int             // 慢充剩余时间
    let chgStatus: Int                   // 充电状态
    let chgPlugStatus: Int               // 充电插头状态
    let batteryHeatStatus: Int           // 电池加热状态
    
    // MARK: - 车门状态
    let doorStsFrontLeft: Int            // 前左车门状态
    let doorStsFrontRight: Int           // 前右车门状态
    let doorStsRearLeft: Int             // 后左车门状态
    let doorStsRearRight: Int            // 后右车门状态
    var mainLockStatus: Int              // 主锁状态
    let trunkLockStatus: Int             // 后备箱锁状态
    let doorsLockStatus: Int?            // 车门锁状态
    
    // MARK: - 车窗状态
    let lfWindowOpen: Int                // 左前车窗开启状态
    let rfWindowOpen: Int                // 右前车窗开启状态
    let lrWindowOpen: Int                // 左后车窗开启状态
    let rrWindowOpen: Int                // 右后车窗开启状态
    let topWindowOpen: Int               // 天窗开启状态
    
    // MARK: - 轮胎信息
    let lfTirePresure: Int               // 左前轮胎压力
    let rfTirePresure: Int               // 右前轮胎压力
    let lrTirePresure: Int               // 左后轮胎压力
    let rrTirePresure: Int               // 右后轮胎压力
    
    // MARK: - 空调系统
    let acStatus: Int                    // 空调状态
    let temperatureInCar: Int            // 车内温度
    let quickcoolACStatus: Int?          // 快速制冷空调状态
    let quickheatACStatus: Int           // 快速制热空调状态
    let defrostStatus: Int               // 除霜状态
    
    // MARK: - 灯光系统
    let lowlightStatus: Int              // 近光灯状态
    let highlightStatus: Int             // 远光灯状态
    
    // MARK: - 车辆基本信息
    let keyStatus: Int                   // 钥匙状态
    let totalMileage: String             // 总里程
    let acOnMile: Int                    // 空调开启里程
    let acOffMile: Int                   // 空调关闭里程
    
    init(json: JSON) {
        // 位置信息
        self.latitude = json["latitude"].doubleValue
        self.longitude = json["longtitude"].doubleValue
        
        // 电池信息
        self.soc = json["soc"].intValue
        self.acOnMile = json["acOnMile"].intValue
        self.acOffMile = json["acOffMile"].intValue
        self.quickChgLeftTime = json["quickChgLeftTime"].intValue
        self.slowChgLeftTime = json["slowChgLeftTime"].intValue
        self.chgStatus = json["chgStatus"].intValue
        self.chgPlugStatus = json["chgPlugStatus"].intValue
        self.batteryHeatStatus = json["batteryHeatStatus"].intValue
        
        // 车门状态
        self.doorStsFrontLeft = json["doorStsFrontLeft"].intValue
        self.doorStsFrontRight = json["doorStsFrontRight"].intValue
        self.doorStsRearLeft = json["doorStsRearLeft"].intValue
        self.doorStsRearRight = json["doorStsRearRight"].intValue
        self.mainLockStatus = json["mainLockStatus"].intValue
        self.trunkLockStatus = json["trunkLockStatus"].intValue
        self.doorsLockStatus = json["doorsLockStatus"].int
        
        // 车窗状态
        self.lfWindowOpen = json["lfWindowOpen"].intValue
        self.rfWindowOpen = json["rfWindowOpen"].intValue
        self.lrWindowOpen = json["lrWindowOpen"].intValue
        self.rrWindowOpen = json["rrWindowOpen"].intValue
        self.topWindowOpen = json["topWindowOpen"].intValue
        
        // 轮胎信息
        self.lfTirePresure = json["lfTirePresure"].intValue
        self.rfTirePresure = json["rfTirePresure"].intValue
        self.lrTirePresure = json["lrTirePresure"].intValue
        self.rrTirePresure = json["rrTirePresure"].intValue
        
        // 空调系统
        self.acStatus = json["acStatus"].intValue
        self.temperatureInCar = json["temperatureInCar"].intValue
        self.quickcoolACStatus = json["quickcoolACStatus"].int
        self.quickheatACStatus = json["quickheatACStatus"].intValue
        self.defrostStatus = json["defrostStatus"].intValue
        
        // 灯光系统
        self.lowlightStatus = json["lowlightStatus"].intValue
        self.highlightStatus = json["highlightStatus"].intValue
        
        // 车辆基本信息
        self.keyStatus = json["keyStatus"].intValue
        self.totalMileage = json["totalMileage"].stringValue
    }
    
    /// 从字典数据初始化CarModel的便利构造器
    /// 使用SwiftyJSON将字典转换为JSON对象，然后调用现有的init(json:)方法
    init?(dictionary: [String: Any]) {
        let json = JSON(dictionary)
        self.init(json: json)
    }
    
    /// 推测车型及电池容量（返回如："405", 41.0）
    var estimatedModelAndCapacity: (model: String, batteryCapacity: Double) {
        let socValue = Double(soc)
        guard socValue > 0 else {
            return ("Unknown", 0.0)
        }

        let currentMileage = acOnMile
        let estimatedFullMileage = Double(currentMileage) / (socValue / 100.0)

        // 模型数据（续航和容量）
        let modelRanges: [(name: String, mileage: Double, battery: Double)] = [
            ("330", 330.0, 34.5),
            ("405", 405.0, 41.0),
            ("505", 505.0, 51.5)
        ]

        let tolerance = 20.0 // km 允许的误差范围

        let candidates = modelRanges.filter {
            abs($0.mileage - estimatedFullMileage) <= tolerance
        }

        let closest = candidates.min(by: {
            abs($0.mileage - estimatedFullMileage) < abs($1.mileage - estimatedFullMileage)
        })

        return (closest?.name ?? "Unknown", closest?.battery ?? 0.0)
    }
    
    /// 车辆坐标位置
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 车锁状态描述
    var lockStatusDescription: String {
        return mainLockStatus == 0 ? "已锁车" : "已解锁"
    }
    
    /// 车窗状态数组
    var windowStates: [Bool] {
        return [
            lfWindowOpen != 0,  // 左前车窗
            rfWindowOpen != 0,  // 右前车窗
            lrWindowOpen != 0,  // 左后车窗
            rrWindowOpen != 0,  // 右后车窗
            topWindowOpen != 0  // 天窗
        ]
    }
    
    /// 将CarModel转换为字典形式，用于保存到App Groups
    func toDictionary() -> [String: Any] {
        var dictionary: [String: Any] = [
            // 位置信息
            "latitude": latitude,
            "longitude": longitude,
            
            // 电池信息
            "soc": soc,
            "quickChgLeftTime": quickChgLeftTime,
            "slowChgLeftTime": slowChgLeftTime,
            "chgStatus": chgStatus,
            "chgPlugStatus": chgPlugStatus,
            "batteryHeatStatus": batteryHeatStatus,
            
            // 车门状态
            "doorStsFrontLeft": doorStsFrontLeft,
            "doorStsFrontRight": doorStsFrontRight,
            "doorStsRearLeft": doorStsRearLeft,
            "doorStsRearRight": doorStsRearRight,
            "mainLockStatus": mainLockStatus,
            "trunkLockStatus": trunkLockStatus,
            
            // 车窗状态
            "lfWindowOpen": lfWindowOpen,
            "rfWindowOpen": rfWindowOpen,
            "lrWindowOpen": lrWindowOpen,
            "rrWindowOpen": rrWindowOpen,
            "topWindowOpen": topWindowOpen,
            
            // 轮胎信息
            "lfTirePresure": lfTirePresure,
            "rfTirePresure": rfTirePresure,
            "lrTirePresure": lrTirePresure,
            "rrTirePresure": rrTirePresure,
            
            // 空调系统
            "acStatus": acStatus,
            "temperatureInCar": temperatureInCar,
            "quickheatACStatus": quickheatACStatus,
            "defrostStatus": defrostStatus,
            
            // 灯光系统
            "lowlightStatus": lowlightStatus,
            "highlightStatus": highlightStatus,
            
            // 车辆基本信息
            "keyStatus": keyStatus,
            "totalMileage": totalMileage,
            "acOnMile": acOnMile,
            "acOffMile": acOffMile,
            
            // 添加时间戳用于数据新鲜度判断
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        // 安全处理可选属性，避免null值导致崩溃
        if let doorsLockStatus = doorsLockStatus {
            dictionary["doorsLockStatus"] = doorsLockStatus
        }
        
        if let quickcoolACStatus = quickcoolACStatus {
            dictionary["quickcoolACStatus"] = quickcoolACStatus
        }
        
        return dictionary
    }
}
