//
//  CarInfo.swift
//  Pan3
//
//  Created by Feng on 2025/9/14.
//

import UIKit
import WidgetKit

struct CarInfo: Codable, Hashable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let isCharge: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
    let chgLeftTime: Int
    
    static let placeholder = CarInfo(
        remainingMileage: 330,
        soc: 60,
        isLocked: false,
        windowsOpen: true,
        isCharge: false,
        airConditionerOn: true,
        lastUpdated: Date(),
        chgLeftTime: 0
    )
    
    static let placeholder1 = CarInfo(
        remainingMileage: 435,
        soc: 80,
        isLocked: true,
        windowsOpen: false,
        isCharge: false,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 0
    )
    
    static let placeholder2 = CarInfo(
        remainingMileage: 505,
        soc: 100,
        isLocked: false,
        windowsOpen: false,
        isCharge: true,
        airConditionerOn: false,
        lastUpdated: Date(),
        chgLeftTime: 127
    )
    
    // 创建更新后的CarInfo实例
    func updatingLockStatus(_ isLocked: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: self.isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingAirConditioner(_ isOn: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: self.isCharge,
            airConditionerOn: isOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingWindows(_ areOpen: Bool) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: areOpen,
            isCharge: self.isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: self.chgLeftTime
        )
    }
    
    func updatingChargingStatus(_ isCharge: Bool, chgLeftTime: Int) -> CarInfo {
        return CarInfo(
            remainingMileage: self.remainingMileage,
            soc: self.soc,
            isLocked: self.isLocked,
            windowsOpen: self.windowsOpen,
            isCharge: isCharge,
            airConditionerOn: self.airConditionerOn,
            lastUpdated: Date(),
            chgLeftTime: chgLeftTime
        )
    }
    
    // 通用的解析CarInfo方法
    static func parseCarInfo(from carData: [String: Any]) -> CarInfo {
        // 安全处理soc字段，支持Int和String类型
        let soc: Int
        if let socInt = carData["soc"] as? Int {
            soc = socInt
        } else if let socString = carData["soc"] as? String {
            soc = Int(socString) ?? 0
        } else {
            soc = 0
        }
        
        let remainingMileage = carData["acOnMile"] as? Int ?? 0
        let mainLockStatus = carData["mainLockStatus"] as? Int ?? 0
        let acStatus = carData["acStatus"] as? Int ?? 0
        let lfWindow = carData["lfWindowOpen"] as? Int ?? 0
        let rfWindow = carData["rfWindowOpen"] as? Int ?? 0
        let lrWindow = carData["lrWindowOpen"] as? Int ?? 0
        let rrWindow = carData["rrWindowOpen"] as? Int ?? 0
        let isCharge = carData["chgStatus"] as? Int ?? 2
        let chgLeftTime = carData["quickChgLeftTime"] as? Int ?? 0
        
        return CarInfo(
            remainingMileage: remainingMileage,
            soc: soc,
            isLocked: mainLockStatus == 0,
            windowsOpen: lfWindow == 100 || rfWindow == 100 || lrWindow == 100 || rrWindow == 100,
            isCharge: isCharge != 2,
            airConditionerOn: acStatus == 1,
            lastUpdated: Date(),
            chgLeftTime: chgLeftTime
        )
    }
}
