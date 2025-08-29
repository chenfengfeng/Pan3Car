//
//  CarWatchWidget.swift
//  CarWatchWidget
//
//  Created by Feng on 2025/8/24.
//

import Foundation
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("[CarWatchWidget] getSnapshot called")
        let entry = SimpleEntry(date: Date(), carInfo: CarInfo.placeholder)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("[CarWatchWidget] getTimeline called")
        let currentDate = Date()
        
        // 检查认证信息是否存在
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        
        // 如果没有认证信息，显示错误状态
        if timaToken == nil || defaultVin == nil {
            let entry = SimpleEntry(date: currentDate, carInfo: nil, errorMessage: "请先在主应用中登录")
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 检查是否有最近的本地修改
        if WidgetDataManager.shared.hasRecentLocalModification(withinSeconds: 10) {
            print("[CarWatchWidget] 检测到最近的本地修改，跳过网络请求，使用本地缓存数据")
            // 使用本地缓存数据，避免覆盖本地修改
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry: SimpleEntry
            if let carInfo = carInfo {
                entry = SimpleEntry(date: currentDate, carInfo: carInfo)
            } else {
                entry = SimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 尝试获取最新车辆信息
        SharedNetworkManager.shared.getCarInfo { result in
            var entry: SimpleEntry
            
            switch result {
            case .success(let carData):
                let carInfo = CarInfo.parseCarInfo(from: carData)
                WidgetDataManager.shared.updateCarInfo(carInfo)
                entry = SimpleEntry(date: currentDate, carInfo: carInfo)
                
            case .failure(let error):
                print("[CarWatchWidget] 获取车辆信息失败: \(error.localizedDescription)")
                
                // 检查是否是认证失败
                if error.localizedDescription.contains("Authentication failure") {
                    entry = SimpleEntry(date: currentDate, carInfo: nil, errorMessage: "认证失败，请重新登录")
                } else {
                    // 其他网络错误，尝试使用本地缓存数据
                    let carInfo = WidgetDataManager.shared.getCachedCarInfo()
                    if let carInfo = carInfo {
                        entry = SimpleEntry(date: currentDate, carInfo: carInfo)
                    } else {
                        entry = SimpleEntry(date: currentDate, carInfo: nil, errorMessage: "无法获取车辆数据")
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let carInfo: CarInfo?
    let errorMessage: String?
    
    init(date: Date, carInfo: CarInfo?, errorMessage: String? = nil) {
        self.date = date
        self.carInfo = carInfo
        self.errorMessage = errorMessage
    }
}

struct CarWatchWidgetEntryView : View {
    var entry: Provider.Entry

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
        } else if let carInfo = entry.carInfo {
            // 正常状态显示 - 3行纵向布局，参考CarWidgetRectangular的设计
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：锁车状态
                HStack(alignment: .bottom, spacing: 4) {
                    Image(systemName: carInfo.isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.callout)
                    
                    Text(carInfo.isLocked ? "胖3已锁车" : "胖3已解锁")
                        .font(.callout)
                }
                
                // 第二行：剩余里程
                HStack(alignment: .bottom, spacing: 4) {
                    Text("剩余里程")
                        .font(.callout)
                    
                    Text("\(carInfo.remainingMileage)")
                        .font(.callout)
                    
                    Text("km")
                        .font(.callout)
                }
                
                // 第三行：电量进度条
                ProgressView(value: Double(carInfo.soc), total: 100)
                    .tint(socColor(for: carInfo.soc))
                    .progressViewStyle(.linear)
            }
        }
    }
    
    // MARK: - 颜色函数
    private func socColor(for soc: Int) -> Color {
        if soc < 10 {
            return .red
        } else if soc < 20 {
            return .orange
        } else {
            return .green
        }
    }
}

struct CarWatchWidget: Widget {
    let kind: String = "CarWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                CarWatchWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                CarWatchWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("车辆状态")
        .description("在Apple Watch上显示车辆剩余里程、电量和状态信息")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    CarWatchWidget()
} timeline: {
    let carInfo1 = CarInfo(remainingMileage: 300, soc: 85, isLocked: true, windowsOpen: false, isCharge: false, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 0)
    let carInfo2 = CarInfo(remainingMileage: 200, soc: 45, isLocked: false, windowsOpen: true, isCharge: false, airConditionerOn: true, lastUpdated: Date(), chgLeftTime: 0)
    let carInfo3 = CarInfo(remainingMileage: 400, soc: 92, isLocked: true, windowsOpen: false, isCharge: true, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 120)
    SimpleEntry(date: .now, carInfo: carInfo1)
    SimpleEntry(date: .now, carInfo: carInfo2)
    SimpleEntry(date: .now, carInfo: carInfo3)
    SimpleEntry(date: .now, carInfo: nil, errorMessage: "请先在主应用中登录")
}
