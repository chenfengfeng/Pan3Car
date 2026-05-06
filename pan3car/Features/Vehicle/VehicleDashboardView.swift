//
//  VehicleDashboardView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import MapKit
import SwiftUI

struct VehicleDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: VehicleDashboardSnapshot
    
    @State private var animatedRange: Int = 0
    @State private var animatedSOC: Int = 0
    @State private var animatedMileage: Double = 0
    @State private var isHeroCarPresented = false
    @State private var controlStates: [String: Bool] = [:]
    @State private var acRotationDegrees: Double = 0
    @State private var isACSheetPresented = false
    @State private var selectedACTemperature = "24"
    @State private var selectedACDuration = "30"

    private let acTemperatureOptions = ["速冷", "20", "24", "26", "28", "速热"]
    private let acDurationOptions = ["10", "15", "20", "25", "30"]

    var body: some View {
        ZStack {
            liquidBackground

            ScrollView {
                VStack(spacing: 0) {
                    heroSection

                    LazyVStack(spacing: 24) {
                        vehicleStatsCard
                        activeSessionCards
                        controlsGrid
                        quickInfoGrid
                        WindowStatusCard(items: snapshot.windows)
                        DoorStatusCard(items: snapshot.doors)
                        TirePressureCard(items: snapshot.tirePressures)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, -88)
                }
            }
        }
        .navigationTitle("胖胖的胖3")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("vehicle.dashboard")
        .task(id: snapshot.availableRangeKm) {
            await animateRangeFromZeroIfNeeded(to: snapshot.availableRangeKm)
        }
        .task(id: snapshot.soc) {
            await animateSOCIfNeeded(to: snapshot.soc)
        }
        .task(id: snapshot.totalMileageKm) {
            await animateMileageIfNeeded(to: snapshot.totalMileageKm)
        }
        .task {
            initializeControlStatesIfNeeded()
        }
        .sheet(isPresented: $isACSheetPresented) {
            ACControlSheet(
                selectedTemperature: $selectedACTemperature,
                selectedDuration: $selectedACDuration,
                temperatureOptions: acTemperatureOptions,
                durationOptions: acDurationOptions,
                onStart: openAC
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(.ultraThinMaterial)
        }
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

    private var heroSection: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                rangeHeroMetric
                    .padding(.horizontal, 52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 24)
                    .zIndex(0)

                Image("car_profile")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .padding(.horizontal, 14)
                    .offset(x: heroCarXOffset(containerWidth: proxy.size.width), y: -38)
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.15), radius: 20, x: 0, y: 15)
                    .accessibilityHidden(true)
                    .zIndex(1)
            }
        }
        .frame(height: 318)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("可用行程 \(snapshot.availableRangeKm) 公里")
        .accessibilityIdentifier("vehicle.rangeHero")
        .task {
            await animateHeroCarEntry()
        }
    }

    private var rangeHeroMetric: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(animatedRange)")
                .contentTransition(.numericText(value: Double(animatedRange)))
                .monospacedDigit()
                .font(.system(size: 78, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.62)
                .lineLimit(1)

            Text("km")
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .shadow(color: colorScheme == .dark ? .black.opacity(0.28) : .white.opacity(0.62), radius: 16, x: 0, y: 8)
    }

    private var vehicleStatsCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("总里程")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        AnimatedIntegerText(value: animatedMileage)
                        Text("km")
                    }
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityIdentifier("vehicle.totalMileage")
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
                    Text("电量进度")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(animatedSOC)%")
                        .contentTransition(.numericText(value: Double(animatedSOC)))
                        .monospacedDigit()
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(socTint)
                }
            }
        }
        .padding(24)
        .liquidGlass(cornerRadius: 32)
    }

    private var activeSessionCards: some View {
        VStack(spacing: 16) {
            ActiveSessionCard(
                title: "车辆正在行驶",
                primaryValue: "324.3 km",
                primaryLabel: "已行驶",
                secondaryValue: "442 km",
                secondaryLabel: "消耗续航",
                systemImage: "car.fill",
                tint: .blue,
                accessibilityID: "vehicle.activeDriving"
            )

            ActiveSessionCard(
                title: "车辆正在充电",
                primaryValue: "32.3 度电",
                primaryLabel: "已充电",
                secondaryValue: "234 km",
                secondaryLabel: "增加续航",
                systemImage: "bolt.fill",
                tint: .green,
                accessibilityID: "vehicle.activeCharging"
            )
        }
    }

    private var controlsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
            ForEach(snapshot.controls) { control in
                let isActive = controlState(for: control)
                let isHighlighted = controlHighlightState(for: control, isActive: isActive)
                let title = controlTitle(for: control, isActive: isActive)
                let systemImage = controlSystemImage(for: control, isActive: isActive)
                let tint = controlTint(for: control)

                if control.id == "ac" && !isActive {
                    Button {
                        isACSheetPresented = true
                    } label: {
                        controlButtonLabel(
                            control: control,
                            title: title,
                            systemImage: systemImage,
                            tint: tint,
                            isHighlighted: isHighlighted
                        )
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(cornerRadius: 24)
                    .animation(.spring(response: 0.34, dampingFraction: 0.68), value: isHighlighted)
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: systemImage)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("vehicle.control.\(control.id)")
                } else {
                    Button {
                        toggleControl(control)
                    } label: {
                        controlButtonLabel(
                            control: control,
                            title: title,
                            systemImage: systemImage,
                            tint: tint,
                            isHighlighted: isHighlighted
                        )
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(cornerRadius: 24)
                    .animation(.spring(response: 0.34, dampingFraction: 0.68), value: isHighlighted)
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: systemImage)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("vehicle.control.\(control.id)")
                }
            }
        }
    }

    private func controlButtonLabel(
        control: VehicleControlItem,
        title: String,
        systemImage: String,
        tint: Color,
        isHighlighted: Bool
    ) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? tint : Color.clear)
                    .frame(width: 54, height: 54)
                    .scaleEffect(isHighlighted ? 1 : 0.82)

                if isHighlighted {
                    Circle()
                        .fill(tint)
                        .frame(width: 54, height: 54)
                        .blur(radius: 8)
                        .opacity(0.5)
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(isHighlighted ? .white : .primary)
                    .rotationEffect(.degrees(controlIconRotation(for: control)))
                    .id(systemImage)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .contentShape(.rect)
    }

    private var quickInfoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            NavigationLink {
                VehicleLocationMapView(location: snapshot.location)
            } label: {
                LocationMapCard(location: snapshot.location)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开地图，获取当前位置并开始步行导航")

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

    private func initializeControlStatesIfNeeded() {
        guard controlStates.isEmpty else { return }
        controlStates = Dictionary(uniqueKeysWithValues: snapshot.controls.map { ($0.id, $0.isActive) })
    }

    private func controlState(for control: VehicleControlItem) -> Bool {
        controlStates[control.id] ?? control.isActive
    }

    private func controlHighlightState(for control: VehicleControlItem, isActive: Bool) -> Bool {
        switch control.id {
        case "lock", "window":
            !isActive
        default:
            isActive
        }
    }

    private func toggleControl(_ control: VehicleControlItem) {
        guard control.id == "lock" || control.id == "ac" || control.id == "window" else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) {
            controlStates[control.id] = !controlState(for: control)
        }

        if control.id == "ac" {
            spinACIcon()
        }
    }

    private func openAC() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) {
            controlStates["ac"] = true
        }

        isACSheetPresented = false
        spinACIcon()
    }

    private func controlTitle(for control: VehicleControlItem, isActive: Bool) -> String {
        switch control.id {
        case "lock":
            isActive ? "已锁车" : "已解锁"
        case "ac":
            isActive ? "空调开" : "空调关"
        case "window":
            isActive ? "窗已关" : "窗已开"
        default:
            control.title
        }
    }

    private func controlSystemImage(for control: VehicleControlItem, isActive: Bool) -> String {
        switch control.id {
        case "lock":
            isActive ? "lock.fill" : "lock.open.fill"
        case "ac":
            isActive ? "fan.fill" : "fan"
        case "window":
            isActive ? "window.shade.closed" : "window.shade.open"
        default:
            control.systemImage
        }
    }

    private func controlTint(for control: VehicleControlItem) -> Color {
        switch control.id {
        case "lock":
            .green
        case "ac":
            .cyan
        case "window":
            .teal
        default:
            control.tint
        }
    }

    private func controlIconRotation(for control: VehicleControlItem) -> Double {
        control.id == "ac" ? acRotationDegrees : 0
    }

    private func spinACIcon() {
        guard !reduceMotion else { return }

        withAnimation(.linear(duration: 0.72)) {
            acRotationDegrees += 360
        }
    }

    private func heroCarXOffset(containerWidth: CGFloat) -> CGFloat {
        isHeroCarPresented ? 0 : containerWidth + 260
    }

    @MainActor
    private func animateHeroCarEntry() async {
        if reduceMotion {
            isHeroCarPresented = true
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHeroCarPresented = false
        }

        try? await Task.sleep(nanoseconds: 120_000_000)

        guard !Task.isCancelled else { return }

        withAnimation(.smooth(duration: 1.15, extraBounce: 0)) {
            isHeroCarPresented = true
        }
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

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedSOC = 0
        }

        try? await Task.sleep(nanoseconds: 220_000_000)

        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 1.25)) {
            animatedSOC = newValue
        }
    }

    @MainActor
    private func animateMileageIfNeeded(to newValue: Int) async {
        let target = Double(newValue)

        if reduceMotion {
            animatedMileage = target
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedMileage = 0
        }

        try? await Task.sleep(nanoseconds: 180_000_000)

        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 1.35)) {
            animatedMileage = target
        }
    }
}

private struct AnimatedIntegerText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value.rounded()).formatted())
            .monospacedDigit()
    }
}

private struct ACControlSheet: View {
    @Binding var selectedTemperature: String
    @Binding var selectedDuration: String
    let temperatureOptions: [String]
    let durationOptions: [String]
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "fan.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.cyan, in: Circle())
                    .shadow(color: .cyan.opacity(0.35), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("开启空调")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("\(temperatureSummary) · \(selectedDuration) 分钟")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            SegmentOptionRow(title: "温度", options: temperatureOptions, selection: $selectedTemperature, showsDegreeMark: true)
            SegmentOptionRow(title: "持续时间（分钟）", options: durationOptions, selection: $selectedDuration)

            Button {
                onStart()
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("开启空调")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .cyan.opacity(0.28), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var temperatureSummary: String {
        selectedTemperature == "速冷" || selectedTemperature == "速热" ? selectedTemperature : "\(selectedTemperature)°"
    }
}

private struct SegmentOptionRow: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    var showsDegreeMark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            SlidingSegmentedControl(options: options, selection: $selection, showsDegreeMark: showsDegreeMark)
        }
    }
}

private struct SlidingSegmentedControl: View {
    let options: [String]
    @Binding var selection: String
    var showsDegreeMark = false

    private var selectedIndex: Int {
        options.firstIndex(of: selection) ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            let segmentWidth = proxy.size.width / CGFloat(max(options.count, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.primary.opacity(0.08))

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.cyan)
                    .frame(width: max(segmentWidth - 6, 0), height: 42)
                    .offset(x: CGFloat(selectedIndex) * segmentWidth + 3)
                    .shadow(color: .cyan.opacity(0.28), radius: 10, x: 0, y: 5)

                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection == option

                        SegmentOptionLabel(option: option, isSelected: isSelected, showsDegreeMark: showsDegreeMark)
                            .frame(width: segmentWidth, height: 46)
                            .contentShape(.rect)
                            .onTapGesture {
                                select(option)
                            }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = max(0, min(options.count - 1, Int(value.location.x / segmentWidth)))
                        select(options[index])
                    }
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selection)
        }
        .frame(height: 46)
    }

    private func select(_ option: String) {
        guard selection != option else { return }
        selection = option
    }
}

private struct SegmentOptionLabel: View {
    let option: String
    let isSelected: Bool
    let showsDegreeMark: Bool

    private var shouldShowDegreeMark: Bool {
        showsDegreeMark && Int(option) != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            Text(option)
                .font(.subheadline.weight(.bold))

            if shouldShowDegreeMark {
                Text("°")
                    .font(.caption2.weight(.heavy))
                    .padding(.top, 1)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActiveSessionCard: View {
    let title: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let systemImage: String
    let tint: Color
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(tint, in: Circle())
                    .shadow(color: tint.opacity(0.42), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text("实时状态")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 14) {
                metric(value: primaryValue, label: primaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 42)
                    .overlay(Color.primary.opacity(0.12))

                metric(value: secondaryValue, label: secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .liquidGlass(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(primaryLabel) \(primaryValue) \(secondaryLabel) \(secondaryValue)")
        .accessibilityIdentifier(accessibilityID)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LocationMapCard: View {
    let location: VehicleLocationSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var coordinate: CLLocationCoordinate2D {
        Self.coordinate(from: location.coordinateText) ?? CLLocationCoordinate2D(latitude: 31.3304, longitude: 122.4737)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: .region(region), interactionModes: [])
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .saturation(colorScheme == .dark ? 0.55 : 0.75)
                .opacity(colorScheme == .dark ? 0.62 : 0.72)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    .black.opacity(colorScheme == .dark ? 0.26 : 0.08),
                    .black.opacity(colorScheme == .dark ? 0.72 : 0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("车辆当前位置")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(location.address)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(location.coordinateText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 192, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.34), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.1), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("车辆当前位置 \(location.address) \(location.coordinateText)")
        .accessibilityIdentifier("vehicle.location")
    }

    private static func coordinate(from text: String) -> CLLocationCoordinate2D? {
        let normalized = text
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "N", with: "")
            .replacingOccurrences(of: "E", with: "")
            .replacingOccurrences(of: "S", with: "")
            .replacingOccurrences(of: "W", with: "")

        let parts = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2,
              var latitude = Double(parts[0]),
              var longitude = Double(parts[1]) else {
            return nil
        }

        if text.contains("S") {
            latitude *= -1
        }

        if text.contains("W") {
            longitude *= -1
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let accessibilityID: String
    private let cardHeight: CGFloat = 192

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }

            Spacer(minLength: 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
        .liquidGlass(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct WindowStatusCard: View {
    let items: [VehicleStatusItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("车窗状态")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    WindowStatusTile(item: item)
                }
            }
            .padding(16)
            .liquidGlass(cornerRadius: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WindowStatusTile: View {
    let item: VehicleStatusItem

    private var isOpen: Bool {
        item.value != "关闭"
    }

    private var isLeftSide: Bool {
        item.id.contains("-l")
    }

    private var tint: Color {
        isOpen ? .orange : .green
    }

    private var systemImage: String {
        if isOpen {
            "car.window.right.badge.exclamationmark"
        } else {
            isLeftSide ? "car.window.left" : "car.window.right"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isOpen ? 0.2 : 0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(item.value)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(isOpen ? tint : .primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)车窗 \(item.value)")
        .accessibilityIdentifier("vehicle.window.\(item.id)")
    }
}

private struct DoorStatusCard: View {
    let items: [VehicleStatusItem]

    private var openItems: [VehicleStatusItem] {
        items.filter { $0.value != "关闭" }
    }

    private var summaryText: String {
        openItems.isEmpty ? "全部关闭" : "\(openItems.count)处开启"
    }

    private var summaryTint: Color {
        openItems.isEmpty ? .green : .orange
    }

    private var openDoorSegments: [String] {
        doorSegmentOrder.compactMap { id, segment in
            guard let item = items.first(where: { $0.id == id }),
                  item.value != "关闭" else {
                return nil
            }

            return segment
        }
    }

    private var isTrunkOpen: Bool {
        items.first { $0.id == "door-trunk" }?.value == "开启"
    }

    private var doorSegmentOrder: [(id: String, segment: String)] {
        [
            ("door-lf", "front.left"),
            ("door-rf", "front.right"),
            ("door-lr", "rear.left"),
            ("door-rr", "rear.right")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("车门状态")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            VStack(spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summaryText)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(summaryTint)

                        Text("含四门与后尾箱")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: heroSymbol)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(summaryTint)
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }

                Divider()
                    .overlay(Color.primary.opacity(0.08))

                doorStatusRows
            }
            .padding(20)
            .liquidGlass(cornerRadius: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vehicle.doors.card")
    }

    private var heroSymbol: String {
        if !openDoorSegments.isEmpty {
            return "car.top.door.\(openDoorSegments.joined(separator: ".and.")).open"
        }

        if isTrunkOpen {
            return "car.side.rear.open"
        }

        if openItems.isEmpty {
            return "car.side"
        }

        return "car.side"
    }

    private var doorStatusRows: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                doorStatus(itemID: "door-lf", fallbackTitle: "左前")
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                doorStatus(itemID: "door-rf", fallbackTitle: "右前")
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                doorStatus(itemID: "door-lr", fallbackTitle: "左后")
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                doorStatus(itemID: "door-rr", fallbackTitle: "右后")
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }

            doorStatus(itemID: "door-trunk", fallbackTitle: "后尾箱")
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func doorStatus(itemID: String, fallbackTitle: String) -> some View {
        let item = items.first { $0.id == itemID }
        let value = item?.value ?? "未知"
        let isOpen = value != "关闭"
        let tint: Color = isOpen ? .orange : .green
        let placesIconOnRight = itemID == "door-rf" || itemID == "door-rr"

        return HStack(spacing: 10) {
            if placesIconOnRight {
                doorStatusText(
                    title: item?.title ?? fallbackTitle,
                    value: value,
                    tint: tint,
                    isOpen: isOpen,
                    alignment: .trailing
                )
                doorStatusIcon(item: item, tint: tint)
            } else {
                doorStatusIcon(item: item, tint: tint)
                doorStatusText(
                    title: item?.title ?? fallbackTitle,
                    value: value,
                    tint: tint,
                    isOpen: isOpen,
                    alignment: .leading
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item?.title ?? fallbackTitle)车门 \(value)")
    }

    private func doorStatusIcon(item: VehicleStatusItem?, tint: Color) -> some View {
        Image(systemName: item.map(symbol(for:)) ?? "car.top.door.front.left.open")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 28)
    }

    private func doorStatusText(
        title: String,
        value: String,
        tint: Color,
        isOpen: Bool,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)

            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(isOpen ? tint : .primary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
    }

    private func symbol(for item: VehicleStatusItem) -> String {
        switch item.id {
        case "door-lf":
            "car.top.door.front.left.open"
        case "door-rf":
            "car.top.door.front.right.open"
        case "door-lr":
            "car.top.door.rear.left.open"
        case "door-rr":
            "car.top.door.rear.right.open"
        case "door-trunk":
            "car.side.rear.open"
        default:
            item.systemImage
        }
    }
}

private struct TirePressureCard: View {
    let items: [VehicleStatusItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("胎压状态")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            ZStack {
                Image(systemName: "rectangle.portrait")
                    .font(.system(size: 116, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.18))
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                VStack {
                    HStack(alignment: .top) {
                        tirePressure(itemID: "tire-lf", fallbackTitle: "左前", alignment: .leading)

                        Spacer(minLength: 96)

                        tirePressure(itemID: "tire-rf", fallbackTitle: "右前", alignment: .trailing)
                    }

                    Spacer(minLength: 58)

                    HStack(alignment: .bottom) {
                        tirePressure(itemID: "tire-lr", fallbackTitle: "左后", alignment: .leading)

                        Spacer(minLength: 96)

                        tirePressure(itemID: "tire-rr", fallbackTitle: "右后", alignment: .trailing)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, minHeight: 248)
            .liquidGlass(cornerRadius: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vehicle.tirePressure.card")
    }

    private func tirePressure(
        itemID: String,
        fallbackTitle: String,
        alignment: HorizontalAlignment
    ) -> some View {
        let item = items.first { $0.id == itemID }
        let pressure = Self.pressureKPa(from: item?.value ?? "0")
        let textAlignment: TextAlignment = alignment == .trailing ? .trailing : .leading
        let frameAlignment: Alignment = alignment == .trailing ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 6) {
            Text(item?.title ?? fallbackTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(textAlignment)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(pressure)")
                    .font(.title2.weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(pressure)))

                Text("kPa")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .frame(width: 92, alignment: frameAlignment)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item?.title ?? fallbackTitle)胎压 \(pressure) kPa")
        .accessibilityIdentifier("vehicle.tirePressure.\(itemID)")
    }

    private static func pressureKPa(from value: String) -> Int {
        let lowercasedValue = value.lowercased()
        let numericText = lowercasedValue.replacingOccurrences(
            of: "[^0-9.]",
            with: "",
            options: .regularExpression
        )

        guard let number = Double(numericText) else {
            return 0
        }

        if lowercasedValue.contains("bar") {
            return Int((number * 100).rounded())
        }

        return Int(number.rounded())
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

#Preview("Doors Open") {
    NavigationStack {
        VehicleDashboardView(snapshot: .mockDoorsOpen)
    }
}
