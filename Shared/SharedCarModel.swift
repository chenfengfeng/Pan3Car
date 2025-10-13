//
//  SharedCarModel.swift
//  Pan3Car
//
//  Created by AI Assistant on 2024
//

import Foundation

/// 共享车辆数据模型，支持多Target复用（主应用、小组件、Watch等）
/// 使用纯Foundation框架，不依赖第三方库
struct SharedCarModel: Codable {
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
    var mainLockStatus: Int              // 主锁状态
    let trunkLockStatus: Int             // 后备箱锁状态
    let doorsLockStatus: Int?            // 车门锁状态
    
    // MARK: - 车窗状态
    var lfWindowOpen: Int                // 左前车窗开启状态
    var rfWindowOpen: Int                // 右前车窗开启状态
    var lrWindowOpen: Int                // 左后车窗开启状态
    var rrWindowOpen: Int                // 右后车窗开启状态
    let topWindowOpen: Int               // 天窗开启状态
    
    // MARK: - 轮胎信息
    let lfTirePresure: Int               // 左前轮胎压力
    let rfTirePresure: Int               // 右前轮胎压力
    let lrTirePresure: Int               // 左后轮胎压力
    let rrTirePresure: Int               // 右后轮胎压力
    
    // MARK: - 空调系统
    var acStatus: Int                    // 空调状态
    let temperatureInCar: Int            // 车内温度
    let quickcoolACStatus: Int?          // 快速制冷空调状态
    let quickheatACStatus: Int           // 快速制热空调状态
    let defrostStatus: Int               // 除霜状态
    
    // MARK: - 灯光系统
    let lowlightStatus: Int              // 近光灯状态
    let highlightStatus: Int             // 远光灯状态
    
    // MARK: - 其他信息
    let keyStatus: Int                   // 钥匙状态
    let totalMileage: String             // 总里程
    let acOnMile: Int                    // 空调开启里程
    let acOffMile: Int                   // 空调关闭里程
    
    /// 从字典初始化（用于解析网络请求返回的数据）
    init(from dictionary: [String: Any]) {
        // 位置信息
        self.latitude = dictionary["latitude"] as? String ?? "0"
        self.longitude = dictionary["longtitude"] as? String ?? "0" // 注意API返回的是longtitude而不是longitude
        
        // 电池信息
        self.soc = dictionary["soc"] as? String ?? "0"
        self.quickChgLeftTime = dictionary["quickChgLeftTime"] as? Int ?? 0
        self.slowChgLeftTime = dictionary["slowChgLeftTime"] as? Int ?? 0
        self.chgStatus = dictionary["chgStatus"] as? Int ?? 0
        self.chgPlugStatus = dictionary["chgPlugStatus"] as? Int ?? 0
        self.batteryHeatStatus = dictionary["batteryHeatStatus"] as? Int ?? 0
        
        // 车门状态
        self.doorStsFrontLeft = dictionary["doorStsFrontLeft"] as? Int ?? 0
        self.doorStsFrontRight = dictionary["doorStsFrontRight"] as? Int ?? 0
        self.doorStsRearLeft = dictionary["doorStsRearLeft"] as? Int ?? 0
        self.doorStsRearRight = dictionary["doorStsRearRight"] as? Int ?? 0
        self.mainLockStatus = dictionary["mainLockStatus"] as? Int ?? 0
        self.trunkLockStatus = dictionary["trunkLockStatus"] as? Int ?? 0
        self.doorsLockStatus = dictionary["doorsLockStatus"] as? Int
        
        // 车窗状态
        self.lfWindowOpen = dictionary["lfWindowOpen"] as? Int ?? 0
        self.rfWindowOpen = dictionary["rfWindowOpen"] as? Int ?? 0
        self.lrWindowOpen = dictionary["lrWindowOpen"] as? Int ?? 0
        self.rrWindowOpen = dictionary["rrWindowOpen"] as? Int ?? 0
        self.topWindowOpen = dictionary["topWindowOpen"] as? Int ?? 0
        
        // 轮胎信息
        self.lfTirePresure = dictionary["lfTirePresure"] as? Int ?? 0
        self.rfTirePresure = dictionary["rfTirePresure"] as? Int ?? 0
        self.lrTirePresure = dictionary["lrTirePresure"] as? Int ?? 0
        self.rrTirePresure = dictionary["rrTirePresure"] as? Int ?? 0
        
        // 空调系统
        self.acStatus = dictionary["acStatus"] as? Int ?? 0
        self.temperatureInCar = dictionary["temperatureInCar"] as? Int ?? 20
        self.quickcoolACStatus = dictionary["quickcoolACStatus"] as? Int
        self.quickheatACStatus = dictionary["quickheatACStatus"] as? Int ?? 0
        self.defrostStatus = dictionary["defrostStatus"] as? Int ?? 0
        self.acOnMile = dictionary["acOnMile"] as? Int ?? 0
        self.acOffMile = dictionary["acOffMile"] as? Int ?? 0
        
        // 灯光系统
        self.lowlightStatus = dictionary["lowlightStatus"] as? Int ?? 0
        self.highlightStatus = dictionary["highlightStatus"] as? Int ?? 0
        
        // 其他信息
        self.keyStatus = dictionary["keyStatus"] as? Int ?? 0
        self.totalMileage = dictionary["totalMileage"] as? String ?? "0"
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
    
    /// 获取格式化的车内温度
    var formattedTemperature: String {
        return "\(temperatureInCar)°"
    }
    
    /// 获取车锁状态描述
    var lockStatusDescription: String {
        if mainLockStatus == 0 {
            return "已锁定"
        }
        return "已解锁"
    }
    
    /// 获取空调状态描述
    var airConditionerStatusDescription: String {
        if acStatus == 1 {
            return "已关闭"
        }
        return "已开启"
    }
    
    /// 获取充电状态描述
    var chargingStatusDescription: String {
        if chgStatus == 2 {
            return "未充电"
        }
        return "充电中"
    }
    
    /// 获取车窗开启状态数组（按顺序：左前、右前、左后、右后）
    var windowStates: [Bool] {
        return [
            lfWindowOpen > 0,
            rfWindowOpen > 0,
            lrWindowOpen > 0,
            rrWindowOpen > 0
        ]
    }
    
    /// 获取车门开启状态数组（按顺序：左前、右前、左后、右后、后备箱）
    var doorStates: [Bool] {
        return [
            doorStsFrontLeft > 0,
            doorStsFrontRight > 0,
            doorStsRearLeft > 0,
            doorStsRearRight > 0,
            trunkLockStatus > 0
        ]
    }
    
    /// 获取当前位置坐标
    var coordinate: (latitude: Double, longitude: Double) {
        let lat = Double(latitude) ?? 0.0
        let lng = Double(longitude) ?? 0.0
        return (lat, lng)
    }
}
