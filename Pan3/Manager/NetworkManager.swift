//
//  NetworkManager.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import UIKit
import Alamofire
import SwiftyJSON
import CoreLocation

struct ChargeListResponse {
    let tasks: [ChargeTaskModel]
    let pagination: PaginationInfo
}

struct ChargeStatusResponse {
    let hasRunningTask: Bool
    let task: ChargeTaskModel?
}

struct TripRecordsResponse {
    let trips: [TripRecordData]
    let pagination: PaginationInfo
}

struct PaginationInfo {
    let currentPage: Int
    let totalPages: Int
    let totalCount: Int
    let pageSize: Int
    let hasNext: Bool
    let hasPrev: Bool
}

class NetworkManager {
    static let shared = NetworkManager()
    
    private let baseURL = "https://pan3.dreamforge.top/api"
    
    private init() {}
    
    // MARK: - 登录接口
    func login(userCode: String, password: String, completion: @escaping (Result<AuthResponseModel, Error>) -> Void) {
        // 使用本地服务器的认证接口
        let url = "\(baseURL)/auth/login"
        
        let parameters: [String: Any] = [
            "userCode": userCode,
            "password": password
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: ["Content-Type": "application/json"])
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    let json = JSON(jsonObject)
                    if json["code"].intValue == 200 {
                        let authResponse = AuthResponseModel(json: json)
                        completion(.success(authResponse))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? "登录失败" : json["message"].stringValue
                        let error = NSError(domain: "LoginError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    
    // MARK: - 退出登录
    func logout(completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let no = UserManager.shared.no,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "LogoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/auth/logout"
        
        let parameters: [String: Any] = [
            "no": no
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: headers)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    let json = JSON(jsonObject)
                    // 根据实际API返回格式调整判断逻辑
                    if json["code"].intValue == 200 {
                        completion(.success(true))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "LogoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "退出登录失败" : errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 车辆信息接口
    // 获取车辆详细信息
    func getInfo(completion: @escaping (Result<SharedCarModel, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "CarInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/info"
        
        let parameters: [String: Any] = [
            "vin": vin
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: headers)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    let json = JSON(jsonObject)
                    if !json["data"].dictionaryValue.isEmpty {
                        let model = SharedCarModel(json: json["data"])
                        // 更新UserManager中的车辆信息
                        UserManager.shared.updateCarInfo(with: model)
                        
                        completion(.success(model))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? "获取车辆信息失败" : json["message"].stringValue
                        let error = NSError(domain: "CarInfoError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 车辆控制接口
    
    /// 通用的车辆同步/控制函数
    /// - Parameters:
    ///   - operationType: 操作类型 ("LOCK", "WINDOW", "INTELLIGENT_AIRCONDITIONER", "FIND_VEHICLE")
    ///   - operation: 具体操作 (例如 1 代表关, 2 代表开)
    ///   - temperature: 温度 (仅空调需要)
    ///   - duringTime: 空调持续时间 (仅空调需要)
    ///   - openLevel: 车窗开启程度 (仅车窗需要)
    ///   - pushToken: 推送令牌 (可选)
    ///   - completion: 完成回调
    func syncVehicle(
        operationType: String,
        operation: Int? = nil,
        temperature: Int? = nil,
        duringTime: Int? = nil,
        openLevel: Int? = nil,
        pushToken: String = "",
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "VehicleSyncError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/sync"
        
        // --- 动态构造请求参数 ---
        var parameters: [String: Any] = [
            "vin": vin,
            "operationType": operationType,
            "pushToken": pushToken
        ]
        
        if let operation = operation {
            parameters["operation"] = operation
        }
        if let temperature = temperature {
            parameters["temperature"] = temperature
        }
        if let duringTime = duringTime {
            parameters["duringTime"] = duringTime
        }
        if let openLevel = openLevel {
            parameters["openLevel"] = openLevel
        }
        // --- 参数构造结束 ---
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: headers)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let json = try JSON(data: data)
                    if json["code"].intValue == 200 || json["returnSuccess"].boolValue {
                        completion(.success(true))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? (json["returnErrMsg"].stringValue.isEmpty ? "操作失败" : json["returnErrMsg"].stringValue) : json["message"].stringValue
                        let error = NSError(domain: "VehicleSyncError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 充电接口
    /// 启动充电监控任务 (全新版本)
    /// - Parameters:
    ///   - mode: 监控模式 ("time" 或 "range")
    ///   - targetTimestamp: 目标时间戳 (仅 time 模式需要)
    ///   - targetRange: 目标续航里程 (仅 range 模式需要)
    ///   - autoStopCharge: 是否自动停止充电 (仅 time 模式需要)
    ///   - completion: 完成回调
    func startChargeMonitoring(
        mode: String,
        targetTimestamp: TimeInterval? = nil,
        targetRange: Int? = nil,
        autoStopCharge: Bool = false,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken
        else {
            let error = NSError(domain: "ChargeMonitorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/charge/start"
        let pushToken = UserDefaults.standard.string(forKey: "pushToken") ?? ""
        
        var parameters: [String: Any] = [
            "vin": vin,
            "monitoringMode": mode,
            "pushToken": pushToken
        ]
        
        if mode == "time", let timestamp = targetTimestamp {
            parameters["targetTimestamp"] = String(format: "%.0f", timestamp) // 转为字符串形式的时间戳
            parameters["autoStopCharge"] = autoStopCharge
        } else if mode == "range", let range = targetRange {
            parameters["targetRange"] = range
        } else {
            let error = NSError(domain: "ChargeMonitorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "参数不匹配"])
            completion(.failure(error))
            return
        }
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: headers)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let json = try JSON(data: data)
                    if json["code"].intValue == 200 {
                        // 启动成功
                        completion(.success(true))
                    } else {
                        // 业务逻辑错误，例如已有任务在运行
                        let errorMsg = json["message"].stringValue.isEmpty ? "启动监控失败" : json["message"].stringValue
                        let error = NSError(domain: "ChargeMonitorError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    print(String(data: data, encoding: .utf8) ?? "")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 更新实时活动的推送Token
    func updateLiveActivityToken(_ token: String, type: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "UpdateTokenError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        // 使用正确的 URL 和参数
        let url = "\(baseURL)/charge/update-token"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "activityType": type,
            "activityToken": token
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if json["code"].intValue == 200 {
                            completion(.success(true))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "Token更新失败" : json["message"].stringValue
                            let error = NSError(domain: "UpdateTokenError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                            completion(.failure(error))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    /// 手动停止充电监控任务
    func stopChargeMonitoring(mode: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "StopMonitorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        // 使用正确的 URL
        let url = "\(baseURL)/charge/stop"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "monitoringMode": mode
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if json["code"].intValue == 200 {
                            completion(.success(true))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "停止监控失败" : json["message"].stringValue
                            let error = NSError(domain: "StopMonitorError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                            completion(.failure(error))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 行程记录接口
    
    // 获取行程记录列表
    func getTripRecords(page: Int = 1, completion: @escaping (Result<TripRecordsResponse, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/get_trip_records"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "page": page
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        AF.request(url,
                   method: .post,
                   parameters: parameters,
                   encoding: JSONEncoding.default,
                   headers: headers)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    let json = JSON(jsonObject)
                    // 根据实际API返回格式调整判断逻辑
                    if json["code"].intValue == 200 {
                        let dataDict = json["data"]
                        let tripsArray = dataDict["trips"].arrayValue
                        let paginationDict = dataDict["pagination"]
                        
                        let trips = tripsArray.map { tripJson -> TripRecordData in
                            return TripRecordData(
                                id: tripJson["id"].intValue,
                                vin: tripJson["vin"].stringValue,
                                departureAddress: tripJson["departureAddress"].stringValue,
                                destinationAddress: tripJson["destinationAddress"].stringValue,
                                departureTime: tripJson["departureTime"].stringValue,
                                duration: tripJson["duration"].stringValue,
                                drivingMileage: tripJson["drivingMileage"].doubleValue,
                                consumedMileage: tripJson["consumedMileage"].doubleValue,
                                achievementRate: tripJson["achievementRate"].doubleValue,
                                powerConsumption: tripJson["powerConsumption"].doubleValue,
                                averageSpeed: tripJson["averageSpeed"].doubleValue,
                                energyEfficiency: tripJson["energyEfficiency"].doubleValue,
                                startTime: tripJson["startTime"].stringValue,
                                endTime: tripJson["endTime"].stringValue,
                                startLocation: tripJson["startLocation"].stringValue,
                                endLocation: tripJson["endLocation"].stringValue,
                                startLatLng: tripJson["startLatLng"].string,
                                endLatLng: tripJson["endLatLng"].string,
                                startMileage: tripJson["startMileage"].doubleValue,
                                endMileage: tripJson["endMileage"].doubleValue,
                                startRange: tripJson["startRange"].doubleValue,
                                endRange: tripJson["endRange"].doubleValue,
                                startSoc: tripJson["startSoc"].intValue,
                                endSoc: tripJson["endSoc"].intValue,
                                createdAt: tripJson["createdAt"].stringValue,
                                updatedAt: tripJson["updatedAt"].stringValue
                            )
                        }
                        
                        let pagination = PaginationInfo(
                            currentPage: paginationDict["current_page"].intValue,
                            totalPages: paginationDict["total_pages"].intValue,
                            totalCount: paginationDict["total_count"].intValue,
                            pageSize: paginationDict["page_size"].intValue,
                            hasNext: paginationDict["has_next"].boolValue,
                            hasPrev: paginationDict["has_prev"].boolValue
                        )
                        
                        let response = TripRecordsResponse(trips: trips, pagination: pagination)
                        completion(.success(response))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "TripRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "获取行程记录失败" : errorMsg])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - GPS逆编码功能
    /// 将GPS坐标转换为地址
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - completion: 完成回调，返回地址字符串
    private func reverseGeocodeLocation(latitude: Double, longitude: Double, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("GPS逆编码失败: \(error.localizedDescription)")
                    completion("未知地址")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("GPS逆编码未找到地址信息")
                    completion("未知地址")
                    return
                }
                
                var address = [placemark.subLocality, placemark.name]
                    .compactMap { $0 }
                    .joined(separator: "")
                
                if address.isEmpty {
                    address = "未知地址"
                }
                completion(address)
            }
        }
    }
}
