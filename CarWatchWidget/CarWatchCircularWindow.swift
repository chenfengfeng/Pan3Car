//
//  CarWatchCircularWindow.swift
//  CarWatchWidget
//
//  Created by Feng on 2025/1/25.
//

import WidgetKit
import SwiftUI

struct CarWatchCircularWindowProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarWatchCircularWindowEntry {
        return CarWatchCircularWindowEntry(date: Date(), carInfo: CarInfo.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CarWatchCircularWindowEntry) -> ()) {
        print("[CarWatchCircularWindow] getSnapshot called")
        let entry = CarWatchCircularWindowEntry(date: Date(), carInfo: CarInfo.placeholder)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("[CarWatchCircularWindow] getTimeline called")
        let currentDate = Date()
        
        // 检查认证信息是否存在
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        let defaultVin = userDefaults?.string(forKey: "defaultVin")
        let timaToken = userDefaults?.string(forKey: "timaToken")
        
        // 如果没有认证信息，使用占位数据
        if timaToken == nil || defaultVin == nil {
            let entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: CarInfo.placeholder)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 检查是否有最近的本地修改
        if WidgetDataManager.shared.hasRecentLocalModification(withinSeconds: 10) {
            print("[CarWatchCircularWindow] 检测到最近的本地修改，跳过网络请求，使用本地缓存数据")
            // 使用本地缓存数据，避免覆盖本地修改
            let carInfo = WidgetDataManager.shared.getCachedCarInfo()
            let entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: carInfo ?? CarInfo.placeholder)
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 尝试获取最新车辆信息
        SharedNetworkManager.shared.getCarInfo { result in
            var entry: CarWatchCircularWindowEntry
            
            switch result {
            case .success(let carData):
                let carInfo = CarInfo.parseCarInfo(from: carData)
                WidgetDataManager.shared.updateCarInfo(carInfo)
                entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: carInfo)
                
            case .failure(let error):
                print("[CarWatchCircularWindow] 获取车辆信息失败: \(error.localizedDescription)")
                
                // 检查是否是认证失败
                if error.localizedDescription.contains("Authentication failure") {
                    entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: CarInfo.placeholder)
                } else {
                    // 其他网络错误，尝试使用本地缓存数据
                    let carInfo = WidgetDataManager.shared.getCachedCarInfo()
                    entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: carInfo ?? CarInfo.placeholder)
                }
            }
            
            // 设置下次更新时间为15分钟后
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct CarWatchCircularWindowEntry: TimelineEntry {
    let date: Date
    let carInfo: CarInfo
}

struct CarWatchCircularWindowEntryView: View {
    var entry: CarWatchCircularWindowProvider.Entry
    @Environment(\.widgetRenderingMode) private var renderingMode   // ① 读取系统渲染模式
    
    // 检查是否有任何车窗开启
    private var isAnyWindowOpen: Bool {
        return entry.carInfo.windowsOpen
    }
    
    // 检查是否启用调试模式（按钮功能）
    private var shouldEnableDebug: Bool {
        let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
        return userDefaults?.bool(forKey: "shouldEnableDebug") ?? false
    }

    var body: some View {
        let content = ZStack {
            Circle()                              // 背景圆
                .fill(backgroundFill)             // ② 根据模式返回合适颜色
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: 2) // ③ 描边色同样适配
                )
                .animation(.easeInOut(duration: 0.5), value: isAnyWindowOpen)

            VStack(spacing: 2) {                  // 图标 + 文本
                Image(systemName: isAnyWindowOpen ? "window.shade.open" : "window.shade.closed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)

                Text(isAnyWindowOpen ? "开启" : "关闭")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor)
            }
        }
        
        if shouldEnableDebug {
            Button(intent: GetWidgetSelectWindowStatusIntent(action: isAnyWindowOpen ? .close : .open)) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }

    // MARK: - 颜色适配函数
    private var backgroundFill: Color {
        if renderingMode == .fullColor {
            return isAnyWindowOpen ? .cyan.opacity(0.8) : .clear
        } else {
            return .clear   // 交给系统做蒙版渲染
        }
    }

    private var strokeColor: Color {
        // 关闭时需要白色描边，开启不描边
        if renderingMode == .fullColor {
            return isAnyWindowOpen ? .clear : .white
        } else {
            return .white   // 交给系统做蒙版渲染
        }
    }

    private var iconColor: Color { .white }
    private var textColor: Color { .white }
}

struct CarWatchCircularWindow: Widget {
    let kind: String = "CarWatchCircularWindow"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarWatchCircularWindowProvider()) { entry in
            if #available(watchOS 10.0, *) {
                CarWatchCircularWindowEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                CarWatchCircularWindowEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("车窗状态")
        .description("显示车辆车窗开关状态")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular) {
    CarWatchCircularWindow()
} timeline: {
    let carInfo1 = CarInfo(remainingMileage: 300, soc: 85, isLocked: true, windowsOpen: false, isCharge: false, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 0)
    let carInfo2 = CarInfo(remainingMileage: 200, soc: 75, isLocked: false, windowsOpen: true, isCharge: false, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 0)
    CarWatchCircularWindowEntry(date: .now, carInfo: carInfo1)
    CarWatchCircularWindowEntry(date: .now, carInfo: carInfo2)
}
