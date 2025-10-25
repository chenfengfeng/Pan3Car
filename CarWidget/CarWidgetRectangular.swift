//
//  CarWidgetRectangular.swift
//  CarWidget
//
//  Created by Feng on 2025/1/20.
//  accessoryRectangular 样式的车辆小组件
//

import SwiftUI
import WidgetKit

// accessoryRectangular Provider
struct RectangularProvider: TimelineProvider {
    // 添加静态变量来跟踪最后一次请求时间，避免Widget层面的重复请求
    private static var lastTimelineRequestTime: Date = Date.distantPast
    private static let minTimelineInterval: TimeInterval = 5.0 // 5秒内不重复请求
    func placeholder(in context: Context) -> RectangularSimpleEntry {
        RectangularSimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RectangularSimpleEntry) -> ()) {
        let entry = RectangularSimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RectangularSimpleEntry>) -> ()) {
        let currentDate = Date()
        
        // 检查认证信息是否存在
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        
        // 如果没有认证信息，显示错误状态
        if timaToken == nil || defaultVin == nil {
            let entry = RectangularSimpleEntry(date: currentDate, carInfo: nil, errorMessage: "请先在主应用中登录")
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 优先检查推送数据更新
        let hasPushUpdate = WidgetDataManager.shared.hasPushDataUpdate(withinSeconds: 30)
        let hasRecentModification = WidgetDataManager.shared.hasRecentLocalModification(withinSeconds: 10)
        
        print("[Rectangular Widget Debug] 数据状态检查 - 推送更新: \(hasPushUpdate), 本地修改: \(hasRecentModification)")
        
        if hasPushUpdate {
            print("[Rectangular Widget Debug] 检测到推送数据更新，使用推送更新的缓存数据")
            // 推送数据更新，直接使用缓存数据
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry: RectangularSimpleEntry
            if let carInfo = carInfo {
                entry = RectangularSimpleEntry(date: currentDate, carInfo: carInfo)
                // 清除推送数据更新标记，避免重复使用
                WidgetDataManager.shared.clearPushDataUpdate()
            } else {
                entry = RectangularSimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        } else if hasRecentModification {
            print("[Rectangular Widget Debug] 检测到最近的本地修改，使用本地缓存数据")
            // 使用本地缓存数据，避免覆盖本地修改
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry: RectangularSimpleEntry
            if let carInfo = carInfo {
                entry = RectangularSimpleEntry(date: currentDate, carInfo: carInfo)
            } else {
                entry = RectangularSimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 尝试获取最新车辆信息
        SharedNetworkManager.shared.getCarInfo { result in
            var entry: RectangularSimpleEntry
            
            switch result {
            case .success(let carData):
                let carInfo = CarInfo.parseCarInfo(from: carData)
                WidgetDataManager.shared.updateCarInfo(carInfo)
                // 设置本地修改标记，供小组件检测
                WidgetDataManager.shared.markLocalModification()
                entry = RectangularSimpleEntry(date: currentDate, carInfo: carInfo)
                
            case .failure(let error):
                print("[Rectangular Widget Debug] 获取车辆信息失败: \(error.localizedDescription)")
                
                // 检查是否是认证失败
                if error.localizedDescription.contains("Authentication failure") {
                    entry = RectangularSimpleEntry(date: currentDate, carInfo: nil, errorMessage: "认证失败，请重新登录")
                } else {
                    // 其他网络错误，尝试使用本地缓存数据
                    let carInfo = WidgetDataManager.shared.getCachedCarInfo()
                    if let carInfo = carInfo {
                        entry = RectangularSimpleEntry(date: currentDate, carInfo: carInfo)
                    } else {
                        entry = RectangularSimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
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

struct RectangularSimpleEntry: TimelineEntry {
    let date: Date
    let carInfo: CarInfo?
    let errorMessage: String?
    
    init(date: Date, carInfo: CarInfo?, errorMessage: String? = nil) {
        self.date = date
        self.carInfo = carInfo
        self.errorMessage = errorMessage
    }
}

struct CarWidgetRectangularEntryView: View {
    var entry: RectangularProvider.Entry
    
    var body: some View {
        if let errorMessage = entry.errorMessage {
            // 错误状态显示
            VStack(alignment: .leading, spacing: 2) {
                Text("胖3车辆数据")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        } else if let carInfo = entry.carInfo {
            // 正常状态显示 - 3行纵向布局
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：胖3剩余里程 505km
                HStack(alignment: .bottom, spacing: 4) {
                    Text("剩余里程")
                        .font(.callout)
                    
                    Text("\(carInfo.remainingMileage)")
                        .font(.callout)
                    
                    Text("km")
                        .font(.callout)
                }
                
                // 第二行：电量图标 + 剩余电量100% 或 充电中 xx:xx
                HStack(alignment: .bottom, spacing: 4) {
                    // 电量图标显示在最前面
                    if carInfo.isCharge {
                        Image(systemName: "ev.charger")
                            .font(.callout)
                        
                        Text("充电中")
                            .font(.callout)
                        
                        Text("\(formatMinutes(carInfo.chgLeftTime+122))")
                            .font(.callout)
                    } else {
                        Image(systemName: "car.side.fill")
                            .font(.body)
                            .offset(y: -2)
                        
                        Text("剩余电量")
                            .font(.callout)
                        
                        Text("\(carInfo.soc)")
                            .font(.callout)
                        
                        Text("%")
                            .font(.callout)
                    }
                }
                
                // 第三行：进度条显示电量
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景条
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(8)
                        
                        // 前景进度条
                        Rectangle()
                            .fill(Color.white)
                            .frame(
                                width: geometry.size.width * (Double(carInfo.soc) / 100.0),
                                height: 8
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes <= 0 {
            return "已完成"
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours):\(String(format: "%02d", remainingMinutes))"
            } else {
                return "\(hours)小时"
            }
        } else {
            return "\(remainingMinutes)分钟"
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct CarWidgetRectangular: Widget {
    let kind: String = "CarWidgetRectangular"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularProvider()) { entry in
            CarWidgetRectangularEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("车辆状态")
        .description("在锁屏显示车辆剩余里程、电量和状态信息")
        .supportedFamilies([.accessoryRectangular])
    }
}

@available(iOSApplicationExtension 17.0, *)
#Preview(as: .accessoryRectangular) {
    CarWidgetRectangular()
} timeline: {
    RectangularSimpleEntry(date: .now, carInfo: CarInfo.placeholder)
    RectangularSimpleEntry(date: .now, carInfo: nil, errorMessage: "请先在主应用中登录")
}
