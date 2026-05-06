//
//  VehicleDashboardModels.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct VehicleDashboardSnapshot {
    let availableRangeKm: Int
    let soc: Int
    let totalMileageKm: Int
    let location: VehicleLocationSnapshot
    let cabinTemperature: Int
    let controls: [VehicleControlItem]
    let windows: [VehicleStatusItem]
    let doors: [VehicleStatusItem]
    let tirePressures: [VehicleStatusItem]
}

struct VehicleLocationSnapshot {
    let address: String
    let coordinateText: String
}

struct VehicleControlItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isActive: Bool
    let tint: Color
}

struct VehicleStatusItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

extension VehicleDashboardSnapshot {
    static let mock = VehicleDashboardSnapshot(
        availableRangeKm: 268,
        soc: 76,
        totalMileageKm: 12860,
        location: VehicleLocationSnapshot(
            address: "上海市浦东新区世纪大道附近",
            coordinateText: "31.2304°N, 121.4737°E"
        ),
        cabinTemperature: 26,
        controls: [
            VehicleControlItem(id: "lock", title: "已锁车", systemImage: "lock.fill", isActive: true, tint: .green),
            VehicleControlItem(id: "ac", title: "空调关", systemImage: "fan.fill", isActive: false, tint: .cyan),
            VehicleControlItem(id: "window", title: "窗已关", systemImage: "rectangle.split.3x1.fill", isActive: true, tint: .teal),
            VehicleControlItem(id: "honk", title: "鸣笛", systemImage: "car.front.waves.up", isActive: false, tint: .orange)
        ],
        windows: [
            VehicleStatusItem(id: "window-lf", title: "左前", value: "关闭", systemImage: "window.vertical.closed", tint: .green),
            VehicleStatusItem(id: "window-rf", title: "右前", value: "关闭", systemImage: "window.vertical.closed", tint: .green),
            VehicleStatusItem(id: "window-lr", title: "左后", value: "关闭", systemImage: "window.vertical.closed", tint: .green),
            VehicleStatusItem(id: "window-rr", title: "右后", value: "关闭", systemImage: "window.vertical.closed", tint: .green)
        ],
        doors: [
            VehicleStatusItem(id: "door-lf", title: "左前", value: "关闭", systemImage: "car.side.front.open", tint: .green),
            VehicleStatusItem(id: "door-rf", title: "右前", value: "关闭", systemImage: "car.side.front.open", tint: .green),
            VehicleStatusItem(id: "door-lr", title: "左后", value: "关闭", systemImage: "car.side.rear.open", tint: .green),
            VehicleStatusItem(id: "door-rr", title: "右后", value: "关闭", systemImage: "car.side.rear.open", tint: .green),
            VehicleStatusItem(id: "door-trunk", title: "后尾箱", value: "关闭", systemImage: "car.side.rear.open", tint: .green)
        ],
        tirePressures: [
            VehicleStatusItem(id: "tire-lf", title: "左前", value: "257", systemImage: "gauge.with.dots.needle.50percent", tint: .blue),
            VehicleStatusItem(id: "tire-rf", title: "右前", value: "256", systemImage: "gauge.with.dots.needle.50percent", tint: .blue),
            VehicleStatusItem(id: "tire-lr", title: "左后", value: "248", systemImage: "gauge.with.dots.needle.50percent", tint: .blue),
            VehicleStatusItem(id: "tire-rr", title: "右后", value: "249", systemImage: "gauge.with.dots.needle.50percent", tint: .blue)
        ]
    )

    static let mockDoorsOpen = VehicleDashboardSnapshot(
        availableRangeKm: mock.availableRangeKm,
        soc: mock.soc,
        totalMileageKm: mock.totalMileageKm,
        location: mock.location,
        cabinTemperature: mock.cabinTemperature,
        controls: mock.controls,
        windows: mock.windows,
        doors: [
            VehicleStatusItem(id: "door-lf", title: "左前", value: "关闭", systemImage: "car.top.door.front.left.open", tint: .green),
            VehicleStatusItem(id: "door-rf", title: "右前", value: "关闭", systemImage: "car.top.door.front.right.open", tint: .green),
            VehicleStatusItem(id: "door-lr", title: "左后", value: "开启", systemImage: "car.top.door.rear.left.open", tint: .orange),
            VehicleStatusItem(id: "door-rr", title: "右后", value: "开启", systemImage: "car.top.door.rear.right.open", tint: .orange),
            VehicleStatusItem(id: "door-trunk", title: "后尾箱", value: "关闭", systemImage: "car.side.rear.open", tint: .green)
        ],
        tirePressures: mock.tirePressures
    )
}
