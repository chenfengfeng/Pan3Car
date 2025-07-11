//
//  CarWidgetLiveActivity.swift
//  CarWidget
//
//  Created by Feng on 2025/1/2.
//
#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity View
struct CarWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CarWidgetAttributes.self) { context in
            // 锁屏界面
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开视图
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // 紧凑视图左侧
                CompactLeadingView(context: context)
            } compactTrailing: {
                // 紧凑视图右侧
                CompactTrailingView(context: context)
            } minimal: {
                // 最小化视图
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 状态标签
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(6)
                
                Spacer()
                
                // 百分比
                Text("\(context.state.percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(batteryColor)
            }
            
            // 进度条
            HStack(spacing: 8) {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                    .font(.title3)
                
                ProgressView(value: Float(context.state.percentage), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: batteryColor))
                    .scaleEffect(y: 2)
            }
            
            // 详细信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("初始: \(String(format: "%.1f", context.attributes.initialKm)) km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("目标: \(String(format: "%.1f", context.attributes.targetKm)) km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("已充: \(String(format: "%.1f", context.state.chargedKwh)) kWh")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("目标: \(String(format: "%.1f", context.attributes.targetKwh)) kWh")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 消息
            if let message = context.state.message, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var statusText: String {
        switch context.state.status {
        case "pending": return "充电中"
        case "ready": return "准备中"
        case "done": return "已完成"
        case "timeout", "error": return "失败"
        case "cancelled": return "已取消"
        default: return context.state.status
        }
    }
    
    private var statusColor: Color {
        switch context.state.status {
        case "ready": return .yellow
        case "pending": return .green
        case "done": return .green
        case "timeout", "error": return .red
        case "cancelled": return .orange
        default: return .gray
        }
    }
    
    private var batteryColor: Color {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return .red
        } else if percentage <= 50 {
            return .orange
        } else if percentage <= 75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var batteryIcon: String {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return "battery.25"
        } else if percentage <= 50 {
            return "battery.50"
        } else if percentage <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
}

// MARK: - Dynamic Island Views
struct CompactLeadingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        HStack {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 25, height: 25) // 你可以根据需要调小尺寸
                .clipShape(Circle())
        }
    }
    
    private var batteryColor: Color {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return .red
        } else if percentage <= 50 {
            return .orange
        } else if percentage <= 75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var batteryIcon: String {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return "battery.25"
        } else if percentage <= 50 {
            return "battery.50"
        } else if percentage <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        Text("\(context.state.percentage)%")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        Text("\(context.state.percentage)%")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.primary)
    }
}

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                    .font(.title2)
                
                Text("\(context.state.percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(batteryColor)
            }
            
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusText: String {
        switch context.state.status {
        case "pending": return "充电中"
        case "ready": return "准备中"
        case "done": return "已完成"
        case "timeout", "error": return "失败"
        case "cancelled": return "已取消"
        default: return context.state.status
        }
    }
    
    private var batteryColor: Color {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return .red
        } else if percentage <= 50 {
            return .orange
        } else if percentage <= 75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var batteryIcon: String {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return "battery.25"
        } else if percentage <= 50 {
            return "battery.50"
        } else if percentage <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("目标里程")
                .font(.caption2)
                .foregroundColor(.secondary)
                .offset(x: -10)
            
            Text("\(String(format: "%.1f", context.attributes.targetKm)) km")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .offset(x: -10)
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            ProgressView(value: Float(context.state.percentage), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: batteryColor))
                .scaleEffect(y: 1.5)
            
            // 详细信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("初始: \(String(format: "%.1f", context.attributes.initialKm)) km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("已充: \(String(format: "%.1f", context.state.chargedKwh)) kWh")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("目标: \(String(format: "%.1f", context.attributes.targetKwh)) kWh")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 消息
            if let message = context.state.message, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
    }
    
    private var batteryColor: Color {
        let percentage = context.state.percentage
        if percentage <= 20 {
            return .red
        } else if percentage <= 50 {
            return .orange
        } else if percentage <= 75 {
            return .yellow
        } else {
            return .green
        }
    }
}

// Preview for Live Activity
struct CarWidgetLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 充电中状态预览
            VStack(spacing: 12) {
                HStack {
                    Text("充电中")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("65%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "battery.75")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    ProgressView(value: 0.65)
                        .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                        .scaleEffect(y: 2)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("初始: 100.0 km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("目标: 150.0 km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("已充: 8.5 kWh")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("目标: 35.0 kWh")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("充电进行中，请耐心等待")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .previewDisplayName("充电中")
            
            // 充电完成状态预览
            VStack(spacing: 12) {
                HStack {
                    Text("已完成")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("100%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    ProgressView(value: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 2)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("初始: 100.0 km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("目标: 150.0 km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("已充: 15.0 kWh")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("目标: 35.0 kWh")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("充电已完成")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .previewDisplayName("充电完成")
        }
    }
}
#endif
