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
    
    private let baseURL = "https://yiweiauto.cn"
    
    private init() {}
    
    // MARK: - 登录接口
    func login(userCode: String, password: String, completion: @escaping (Result<LoginModel, Error>) -> Void) {
        let url = "\(baseURL)/api/jac-admin/admin/userBaseInformation/userLogin"
        
        let parameters: [String: Any] = [
            "userType": "1",
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
                    if json["code"].intValue == 0 {
                        let loginModel = LoginModel(json: json["data"])
                        completion(.success(loginModel))
                    } else {
                        let error = NSError(domain: "LoginError", code: json["code"].intValue, userInfo: [NSLocalizedDescriptionKey: json["msg"].stringValue])
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
    
    // MARK: - 用户信息接口
    func getUserInfo(phone: String, userId: String, tspUserId: String, aaaUserID: String, timaToken: String, identityParam: String, completion: @escaping (Result<[UserModel], Error>) -> Void) {
        let url = "\(baseURL)/api/jac-car-control/vehicle/find-vehicle-list"
        
        let parameters: [String: Any] = [
            "phone": phone,
            "userId": userId,
            "tspUserId": tspUserId,
            "aaaUserID": aaaUserID
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "timaToken": timaToken,
            "identityParam": identityParam
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
                        let userModels = json["data"].arrayValue.map { UserModel(json: $0) }
                        completion(.success(userModels))
                    } else {
                        let error = NSError(domain: "UserInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取用户信息失败"])
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
    func getCarInfo(vins: [String], timaToken: String, completion: @escaping (Result<CarModel, Error>) -> Void) {
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition"
        
        let parameters: [String: Any] = [
            "vins": vins
        ]
        
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
                    if json["returnSuccess"].boolValue {
                        let carModel = CarModel(json: json["data"])
                        completion(.success(carModel))
                    } else {
                        let error = NSError(domain: "CarInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: json["returnErrMsg"].stringValue.isEmpty ? "获取车辆信息失败" : json["returnErrMsg"].stringValue])
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
    func controlCarLock(operation: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "CarLockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 1关锁，2开锁
            "operationType": "LOCK"
        ]
        
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
    func controlAirConditioner(operation: Int, temperature: Int, duringTime: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "AirConditionerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control"
        
        let parameters: [String: Any] = [
            "operation": operation, // 2表示开启，1表示关闭
            "extParams": [
                "temperature": temperature,
                "duringTime": duringTime
            ],
            "vin": vin,
            "operationType": "INTELLIGENT_AIRCONDITIONER"
        ]
        
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
    func controlWindow(operation: Int, openLevel: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control"
        
        let parameters: [String: Any] = [
            "operation": operation, // 执行动作类型，1关闭，2开启
            "extParams": [
                "openLevel": openLevel // 开窗等级：0=关闭，2=完全打开
            ],
            "vin": vin,
            "operationType": "WINDOW"
        ]
        
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
    func findCar(completion: @escaping (Result<Bool, Error>) -> Void) {
        // 内部获取必要参数
        guard let vin = UserManager.shared.defaultVin,
              let timaToken = UserManager.shared.timaToken else {
            let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": 1,
            "operationType": "FIND_VEHICLE"
        ]
        
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
        
        let url = "https://api.dreamforge.top/car/add_charge"
        
        let parameters: [String: Any] = [
            "charge_kwh": charge_kwh,
            "token": timaToken,
            "vin": vin
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
        
        let url = "https://api.dreamforge.top/car/update_charge"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "token": timaToken,
            "push_token": push_token
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
        
        let url = "https://api.dreamforge.top/car/cancel_charge"
        
        let parameters: [String: Any] = [
            "vin": vin
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
        
        let url = "https://api.dreamforge.top/car/stop_charge"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "token": timaToken
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
        
        let url = "https://api.dreamforge.top/car/get_charge_status"
        
        let parameters: [String: Any] = [
            "token": timaToken,
            "vin": vin
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
        
        let url = "https://api.dreamforge.top/car/get_charge_list"
        
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
}
