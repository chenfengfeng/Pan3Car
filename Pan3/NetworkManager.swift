//
//  NetworkManager.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import Foundation
import Alamofire
import SwiftyJSON

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
    
    private let baseURL = "https://car.dreamforge.top"
    
    private init() {}
    
    // 获取当前服务器类型
    private func getServerType() -> String {
        return UserDefaults.standard.string(forKey: "ServerType") ?? "main"
    }
    
    // 根据服务器类型获取参数
    private func getServerParameter() -> String? {
        let serverType = getServerType()
        return serverType == "spare" ? "spare" : nil
    }
    
    // MARK: - 登录接口
    func login(userCode: String, password: String, completion: @escaping (Result<AuthResponseModel, Error>) -> Void) {
        // 使用本地服务器的认证接口
        let url = "\(baseURL)/auth"
        
        var parameters: [String: Any] = [
            "userCode": userCode,
            "password": password
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
        
        let url = "\(baseURL)/login_out"
        
        var parameters: [String: Any] = [
            "no": no,
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
    func getInfo(completion: @escaping (Result<JSON, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "CarInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/info"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "timaToken": timaToken
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
                    if json["code"].intValue == 200 {
                        completion(.success(json["data"]))
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
    
    // 控制车锁
    func energyLock(operation: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "CarLockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/energy"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 1关锁，2开锁
            "operationType": "LOCK",
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                    if json["returnSuccess"].boolValue {
                        completion(.success(true))
                    } else {
                        let error = NSError(domain: "CarLockError", code: -1, userInfo: [NSLocalizedDescriptionKey: json["returnErrMsg"].stringValue.isEmpty ? "车锁控制失败" : json["returnErrMsg"].stringValue])
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
    
    // 控制空调
    func energyAirConditioner(operation: Int, temperature: Int, duringTime: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "AirConditionerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/energy"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 2表示开启，1表示关闭
            "operationType": "INTELLIGENT_AIRCONDITIONER",
            "temperature": temperature,
            "duringTime": duringTime,
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                    if json["returnSuccess"].boolValue {
                        completion(.success(true))
                    } else {
                        let error = NSError(domain: "AirConditionerError", code: -1, userInfo: [NSLocalizedDescriptionKey: json["returnErrMsg"].stringValue.isEmpty ? "空调控制失败" : json["returnErrMsg"].stringValue])
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
    
    // 控制车窗
    func energyWindow(operation: Int, openLevel: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/energy"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 执行动作类型，1关闭，2开启
            "operationType": "WINDOW",
            "openLevel": openLevel,
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                    if json["returnSuccess"].boolValue {
                        completion(.success(true))
                    } else {
                        let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: json["returnErrMsg"].stringValue.isEmpty ? "车窗控制失败" : json["returnErrMsg"].stringValue])
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
    
    // 鸣笛寻车
    func energyFind(completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/energy"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "operationType": "FIND_VEHICLE",
            "timaToken": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                    if json["returnSuccess"].boolValue {
                        completion(.success(true))
                    } else {
                        let error = NSError(domain: "findCarError", code: -1, userInfo: [NSLocalizedDescriptionKey: json["returnErrMsg"].stringValue.isEmpty ? "鸣笛失败" : json["returnErrMsg"].stringValue])
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
    // 创建自动充电任务
    func startChargeTask(charge_kwh: Float, completion: @escaping (Result<ChargeStatusResponse, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/add_charge"
        
        var parameters: [String: Any] = [
            "charge_kwh": charge_kwh,
            "token": timaToken,
            "vin": vin
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        // 如果有正在运行的任务，解析任务详情
                        let taskJson = json["data"]
                        let id = taskJson["id"].intValue
                        let vin = taskJson["vin"].stringValue
                        let initialKwh = taskJson["initialKwh"].floatValue
                        let targetKwh = taskJson["targetKwh"].floatValue
                        let chargedKwh = taskJson["chargedKwh"].floatValue
                        let initialKm = taskJson["initialKm"].floatValue
                        let targetKm = taskJson["targetKm"].floatValue
                        let status = taskJson["status"].stringValue
                        let message = taskJson["message"].stringValue
                        let createdAt = taskJson["createTime"].stringValue
                        
                        let task = ChargeTaskModel(
                            id: id,
                            vin: vin,
                            initialKwh: initialKwh,
                            targetKwh: targetKwh,
                            chargedKwh: chargedKwh,
                            initialKm: initialKm,
                            targetKm: targetKm,
                            status: status,
                            message: message,
                            createdAt: createdAt,
                            finishTime: nil
                        )
                        
                        let response = ChargeStatusResponse(hasRunningTask: true, task: task)
                        completion(.success(response))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "按价格充电失败" : errorMsg])
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
    
    // 更新实时活动推送token
    func updateChargeTask(push_token: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/update_charge"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "token": timaToken,
            "push_token": push_token
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        completion(.success(true))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "取消充电失败" : errorMsg])
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
    
    // 取消充电
    func cancelChargeTask(completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/cancel_charge"
        
        var parameters: [String: Any] = [
            "vin": vin
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        completion(.success(true))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "取消充电失败" : errorMsg])
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
    
    // 停止充电
    func stopCharge(completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/stop_charge"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "token": timaToken
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        completion(.success(true))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "停止充电失败" : errorMsg])
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
    
    // 获取充电任务状态
    func getChargeStatus(completion: @escaping (Result<ChargeStatusResponse, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/get_charge_status"
        
        var parameters: [String: Any] = [
            "token": timaToken,
            "vin": vin
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        let hasRunningTask = json["data"]["has_running_task"].boolValue
                        var task: ChargeTaskModel? = nil
                        
                        // 如果有正在运行的任务，解析任务详情
                        if hasRunningTask, let taskJson = json["data"]["task"].dictionary {
                            let id = taskJson["id"]?.intValue ?? 0
                            let vin = taskJson["vin"]?.stringValue ?? ""
                            let initialKwh = taskJson["initialKwh"]?.floatValue ?? 0.0
                            let targetKwh = taskJson["targetKwh"]?.floatValue ?? 0.0
                            let chargedKwh = taskJson["chargedKwh"]?.floatValue ?? 0.0
                            let initialKm = taskJson["initialKm"]?.floatValue ?? 0.0
                            let targetKm = taskJson["targetKm"]?.floatValue ?? 0.0
                            let status = taskJson["status"]?.stringValue ?? ""
                            let createdAt = taskJson["createTime"]?.stringValue ?? ""
                            
                            task = ChargeTaskModel(
                                id: id,
                                vin: vin,
                                initialKwh: initialKwh,
                                targetKwh: targetKwh,
                                chargedKwh: chargedKwh,
                                initialKm: initialKm,
                                targetKm: targetKm,
                                status: status,
                                message: taskJson["message"]?.string,
                                createdAt: createdAt,
                                finishTime: taskJson["finishTime"]?.string
                            )
                        }
                        
                        let response = ChargeStatusResponse(hasRunningTask: hasRunningTask, task: task)
                        completion(.success(response))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "获取充电状态失败" : errorMsg])
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
    
    // 获取充电列表
    func getChargeTaskList(page: Int = 1, completion: @escaping (Result<ChargeListResponse, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin else {
            let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/get_charge_list"
        
        var parameters: [String: Any] = [
            "vin": vin,
            "page": page
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                        let tasksArray = dataDict["tasks"].arrayValue
                        let paginationDict = dataDict["pagination"]
                        
                        let tasks = tasksArray.map { taskJson -> ChargeTaskModel in
                            let id = taskJson["id"].intValue
                            let vin = taskJson["vin"].stringValue
                            let initialKwh = taskJson["initialKwh"].floatValue
                            let targetKwh = taskJson["targetKwh"].floatValue
                            let chargedKwh = taskJson["chargedKwh"].floatValue
                            let initialKm = taskJson["initialKm"].floatValue
                            let targetKm = taskJson["targetKm"].floatValue
                            let status = taskJson["status"].stringValue
                            let createdAt = taskJson["createTime"].stringValue
                            
                            return ChargeTaskModel(
                                id: id,
                                vin: vin,
                                initialKwh: initialKwh,
                                targetKwh: targetKwh,
                                chargedKwh: chargedKwh,
                                initialKm: initialKm,
                                targetKm: targetKm,
                                status: status,
                                message: taskJson["message"].string,
                                createdAt: createdAt,
                                finishTime: taskJson["finishTime"].string
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
                        
                        let response = ChargeListResponse(tasks: tasks, pagination: pagination)
                        completion(.success(response))
                    } else {
                        let errorMsg = json["message"].stringValue.isEmpty ? json["msg"].stringValue : json["message"].stringValue
                        let error = NSError(domain: "ChargeError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "获取充电列表失败" : errorMsg])
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
        
        var parameters: [String: Any] = [
            "vin": vin,
            "page": page
        ]
        
        // 添加服务器参数
        if let serverParam = getServerParameter() {
            parameters["server"] = serverParam
        }
        
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
                                departureAddress: tripJson["departureAddress"].stringValue,
                                destinationAddress: tripJson["destinationAddress"].stringValue,
                                departureTime: tripJson["departureTime"].stringValue,
                                duration: tripJson["duration"].stringValue,
                                drivingMileage: tripJson["drivingMileage"].doubleValue,
                                consumedMileage: tripJson["consumedMileage"].doubleValue,
                                achievementRate: tripJson["achievementRate"].doubleValue,
                                powerConsumption: tripJson["powerConsumption"].doubleValue,
                                averageSpeed: tripJson["averageSpeed"].doubleValue,
                                energyEfficiency: tripJson["energyEfficiency"].doubleValue
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
}
