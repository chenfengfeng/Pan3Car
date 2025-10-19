//
//  CarWidgetLiveActivity.swift
//  CarWidget
//
//  Created by Feng on 2025/1/2.
//
#if canImport(ActivityKit)
import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Live Activity View
struct CarWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CarWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

// MARK: - Shared Progress Utilities
extension View {
    func progressColor(for progress: Int) -> Color {
        if progress <= 20 {
            return .red
        } else if progress <= 50 {
            return .orange
        } else if progress <= 75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    func batteryIcon(for progress: Int) -> String {
        if progress <= 20 {
            return "battery.25"
        } else if progress <= 50 {
            return "battery.50"
        } else if progress <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
}

// MARK: - Lock Screen View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // 顶部：左侧徽章 + 右侧当前 SOC，减少冗余并保证信息完整
            HStack(spacing: 8) {
                Text("充电进度")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green)
                    .cornerRadius(4)
                Spacer()
                HStack(spacing: 4) {
                    Text("当前SOC")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text("\(context.state.currentSoc)%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            
            // 进度：电池图标 + 线形进度条 + 百分比
            HStack(spacing: 6) {
                Image(systemName: batteryIcon(for: context.state.chargeProgress))
                    .foregroundColor(progressColor(for: context.state.chargeProgress))
                    .font(.subheadline)
                
                ProgressView(value: Float(context.state.chargeProgress), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: context.state.chargeProgress)))
                    .scaleEffect(y: 1.6)
                
                Text("\(context.state.chargeProgress)%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor(for: context.state.chargeProgress))
                    .lineLimit(1)
            }
            
            // 三栏关键信息：起始 / SOC变化 / 目标
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("起始")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(context.attributes.startKm)km")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .center, spacing: 2) {
                    Text("SOC变化")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("+\(context.state.currentSoc - context.attributes.initialSoc)%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("目标")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(context.attributes.endKm)km")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .minimumScaleFactor(0.8)
            
            // 当前里程独立一行，便于阅读
            HStack(spacing: 6) {
                Text("当前里程")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(context.state.currentKm)km")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // 消息提示
            if let message = context.state.message, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Dynamic Island Views
struct CompactLeadingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon(for: context.state.chargeProgress))
                .foregroundColor(progressColor(for: context.state.chargeProgress))
                .font(.subheadline)
            
            Text("\(context.state.chargeProgress)%")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(progressColor(for: context.state.chargeProgress))
        }
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(context.state.currentKm) km")
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: batteryIcon(for: context.state.chargeProgress))
                .foregroundColor(progressColor(for: context.state.chargeProgress))
                .font(.caption2)
            
            Text("\(context.state.chargeProgress)%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(progressColor(for: context.state.chargeProgress))
        }
    }
}

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        // 按需求将顶部内容统一到 Center 区域，这里不再展示任何内容
        EmptyView()
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        // 顶部、中间信息都在 Center 展示，这里留空以最大化 Center 可用宽度
        EmptyView()
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<CarWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // 顶部：电量图标 + 进度条 + 充电进度百分比
            HStack(spacing: 10) {
                Image(systemName: batteryIcon(for: context.state.chargeProgress))
                    .foregroundColor(progressColor(for: context.state.chargeProgress))
                    .font(.body)
                ProgressView(value: Float(context.state.chargeProgress), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: context.state.chargeProgress)))
                    .scaleEffect(y: 1.4)
                Text("\(context.state.chargeProgress)%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor(for: context.state.chargeProgress))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // 中间（第一行）：起始里程 / 起始SOC / 目标里程
            HStack {
                Text("起始里程: \(context.attributes.startKm)km")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("起始SOC: \(context.attributes.initialSoc)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("目标里程: \(context.attributes.endKm)km")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // 中间（第二行）：当前SOC / 当前里程（加大字号）
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前SOC")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(context.state.currentSoc)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("当前里程")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(context.state.currentKm)km")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // 下方：充电消息
            if let message = context.state.message, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

#endif
