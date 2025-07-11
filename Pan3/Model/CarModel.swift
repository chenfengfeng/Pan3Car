//
//  CarModel.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import SwiftyJSON

/**
 3个型号的电池容量(kWh)
 330: 34.5
 405: 41
 505: 51.5
 */

struct CarModel: Codable {
    // MARK: - 位置信息
    let latitude: String                 // 纬度
    let longitude: String                // 经度
    
    // MARK: - 电池信息
    let soc: String                      // 电池电量百分比
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
    let mainLockStatus: Int              // 主锁状态
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
        self.latitude = json["latitude"].stringValue
        self.longitude = json["longtitude"].stringValue
        
        // 电池信息
        self.soc = json["soc"].stringValue
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
        self.acOnMile = json["acOnMile"].intValue
        self.acOffMile = json["acOffMile"].intValue
        
        // 灯光系统
        self.lowlightStatus = json["lowlightStatus"].intValue
        self.highlightStatus = json["highlightStatus"].intValue
        
        // 车辆基本信息
        self.keyStatus = json["keyStatus"].intValue
        self.totalMileage = json["totalMileage"].stringValue
    }
    
    /// 推测车型及电池容量（返回如："405", 41.0）
    var estimatedModelAndCapacity: (model: String, batteryCapacity: Double) {
        guard let socValue = Double(soc), socValue > 0 else {
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
}
