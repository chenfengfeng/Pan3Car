//
//  CarWatchCircularLock.swift
//  CarWatchWidget
//
//  Created by Feng on 2025/1/25.
//

import WidgetKit
import SwiftUI

struct CarWatchCircularLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarWatchCircularLockEntry {
        return CarWatchCircularLockEntry(date: Date(), carInfo: CarInfo.placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CarWatchCircularLockEntry) -> ()) {
        print("[CarWatchCircularLock] getSnapshot called")
        let entry = CarWatchCircularLockEntry(date: Date(), carInfo: CarInfo.placeholder)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("[CarWatchCircularLock] getTimeline called")
        let currentDate = Date()
        
        // 网络相关代码已删除，使用占位数据
        let entry = CarWatchCircularLockEntry(date: currentDate, carInfo: CarInfo.placeholder)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct CarWatchCircularLockEntry: TimelineEntry {
    let date: Date
    let carInfo: CarInfo
}

struct CarWatchCircularLockEntryView: View {
    var entry: CarWatchCircularLockProvider.Entry
    @Environment(\.widgetRenderingMode) private var renderingMode   // ① 读取系统渲染模式
    


    var body: some View {
        let content = ZStack {
            Circle()                              // 背景圆
                .fill(backgroundFill)             // ② 根据模式返回合适颜色
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: 2) // ③ 描边色同样适配
                )
                .animation(.easeInOut(duration: 0.5), value: entry.carInfo.isLocked)

            VStack(spacing: 2) {                  // 图标 + 文本
                Image(systemName: entry.carInfo.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)

                Text(entry.carInfo.isLocked ? "锁定" : "解锁")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor)
            }
        }
        
        content
    }

    // MARK: - 颜色适配函数
    private var backgroundFill: Color {
        if renderingMode == .fullColor {
            return entry.carInfo.isLocked ? .clear : .green
        } else {
            return .clear   // 交给系统做蒙版渲染
        }
    }

    private var strokeColor: Color {
        // 锁定时需要白色描边，解锁不描边
        if renderingMode == .fullColor {
            return entry.carInfo.isLocked ? .white : .clear
        } else {
            return .white   // 交给系统做蒙版渲染
        }
    }

    private var iconColor: Color { .white }
    private var textColor: Color { .white }
}

struct CarWatchCircularLock: Widget {
    let kind: String = "CarWatchCircularLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarWatchCircularLockProvider()) { entry in
            if #available(watchOS 10.0, *) {
                CarWatchCircularLockEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                CarWatchCircularLockEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("锁车状态")
        .description("显示车辆锁定状态")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular) {
    CarWatchCircularLock()
} timeline: {
    let carInfo1 = CarInfo(remainingMileage: 300, soc: 85, isLocked: true, windowsOpen: false, isCharge: false, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 0)
    let carInfo2 = CarInfo(remainingMileage: 200, soc: 75, isLocked: false, windowsOpen: false, isCharge: false, airConditionerOn: false, lastUpdated: Date(), chgLeftTime: 0)
    CarWatchCircularLockEntry(date: .now, carInfo: carInfo1)
    CarWatchCircularLockEntry(date: .now, carInfo: carInfo2)
}
