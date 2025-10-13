//
//  ChargeTaskModel+CarWidgetAttributes.swift
//  Pan3
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

extension ChargeTaskModel {
    /// 将 ChargeTaskModel 转换为 CarWidgetAttributes
    func toCarWidgetAttributes() -> CarWidgetAttributes {
        return CarWidgetAttributes(
            taskId: id,
            vin: vin,
            createdAt: createdAt,
            initialKm: initialKm,
            targetKm: targetKm,
            initialKwh: initialKwh,
            targetKwh: targetKwh
        )
    }
    
    /// 将 ChargeTaskModel 转换为 CarWidgetAttributes.ContentState
    func toContentState() -> CarWidgetAttributes.ContentState {
        let percentage = calculatePercentage()
        
        return CarWidgetAttributes.ContentState(
            status: status,
            chargedKwh: chargedKwh,
            percentage: Int(percentage),
            message: message ?? "",
            lastUpdateTime: Date()
        )
    }
    
    /// 计算充电百分比
    private func calculatePercentage() -> Float {
        return Float(BatteryCalculationUtility.calculateChargingProgress(
            initialKwh: Double(initialKwh),
            targetKwh: Double(targetKwh),
            chargedKwh: Double(chargedKwh)
        ))
    }
}
