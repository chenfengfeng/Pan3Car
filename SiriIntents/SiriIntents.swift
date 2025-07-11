import AppIntents
import Foundation

// Intent扩展的NetworkManager，使用真实网络请求
class NetworkManager {
    static let shared = NetworkManager()
    
    private let baseURL = "https://yiweiauto.cn"
    
    private init() {}
    
    // MARK: - 获取用户认证信息
    private var timaToken: String? {
        return UserDefaults(suiteName: "group.com.feng.pan3")?.string(forKey: "timaToken")
    }
    
    private var defaultVin: String? {
        return UserDefaults(suiteName: "group.com.feng.pan3")?.string(forKey: "defaultVin")
    }
    
    // MARK: - 网络请求方法
    func findCar(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "FindCarError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control"
        
        let parameters: [String: Any] = [
            "vin": vin,
            "operation": 1,
            "operationType": "FIND_VEHICLE"
        ]
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    func controlCarLock(operation: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
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
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    func controlWindow(operation: Int, openLevel: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
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
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    func controlAirConditioner(operation: Int, temperature: Int, duringTime: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
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
        
        performRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    // MARK: - 获取车辆信息
    func getCarInfo(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let vin = defaultVin,
              let timaToken = timaToken else {
            let error = NSError(domain: "CarInfoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录或未绑定车辆"])
            completion(.failure(error))
            return
        }
        
        let url = "\(baseURL)/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition"
        
        let parameters: [String: Any] = [
            "vins": [vin]
        ]
        
        performCarInfoRequest(url: url, parameters: parameters, timaToken: timaToken, completion: completion)
    }
    
    // MARK: - 通用网络请求方法
    private func performRequest(url: String, parameters: [String: Any], timaToken: String, completion: @escaping (Result<Bool, Error>) -> Void) {
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
                    if let returnSuccess = jsonObject["returnSuccess"] as? Bool, returnSuccess {
                        completion(.success(true))
                    } else {
                        let errorMessage = jsonObject["returnErrMsg"] as? String ?? "操作失败"
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
        }.resume()
    }
    
    // MARK: - 车辆信息请求方法
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
                    if let returnSuccess = jsonObject["returnSuccess"] as? Bool, returnSuccess {
                        if let carData = jsonObject["data"] as? [String: Any] {
                            completion(.success(carData))
                        } else {
                            let error = NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "车辆数据格式错误"])
                            completion(.failure(error))
                        }
                    } else {
                        let errorMessage = jsonObject["returnErrMsg"] as? String ?? "获取车辆信息失败"
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
        }.resume()
    }
}

// MARK: - Enums

enum CarLockAction: String, AppEnum {
    case lock = "lock"
    case unlock = "unlock"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "车锁操作")
    static var caseDisplayRepresentations: [CarLockAction: DisplayRepresentation] = [
        .lock: "锁车",
        .unlock: "解锁"
    ]
}

enum WindowAction: String, AppEnum {
    case open = "open"
    case close = "close"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "车窗操作")
    static var caseDisplayRepresentations: [WindowAction: DisplayRepresentation] = [
        .open: "开窗",
        .close: "关窗"
    ]
}

enum AirConditionerAction: String, AppEnum {
    case turnOn = "turnOn"
    case turnOff = "turnOff"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "空调操作")
    static var caseDisplayRepresentations: [AirConditionerAction: DisplayRepresentation] = [
        .turnOn: "开启",
        .turnOff: "关闭"
    ]
}

enum TemperatureLevel: Int, AppEnum {
    case temp17 = 17
    case temp18 = 18
    case temp19 = 19
    case temp20 = 20
    case temp21 = 21
    case temp22 = 22
    case temp23 = 23
    case temp24 = 24
    case temp25 = 25
    case temp26 = 26
    case temp27 = 27
    case temp28 = 28
    case temp29 = 29
    case temp30 = 30
    case temp31 = 31
    case temp32 = 32
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "温度")
    static var caseDisplayRepresentations: [TemperatureLevel: DisplayRepresentation] = [
        .temp17: "速冷",
        .temp18: "18°C",
        .temp19: "19°C",
        .temp20: "20°C",
        .temp21: "21°C",
        .temp22: "22°C",
        .temp23: "23°C",
        .temp24: "24°C",
        .temp25: "25°C",
        .temp26: "26°C",
        .temp27: "27°C",
        .temp28: "28°C",
        .temp29: "29°C",
        .temp30: "30°C",
        .temp31: "31°C",
        .temp32: "速热"
    ]
}

// MARK: - App Intents

// 寻车鸣笛
struct FindCarIntent: AppIntent {
    static var title: LocalizedStringResource = "胖3寻车鸣笛"
    static var description = IntentDescription("让车辆发出鸣笛声以方便定位")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            NetworkManager.shared.findCar { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "车辆鸣笛成功，请注意听声音和观察闪灯")))
                case .failure(let error):
                    print("FindCarIntent error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 车锁控制
struct CarLockControlIntent: AppIntent {
    init() {}
    
    // 便捷构造器 —— 方便你在代码里手动创建
    init(action: CarLockAction) {
        self.init()
        self.action = action
    }
    static var title: LocalizedStringResource = "胖3车锁控制"
    static var description = IntentDescription("控制车辆锁定状态")
    
    @Parameter(title: "操作")
    var action: CarLockAction
    
    static var parameterSummary: some ParameterSummary {
        Summary("控制胖3\(\.$action)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .lock ? 1 : 2
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            NetworkManager.shared.controlCarLock(operation: operation) { result in
                switch result {
                case .success(_):
                    let message = action == .lock ? "车辆已锁定" : "车辆已解锁"
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 车窗控制
struct WindowControlIntent: AppIntent {
    init() {}
    
    // 便捷构造器 —— 方便你在代码里手动创建
    init(action: WindowAction) {
        self.init()
        self.action = action
    }
    static var title: LocalizedStringResource = "胖3车窗控制"
    static var description = IntentDescription("控制车窗开关状态")
    
    @Parameter(title: "操作")
    var action: WindowAction
    
    static var parameterSummary: some ParameterSummary {
        Summary("控制胖3\(\.$action)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .open ? 2 : 1
        let openLevel = action == .open ? 2 : 0
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            NetworkManager.shared.controlWindow(operation: operation, openLevel: openLevel) { result in
                switch result {
                case .success(_):
                    let message = action == .open ? "车窗已打开" : "车窗已关闭"
                      continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 空调控制
struct AirConditionerControlIntent: AppIntent {
    init() {}
    
    // 便捷构造器 —— 方便你在代码里手动创建
    init(action: AirConditionerAction) {
        self.init()
        self.action = action
    }
    static var title: LocalizedStringResource = "胖3空调控制"
    static var description = IntentDescription("控制车辆空调开关")
    
    @Parameter(title: "操作")
    var action: AirConditionerAction
    
    static var parameterSummary: some ParameterSummary {
        Summary("控制胖3\(\.$action)空调")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation = action == .turnOn ? 2 : 1
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            NetworkManager.shared.controlAirConditioner(operation: operation, temperature: 26, duringTime: 30) { result in
                switch result {
                case .success(_):
                      let message = action == .turnOn ? "空调已开启" : "空调已关闭"
                       continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 空调温度设置
struct SetAirConditionerTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "胖3空调温度设置"
    static var description = IntentDescription("开启车辆空调并设定温度")
    
    @Parameter(title: "温度")
    var temperature: TemperatureLevel
    
    static var parameterSummary: some ParameterSummary {
        Summary("将胖3空调温度设为\(\.$temperature)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            NetworkManager.shared.controlAirConditioner(operation: 2, temperature: temperature.rawValue, duringTime: 30) { result in
                switch result {
                case .success(_):
                    let tempDisplay = temperature == .temp17 ? "速冷" : (temperature == .temp32 ? "速热" : "\(temperature.rawValue)度")
                    continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: "空调已开启，温度设置为\(tempDisplay)")))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 智能车锁切换
struct ToggleCarLockIntent: AppIntent {
    static var title: LocalizedStringResource = "胖3智能车锁切换"
    static var description = IntentDescription("自动检测车锁状态并执行相反操作")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IntentResultContainer<Never, Never, Never, IntentDialog>, Error>) in
            // 首先获取车锁状态
            NetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let carData):
                    let mainLockStatus = carData["mainLockStatus"] as? Int ?? 0
                    let isLocked = mainLockStatus == 0 // 0表示锁定，1表示未锁定
                    
                    // 根据当前状态执行相反操作
                    let operation = isLocked ? 2 : 1 // 如果已锁定则解锁(2)，如果未锁定则锁定(1)
                    
                    NetworkManager.shared.controlCarLock(operation: operation) { lockResult in
                        switch lockResult {
                        case .success(_):
                            let message = isLocked ? "车辆已解锁" : "车辆已锁定"
                            continuation.resume(returning: .result(dialog: IntentDialog(stringLiteral: message)))
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// 车辆关键信息结构体
struct CarKeyInfo: Codable, Sendable {
    let remainingMileage: Int        // 剩余里程
    let soc: String                  // 电池电量百分比
    let isLocked: Bool               // 锁车状态 (true=锁定, false=未锁定)
    let windowsOpen: Bool            // 车窗状态 (true=有车窗开启, false=全部关闭)
    let airConditionerOn: Bool       // 空调状态 (true=空调开启的状态, false=关闭)
    
    init(remainingMileage: Int, soc: String, mainLockStatus: Int, acStatus: Int, 
         lfWindow: Int, rfWindow: Int, lrWindow: Int, rrWindow: Int) {
        self.remainingMileage = remainingMileage
        self.soc = soc
        self.isLocked = mainLockStatus == 0  // 0表示锁定
        self.airConditionerOn = acStatus == 1  // 1表示开启
        
        // 判断是否有任何车窗开启 (0=关闭, 1=开启)
        self.windowsOpen = lfWindow == 1 || rfWindow == 1 || lrWindow == 1 || rrWindow == 1
    }
}

// 小组件使用的车辆信息结构体
struct WidgetCarInfo: Codable {
    let remainingMileage: Int
    let soc: Int
    let isLocked: Bool
    let windowsOpen: Bool
    let airConditionerOn: Bool
    let lastUpdated: Date
}



// MARK: - App Shortcuts Provider

struct ShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] = [
        // 车锁控制
        AppShortcut(
            intent: CarLockControlIntent(action: .unlock),
            phrases: ["\(.applicationName) 解锁"],
            shortTitle: "解锁",
            systemImageName: "lock.open.fill"
        ),
        // 车锁控制
        AppShortcut(
            intent: CarLockControlIntent(action: .lock),
            phrases: ["\(.applicationName) 锁车", "\(.applicationName) 上锁", "\(.applicationName) 锁定", "\(.applicationName) 关锁"],
            shortTitle: "锁车",
            systemImageName: "lock.fill"
        ),
        // 车窗控制
        AppShortcut(
            intent: WindowControlIntent(action: .close),
            phrases: ["\(.applicationName) 关闭车窗"],
            shortTitle: "关闭车窗",
            systemImageName: "dock.arrow.up.rectangle"
        ),
        // 车窗控制
        AppShortcut(
            intent: WindowControlIntent(action: .open),
            phrases: ["\(.applicationName) 打开车窗"],
            shortTitle: "打开车窗",
            systemImageName: "dock.arrow.down.rectangle"
        ),
        // 空调控制
        AppShortcut(
            intent: AirConditionerControlIntent(action: .turnOn),
            phrases: ["\(.applicationName) 打开空调"],
            shortTitle: "打开空调",
            systemImageName: "fan"
        ),
        
        // 空调控制
        AppShortcut(
            intent: AirConditionerControlIntent(action: .turnOff),
            phrases: ["\(.applicationName) 关闭空调"],
            shortTitle: "关闭空调",
            systemImageName: "fan.slash"
        ),
        // 空调温度设置
        AppShortcut(
            intent: SetAirConditionerTemperatureIntent(),
            phrases: ["\(.applicationName) 设置空调温度", "\(.applicationName) 调节温度"],
            shortTitle: "设置温度",
            systemImageName: "thermometer"
        ),
        // 寻车鸣笛
        AppShortcut(
            intent: FindCarIntent(),
            phrases: ["\(.applicationName) 鸣笛", "\(.applicationName) 找车"],
            shortTitle: "找车",
            systemImageName: "location.circle"
        ),
        // 智能切换锁车状态
        AppShortcut(
            intent: ToggleCarLockIntent(),
            phrases: ["\(.applicationName) 切换锁车"],
            shortTitle: "切换锁车",
            systemImageName: "lock.open.rotation"
        )
    ]
}
