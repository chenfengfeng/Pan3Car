//
//  AddressFormatter.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-03
//

import Foundation

/// 智能地址格式化器
/// 根据起终点的地理层级关系，自适应显示地址详细程度
class AddressFormatter {
    
    // MARK: - Display Level
    
    /// 地址显示层级
    enum DisplayLevel {
        case local      // 仅地点名（同区）
        case district   // 区 + 地点（跨区）
        case city       // 市 + 区 + 地点（跨市）
        case province   // 省 + 市 + 区 + 地点（跨省）
    }
    
    // MARK: - Public Methods
    
    /// 智能格式化起终点地址
    /// - Parameters:
    ///   - start: 起点地址组件
    ///   - end: 终点地址组件
    /// - Returns: 格式化后的起终点地址元组，以及城市信息用于存储
    static func format(
        start: AddressComponents,
        end: AddressComponents
    ) -> (startAddress: String, endAddress: String, startCity: String?, endCity: String?) {
        
        // 检查地址有效性
        guard start.isValid && end.isValid else {
            return (
                startAddress: formatFallback(start),
                endAddress: formatFallback(end),
                startCity: start.city,
                endCity: end.city
            )
        }
        
        // 确定显示层级
        let level = determineDisplayLevel(start: start, end: end)
        
        // 根据层级格式化地址
        let startAddress = formatAddress(start, level: level)
        let endAddress = formatAddress(end, level: level)
        
        return (
            startAddress: startAddress,
            endAddress: endAddress,
            startCity: start.city,
            endCity: end.city
        )
    }
    
    // MARK: - Private Methods
    
    /// 确定地址显示层级
    private static func determineDisplayLevel(
        start: AddressComponents,
        end: AddressComponents
    ) -> DisplayLevel {
        
        // 比较省份
        if !isSameValue(start.province, end.province) {
            return .province  // 跨省
        }
        
        // 比较城市（处理直辖市情况）
        let startCity = getNormalizedCity(start)
        let endCity = getNormalizedCity(end)
        
        if !isSameValue(startCity, endCity) {
            return .city  // 跨市
        }
        
        // 比较区县
        if !isSameValue(start.district, end.district) {
            return .district  // 跨区
        }
        
        // 同区
        return .local
    }
    
    /// 格式化单个地址
    private static func formatAddress(
        _ components: AddressComponents,
        level: DisplayLevel
    ) -> String {
        
        var parts: [String] = []
        
        switch level {
        case .province:
            // 跨省：省 + 市 + 区 + 地点
            if let province = components.province {
                // 处理直辖市：避免重复显示（如 "上海市上海市"）
                let city = getNormalizedCity(components)
                if city != province {
                    parts.append(province)
                }
            }
            if let city = getNormalizedCity(components) {
                parts.append(city)
            }
            if let district = components.district {
                parts.append(district)
            }
            if let location = components.locationName {
                parts.append(location)
            }
            
        case .city:
            // 跨市：市 + 区 + 地点
            if let city = getNormalizedCity(components) {
                parts.append(city)
            }
            if let district = components.district {
                parts.append(district)
            }
            if let location = components.locationName {
                parts.append(location)
            }
            
        case .district:
            // 跨区：区 + 地点
            if let district = components.district {
                parts.append(district)
            }
            if let location = components.locationName {
                parts.append(location)
            }
            
        case .local:
            // 同区：仅地点
            if let location = components.locationName {
                parts.append(location)
            }
        }
        
        // 如果没有任何组件，使用后备方案
        if parts.isEmpty {
            return formatFallback(components)
        }
        
        // 根据层级决定分隔符
        let separator: String
        switch level {
        case .province, .city:
            separator = " "  // 高层级用空格分隔，清晰易读
        case .district, .local:
            separator = " "  // 低层级也用空格，保持一致
        }
        
        return parts.joined(separator: separator)
    }
    
    /// 获取标准化的城市名（处理直辖市）
    private static func getNormalizedCity(_ components: AddressComponents) -> String? {
        // 对于直辖市，city 和 province 可能相同
        // 优先返回 city，如果为空则返回 province
        if let city = components.city, !city.isEmpty {
            return city
        }
        return components.province
    }
    
    /// 比较两个字符串值是否相同（处理 nil 情况）
    private static func isSameValue(_ value1: String?, _ value2: String?) -> Bool {
        // 如果都为 nil，视为相同
        if value1 == nil && value2 == nil {
            return true
        }
        // 如果一个为 nil，一个不为 nil，视为不同
        guard let v1 = value1, let v2 = value2 else {
            return false
        }
        // 比较字符串值
        return v1 == v2
    }
    
    /// 后备格式化方案（当地址组件不完整时）
    private static func formatFallback(_ components: AddressComponents) -> String {
        // 尝试使用完整地址
        if let fullAddress = components.fullAddress, !fullAddress.isEmpty {
            return fullAddress
        }
        
        // 尝试组合任何可用的组件
        let availableParts = [
            components.province,
            components.city,
            components.district,
            components.street,
            components.detail
        ].compactMap { $0 }
        
        if !availableParts.isEmpty {
            return availableParts.joined(separator: "")
        }
        
        // 完全无法解析
        return "位置信息不完整"
    }
    
    // MARK: - Simplified Format (Optional)
    
    /// 获取简化的单个地址（不考虑起终点关系）
    /// - Parameters:
    ///   - components: 地址组件
    ///   - level: 指定的显示层级
    /// - Returns: 格式化后的地址字符串
    static func simplified(_ components: AddressComponents, level: DisplayLevel) -> String {
        return formatAddress(components, level: level)
    }
    
    // MARK: - Charge Address Format
    
    /// 格式化充电记录地址（始终显示完整信息：城市+区+地点）
    /// - Parameter components: 地址组件
    /// - Returns: 格式化后的完整地址字符串
    static func formatChargeAddress(_ components: AddressComponents) -> String {
        guard components.isValid else {
            return formatFallback(components)
        }
        
        var parts: [String] = []
        
        // 获取城市（处理直辖市）
        if let city = getNormalizedCity(components) {
            parts.append(city)
        }
        
        // 添加区
        if let district = components.district {
            parts.append(district)
        }
        
        // 添加具体位置
        if let location = components.locationName {
            parts.append(location)
        }
        
        // 如果没有任何组件，使用后备方案
        if parts.isEmpty {
            return formatFallback(components)
        }
        
        // 用空格分隔，清晰易读
        return parts.joined(separator: " ")
    }
}


