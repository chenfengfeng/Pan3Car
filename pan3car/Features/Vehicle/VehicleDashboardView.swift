//
//  VehicleDashboardView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct VehicleDashboardView: View {
    let snapshot: VehicleDashboardSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                rangeCard
                controlsGrid
                quickInfoGrid
                StatusSection(title: "车窗状态", items: snapshot.windows)
                StatusSection(title: "车门状态", items: snapshot.doors)
                StatusSection(title: "胎压状态", items: snapshot.tirePressures)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("车辆")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("vehicle.dashboard")
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("可用行程")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(snapshot.availableRangeKm)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)

                        Text("km")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("可用行程 \(snapshot.availableRangeKm) 公里")
                    .accessibilityIdentifier("vehicle.range")
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("SOC")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(snapshot.soc)%")
                        .font(.title.bold())
                        .foregroundStyle(socTint)
                        .accessibilityIdentifier("vehicle.socText")
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: Double(snapshot.soc), total: 100)
                    .tint(socTint)
                    .accessibilityLabel("SOC进度")
                    .accessibilityValue("\(snapshot.soc)%")
                    .accessibilityIdentifier("vehicle.socProgress")

                Text("总里程 \(snapshot.totalMileageKm.formatted()) km")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("vehicle.totalMileage")
            }
        }
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var controlsGrid: some View {
        LazyVGrid(columns: adaptiveControlColumns, spacing: 12) {
            ForEach(snapshot.controls) { control in
                Button {
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: control.systemImage)
                            .font(.title2.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(control.isActive ? .white : control.tint)
                            .background(control.isActive ? control.tint : control.tint.opacity(0.14), in: Circle())

                        Text(control.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
                .accessibilityLabel(control.title)
                .accessibilityIdentifier("vehicle.control.\(control.id)")
            }
        }
    }

    private var quickInfoGrid: some View {
        LazyVGrid(columns: adaptiveInfoColumns, spacing: 12) {
            InfoCard(
                title: "车辆当前位置",
                value: snapshot.location.address,
                subtitle: snapshot.location.coordinateText,
                systemImage: "location.fill",
                tint: .orange,
                accessibilityID: "vehicle.location"
            )

            InfoCard(
                title: "车内温度",
                value: "\(snapshot.cabinTemperature)°C",
                subtitle: "当前座舱温度",
                systemImage: "thermometer.medium",
                tint: .red,
                accessibilityID: "vehicle.temperature"
            )
        }
    }

    private var socTint: Color {
        snapshot.soc >= 30 ? .green : .orange
    }

    private var adaptiveControlColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 76), spacing: 12)]
    }

    private var adaptiveInfoColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 156), spacing: 12)]
    }
}

private struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct StatusSection: View {
    let title: String
    let items: [VehicleStatusItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    StatusTile(item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusTile: View {
    let item: VehicleStatusItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34)
                .background(item.tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(item.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title) \(item.value)")
        .accessibilityIdentifier("vehicle.status.\(item.id)")
    }
}

#Preview("Vehicle Light") {
    NavigationStack {
        VehicleDashboardView(snapshot: .mock)
    }
}

#Preview("Vehicle Dark") {
    NavigationStack {
        VehicleDashboardView(snapshot: .mock)
    }
    .preferredColorScheme(.dark)
}
