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

// MARK: - App V3 Trip/Charge Sync Models

private func optionalInt64(_ json: JSON) -> Int64? {
    json.type == .null ? nil : json.int64
}

private func optionalInt(_ json: JSON) -> Int? {
    json.type == .null ? nil : json.int
}

private func optionalDouble(_ json: JSON) -> Double? {
    json.type == .null ? nil : json.double
}

struct TripSyncItem {
    let clientTripID: String
    let vin: String
    let status: Int
    let startTimeMs: Int64
    let endTimeMs: Int64?
    let startLat: Double?
    let startLon: Double?
    let endLat: Double?
    let endLon: Double?
    let distanceKm: Double?
    let drivingDurationMs: Int64?
    let energyConsumedKwh: Double?
    let parkedEnergyKwh: Double?
    let avgEnergyPer100Km: Double?
    let maxSpeed: Int64?
    let startSoc: Int64?
    let endSoc: Int64?
    let startRangeKm: Double?
    let endRangeKm: Double?
    let pointsCount: Int64?

    init?(json: JSON) {
        let clientTripID = json["client_trip_id"].stringValue
        let vin = json["vin"].stringValue
        guard !clientTripID.isEmpty, !vin.isEmpty, let startTimeMs = json["start_time"].int64 else {
            return nil
        }

        self.clientTripID = clientTripID
        self.vin = vin
        self.status = json["status"].intValue
        self.startTimeMs = startTimeMs
        self.endTimeMs = optionalInt64(json["end_time"])
        self.startLat = optionalDouble(json["start_lat"])
        self.startLon = optionalDouble(json["start_lon"])
        self.endLat = optionalDouble(json["end_lat"])
        self.endLon = optionalDouble(json["end_lon"])
        self.distanceKm = optionalDouble(json["distance_km"])
        self.drivingDurationMs = optionalInt64(json["driving_duration_ms"])
        self.energyConsumedKwh = optionalDouble(json["energy_consumed_kwh"])
        self.parkedEnergyKwh = optionalDouble(json["parked_energy_kwh"])
        self.avgEnergyPer100Km = optionalDouble(json["avg_energy_per_100_km"])
        self.maxSpeed = optionalInt64(json["max_speed"])
        self.startSoc = optionalInt64(json["start_soc"])
        self.endSoc = optionalInt64(json["end_soc"])
        self.startRangeKm = optionalDouble(json["start_range_km"])
        self.endRangeKm = optionalDouble(json["end_range_km"])
        self.pointsCount = optionalInt64(json["points_count"])
    }
}

struct TripPointItem {
    let clientTripID: String
    let vin: String
    let timestampMs: Int64
    let lat: Double
    let lon: Double
    let speed: Double
    let powerKw: Double
    let tripDistanceKm: Double?
    let soc: Int64?
    let remainingRangeKm: Double?

    init?(json: JSON) {
        let clientTripID = json["client_trip_id"].stringValue
        let vin = json["vin"].stringValue
        guard !clientTripID.isEmpty,
              !vin.isEmpty,
              let timestampMs = json["timestamp"].int64,
              let lat = json["lat"].double,
              let lon = json["lon"].double else {
            return nil
        }

        self.clientTripID = clientTripID
        self.vin = vin
        self.timestampMs = timestampMs
        self.lat = lat
        self.lon = lon
        self.speed = json["speed"].doubleValue
        self.powerKw = json["power_kw"].doubleValue
        self.tripDistanceKm = optionalDouble(json["trip_distance_km"])
        self.soc = optionalInt64(json["soc"])
        self.remainingRangeKm = optionalDouble(json["remaining_range_km"])
    }
}

struct TripSyncV3Response {
    let upserts: [TripSyncItem]
    let deletes: [String]
}

struct TripPointsV3Page {
    let vin: String
    let clientTripID: String
    let count: Int
    let nextTimestamp: Int64
    let hasMore: Bool
    let points: [TripPointItem]
}

struct ChargeSyncItem {
    let clientChargeID: String
    let vin: String
    let status: Int
    let startTimeMs: Int64
    let endTimeMs: Int64?
    let lat: Double?
    let lon: Double?
    let startSoc: Int64?
    let endSoc: Int64?
    let startRangeKm: Double?
    let endRangeKm: Double?
    let addedRangeKm: Double?
    let chargedEnergyKwh: Double?
    let pointsCount: Int64?

    init?(json: JSON) {
        let clientChargeID = json["client_charge_id"].stringValue
        let vin = json["vin"].stringValue
        guard !clientChargeID.isEmpty, !vin.isEmpty, let startTimeMs = json["start_time"].int64 else {
            return nil
        }

        self.clientChargeID = clientChargeID
        self.vin = vin
        self.status = json["status"].intValue
        self.startTimeMs = startTimeMs
        self.endTimeMs = optionalInt64(json["end_time"])
        self.lat = optionalDouble(json["lat"])
        self.lon = optionalDouble(json["lon"])
        self.startSoc = optionalInt64(json["start_soc"])
        self.endSoc = optionalInt64(json["end_soc"])
        self.startRangeKm = optionalDouble(json["start_range_km"])
        self.endRangeKm = optionalDouble(json["end_range_km"])
        self.addedRangeKm = optionalDouble(json["added_range_km"])
        self.chargedEnergyKwh = optionalDouble(json["charged_energy_kwh"])
        self.pointsCount = optionalInt64(json["points_count"])
    }
}

struct ChargePointItem {
    let clientChargeID: String
    let vin: String
    let timestampMs: Int64
    let voltage: Double
    let current: Double
    let powerKw: Double
    let soc: Int64?
    let remainingRangeKm: Double?

    init?(json: JSON) {
        let clientChargeID = json["client_charge_id"].stringValue
        let vin = json["vin"].stringValue
        guard !clientChargeID.isEmpty, !vin.isEmpty, let timestampMs = json["timestamp"].int64 else {
            return nil
        }

        self.clientChargeID = clientChargeID
        self.vin = vin
        self.timestampMs = timestampMs
        self.voltage = json["voltage"].doubleValue
        self.current = json["current"].doubleValue
        self.powerKw = json["power_kw"].doubleValue
        self.soc = optionalInt64(json["soc"])
        self.remainingRangeKm = optionalDouble(json["remaining_range_km"])
    }
}

struct ChargeSyncV3Response {
    let upserts: [ChargeSyncItem]
    let deletes: [String]
}

struct ChargePointsV3Page {
    let vin: String
    let clientChargeID: String
    let count: Int
    let nextTimestamp: Int64
    let hasMore: Bool
    let points: [ChargePointItem]
}

class NetworkManager: NSObject {
    static let shared = NetworkManager()

    private let baseURL = "https://pan3.dreamforge.top/api"

    private override init() {
        super.init()
    }

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
              let timaToken = UserManager.shared.timaToken,
              let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "LogoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/auth/logout"

        let parameters: [String: Any] = [
            "no": no,
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
    ///   - completion: 完成回调
    func syncVehicle(
        operationType: String,
        operation: Int? = nil,
        temperature: Int? = nil,
        duringTime: Int? = nil,
        openLevel: Int? = nil,
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
            "operationType": operationType
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

        var parameters: [String: Any] = [
            "vin": vin,
            "monitoringMode": mode
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

    // MARK: - 推送Token更新接口

    /// 更新推送Token
    /// - Parameters:
    ///   - pushToken: 推送Token
    ///   - completion: 完成回调
    func updatePushToken(pushToken: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "UpdatePushTokenError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/auth/updatePushToken"

        let parameters: [String: Any] = [
            "vin": vin,
            "pushToken": pushToken
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
                            let errorMsg = json["message"].stringValue.isEmpty ? "推送Token更新失败" : json["message"].stringValue
                            let error = NSError(domain: "UpdatePushTokenError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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
                                trackSource: tripJson["trackSource"].string,
                                energyConsumptionKwh: tripJson["energyConsumptionKwh"].double,
                                energyConsumptionPer100km: tripJson["energyConsumptionPer100km"].double,
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

    // MARK: - 充电数据同步接口

    /// 从服务器获取充电记录（包含data_points）
    /// - Parameters:
    ///   - limit: 限制获取数量（可选）
    ///   - completion: 完成回调
    func getChargeRecordsFromServer(limit: Int? = nil, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "ChargeRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        print("[getChargeRecordsFromServer] 准备请求 - VIN: \"\(vin)\", VIN长度: \(vin.count)")

        let url = "\(baseURL)/charge/records"

        var parameters: [String: Any] = [
            "vin": vin
        ]

        if let limit = limit {
            parameters["limit"] = limit
        }

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
                            let chargesArray = json["data"]["charges"].arrayValue.map { $0.dictionaryObject ?? [:] }
                            print("[getChargeRecordsFromServer] 成功获取 \(chargesArray.count) 条充电记录")
                            completion(.success(chargesArray))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "获取充电记录失败" : json["message"].stringValue
                            let error = NSError(domain: "ChargeRecordsError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    /// 确认充电数据同步完成，通知服务器删除数据
    /// - Parameters:
    ///   - chargeIds: 已同步的充电记录ID数组
    ///   - completion: 完成回调
    func confirmChargeSyncComplete(chargeIds: [Int], completion: @escaping (Result<[String: Int], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "SyncCompleteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/charge/sync-complete"

        let parameters: [String: Any] = [
            "vin": vin,
            "chargeIds": chargeIds
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
                            let deletedCharges = json["data"]["deletedCharges"].intValue
                            let deletedDataPoints = json["data"]["deletedDataPoints"].intValue

                            print("[confirmChargeSyncComplete] 服务器已删除 \(deletedCharges) 条充电记录, \(deletedDataPoints) 个数据点")

                            let result = [
                                "deletedCharges": deletedCharges,
                                "deletedDataPoints": deletedDataPoints
                            ]
                            completion(.success(result))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "确认同步失败" : json["message"].stringValue
                            let error = NSError(domain: "SyncCompleteError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    // MARK: - 充电数据 V2 同步接口

    /// V2: 从服务器获取增量充电记录（包含data_points）
    /// - Parameters:
    ///   - after: 获取此时间戳之后的记录
    ///   - completion: 完成回调
    func getChargeRecordsFromServerV2(after: String? = nil, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        // V2使用GET请求
        let url = "\(baseURL)/charge/sync-v2"

        var parameters: [String: Any] = [
            "vin": vin
        ]

        if let after = after {
            parameters["after"] = after
        }

        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]

        print("[Charge V2 Sync] 拉取请求: \(url) parameters: \(parameters)")

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)

                        if json["code"].intValue == 200 {
                            let chargesArray = json["data"]["charges"].arrayValue.map { $0.dictionaryObject ?? [:] }
                            print("[Charge V2 Sync] 成功获取 \(chargesArray.count) 条增量充电记录")
                            completion(.success(chargesArray))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "获取充电记录失败" : json["message"].stringValue
                            let error = NSError(domain: "ChargeRecordsError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    /// V2: 确认充电数据同步完成，通知服务器标记指定ID的充电记录为已同步
    /// - Parameters:
    ///   - chargeIDs: 已同步的充电记录ID数组
    ///   - completion: 完成回调
    func confirmChargeSyncCompleteV2(chargeIDs: [Int], completion: @escaping (Result<[String: Int], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeSyncCompleteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/charge/sync-v2/confirm"

        let parameters: [String: Any] = [
            "vin": vin,
            "charge_ids": chargeIDs
        ]

        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]

        print("[Charge V2 Confirm] 确认请求 (按ID): \(chargeIDs)")

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)

                        if json["code"].intValue == 200 {
                            let syncedCount = json["data"]["synced_count"].intValue
                            print("[Charge V2 Confirm] 服务器已标记 \(syncedCount) 条充电记录为已同步")

                            let result = [
                                "syncedCharges": syncedCount
                            ]
                            completion(.success(result))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "确认同步失败" : json["message"].stringValue
                            let error = NSError(domain: "ChargeSyncCompleteError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    // MARK: - 行程数据同步接口

    /// 从服务器获取行程记录（包含data_points）
    /// - Parameters:
    ///   - limit: 限制获取数量（可选）
    ///   - completion: 完成回调
    func getTripRecordsFromServer(limit: Int? = nil, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "TripRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            print("[getTripRecordsFromServer] 错误: 用户未登录或未绑定车辆")
            completion(.failure(error))
            return
        }

        print("[getTripRecordsFromServer] ========== 开始请求 ==========")
        print("[getTripRecordsFromServer] VIN: \"\(vin)\", VIN长度: \(vin.count)")
        print("[getTripRecordsFromServer] TimaToken: \(timaToken.prefix(20))...")

        let url = "\(baseURL)/trip/records"
        print("[getTripRecordsFromServer] URL: \(url)")

        var parameters: [String: Any] = [
            "vin": vin
        ]

        if let limit = limit {
            parameters["limit"] = limit
        }
        print("[getTripRecordsFromServer] 请求参数: \(parameters)")

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Timatoken": timaToken
        ]
        print("[getTripRecordsFromServer] 请求头: \(headers)")

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                print("[getTripRecordsFromServer] ========== 收到响应 ==========")
                print("[getTripRecordsFromServer] HTTP状态码: \(response.response?.statusCode ?? -1)")

                switch response.result {
                case .success(let data):
                    print("[getTripRecordsFromServer] 响应数据大小: \(data.count) bytes")
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("[getTripRecordsFromServer] 原始响应: \(rawString.prefix(500))...")
                    }
                    do {
                        let json = try JSON(data: data)
                        print("[getTripRecordsFromServer] JSON解析成功 - code: \(json["code"].intValue), message: \(json["message"].stringValue)")

                        if json["code"].intValue == 200 {
                            let tripsArray = json["data"]["trips"].arrayValue.map { $0.dictionaryObject ?? [:] }
                            print("[getTripRecordsFromServer] 成功获取 \(tripsArray.count) 条行程记录")
                            completion(.success(tripsArray))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "获取行程记录失败" : json["message"].stringValue
                            print("[getTripRecordsFromServer] 服务器返回错误: \(errorMsg)")
                            let error = NSError(domain: "TripRecordsError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                            completion(.failure(error))
                        }
                    } catch {
                        print("[getTripRecordsFromServer] JSON解析失败: \(error)")
                        completion(.failure(error))
                    }
                case .failure(let error):
                    print("[getTripRecordsFromServer] 网络请求失败: \(error)")
                    print("[getTripRecordsFromServer] 错误详情: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }

    /// 确认行程数据同步完成，通知服务器删除数据
    /// - Parameters:
    ///   - tripIds: 已同步的行程记录ID数组
    ///   - completion: 完成回调
    func confirmTripSyncComplete(tripIds: [Int], completion: @escaping (Result<[String: Int], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "TripSyncCompleteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/trip/sync-complete"

        let parameters: [String: Any] = [
            "vin": vin,
            "tripIds": tripIds
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
                            let deletedTrips = json["data"]["deletedTrips"].intValue
                            let deletedDataPoints = json["data"]["deletedDataPoints"].intValue

                            print("[confirmTripSyncComplete] 服务器已删除 \(deletedTrips) 条行程记录, \(deletedDataPoints) 个数据点")

                            let result = [
                                "deletedTrips": deletedTrips,
                                "deletedDataPoints": deletedDataPoints
                            ]
                            completion(.success(result))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "确认同步失败" : json["message"].stringValue
                            let error = NSError(domain: "TripSyncCompleteError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    // MARK: - V2 Sync API

    /// V2: 从服务器获取增量行程记录（包含data_points）
    /// - Parameters:
    ///   - after: 获取此时间戳之后的记录
    ///   - completion: 完成回调
    func getTripRecordsFromServerV2(after: String? = nil, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripRecordsError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        // V2使用GET请求
        let url = "\(baseURL)/trip/sync-v2"

        var parameters: [String: Any] = [
            "vin": vin
        ]

        if let after = after {
            parameters["after"] = after
        }

        // V2不需要Timatoken，或者如果需要也可带上
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]

        print("[V2 Sync] 拉取请求: \(url) parameters: \(parameters)")

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)

                        // 打印完整JSON以便调试
                        // print("[V2 Sync] Response: \(json)")

                        if json["code"].intValue == 200 {
                            let tripsArray = json["data"]["trips"].arrayValue.map { $0.dictionaryObject ?? [:] }
                            print("[V2 Sync] 成功获取 \(tripsArray.count) 条增量行程记录")
                            completion(.success(tripsArray))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "获取行程记录失败" : json["message"].stringValue
                            let error = NSError(domain: "TripRecordsError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    /// V2: 确认行程数据同步完成，通知服务器标记指定ID的行程为已同步
    /// - Parameters:
    ///   - tripIDs: 已同步的行程ID数组
    ///   - completion: 完成回调
    func confirmTripSyncCompleteV2(tripIDs: [Int], completion: @escaping (Result<[String: Int], Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripSyncCompleteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/trip/sync-v2/confirm"

        let parameters: [String: Any] = [
            "vin": vin,
            "trip_ids": tripIDs
        ]

        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]

        print("[V2 Confirm] 确认请求 (按ID): \(tripIDs)")

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)

                        if json["code"].intValue == 200 {
                            let syncedCount = json["data"]["synced_count"].intValue
                            print("[V2 Confirm] 服务器已标记 \(syncedCount) 条行程记录为已同步")

                            let result = [
                                "syncedTrips": syncedCount
                            ]
                            completion(.success(result))
                        } else {
                            let errorMsg = json["message"].stringValue.isEmpty ? "确认同步失败" : json["message"].stringValue
                            let error = NSError(domain: "TripSyncCompleteError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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

    // MARK: - App V3 Trip/Charge Sync API

    func getTripSyncV3(completion: @escaping (Result<TripSyncV3Response, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripSyncV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/trip/sync"
        let parameters: [String: Any] = ["vin": vin]
        let headers = appV3Headers()

        print("[Trip V3 Sync] 拉取请求: \(url) parameters: \(parameters)")

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "TripSyncV3Error", json: json, fallback: "获取行程记录失败")))
                            return
                        }

                        let upserts = json["data"]["upserts"].arrayValue.compactMap { TripSyncItem(json: $0) }
                        let deletes = json["data"]["deletes"].arrayValue.compactMap { $0.string }
                        completion(.success(TripSyncV3Response(upserts: upserts, deletes: deletes)))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    func getTripPointsV3(clientTripID: String, timestamp: Int64, completion: @escaping (Result<TripPointsV3Page, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripPointsV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/trip/points"
        let parameters: [String: Any] = [
            "vin": vin,
            "client_trip_id": clientTripID,
            "timestamp": timestamp
        ]
        let headers = appV3Headers()

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "TripPointsV3Error", json: json, fallback: "获取行程轨迹点失败")))
                            return
                        }

                        let data = json["data"]
                        let page = TripPointsV3Page(
                            vin: data["vin"].stringValue,
                            clientTripID: data["client_trip_id"].stringValue,
                            count: data["count"].intValue,
                            nextTimestamp: data["next_timestamp"].int64Value,
                            hasMore: data["has_more"].boolValue,
                            points: data["points"].arrayValue.compactMap { TripPointItem(json: $0) }
                        )
                        completion(.success(page))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    func ackTripSyncV3(clientTripIDs: [String], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "TripAckV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/trip/sync/ack"
        let parameters: [String: Any] = [
            "vin": vin,
            "client_trip_ids": clientTripIDs
        ]
        let headers = appV3Headers()

        print("[Trip V3 Ack] 确认请求: \(clientTripIDs)")

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "TripAckV3Error", json: json, fallback: "确认行程同步失败")))
                            return
                        }
                        completion(.success(true))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    func getChargeSyncV3(completion: @escaping (Result<ChargeSyncV3Response, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeSyncV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/charge/sync"
        let parameters: [String: Any] = ["vin": vin]
        let headers = appV3Headers()

        print("[Charge V3 Sync] 拉取请求: \(url) parameters: \(parameters)")

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "ChargeSyncV3Error", json: json, fallback: "获取充电记录失败")))
                            return
                        }

                        let upserts = json["data"]["upserts"].arrayValue.compactMap { ChargeSyncItem(json: $0) }
                        let deletes = json["data"]["deletes"].arrayValue.compactMap { $0.string }
                        completion(.success(ChargeSyncV3Response(upserts: upserts, deletes: deletes)))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    func getChargePointsV3(clientChargeID: String, timestamp: Int64, completion: @escaping (Result<ChargePointsV3Page, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargePointsV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/charge/points"
        let parameters: [String: Any] = [
            "vin": vin,
            "client_charge_id": clientChargeID,
            "timestamp": timestamp
        ]
        let headers = appV3Headers()

        AF.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "ChargePointsV3Error", json: json, fallback: "获取充电过程点失败")))
                            return
                        }

                        let data = json["data"]
                        let page = ChargePointsV3Page(
                            vin: data["vin"].stringValue,
                            clientChargeID: data["client_charge_id"].stringValue,
                            count: data["count"].intValue,
                            nextTimestamp: data["next_timestamp"].int64Value,
                            hasMore: data["has_more"].boolValue,
                            points: data["points"].arrayValue.compactMap { ChargePointItem(json: $0) }
                        )
                        completion(.success(page))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    func ackChargeSyncV3(clientChargeIDs: [String], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeAckV3Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }

        let url = "\(baseURL)/app/v3/charge/sync/ack"
        let parameters: [String: Any] = [
            "vin": vin,
            "client_charge_ids": clientChargeIDs
        ]
        let headers = appV3Headers()

        print("[Charge V3 Ack] 确认请求: \(clientChargeIDs)")

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        guard json["code"].intValue == 200 else {
                            completion(.failure(self.apiError(domain: "ChargeAckV3Error", json: json, fallback: "确认充电同步失败")))
                            return
                        }
                        completion(.success(true))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    private func apiError(domain: String, json: JSON, fallback: String) -> NSError {
        let message = json["message"].stringValue.isEmpty ? fallback : json["message"].stringValue
        let errorDetail = json["error"].stringValue
        let description = errorDetail.isEmpty ? message : "\(message): \(errorDetail)"
        return NSError(domain: domain, code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: description])
    }

    private func appV3Headers() -> HTTPHeaders {
        var headers: HTTPHeaders = ["Content-Type": "application/json"]
        if let timaToken = UserManager.shared.timaToken {
            headers.add(name: "Timatoken", value: timaToken)
        }
        return headers
    }
}

// MARK: - DNS 解析协议监控
extension NetworkManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        for metric in metrics.transactionMetrics {
            let dnsProtocol = metric.domainResolutionProtocol
            let protocolName: String
            switch dnsProtocol {
            case .unknown: protocolName = "未知"
            case .udp: protocolName = "UDP (传统DNS)"
            case .tcp: protocolName = "TCP"
            case .tls: protocolName = "TLS (DoT)"
            case .https: protocolName = "HTTPS (DoH) ✅"
            @unknown default: protocolName = "未知(\(dnsProtocol.rawValue))"
            }

            if let url = task.originalRequest?.url?.host {
                print("[DNS监控] \(url) -> \(protocolName)")
            }
        }
    }

    /// 测试 DNS 解析协议（调试用）
    func testDNSResolution() {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        guard let url = URL(string: "https://pan3.dreamforge.top/api/health") else { return }

        let task = session.dataTask(with: url) { _, _, error in
            if let error = error {
                print("[DNS测试] 请求失败: \(error.localizedDescription)")
            } else {
                print("[DNS测试] 请求成功")
            }
        }
        task.resume()
    }
}
