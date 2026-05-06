//
//  VehicleDashboardView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct VehicleDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: VehicleDashboardSnapshot
    
    @State private var animatedRange: Int = 0
    @State private var animatedSOC: Int = 0

    var body: some View {
        ZStack {
            liquidBackground

            ScrollView {
                VStack(spacing: 0) {
                    // 车辆展示主图
                    Image("car_profile")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .padding(.top, 10)
                        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.15), radius: 20, x: 0, y: 15)

                    LazyVStack(spacing: 24) {
                        rangeCard
                        controlsGrid
                        quickInfoGrid
                        StatusSection(title: "车窗状态", items: snapshot.windows)
                        StatusSection(title: "车门状态", items: snapshot.doors)
                        StatusSection(title: "胎压状态", items: snapshot.tirePressures)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("车辆")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("vehicle.dashboard")
    }

    private var liquidBackground: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .systemGroupedBackground) // fallback base
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let opacityMultiplier = colorScheme == .dark ? 0.6 : 1.0
                
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 1.2)
                    .blur(radius: 100)
                    .offset(x: -w * 0.4, y: -h * 0.1)
                    .opacity(0.35 * opacityMultiplier)
                
                Circle()
                    .fill(LinearGradient(colors: [.mint, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                    .frame(width: w)
                    .blur(radius: 90)
                    .offset(x: w * 0.3, y: h * 0.4)
                    .opacity(0.25 * opacityMultiplier)
                
                Circle()
                    .fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.8)
                    .blur(radius: 120)
                    .offset(x: w * 0.1, y: h * 0.8)
                    .opacity(0.2 * opacityMultiplier)
            }
            .ignoresSafeArea()
        }
    }

    private var rangeCard: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("预估续航")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(animatedRange)")
                            .contentTransition(.numericText(value: Double(animatedRange)))
                            .monospacedDigit()
                            .font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        
                        Text("km")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("可用行程 \(snapshot.availableRangeKm) 公里")
                    .accessibilityIdentifier("vehicle.range")
                }
                
                Spacer(minLength: 16)
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("剩余电量")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 0) {
                        Text("\(animatedSOC)")
                            .contentTransition(.numericText(value: Double(animatedSOC)))
                            .monospacedDigit()
                        Text("%")
                    }
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(socTint)
                    .accessibilityIdentifier("vehicle.socText")
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 12)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [socTint.opacity(0.6), socTint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * CGFloat(clampedSOC) / 100, 12), height: 12)
                            .shadow(color: socTint.opacity(0.4), radius: 6, x: 0, y: 2)
                    }
                }
                .frame(height: 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("SOC进度")
                .accessibilityValue("\(snapshot.soc)%")
                .accessibilityIdentifier("vehicle.socProgress")
                
                HStack {
                    Text("总里程")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(snapshot.totalMileageKm.formatted()) km")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("vehicle.totalMileage")
                }
            }
        }
        .padding(24)
        .liquidGlass(cornerRadius: 32)
        .task(id: snapshot.availableRangeKm) {
            await animateRangeFromZeroIfNeeded(to: snapshot.availableRangeKm)
        }
        .task(id: snapshot.soc) {
            await animateSOCIfNeeded(to: snapshot.soc)
        }
    }

    private var controlsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 16) {
            ForEach(snapshot.controls) { control in
                Button {
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(control.isActive ? control.tint : Color.clear)
                                .frame(width: 54, height: 54)
                            
                            if control.isActive {
                                Circle()
                                    .fill(control.tint)
                                    .frame(width: 54, height: 54)
                                    .blur(radius: 8)
                                    .opacity(0.5)
                            }
                            
                            Image(systemName: control.systemImage)
                                .font(.title2.weight(.medium))
                                .foregroundStyle(control.isActive ? .white : .primary)
                        }
                        
                        Text(control.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .liquidGlass(cornerRadius: 24)
                .accessibilityLabel(control.title)
                .accessibilityIdentifier("vehicle.control.\(control.id)")
            }
        }
    }

    private var quickInfoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            InfoCard(
                title: "车辆当前位置",
                value: snapshot.location.address,
                subtitle: snapshot.location.coordinateText,
                systemImage: "location.fill",
                tint: .blue,
                accessibilityID: "vehicle.location"
            )

            InfoCard(
                title: "车内温度",
                value: "\(snapshot.cabinTemperature)°C",
                subtitle: "当前座舱温度",
                systemImage: "thermometer.sun.fill",
                tint: .orange,
                accessibilityID: "vehicle.temperature"
            )
        }
    }

    private var socTint: Color {
        snapshot.soc >= 30 ? .green : .orange
    }

    private var clampedSOC: Int {
        min(max(animatedSOC, 0), 100)
    }

    @MainActor
    private func animateRangeFromZeroIfNeeded(to newValue: Int) async {
        if reduceMotion {
            animatedRange = newValue
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedRange = 0
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        guard !Task.isCancelled else { return }

        withAnimation(.bouncy(duration: 1.5)) {
            animatedRange = newValue
        }
    }

    @MainActor
    private func animateSOCIfNeeded(to newValue: Int) async {
        if reduceMotion {
            animatedSOC = newValue
            return
        }

        withAnimation(.bouncy(duration: 1.5)) {
            animatedSOC = newValue
        }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct StatusSection: View {
    let title: String
    let items: [VehicleStatusItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(items) { item in
                    StatusTile(item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

private struct StatusTile: View {
    let item: VehicleStatusItem

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(item.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(item.value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title) \(item.value)")
        .accessibilityIdentifier("vehicle.status.\(item.id)")
    }
}

struct LiquidGlassStyle: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? .white.opacity(0.3) : .white.opacity(0.8),
                                .clear,
                                colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(LiquidGlassStyle(cornerRadius: cornerRadius))
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
