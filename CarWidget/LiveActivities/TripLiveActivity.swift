//
//  TripLiveActivity.swift
//  CarWidget
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripAttributes.self) { context in
            // 锁定屏幕视图
            TripLockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // 动态岛视图
            DynamicIsland {
                // 展开状态
                DynamicIslandExpandedRegion(.leading) {
                    TripExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TripExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    TripExpandedCenterView(context: context)
                }
            } compactLeading: {
                // 紧凑状态左侧
                TripCompactLeadingView(context: context)
            } compactTrailing: {
                // 紧凑状态右侧
                TripCompactTrailingView(context: context)
            } minimal: {
                // 最小状态
                TripMinimalView(context: context)
            }
        }
    }
}

// MARK: - 锁定屏幕视图
struct TripLockScreenLiveActivityView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部：App图标 + 行程进行中状态
            HStack {
                // App图标
                Image("AppIcon")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("行程进行中")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 行程效率
                Text("\(context.state.tripEfficiency, specifier: "%.1f") km/h")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 中部：左右两侧区域
            HStack(spacing: 20) {
                // 左侧区域
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("已行驶时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(context.state.formattedElapsedTime)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.green)
                        Text("出发时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(context.attributes.formattedDepartureTime)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // 右侧区域
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("实际里程")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "road.lanes")
                            .foregroundColor(.orange)
                    }
                    Text("\(context.state.actualMileage, specifier: "%.1f") km")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("出发时里程")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "speedometer")
                            .foregroundColor(.gray)
                    }
                    Text("\(context.attributes.initialMileage, specifier: "%.1f") km")
                        .font(.subheadline)
                }
            }
            
            // 底部：行程效率对比
            VStack(spacing: 6) {
                HStack {
                    Text("里程效率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(context.state.mileageEfficiencyPercentage, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(context.state.mileageEfficiencyPercentage >= 100 ? .green : .orange)
                }
                
                HStack {
                    Text("实际: \(context.state.actualMileage, specifier: "%.1f") km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("消耗: \(context.state.consumedMileage, specifier: "%.1f") km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 进度条
                ProgressView(value: min(context.state.actualMileage, context.state.consumedMileage), 
                           total: max(context.state.actualMileage, context.state.consumedMileage))
                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.mileageEfficiencyPercentage >= 100 ? .green : .orange))
                    .scaleEffect(x: 1, y: 0.5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - 动态岛紧凑状态左侧视图
struct TripCompactLeadingView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "car")
                .foregroundColor(.blue)
                .font(.caption)
            Text(context.state.formattedElapsedTime)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 动态岛紧凑状态右侧视图
struct TripCompactTrailingView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(context.state.actualMileage, specifier: "%.0f")")
                .font(.caption2)
                .fontWeight(.medium)
            Text("km")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 动态岛最小状态视图
struct TripMinimalView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        Image(systemName: "car")
            .foregroundColor(.blue)
            .font(.caption)
    }
}

// MARK: - 动态岛展开状态左侧视图
struct TripExpandedLeadingView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("已行驶")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(context.state.formattedElapsedTime)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 动态岛展开状态右侧视图
struct TripExpandedTrailingView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text("实际里程")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Image(systemName: "road.lanes")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            Text("\(context.state.actualMileage, specifier: "%.1f") km")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 动态岛展开状态中心视图
struct TripExpandedCenterView: View {
    let context: ActivityViewContext<TripAttributes>
    
    var body: some View {
        VStack(spacing: 4) {
            Text("行程进行中")
                .font(.caption)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                Text("\(context.state.tripEfficiency, specifier: "%.1f") km/h")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 2, height: 2)
                
                Text("\(context.state.mileageEfficiencyPercentage, specifier: "%.0f")%")
                    .font(.caption2)
                    .foregroundColor(context.state.mileageEfficiencyPercentage >= 100 ? .green : .orange)
            }
        }
    }
}