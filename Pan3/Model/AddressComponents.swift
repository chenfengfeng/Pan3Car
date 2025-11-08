//
//  AddressComponents.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-03
//

import Foundation
import CoreLocation

/// 统一的地址组件模型
/// 支持从 CLPlacemark 和高德地图 API 响应初始化
struct AddressComponents {
    
    // MARK: - Properties
    
    /// 省/直辖市（如 "上海市", "江苏省"）
    let province: String?
    
    /// 城市（如 "上海市", "南京市"）
    let city: String?
    
    /// 区/县（如 "浦东新区", "黄浦区"）
    let district: String?
    
    /// 街道（如 "世纪大道"）
    let street: String?
    
    /// 具体地点/门牌号（如 "1号"）
    let detail: String?
    
    /// 完整原始地址（备用）
    let fullAddress: String?
    
    // MARK: - Computed Properties
    
    /// 是否为有效地址
    var isValid: Bool {
        return province != nil || city != nil || district != nil || detail != nil
    }
    
    /// 获取最详细的地点名称（优先级：detail > name > street）
    var locationName: String? {
        return detail ?? street
    }
    
    // MARK: - Initializers
    
    /// 从 CLPlacemark 初始化
    /// - Parameter placemark: CoreLocation 的地标对象
    init(from placemark: CLPlacemark) {
        // 省份（administrativeArea）
        self.province = placemark.administrativeArea
        
        // 城市（locality）
        // 注意：直辖市的 locality 可能与 administrativeArea 相同
        self.city = placemark.locality
        
        // 区/县（subLocality）
        self.district = placemark.subLocality
        
        // 街道（thoroughfare）
        self.street = placemark.thoroughfare
        
        // 具体地点（优先使用 name，它通常包含最详细的信息）
        // 如果 name 和 thoroughfare 相同，则尝试组合 subThoroughfare（门牌号）
        var detailText: String?
        if let name = placemark.name {
            detailText = name
        } else if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                detailText = thoroughfare + subThoroughfare
            } else {
                detailText = thoroughfare
            }
        }
        self.detail = detailText
        
        // 完整地址（备用）
        self.fullAddress = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.subThoroughfare
        ].compactMap { $0 }.joined(separator: "")
    }
    
    /// 从高德地图 API 响应初始化
    /// - Parameter amapResponse: 高德地图返回的 JSON 数据
    init(from amapResponse: [String: Any]) {
        if let regeocode = amapResponse["regeocode"] as? [String: Any],
           let addressComponent = regeocode["addressComponent"] as? [String: Any] {
            
            // 省份
            self.province = addressComponent["province"] as? String
            
            // 城市（直辖市的 city 字段可能为空或与 province 相同）
            let cityValue = addressComponent["city"] as? String
            let provinceValue = addressComponent["province"] as? String
            // 避免直辖市重复显示
            if cityValue == provinceValue || cityValue?.isEmpty == true {
                self.city = nil
            } else {
                self.city = cityValue
            }
            
            // 区/县
            self.district = addressComponent["district"] as? String
            
            // 尝试获取 POI（兴趣点）信息，这是最详细的地址
            var detailAddress: String?
            var streetName: String?
            
            // 1. 优先使用 POI 信息
            if let pois = regeocode["pois"] as? [[String: Any]],
               let firstPoi = pois.first,
               let poiName = firstPoi["name"] as? String,
               !poiName.isEmpty {
                detailAddress = poiName
                print("[AddressComponents] 使用 POI: \(poiName)")
            }
            
            // 2. 如果没有 POI，使用街道+门牌号
            if detailAddress == nil,
               let streetNumber = addressComponent["streetNumber"] as? [String: Any] {
                let street = streetNumber["street"] as? String ?? ""
                let number = streetNumber["number"] as? String ?? ""
                
                if !street.isEmpty {
                    streetName = street
                    if !number.isEmpty {
                        detailAddress = street + number
                    } else {
                        detailAddress = street
                    }
                }
            }
            
            // 3. 如果还是没有，尝试使用 township（街道/乡镇）+ building（建筑物）
            if detailAddress == nil {
                let township = addressComponent["township"] as? String
                let building = addressComponent["building"] as? String
                
                if let building = building, !building.isEmpty {
                    detailAddress = building
                } else if let township = township, !township.isEmpty {
                    detailAddress = township
                }
            }
            
            self.street = streetName
            self.detail = detailAddress
            
            // 完整地址
            self.fullAddress = regeocode["formatted_address"] as? String
            
        } else {
            // 解析失败，返回空对象
            self.province = nil
            self.city = nil
            self.district = nil
            self.street = nil
            self.detail = nil
            self.fullAddress = nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// 生成简化的地址字符串（用于调试）
    func debugDescription() -> String {
        var components: [String] = []
        
        if let province = province { components.append("省:\(province)") }
        if let city = city { components.append("市:\(city)") }
        if let district = district { components.append("区:\(district)") }
        if let street = street { components.append("街:\(street)") }
        if let detail = detail { components.append("详:\(detail)") }
        
        return components.joined(separator: " | ")
    }
}


