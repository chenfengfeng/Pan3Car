//
//  ContentView.swift
//  Car Watch App
//
//  Created by Feng on 2025/8/14.
//

import SwiftUI
import CoreLocation
import WatchConnectivity
import WatchKit

// 使用自定义Button样式以保持视觉一致性

struct ContentView: View {
    @State private var currentPage = 0

    
    // 车辆数据模型
    @State private var carModel: SharedCarModel?
    @State private var isLoading = false
    @State private var lastUpdateTime = Date()
    
    // 第三页详细信息的状态变量
    @State private var currentLocation = "获取位置中..."
    @State private var isHornPressed = false // 鸣笛按钮动画状态
    
    // WatchConnectivity管理器
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景图片
                Image(backgroundImageName)//根据充电状态动态选择背景图片
                    .resizable()
                    .ignoresSafeArea(.all)
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: currentPage == 0 ? 0 : 5)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                
                TabView(selection: $currentPage) {
                    // 第1页
                    carInfoContent()
                        .frame(height: geo.size.height)
                        .tag(0)
                    
                    // 第2页
                    controlPanelView()
                        .frame(height: geo.size.height)
                        .tag(1)
                    
                    // 第3页
                    detailInfoView()
                        .frame(height: geo.size.height)
                        .tag(2)
                }
                .tabViewStyle(.verticalPage)
                .indexViewStyle(.page(backgroundDisplayMode: .never))
            }
        }
        .edgesIgnoringSafeArea(.all) // watchOS全屏设置
        .onAppear {
            // 初始化WatchConnectivity
            _ = WatchConnectivityManager.shared
            loadCarData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authDataUpdated)) { _ in
            print("[Watch Debug] 收到认证数据更新通知，开始刷新车辆数据")
            loadCarData()
        }
        .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationDidBecomeActiveNotification)) { _ in
            print("[Watch Debug] Watch应用变为活跃状态，刷新车辆数据")
            loadCarData()
        }

    }
    
    // 第一页：汽车信息内容
    private func carInfoContent() -> some View {
        VStack {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // 剩余里程
                        let mile = carModel?.acOnMile ?? 0
                        HStack(alignment: .bottom, spacing: 2) {
                            Text("\(mile)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .animation(.easeInOut(duration: 1.0), value: mile)
                                .contentTransition(.numericText(value: Double(mile)))
                            
                            Text("km")
                                .font(.caption)
                                .foregroundColor(.white)
                                .offset(y: -3)
                        }
                        // SOC进度条
                        ZStack(alignment: .leading) {
                            // 灰色背景进度条
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 4)
                                .cornerRadius(2)
                            
                            // 实际进度条
                            Rectangle()
                                .fill(socColor(for: socPercentage))
                                .frame(width: 80 * (Double(socPercentage) / 100.0), height: 4)
                                .cornerRadius(2)
                        }
                        Text(statusText)// 根据车辆状态显示不同信息
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.leading, 10)
            }
            Spacer()
            VStack() {
                Text("总里程 \(totalMileageText)km")
                    .padding(.trailing, 20)
                    .contentTransition(.numericText(value: totalMileageValue))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 15)
        }
    }
    
    // 第二页：控制面板视图
    private func controlPanelView() -> some View {
        GeometryReader { geometry in
            let buttonSize = min(geometry.size.width * 0.4, geometry.size.height * 0.35)
            let spacing = geometry.size.width * 0.05
            
            VStack(spacing: spacing * 2) {
                // 第一行：车锁、空调
                HStack(spacing: spacing) {
                    // 车锁开关
                    VStack(spacing: 8) {
                        Button(action: {
                            let operation = isCarLocked ? 2 : 1
                            SharedNetworkManager.shared.energyLock(operation: operation) { _ in
                                print("车锁控制按钮被点击，状态已切换")
                            }
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                // 本地切换车锁状态
                                if var model = carModel {
                                    model.mainLockStatus = model.mainLockStatus == 0 ? 1 : 0
                                    carModel = model
                                }
                            }
                        }) {
                            Image(systemName: isCarLocked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: buttonSize * 0.5))
                                .foregroundColor(.white)
                                .scaleEffect(isCarLocked ? 1.0 : 1.1)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(isCarLocked ? Color.white.opacity(0.2) : Color.green.opacity(0.8))
                        .clipShape(Circle())
                        .scaleEffect(isCarLocked ? 0.95 : 1.0)
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(isCarLocked ? "已锁车" : "已解锁")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .opacity(isCarLocked ? 0.8 : 1.0)
                    }
                    
                    // 空调开关
                    VStack(spacing: 8) {
                        Button(action: {
                            let operation = isACOn ? 2 : 1
                            let temperature = 26 // 默认温度
                            let duringTime = 30 // 默认持续时间10分钟
                            
                            SharedNetworkManager.shared.energyAirConditioner(operation: operation, temperature: temperature, duringTime: duringTime) { _ in
                                print("空调控制按钮被点击，状态已切换")
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                // 本地切换空调状态
                                if var model = carModel {
                                    model.acStatus = model.acStatus == 0 ? 1 : 0
                                    carModel = model
                                }
                            }
                        }) {
                            Image(systemName: isACOn ? "fanblades.fill" : "fanblades.slash.fill")
                                .font(.system(size: buttonSize * 0.45))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(isACOn ? 360 : 0))
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(isACOn ? Color.blue.opacity(0.8) : Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .scaleEffect(isACOn ? 1.0 : 0.95)
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(isACOn ? "空调开" : "空调关")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .opacity(isACOn ? 1.0 : 0.8)
                    }
                }
                
                // 第二行：车窗、鸣笛
                HStack(spacing: spacing) {
                    // 车窗开关
                    VStack(spacing: 8) {
                        Button(action: {
                            let operation = isWindowOpen ? 1 : 2  // 2开启，1关闭
                            let openLevel = isWindowOpen ? 0 : 2  // 2完全打开，0关闭
                            SharedNetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel) { _ in
                                print("车窗控制按钮被点击")
                            }
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                // 切换车窗控制功能
                                if var model = carModel {
                                    model.lfWindowOpen = model.lfWindowOpen == 0 ? 1 : 0
                                    model.lrWindowOpen = model.lrWindowOpen == 0 ? 1 : 0
                                    model.rfWindowOpen = model.rfWindowOpen == 0 ? 1 : 0
                                    model.rrWindowOpen = model.rrWindowOpen == 0 ? 1 : 0
                                    carModel = model
                                }
                            }
                        }) {
                            Image(systemName: isWindowOpen ? "window.shade.open" : "window.shade.closed")
                                .font(.system(size: buttonSize * 0.5))
                                .foregroundColor(.white)
                                .offset(y: isWindowOpen ? 0 : 2)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(isWindowOpen ? Color.mint.opacity(0.8) : Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .scaleEffect(isWindowOpen ? 1.0 : 0.95)
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(isWindowOpen ? "窗已开" : "窗已关")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .opacity(isWindowOpen ? 1.0 : 0.8)
                    }
                    
                    // 鸣笛按钮
                    VStack(spacing: 8) {
                        Button(action: {
                            SharedNetworkManager.shared.findCar { _ in
                                print("鸣笛按钮被点击")
                            }
                            // 鸣笛动作，添加震动和缩放动画效果
                            withAnimation(.easeInOut(duration: 0.2).repeatCount(3, autoreverses: true)) {
                                isHornPressed.toggle()
                            }
                            // 延迟重置状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isHornPressed = false
                            }
                        }) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: buttonSize * 0.45))
                                .foregroundColor(.white)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(Circle())
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isHornPressed ? 1.2 : 1.0) // 根据状态控制缩放
                        
                        Text("鸣笛")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
    
    // 第三页：详细信息视图
    private func detailInfoView() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // 车内温度（不可点击）
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("车内温度")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text({
                            guard let temp = carModel?.temperatureInCar, temp <= 100 else { return "--°C" }
                            return "\(temp)°C"
                        }())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // 当前位置
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("当前位置")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    HStack {
                        Text(currentLocation)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // 车窗状态
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "car.window.left")
                            .foregroundColor(.mint)
                        Text("车窗状态")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            windowStatusItem("前左", isOpen: carModel?.lfWindowOpen != 0)
                            windowStatusItem("前右", isOpen: carModel?.rfWindowOpen != 0)
                        }
                        HStack(spacing: 8) {
                            windowStatusItem("后左", isOpen: carModel?.lrWindowOpen != 0)
                            windowStatusItem("后右", isOpen: carModel?.rrWindowOpen != 0)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // 车门状态
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "car.side.fill")
                            .foregroundColor(.green)
                        Text("车门状态")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            doorStatusItem("前左门", isOpen: carModel?.doorStsFrontLeft != 0)
                            doorStatusItem("前右门", isOpen: carModel?.doorStsFrontRight != 0)
                        }
                        HStack(spacing: 8) {
                            doorStatusItem("后左门", isOpen: carModel?.doorStsRearLeft != 0)
                            doorStatusItem("后右门", isOpen: carModel?.doorStsRearRight != 0)
                        }
                        HStack {
                            trunkStatusItem("后尾箱", isOpen: carModel?.trunkLockStatus != 0)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // VIN显示
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "barcode")
                            .foregroundColor(.gray)
                        Text("VIN码")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    HStack {
                        Text(watchConnectivity.defaultVin ?? "获取中...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }
    
    // 车窗状态项
    private func windowStatusItem(_ title: String, isOpen: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white)
            Text(isOpen ? "开" : "关")
                .font(.caption2)
                .foregroundColor(isOpen ? Color.orange : Color.green)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 车门状态项
    private func doorStatusItem(_ title: String, isOpen: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white)
            Text(isOpen ? "开" : "关")
                .font(.caption2)
                .foregroundColor(isOpen ? Color.orange : Color.green)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 后尾箱状态项
    private func trunkStatusItem(_ title: String, isOpen: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white)
            Text(isOpen ? "开" : "关")
                .font(.caption2)
                .foregroundColor(isOpen ? Color.orange : Color.green)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func socColor(for soc: Int) -> Color {
        if soc < 10 {
            return .red
        } else if soc < 20 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    // 格式化分钟数为时间字符串
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes <= 0 {
            return "已完成"
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)小时\(remainingMinutes)分钟"
            } else {
                return "\(hours)小时"
            }
        } else {
            return "\(remainingMinutes)分钟"
        }
    }
    
    // MARK: - 数据获取方法
    
    /// 加载车辆数据
    private func loadCarData() {
        guard !isLoading else { return }
        
        isLoading = true
        SharedNetworkManager.shared.getCarModel { result in
            DispatchQueue.main.async {
                isLoading = false
                lastUpdateTime = Date()
                
                switch result {
                case .success(let model):
                    carModel = model
                    updateUIFromCarModel(model)
                case .failure(let error):
                    print("[Watch Debug] 获取车辆数据失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 刷新车辆数据（异步版本）
    private func refreshCarData() async {
        await withCheckedContinuation { continuation in
            SharedNetworkManager.shared.getCarModel { result in
                DispatchQueue.main.async {
                    lastUpdateTime = Date()
                    
                    switch result {
                    case .success(let model):
                        carModel = model
                        updateUIFromCarModel(model)
                    case .failure(let error):
                        print("[Watch Debug] 刷新车辆数据失败: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    /// 从车辆模型更新UI状态
    private func updateUIFromCarModel(_ model: SharedCarModel) {
        // 获取位置信息
        let coordinate = model.coordinate
        if coordinate.latitude != 0 && coordinate.longitude != 0 {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let geocoder = CLGeocoder()
            print(coordinate)
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("[Watch Debug] 逆地理编码失败: \(error.localizedDescription)")
                        currentLocation = "位置获取失败"
                        return
                    }
                    
                    if let placemark = placemarks?.first {
                        var addressComponents: [String] = []
                        
                        if let subLocality = placemark.subLocality {
                            addressComponents.append(subLocality)
                        }
                        if let thoroughfare = placemark.thoroughfare {
                            addressComponents.append(thoroughfare)
                        }
                        
                        currentLocation = addressComponents.joined(separator: " ")
                    } else {
                        currentLocation = "位置解析失败"
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    /// 剩余里程
    private var remainingMileage: Int {
        return carModel?.acOnMile ?? 0
    }
    
    /// SOC百分比
    private var socPercentage: Int {
        guard let soc = carModel?.soc, let socValue = Int(soc) else { return 0 }
        return socValue
    }
    
    /// 状态文本
    private var statusText: String {
        guard let model = carModel else { return "数据加载中..." }
        
        if model.chgStatus == 1 {
            // 充电中
            let remainingTime = model.quickChgLeftTime > 0 ? model.quickChgLeftTime : model.slowChgLeftTime
            if remainingTime > 0 {
                return "充电中 剩余\(formatMinutes(remainingTime))"
            } else {
                return "充电中"
            }
        } else {
            // 非充电状态
            return model.lockStatusDescription
        }
    }
    
    /// 总里程文本
    private var totalMileageText: String {
        return carModel?.totalMileage ?? "0"
    }
    
    /// 总里程数值（用于动画）
    private var totalMileageValue: Double {
        guard let mileageStr = carModel?.totalMileage, let value = Double(mileageStr) else { return 0 }
        return value
    }
    
    /// 背景图片名称
    private var backgroundImageName: String {
        guard let model = carModel else { return "my_car" }
        return model.chgStatus == 2 ? "my_car" : "my_car_charge"
    }
    
    // MARK: - 从CarModel获取车辆状态
    
    /// 车锁状态 - 从CarModel的mainLockStatus获取
    private var isCarLocked: Bool {
        guard let model = carModel else { return true }
        return model.mainLockStatus == 0 // 0表示已锁定，其他表示已解锁
    }
    
    /// 空调状态 - 从CarModel的acStatus获取
    private var isACOn: Bool {
        guard let model = carModel else { return false }
        return model.acStatus == 0 // 0表示开启，1表示关闭（根据airConditionerStatusDescription的逻辑）
    }
    
    /// 车窗状态 - 从CarModel的windowStates获取（任意一个窗户开启即认为车窗开启）
    private var isWindowOpen: Bool {
        guard let model = carModel else { return false }
        return model.windowStates.contains(true) // 任意一个窗户开启即认为车窗开启
    }
}

#Preview {
    ContentView()
        .onAppear {
            // This will be overridden by the preview data below
        }
        .environmentObject({
            let manager = WatchConnectivityManager.shared
            return manager
        }())
}
