//
//  SharedNetworkManager.swift
//  Pan3Car
//
//  Created by AI Assistant on 2024
//

import Foundation
#if os(watchOS)
import WatchConnectivity
#endif

/// 共享网络管理器，支持多Target复用（主应用、小组件、Watch等）
class SharedNetworkManager {
    static let shared = SharedNetworkManager()
    
    private let baseURL = "https://pan3.dreamforge.top/api"
    
    // 请求频率控制
    private var lastInfoRequestTime: Date = Date(timeIntervalSince1970: 0)
    private let minRequestInterval: TimeInterval = 3.0 // 最小请求间隔3秒
    private let requestQueue = DispatchQueue(label: "shared.network.queue", qos: .userInitiated)
    
    // 请求去重机制
    private var isInfoRequestInProgress = false
    private var pendingInfoCompletions: [(Result<[String: Any], Error>) -> Void] = []
    
    private init() {}
    
    // MARK: - 获取用户认证信息
    private var timaToken: String? {
        #if os(watchOS)
        // 在Watch应用中，从WatchConnectivityManager获取token
        return WatchConnectivityManager.shared.getCurrentToken()
        #else
        // 在iPhone应用中，从App Groups获取
        return UserDefaults(suiteName: "group.com.feng.pan3")?.string(forKey: "timaToken")
        #endif
    }
    
    private var defaultVin: String? {
        #if os(watchOS)
        // 在Watch应用中，从WatchConnectivityManager获取vin
        return WatchConnectivityManager.shared.getCurrentVin()
        #else
        // 在iPhone应用中，从App Groups获取
        return UserDefaults(suiteName: "group.com.feng.pan3")?.string(forKey: "defaultVin")
        #endif
    }
    
    private var pushToken: String? {
        #if os(watchOS)
        // 在Watch应用中，从WatchConnectivityManager获取pushToken
        return WatchConnectivityManager.shared.getCurrentPushToken()
        #else
        // 在iPhone应用中，从App Groups获取
        return UserDefaults(suiteName: "group.com.feng.pan3")?.string(forKey: "pushToken")
        #endif
    }
    
    private var presetTemperature: Int {
        #if os(watchOS)
        // 在Watch应用中，从WatchConnectivityManager获取预设温度
        // 如果Watch端没有实现温度同步，使用默认值26度
        return 26
        #else
        // 在iPhone应用中，从App Groups获取预设温度，如果没有设置则使用默认值26度
        return UserDefaults(suiteName: "group.com.feng.pan3")?.integer(forKey: "PresetTemperature") ?? 26
        #endif
    }
    
    // MARK: - 车辆控制方法（使用energy端点）
    
    /// 车锁控制
    func energyLock(operation: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "CarLockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/sync"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 1关锁，2开锁
            "operationType": "LOCK",
            "pushToken": pushToken ?? ""
        ]
        
        print("[Shared Debug] 执行远程锁操作：\(operation)")
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    /// 车窗控制
    func energyWindow(operation: Int, openLevel: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "WindowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/sync"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 执行动作类型，1关闭，2开启
            "operationType": "WINDOW",
            "openLevel": openLevel, // 开窗等级：0=关闭，2=完全打开
            "pushToken": pushToken ?? ""
        ]
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    /// 空调控制
    func energyAirConditioner(operation: Int, temperature: Int? = nil, duringTime: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "AirConditionerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/sync"
        
        // 如果没有传入温度参数，使用预设温度
        let actualTemperature = temperature ?? presetTemperature
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": operation, // 2表示开启，1表示关闭
            "operationType": "INTELLIGENT_AIRCONDITIONER",
            "temperature": actualTemperature,
            "duringTime": duringTime,
            "pushToken": pushToken ?? ""
        ]
        
        print("[Shared Debug] 空调控制 - 操作: \(operation), 温度: \(actualTemperature)°C (预设温度: \(presetTemperature)°C)")
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    /// 寻车功能
    func findCar(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "FindCarError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/car/sync"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operationType": "FIND_VEHICLE",
            "pushToken": pushToken ?? ""
        ]
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    // MARK: - 获取车辆信息
    
    /// 获取车辆信息（带频率控制和请求去重）
    func getCarInfo(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "CarInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        requestQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 如果已有请求在进行中，将回调加入等待队列
            if self.isInfoRequestInProgress {
                print("[Shared Debug] [\(Date())] 检测到重复请求，加入等待队列")
                self.pendingInfoCompletions.append(completion)
                return
            }
            
            let now = Date()
            let timeSinceLastRequest = now.timeIntervalSince(self.lastInfoRequestTime)
            
            if timeSinceLastRequest < self.minRequestInterval {
                let waitTime = self.minRequestInterval - timeSinceLastRequest
                print("[Shared Debug] [\(Date())] 请求过于频繁，等待 \(waitTime) 秒")
                
                // 将当前请求也加入等待队列
                self.pendingInfoCompletions.append(completion)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                    // 延迟执行时再次检查是否已有请求在进行中
                    self.requestQueue.async {
                        if !self.isInfoRequestInProgress {
                            DispatchQueue.main.async {
                                self.performActualInfoRequest(vin: vin, timaToken: timaToken)
                            }
                        } else {
                            print("[Shared Debug] [\(Date())] 延迟执行时发现已有请求在进行中，跳过")
                        }
                    }
                }
            } else {
                // 将当前请求加入等待队列
                self.pendingInfoCompletions.append(completion)
                
                DispatchQueue.main.async {
                    self.performActualInfoRequest(vin: vin, timaToken: timaToken)
                }
            }
        }
    }
    
    private func performActualInfoRequest(vin: String, timaToken: String) {
        // 标记请求开始
        isInfoRequestInProgress = true
        lastInfoRequestTime = Date()
        print("[Shared Debug] 执行info请求，时间: \(lastInfoRequestTime)，等待队列数量: \(pendingInfoCompletions.count)")
        
        let url = "\(baseURL)/car/info"
        
        let parameters: [String: Any] = [
            "vin": vin
        ]
        
        performCarInfoRequest(url: url, parameters: parameters, timaToken: timaToken) { [weak self] result in
            guard let self = self else { return }
            
            // 通知所有等待的回调
            let completions = self.pendingInfoCompletions
            self.pendingInfoCompletions.removeAll()
            self.isInfoRequestInProgress = false
            
            print("[Shared Debug] info请求完成，通知 \(completions.count) 个等待的回调")
            
            for completion in completions {
                completion(result)
            }
        }
    }
    
    // MARK: - 通用网络请求方法
    
    /// 通用请求方法（用于car/sync端点）
    private func performRequest(url: String, parameters: [String: Any], timaToken: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let requestURL = URL(string: url) else {
            let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(timaToken, forHTTPHeaderField: "timaToken")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])
                completion(.failure(error))
                return
            }
            
            DispatchQueue.main.async {
                do {
                    print("收到接口请求回调")
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let code = jsonObject["code"] as? Int, code == 200 {
                            completion(.success(jsonObject))
                        } else {
                            let errorMessage = jsonObject["message"] as? String ?? "操作失败"
                            let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            completion(.failure(error))
                        }
                    } else {
                        let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// 车辆信息请求方法（用于info端点）
    private func performCarInfoRequest(url: String, parameters: [String: Any], timaToken: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let requestURL = URL(string: url) else {
            let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(timaToken, forHTTPHeaderField: "timaToken")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])
                completion(.failure(error))
                return
            }
            
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let code = jsonObject["code"] as? Int, code == 200 {
                        if let data = jsonObject["data"] as? [String: Any] {
                            completion(.success(data))
                        } else {
                            let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "车辆数据格式错误"])
                            completion(.failure(error))
                        }
                    } else {
                        if let code = jsonObject["returnSuccess"] as? Int, code == 1 {
                            completion(.success(jsonObject))
                        } else {
                            let errorMessage = jsonObject["message"] as? String ?? "获取车辆信息失败"
                            let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            completion(.failure(error))
                        }
                    }
                } else {
                    let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - 高德地图逆地理编码
    
    /// 获取格式化地址（使用高德地图逆地理编码API）
    func getFormattedAddress(latitude: String, longitude: String, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = "ad43794c805061ae25622bc72c8f4763"
        let urlString = "https://restapi.amap.com/v3/geocode/regeo?key=\(apiKey)&location=\(longitude),\(latitude)&radius=1000&extensions=base"
        
        guard let requestURL = URL(string: urlString) else {
            let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])
                completion(.failure(error))
                return
            }
            
            DispatchQueue.main.async {
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let status = jsonObject["status"] as? String, status == "1" {
                            if let regeocode = jsonObject["regeocode"] as? [String: Any],
                               let formattedAddress = regeocode["formatted_address"] as? String {
                                completion(.success(formattedAddress))
                            } else {
                                let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "地址数据格式错误"])
                                completion(.failure(error))
                            }
                        } else {
                            let errorMessage = jsonObject["info"] as? String ?? "获取地址失败"
                            let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            completion(.failure(error))
                        }
                    } else {
                        let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
