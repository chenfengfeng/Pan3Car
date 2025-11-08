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
        
        // 从App Groups读取SharedCarModel数据
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[CarWatchCircularWindow] 无法访问App Groups，使用占位数据")
            let entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: CarInfo.placeholder)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }
        
        // 尝试从App Groups读取SharedCarModel数据
        if let sharedCarModelDict = userDefaults.object(forKey: "SharedCarModelData") as? [String: Any],
           let sharedCarModel = SharedCarModel(dictionary: sharedCarModelDict) {
            
            // 将SharedCarModel转换为CarInfo
            let carInfo = CarInfo.from(sharedCarModel: sharedCarModel)
            let entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: carInfo)
            
            print("[CarWatchCircularWindow] 成功从App Groups加载SharedCarModel数据")
            
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        } else {
            // 如果没有SharedCarModel数据，使用占位数据
            print("[CarWatchCircularWindow] 未找到SharedCarModel数据，使用占位数据")
        let entry = CarWatchCircularWindowEntry(date: currentDate, carInfo: CarInfo.placeholder)
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
        
        // 点击打开 Watch App 并自动弹出车窗确认对话框
        content
            .widgetURL(URL(string: "pan3watch://control?action=window"))
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
