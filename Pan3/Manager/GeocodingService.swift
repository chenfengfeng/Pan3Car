//
//  GeocodingService.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-03
//

import Foundation
import CoreLocation

/// 地理编码服务
/// 负责将 GPS 坐标转换为地址，支持 CLGeocoder 和高德 API 的两级降级
class GeocodingService {
    
    // MARK: - Singleton
    
    static let shared = GeocodingService()
    
    private init() {}
    
    // MARK: - Constants
    
    /// 解析间隔（秒），避免超过 CLGeocoder 频率限制
    private let geocodingInterval: TimeInterval = 0.2
    
    /// 高德地图 API Key
    private let amapAPIKey = "ad43794c805061ae25622bc72c8f4763"
    
    // MARK: - Notifications
    
    /// 地址解析完成通知
    static let addressDidUpdateNotification = Notification.Name("TripAddressDidUpdate")
    
    // MARK: - Queue Management
    
    private var geocodingQueue = DispatchQueue(label: "com.pan3.geocoding", qos: .utility)
    private var isProcessing = false
    
    // MARK: - Public Methods
    
    /// 批量解析行程记录的地址
    /// - Parameter records: 需要解析的行程记录数组
    func geocodeTripRecords(_ records: [TripRecord]) {
        guard !records.isEmpty else {
            print("[GeocodingService] 没有需要解析的记录")
            return
        }
        
        print("[GeocodingService] 开始批量解析 \(records.count) 条记录")
        
        geocodingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.isProcessing = true
            
            for (index, record) in records.enumerated() {
                // 检查是否需要解析
                if !record.needsGeocoding {
                    print("[GeocodingService] 记录 \(index + 1)/\(records.count) 已有地址，跳过")
                    continue
                }
                
                print("[GeocodingService] 正在解析记录 \(index + 1)/\(records.count)")
                
                // 使用信号量实现同步等待
                let semaphore = DispatchSemaphore(value: 0)
                
                self.geocodeSingleTripRecord(record) { success in
                    if success {
                        print("[GeocodingService] 记录 \(index + 1)/\(records.count) 解析成功")
                    } else {
                        print("[GeocodingService] 记录 \(index + 1)/\(records.count) 解析失败")
                    }
                    semaphore.signal()
                }
                
                // 等待解析完成
                semaphore.wait()
                
                // 添加延迟，避免频率限制
                if index < records.count - 1 {
                    Thread.sleep(forTimeInterval: self.geocodingInterval)
                }
            }
            
            self.isProcessing = false
            print("[GeocodingService] 批量解析完成")
            
            // 发送通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: GeocodingService.addressDidUpdateNotification,
                    object: nil
                )
            }
        }
    }
    
    /// 解析单条行程记录的地址
    /// - Parameters:
    ///   - record: 行程记录
    ///   - completion: 完成回调
    private func geocodeSingleTripRecord(_ record: TripRecord, completion: @escaping (Bool) -> Void) {
        
        // 解析起点和终点
        let group = DispatchGroup()
        var startComponents: AddressComponents?
        var endComponents: AddressComponents?
        var hasError = false
        
        // 解析起点
        if record.startAddress == nil && record.startLat != 0 && record.startLon != 0 {
            group.enter()
            geocodeCoordinate(latitude: record.startLat, longitude: record.startLon) { components in
                startComponents = components
                if components == nil {
                    hasError = true
                }
                group.leave()
            }
        }
        
        // 解析终点
        if record.endAddress == nil && record.endLat != 0 && record.endLon != 0 {
            group.enter()
            geocodeCoordinate(latitude: record.endLat, longitude: record.endLon) { components in
                endComponents = components
                if components == nil {
                    hasError = true
                }
                group.leave()
            }
        }
        
        // 等待所有解析完成
        group.notify(queue: .main) {
            // 如果有地址组件被解析出来，进行格式化和保存
            if let start = startComponents, let end = endComponents {
                // 智能格式化
                let formatted = AddressFormatter.format(start: start, end: end)
                
                // 更新数据库
                record.updateStartAddress(formatted.startAddress, city: formatted.startCity)
                record.updateEndAddress(formatted.endAddress, city: formatted.endCity)
                
                // 保存到 Core Data
                CoreDataManager.shared.saveContext()
                
                completion(true)
            } else if let start = startComponents {
                // 只有起点解析成功
                let formatted = AddressFormatter.format(start: start, end: AddressComponents(from: [:]))
                record.updateStartAddress(formatted.startAddress, city: formatted.startCity)
                
                // 终点解析失败，标记为"解析失败"
                if record.endAddress == nil && record.endLat != 0 && record.endLon != 0 {
                    record.updateEndAddress("解析失败", city: nil)
                }
                
                CoreDataManager.shared.saveContext()
                completion(true)
            } else if let end = endComponents {
                // 只有终点解析成功
                let formatted = AddressFormatter.format(start: AddressComponents(from: [:]), end: end)
                record.updateEndAddress(formatted.endAddress, city: formatted.endCity)
                
                // 起点解析失败，标记为"解析失败"
                if record.startAddress == nil && record.startLat != 0 && record.startLon != 0 {
                    record.updateStartAddress("解析失败", city: nil)
                }
                
                CoreDataManager.shared.saveContext()
                completion(true)
            } else {
                // 起点和终点都解析失败，标记为"解析失败"
                if record.startAddress == nil && record.startLat != 0 && record.startLon != 0 {
                    record.updateStartAddress("解析失败", city: nil)
                }
                if record.endAddress == nil && record.endLat != 0 && record.endLon != 0 {
                    record.updateEndAddress("解析失败", city: nil)
                }
                
                // 保存到 Core Data
                CoreDataManager.shared.saveContext()
                
                completion(false)
            }
        }
    }
    
    /// 解析单个坐标为地址组件
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - completion: 完成回调，返回地址组件
    private func geocodeCoordinate(
        latitude: Double,
        longitude: Double,
        completion: @escaping (AddressComponents?) -> Void
    ) {
        // 优先使用高德 API（对中国地区数据更详细）
        geocodeWithAmap(latitude: latitude, longitude: longitude) { components in
            if let components = components {
                completion(components)
            } else {
                // 降级到 CLGeocoder
                self.geocodeWithCLGeocoder(latitude: latitude, longitude: longitude, completion: completion)
            }
        }
    }
    
    // MARK: - CLGeocoder Implementation
    
    /// 使用系统 CLGeocoder 解析坐标
    private func geocodeWithCLGeocoder(
        latitude: Double,
        longitude: Double,
        completion: @escaping (AddressComponents?) -> Void
    ) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("[GeocodingService] CLGeocoder 失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("[GeocodingService] CLGeocoder 未找到地址")
                completion(nil)
                return
            }
            
            let components = AddressComponents(from: placemark)
            print("[GeocodingService] CLGeocoder 成功: \(components.debugDescription())")
            completion(components)
        }
    }
    
    // MARK: - Amap API Implementation
    
    /// 使用高德地图 API 解析坐标
    private func geocodeWithAmap(
        latitude: Double,
        longitude: Double,
        completion: @escaping (AddressComponents?) -> Void
    ) {
        // 使用 extensions=all 获取 POI 信息，radius 设置为 100 米以获取更精确的结果
        let urlString = "https://restapi.amap.com/v3/geocode/regeo?key=\(amapAPIKey)&location=\(longitude),\(latitude)&radius=100&extensions=all"
        
        guard let url = URL(string: urlString) else {
            print("[GeocodingService] 高德 API URL 无效")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[GeocodingService] 高德 API 请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("[GeocodingService] 高德 API 未返回数据")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let status = json["status"] as? String, status == "1" {
                        let components = AddressComponents(from: json)
                        print("[GeocodingService] 高德 API 成功: \(components.debugDescription())")
                        completion(components)
                    } else {
                        let errorInfo = json["info"] as? String ?? "未知错误"
                        print("[GeocodingService] 高德 API 返回错误: \(errorInfo)")
                        completion(nil)
                    }
                } else {
                    print("[GeocodingService] 高德 API 响应格式错误")
                    completion(nil)
                }
            } catch {
                print("[GeocodingService] 高德 API 数据解析失败: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }
}

