//
//  CarWidget.swift
//  CarWidget
//
//  Created by Feng on 2025/7/6.
//

import SwiftUI
import WidgetKit
import AppIntents

@available(iOSApplicationExtension 17.0, *)
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), carInfo: CarInfo.placeholder)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, carInfo: CarInfo.placeholder)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        
        // 检查认证信息是否存在
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        
        var entry: SimpleEntry
        
        // 如果没有认证信息，显示错误状态
        if timaToken == nil || defaultVin == nil {
            entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: nil, errorMessage: "请先在主应用中登录")
        } else {
            // 尝试获取最新车辆信息
            var carInfo = await getLatestCarInfo()
            if let carInfo = carInfo {
                WidgetDataManager.shared.updateCarInfo(carInfo)
                entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: carInfo)
            } else {
                // 如果网络请求失败，尝试使用本地缓存数据
                carInfo = WidgetDataManager.shared.getCurrentCarInfo()
                if let carInfo = carInfo {
                    entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: carInfo)
                } else {
                    // 没有缓存数据，显示错误状态
                    entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: nil, errorMessage: "无法获取车辆数据")
                }
            }
        }
        
        // 设置下次更新时间为15分钟后
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    // 获取最新车辆信息的辅助方法
    private func getLatestCarInfo() async -> CarInfo? {
        return try? await withCheckedThrowingContinuation { continuation in
            // 先检查认证信息是否存在
            let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
            let timaToken = userDefaults?.string(forKey: "timaToken")
            let defaultVin = userDefaults?.string(forKey: "defaultVin") 
            
            print("[Widget Debug] timaToken存在: \(timaToken != nil), defaultVin存在: \(defaultVin != nil)")
            
            WidgetNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let carData):
                    print("[Widget Debug] 网络请求成功，返回数据: \(carData)")
                    
                    // 解析SOC
                    let socString = carData["soc"] as? String ?? "0"
                    let soc = Int(socString) ?? 0
                    
                    // acOnMile表示当前可行驶里程（剩余续航）
                    let remainingMileage = carData["acOnMile"] as? Int ?? 0
                    
                    print("[Widget Debug] 解析结果 - SOC: \(soc), 剩余里程: \(remainingMileage)")
                    
                    let mainLockStatus = carData["mainLockStatus"] as? Int ?? 0
                    let acStatus = carData["acStatus"] as? Int ?? 0
                    let lfWindow = carData["lfWindowOpen"] as? Int ?? 0
                    let rfWindow = carData["rfWindowOpen"] as? Int ?? 0
                    let lrWindow = carData["lrWindowOpen"] as? Int ?? 0
                    let rrWindow = carData["rrWindowOpen"] as? Int ?? 0
                    let topWindow = carData["topWindowOpen"] as? Int ?? 0
                    let isCharge = carData["chgStatus"] as? Int ?? 2
                    
                    let carInfo = CarInfo(
                        remainingMileage: remainingMileage,
                        soc: soc,
                        isLocked: mainLockStatus == 0,
                        windowsOpen: lfWindow == 1 || rfWindow == 1 || lrWindow == 1 || rrWindow == 1 || topWindow == 1,
                        isCharge: isCharge != 2,
                        airConditionerOn: acStatus == 1,
                        lastUpdated: Date()
                    )
                    continuation.resume(returning: carInfo)
                case .failure(let error):
                    print("[Widget Debug] 网络请求失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let carInfo: CarInfo?
    let errorMessage: String?
    
    init(date: Date, configuration: ConfigurationAppIntent, carInfo: CarInfo?, errorMessage: String? = nil) {
        self.date = date
        self.configuration = configuration
        self.carInfo = carInfo
        self.errorMessage = errorMessage
    }
}

@available(iOSApplicationExtension 17.0, *)
struct CarWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        GeometryReader { geometry in
            if let errorMessage = entry.errorMessage {
                // 错误状态显示
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text("请检查网络连接或重新登录")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            } else if let carInfo = entry.carInfo {
                // 正常状态显示
                VStack(spacing: 0) {
                    // 主要内容区域
                    ZStack {
                        // 顶部信息区域
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    // 剩余里程
                                    HStack(alignment: .bottom, spacing: 2) {
                                        Text("\(carInfo.remainingMileage)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("km")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .offset(y: -3)
                                    }
                                    
                                    // SOC进度条
                                    ProgressView(value: Double(carInfo.soc), total: 100)
                                        .progressViewStyle(LinearProgressViewStyle(tint: socColor(for: carInfo.soc)))
                                        .frame(width: 80, height: 4)
                                    
                                    // 更新时间
                                    Text("更新于 \(carInfo.lastUpdated, formatter: timeFormatter)")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                // 刷新按钮
                                Button(intent: RefreshCarInfoIntent()) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 0)
                            .padding(.top, 0)
                            
                            Spacer()
                        }
                    }
                    
                    // 底部控制按钮区域 - 不受safe area保护
                    HStack(spacing: 0) {
                        // 车锁按钮
                        ControlButton(
                            icon: carInfo.isLocked ? "lock.fill" : "lock.open.fill",
                            title: carInfo.isLocked ? "已锁车" : "已解锁",
                            isActive: carInfo.isLocked,
                            intent: CarLockControlIntent(action: carInfo.isLocked ? .unlock : .lock)
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 空调按钮
                        ControlButton(
                            icon: carInfo.airConditionerOn ? "fan" : "fan.slash",
                            title: carInfo.airConditionerOn ? "空调开" : "空调关",
                            isActive: carInfo.airConditionerOn,
                            intent: AirConditionerControlIntent(action: carInfo.airConditionerOn ? .turnOff : .turnOn)
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 车窗按钮
                        ControlButton(
                            icon: carInfo.windowsOpen ? "dock.arrow.up.rectangle" : "dock.arrow.down.rectangle",
                            title: carInfo.windowsOpen ? "窗已开" : "窗已关",
                            isActive: carInfo.windowsOpen,
                            intent: WindowControlIntent(action: carInfo.windowsOpen ? .close : .open)
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 鸣笛按钮
                        ControlButton(
                            icon: "location.circle",
                            title: "寻车",
                            isActive: false,
                            intent: FindCarIntent()
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 30)
                }
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func socColor(for soc: Int) -> Color {
        if soc < 10 {
            return .red
        } else if soc < 20 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let intent: any AppIntent
    
    var body: some View {
        Button(intent: intent) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Widget Network Manager

// Widget扩展的NetworkManager，使用真实网络请求
class WidgetNetworkManager {
    static let shared = WidgetNetworkManager()
    
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

@available(iOSApplicationExtension 17.0, *)
struct CarWidget: Widget {
    let kind: String = "CarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CarWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Image(entry.carInfo?.isCharge == true ? "my_car_charge" : "my_car")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
        }
        .configurationDisplayName("车辆控制")
        .description("显示车辆状态并提供快速控制")
        .supportedFamilies([.systemMedium])
    }
}

@available(iOSApplicationExtension 17.0, *)
#Preview(as: .systemMedium) {
    CarWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), carInfo: CarInfo.placeholder)
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), carInfo: nil, errorMessage: "请先在主应用中登录")
}
