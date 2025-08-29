//
//  CarWidgetLegacy.swift
//  CarWidget
//
//  Created by Feng on 2025/1/20.
//  iOS 16兼容的车辆小组件
//

import SwiftUI
import WidgetKit

// iOS 16兼容的Provider
struct LegacyProvider: TimelineProvider {
    // 添加静态变量来跟踪最后一次请求时间，避免Widget层面的重复请求
    private static var lastTimelineRequestTime: Date = Date.distantPast
    private static let minTimelineInterval: TimeInterval = 5.0 // 5秒内不重复请求
    func placeholder(in context: Context) -> LegacySimpleEntry {
        LegacySimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LegacySimpleEntry) -> ()) {
        let entry = LegacySimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LegacySimpleEntry>) -> ()) {
        let currentDate = Date()
        
        let timeSinceLastRequest = currentDate.timeIntervalSince(Self.lastTimelineRequestTime)
        if timeSinceLastRequest < Self.minTimelineInterval {
            // 使用缓存数据
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry = LegacySimpleEntry(date: currentDate, carInfo: carInfo ?? nil, errorMessage: carInfo == nil ? "无法获取车辆数据" : nil)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        Self.lastTimelineRequestTime = currentDate
        
        // 检查认证信息是否存在
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        
        // 如果没有认证信息，显示错误状态
        if timaToken == nil || defaultVin == nil {
            let entry = LegacySimpleEntry(date: currentDate, carInfo: nil, errorMessage: "请先在主应用中登录")
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 检查是否有最近的本地修改
        if WidgetDataManager.shared.hasRecentLocalModification(withinSeconds: 10) {
            print("[Legacy Widget Debug] 检测到最近的本地修改，跳过网络请求，使用本地缓存数据")
            // 使用本地缓存数据，避免覆盖本地修改
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry: LegacySimpleEntry
            if let carInfo = carInfo {
                entry = LegacySimpleEntry(date: currentDate, carInfo: carInfo)
            } else {
                entry = LegacySimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 尝试获取最新车辆信息
        SharedNetworkManager.shared.getCarInfo { result in
            var entry: LegacySimpleEntry
            
            switch result {
            case .success(let carData):
                let carInfo = CarInfo.parseCarInfo(from: carData)
                WidgetDataManager.shared.updateCarInfo(carInfo)
                entry = LegacySimpleEntry(date: currentDate, carInfo: carInfo)
                
            case .failure(let error):
                print("[Legacy Widget Debug] 获取车辆信息失败: \(error.localizedDescription)")
                
                // 检查是否是认证失败
                if error.localizedDescription.contains("Authentication failure") {
                    entry = LegacySimpleEntry(date: currentDate, carInfo: nil, errorMessage: "认证失败，请重新登录")
                } else {
                    // 其他网络错误，尝试使用本地缓存数据
                    let carInfo = WidgetDataManager.shared.getCachedCarInfo()
                    if let carInfo = carInfo {
                        entry = LegacySimpleEntry(date: currentDate, carInfo: carInfo)
                    } else {
                        entry = LegacySimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
                    }
                }
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct LegacySimpleEntry: TimelineEntry {
    let date: Date
    let carInfo: CarInfo?
    let errorMessage: String?
    
    init(date: Date, carInfo: CarInfo?, errorMessage: String? = nil) {
        self.date = date
        self.carInfo = carInfo
        self.errorMessage = errorMessage
    }
}

struct CarWidgetLegacyEntryView: View {
    var entry: LegacyProvider.Entry
    
    var body: some View {
        if let errorMessage = entry.errorMessage {
            // 错误状态显示
            ZStack {
                GeometryReader { geo in
                    Color.black
                        .frame(width: geo.size.width  + 20 + 20,
                               height: geo.size.height + 20 + 20)
                        .offset(x: -20, y: -20)
                }
                Image("my_car")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let carInfo = entry.carInfo {
            ZStack {
                GeometryReader { geo in
                    Color.black
                        .frame(width: geo.size.width  + 20 + 20,
                               height: geo.size.height + 20 + 20)
                        .offset(x: -20, y: -20)
                }
                
                Image(carInfo.isCharge ? "my_car_charge" : "my_car")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                // 重新设计的布局
                GeometryReader { geometry in
                    VStack(spacing: 2) {
                        // 剩余里程 - 顶部大字显示，左对齐8px
                        HStack(alignment: .bottom, spacing: 2) {
                            Text("\(carInfo.remainingMileage)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("km")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .offset(y: -2)
                            
                            Spacer()
                        }
                        .padding(.leading, 8)
                        .offset(x: 40)
                        
                        // SOC进度条 - 中间，左对齐8px，最大宽度为小组件宽度的一半
                        HStack {
                            ZStack(alignment: .leading) {
                                // 灰色背景进度条
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width / 3, height: 6)
                                    .cornerRadius(3)
                                
                                // 实际进度条
                                Rectangle()
                                    .fill(socColor(for: carInfo.soc))
                                    .frame(width: (geometry.size.width / 3) * (Double(carInfo.soc) / 100.0), height: 6)
                                    .cornerRadius(3)
                            }
                            .padding(.leading, 8)
                            .offset(x: 40)
                            
                            Spacer()
                        }
                        
                        Spacer(minLength: 4)
                        
                        // 状态信息 - 底部
                        if carInfo.isCharge {
                            VStack(spacing: 2) {
                                Text("正在充电")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                                
                                if carInfo.chgLeftTime > 0 {
                                    Text("剩余 \(formatMinutes(carInfo.chgLeftTime))")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        } else {
                            Text("更新于 \(carInfo.lastUpdated, formatter: timeFormatter)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            return "\(remainingMinutes)m"
        }
    }
}

struct CarWidgetLegacy: Widget {
    let kind: String = "CarWidgetLegacy"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LegacyProvider()) { entry in
            CarWidgetLegacyEntryView(entry: entry)
        }
        .configurationDisplayName("车辆状态")
        .description("显示车辆剩余里程、电量和状态信息")
        .supportedFamilies([.systemSmall])
    }
}

// Preview is only available in iOS 17+, so we comment it out for iOS 16 compatibility
// #Preview(as: .systemSmall) {
//     CarWidgetLegacy()
// } timeline: {
//     LegacySimpleEntry(date: .now, carInfo: CarInfo.placeholder)
//     LegacySimpleEntry(date: .now, carInfo: nil, errorMessage: "请先在主应用中登录")
// }
