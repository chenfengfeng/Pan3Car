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
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        
        // 没有缓存数据，显示错误状态
        var entry: SimpleEntry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: nil, errorMessage: "无法获取车辆数据")
        
        // 如果没有认证信息，显示错误状态
        if timaToken == nil || defaultVin == nil {
            entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: nil, errorMessage: "请先在主应用中登录")
        } else {
            // 尝试获取最新车辆信息
            do {
                if let carInfo = try await getLatestCarInfo() {
                    WidgetDataManager.shared.updateCarInfo(carInfo)
                    entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: carInfo)
                }
            } catch {
                print("[Widget Debug] 获取车辆信息失败: \(error.localizedDescription)")
                // 检查是否是认证失败
                if error.localizedDescription.contains("Authentication failure") {
                    entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: nil, errorMessage: "认证失败，请重新登录")
                } else {
                    // 其他网络错误，尝试使用本地缓存数据
                    let carInfo = WidgetDataManager.shared.getCachedCarInfo()
                    if let carInfo = carInfo {
                        entry = SimpleEntry(date: currentDate, configuration: configuration, carInfo: carInfo)
                    }
                }
            }
        }
        
        // 设置下次更新时间为15分钟后
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    // 获取最新车辆信息的辅助方法
    private func getLatestCarInfo() async throws -> CarInfo? {
        return try? await withCheckedThrowingContinuation { continuation in
            // 先检查认证信息是否存在
            let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
            let defaultVin = userDefaults?.string(forKey: "defaultVin")
            let timaToken = userDefaults?.string(forKey: "timaToken")
            
            print("[Widget Debug] timaToken存在: \(timaToken != nil), defaultVin存在: \(defaultVin != nil)")
            
            SharedNetworkManager.shared.getCarInfo { result in
                switch result {
                case .success(let carData):
                    let carInfo = CarInfo.parseCarInfo(from: carData)
                    
                    print("[Widget Debug] 解析结果 - SOC: \(carInfo.soc), 剩余里程: \(carInfo.remainingMileage)")
                    
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
                                    ZStack(alignment: .leading) {
                                        // 灰色背景进度条
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 4)
                                            .cornerRadius(2)
                                        
                                        // 实际进度条
                                        Rectangle()
                                            .fill(socColor(for: carInfo.soc))
                                            .frame(width: 80 * (Double(carInfo.soc) / 100.0), height: 4)
                                            .cornerRadius(2)
                                    }
                                    if carInfo.isCharge {
                                        HStack{
                                            // 更新时间
                                            Text("正在充电中")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            // 更新时间
                                            Text("预计 \(formatMinutes(carInfo.chgLeftTime))")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }else{
                                        // 更新时间
                                        Text("更新于 \(carInfo.lastUpdated, formatter: timeFormatter)")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                
                                Spacer()
                                
                                // 刷新按钮
                                Button(intent: GetWidgetCarInfoIntent()) {
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
                    // 检查是否启用调试模式来控制按钮功能
                    let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
                    let shouldEnableDebug = userDefaults?.bool(forKey: "shouldEnableDebug") ?? false
                    
                    HStack(spacing: 0) {
                        // 车锁按钮
                        ControlButton(
                            icon: carInfo.isLocked ? "lock.fill" : "lock.open.fill",
                            title: carInfo.isLocked ? "已锁车" : "已解锁",
                            isActive: carInfo.isLocked,
                            intent: GetSelectLockStatusIntent(action: carInfo.isLocked ? .unlock : .lock),
                            isEnabled: shouldEnableDebug
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 空调按钮
                        ControlButton(
                            icon: carInfo.airConditionerOn ? "fan" : "fan.slash",
                            title: carInfo.airConditionerOn ? "空调开" : "空调关",
                            isActive: carInfo.airConditionerOn,
                            intent: GetSelectACStatusIntent(action: carInfo.airConditionerOn ? .turnOff : .turnOn),
                            isEnabled: shouldEnableDebug
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 车窗按钮
                        ControlButton(
                            icon: carInfo.windowsOpen ? "dock.arrow.up.rectangle" : "dock.arrow.down.rectangle",
                            title: carInfo.windowsOpen ? "窗已开" : "窗已关",
                            isActive: carInfo.windowsOpen,
                            intent: GetSelectWindowStatusIntent(action: carInfo.windowsOpen ? .close : .open),
                            isEnabled: shouldEnableDebug
                        )
                        .frame(maxWidth: .infinity)
                        
                        // 鸣笛按钮
                        ControlButton(
                            icon: "location.circle",
                            title: "寻车",
                            isActive: false,
                            intent: GetFindCarStatusIntent(),
                            isEnabled: shouldEnableDebug
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
    
    // 格式化分钟数为时间字符串
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes <= 0 {
            return "已完成"
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)小时\(remainingMinutes)分钟"
            } else {
                return "\(hours)小时"
            }
        } else {
            return "\(remainingMinutes)分钟"
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let intent: any AppIntent
    let isEnabled: Bool
    
    var body: some View {
        if isEnabled {
            Button(intent: intent) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
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
    }
}

// MARK: - 使用共享网络管理器
// WidgetNetworkManager已被SharedNetworkManager替代，支持多Target复用

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
        .configurationDisplayName("车辆显示小组件")
        .description("显示车辆状态各种状态信息")
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
