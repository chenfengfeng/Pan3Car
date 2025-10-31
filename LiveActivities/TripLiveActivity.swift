import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - 主程序入口
struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // 配置 Activity, 关联 TripAttributes
        ActivityConfiguration(for: TripAttributes.self) { context in
            // MARK: 1. 锁定屏幕视图
            // 这里我们使用最终的 V3.0 布局
            TripLockScreenLiveActivityView(context: context)
            
        } dynamicIsland: { context in
            // MARK: 2. 灵动岛视图
            DynamicIsland {
                // --- 展开状态 (Expanded) ---
                // 左侧: 显示车辆状态
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 4) {
                        Text("出发时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(context.attributes.formattedDepartureTime)
                            .font(.caption)
                    }
                    .padding(.leading, 4)
                }
                
                // 右侧: 显示效率百分比
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 4) {
                        Text("行驶时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(context.state.formattedElapsedTime(from: context.attributes.departureTime))
                            .font(.caption)
                    }
                    .padding(.trailing, 4)
                }
                
                // 中间: 显示实际里程和消耗里程
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Text(String(format: "实际里程 %.1fkm", context.state.actualMileage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "消耗里程 %.1fkm", context.state.consumedMileage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
                
                // 底部: 显示出发时间和行驶时间
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        
                        Text(context.state.vehicleStatus.displayTitle)
                        
                        Spacer()
                        
                        Text(String(format: "达成率%.1f%%", context.state.mileageEfficiencyPercentage))
                            .foregroundColor(context.state.efficiencyColor)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal)
                }
                
            } compactLeading: {
                // --- 紧凑状态 (Compact) ---
                // 左侧：行驶状态
                Text(context.state.vehicleStatus.displayTitle)
                
            } compactTrailing: {
                // 右侧: 效率百分比
                Text(String(format: "达成率%.1f%%", context.state.mileageEfficiencyPercentage))
                    .foregroundColor(context.state.efficiencyColor)
                    .contentTransition(.numericText())
                
            } minimal: {
                // --- 最小状态 (Minimal) ---
                // (例如在 Apple Watch 上显示)
                Text(String(format: "%.0f%%", context.state.mileageEfficiencyPercentage))
                    .foregroundColor(context.state.efficiencyColor)
                    .contentTransition(.numericText())
            }
        }
    }
}

// MARK: - 视图组件 (View Components)

/// 锁屏视图 (采用灵动岛风格的多区域布局)
struct TripLockScreenLiveActivityView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部区域：主要状态信息
            HStack {
                // 左侧：出发时间信息
                VStack(alignment: .center, spacing: 4) {
                    Text("出发时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.attributes.formattedDepartureTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // 右侧：行驶时间信息
                VStack(alignment: .center, spacing: 4) {
                    Text("行驶时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.state.formattedElapsedTime(from: context.attributes.departureTime))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // 中心区域：核心数据展示
            VStack(spacing: 8) {
                // 里程对比信息
                HStack(spacing: 8) {
                    Text(String(format: "实际里程 %.1fkm", context.state.actualMileage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("/")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "消耗里程 %.1fkm", context.state.consumedMileage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 进度条
                ProgressView(value: context.state.progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.progressBarColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            .padding(.horizontal, 20)
            
            // 车辆状态和效率百分比
            HStack {
                Text(context.state.vehicleStatus.displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "达成率%.1f%%", context.state.mileageEfficiencyPercentage))
                    .foregroundColor(context.state.efficiencyColor)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.black) // 锁屏界面通常是黑色背景
        .foregroundColor(.white) // 默认文字为白色
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
