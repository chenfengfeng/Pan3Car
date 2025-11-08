//
//  ContentView.swift
//  Car Watch App
//
//  Created by Feng on 2025/8/14.
//

import SwiftUI
import CoreLocation
import WatchKit
import WidgetKit

// 使用自定义Button样式以保持视觉一致性

struct ContentView: View {
    @State private var currentPage = 0
    
    // 车辆数据模型
    @State private var carModel: SharedCarModel?
    @State private var isLoading = false
    
    // 第三页详细信息的状态变量
    @State private var currentLocation = "获取位置中..."
    @State private var isHornPressed = false // 鸣笛按钮动画状态
    @State private var showLockConfirm = false // 车锁二次确认弹窗
    @State private var showACConfirm = false // 空调二次确认弹窗
    @State private var showWindowConfirm = false // 车窗二次确认弹窗
    @State private var showHornConfirm = false // 鸣笛二次确认弹窗
    
    // WatchConnectivity管理器
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    @State private var lastUpdateTime: Date?
    
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
                        .onTapGesture {
                            if currentPage == 0 {
                                print("[Watch Debug] 用户点击背景图片，开始刷新车辆数据")
                                // 防止重复点击
                                guard !isLoading else { return }
                                loadCarData()
                            }
                        }
                    
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
                
                // Loading 指示器
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea(.all)
                        
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("加载中...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all) // watchOS全屏设置
        .onAppear {
            loadCarData()
            requestAuthDataIfNeeded()
            
            // 监听数据更新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchCarDataDidUpdate"),
                object: nil,
                queue: .main
            ) { _ in
                print("[Watch Debug] 收到数据更新通知，重新加载数据")
                loadCarData()
            }
        }
        .onChange(of: watchConnectivityManager.lastUpdateTime) { _ in
            print("[Watch Debug] lastUpdateTime改变，重新加载数据")
            loadCarData()
        }
        .onOpenURL { url in
            handleURLScheme(url)
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
                            showLockConfirm = true
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
                        .alert("确认\(isCarLocked ? "解锁车辆" : "锁定车辆")？", isPresented: $showLockConfirm) {
                            Button("确认") {
                                let operation = isCarLocked ? 2 : 1 // 2=开锁, 1=关锁
                                
                                // 1. 乐观更新本地UI
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                    if var model = carModel {
                                        model.mainLockStatus = model.mainLockStatus == 0 ? 1 : 0
                                        carModel = model
                                        
                                        // 2. 保存到App Groups并刷新Widget
                                        saveCarModelToAppGroups(model)
                                    }
                                }
                                
                                // 3. 异步发送网络请求
                                if #available(watchOS 10.0, *) {
                                    Task {
                                        let intent = WatchLockControlIntent(operation: operation)
                                        try? await intent.perform()
                                    }
                                }
                            }
                            Button("取消", role: .cancel) { }
                        }
                        
                        Text(isCarLocked ? "已锁车" : "已解锁")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    // 空调开关
                    VStack(spacing: 8) {
                        Button(action: {
                            showACConfirm = true
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
                        .alert("确认\(isACOn ? "关闭空调" : "开启空调")？", isPresented: $showACConfirm) {
                            Button("确认") {
                                let operation = isACOn ? 1 : 2
                                let duringTime = 30
                                
                                // 1. 乐观更新本地UI
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                    if var model = carModel {
                                        // 空调状态：0=开启，1=关闭
                                        model.acStatus = model.acStatus == 0 ? 1 : 0
                                        carModel = model
                                        
                                        // 2. 保存到App Groups并刷新Widget
                                        saveCarModelToAppGroups(model)
                                    }
                                }
                                
                                // 3. 异步发送网络请求
                                if #available(watchOS 10.0, *) {
                                    Task {
                                        let intent = WatchACControlIntent(operation: operation, temperature: nil, duringTime: duringTime)
                                        try? await intent.perform()
                                    }
                                }
                            }
                            Button("取消", role: .cancel) {}
                        }
                        
                        Text(isACOn ? "空调开" : "空调关")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                // 第二行：车窗、鸣笛
                HStack(spacing: spacing) {
                    // 车窗开关
                    VStack(spacing: 8) {
                        Button(action: {
                            showWindowConfirm = true
                        }) {
                            Image(systemName: isWindowOpen ? "window.shade.open" : "window.shade.closed")
                                .font(.system(size: buttonSize * 0.5))
                                .foregroundColor(.white)
                                .offset(y: isWindowOpen ? 0 : 2)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(isWindowOpen ? Color.cyan.opacity(0.8) : Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .scaleEffect(isWindowOpen ? 1.0 : 0.95)
                        .buttonStyle(PlainButtonStyle())
                        .alert("确认\(isWindowOpen ? "关闭车窗" : "打开车窗")？", isPresented: $showWindowConfirm) {
                            Button("确认") {
                                let operation = isWindowOpen ? 1 : 2  // 2开启，1关闭
                                let openLevel = isWindowOpen ? 0 : 2  // 2完全打开，0关闭
                                
                                // 1. 乐观更新本地UI
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                                    if var model = carModel {
                                        // 更新所有车窗状态：0=关闭，100=完全打开
                                        let newWindowStatus = openLevel == 2 ? 100 : 0
                                        model.lfWindowOpen = newWindowStatus
                                        model.rfWindowOpen = newWindowStatus
                                        model.lrWindowOpen = newWindowStatus
                                        model.rrWindowOpen = newWindowStatus
                                        carModel = model
                                        
                                        // 2. 保存到App Groups并刷新Widget
                                        saveCarModelToAppGroups(model)
                                    }
                                }
                                
                                // 3. 异步发送网络请求
                                if #available(watchOS 10.0, *) {
                                    Task {
                                        let intent = WatchWindowControlIntent(operation: operation, openLevel: openLevel)
                                        try? await intent.perform()
                                    }
                                }
                            }
                            Button("取消", role: .cancel) {}
                        }
                        
                        Text(isWindowOpen ? "窗已开" : "窗已关")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    // 鸣笛按钮
                    VStack(spacing: 8) {
                        Button(action: {
                            showHornConfirm = true
                        }) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: buttonSize * 0.45))
                                .foregroundColor(.white)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isHornPressed ? 1.2 : 1.0) // 根据状态控制缩放
                        .alert("确认鸣笛？", isPresented: $showHornConfirm) {
                            Button("确认") {
                                isHornPressed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isHornPressed = false
                                }
                            }
                            Button("取消", role: .cancel) {}
                        }
                        
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
                            doorStatusItem("前左", isOpen: carModel?.doorStsFrontLeft != 0)
                            doorStatusItem("前右", isOpen: carModel?.doorStsFrontRight != 0)
                        }
                        HStack(spacing: 8) {
                            doorStatusItem("后左", isOpen: carModel?.doorStsRearLeft != 0)
                            doorStatusItem("后右", isOpen: carModel?.doorStsRearRight != 0)
                        }
                        HStack {
                            trunkStatusItem("后尾箱", isOpen: carModel?.trunkLockStatus != 0)
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
                        Text(vinCode)
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
        .frame(maxWidth: .infinity, alignment: .center)
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
        .frame(maxWidth: .infinity, alignment: .center)
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
        .frame(maxWidth: .infinity, alignment: .center)
        
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
    
    // MARK: - URL Scheme 处理
    
    /// 处理从 Widget 点击过来的 URL
    private func handleURLScheme(_ url: URL) {
        print("[Watch Debug] 收到URL: \(url)")
        
        guard url.scheme == "pan3watch" else {
            print("[Watch Debug] URL scheme 不匹配")
            return
        }
        
        // 导航到控制页面
        if url.host == "control" {
            currentPage = 1  // 切换到第二页（控制面板）
            print("[Watch Debug] 已切换到控制页面")
            
            // 解析 action 参数，自动弹出对应的确认对话框
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let actionItem = queryItems.first(where: { $0.name == "action" }),
               let action = actionItem.value {
                
                print("[Watch Debug] 解析到 action: \(action)")
                
                // 延迟弹出对话框，确保页面切换动画完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    switch action {
                    case "lock":
                        print("[Watch Debug] 弹出车锁确认对话框")
                        showLockConfirm = true
                    case "ac":
                        print("[Watch Debug] 弹出空调确认对话框")
                        showACConfirm = true
                    case "window":
                        print("[Watch Debug] 弹出车窗确认对话框")
                        showWindowConfirm = true
                    default:
                        print("[Watch Debug] 未知的 action: \(action)")
                    }
                }
            }
        }
    }
    
    // MARK: - 数据获取方法
    
    /// 保存更新后的车辆数据到App Groups
    private func saveCarModelToAppGroups(_ model: SharedCarModel) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
            print("[Watch] 无法访问App Groups")
            return
        }
        
        let carModelDict = model.toDictionary()
        userDefaults.set(carModelDict, forKey: "SharedCarModelData")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "SharedCarModelLastUpdate")
        userDefaults.synchronize()
        
        print("[Watch] 已保存更新后的车辆数据到App Groups")
        
        // 刷新 Watch Widget
        WidgetCenter.shared.reloadAllTimelines()
        print("[Watch] 已刷新Watch Widget")
    }
    
    /// 请求iOS端发送认证数据（如果本地没有）
    private func requestAuthDataIfNeeded() {
        // 检查是否已有认证数据
        let hasToken = watchConnectivityManager.getCurrentToken() != nil
        let hasVin = watchConnectivityManager.getCurrentVin() != nil
        
        if !hasToken || !hasVin {
            print("[Watch Debug] 本地缺少认证数据，向iOS请求同步")
            watchConnectivityManager.requestAuthDataFromiOS()
        } else {
            print("[Watch Debug] 本地已有认证数据，Token: \(hasToken), VIN: \(hasVin)")
        }
    }
    
    /// 加载车辆数据
    private func loadCarData() {
        carModel = watchConnectivityManager.loadSharedCarModelFromAppGroups()
        lastUpdateTime = watchConnectivityManager.getLastUpdateTime()
        print("[Watch Debug] 从App Groups加载车辆数据: \(carModel != nil ? "成功" : "失败")")
        
        // 加载数据后更新UI（包括地址解析）
        if let model = carModel {
            updateUIFromCarModel(model)
        }
    }
    
    /// 刷新车辆数据（异步版本）
    private func refreshCarData() async {
        // 网络相关代码已删除
        // 使用默认数据或占位数据
//        carModel = SharedCarModel()
//        updateUIFromCarModel(carModel)
    }
    
    /// 从车辆模型更新UI状态
    private func updateUIFromCarModel(_ model: SharedCarModel) {
        // 获取位置信息
        let coordinate = model.coordinate
        print("[Watch Debug] GPS坐标: 纬度=\(coordinate.latitude), 经度=\(coordinate.longitude)")
        
        if coordinate.latitude != 0 && coordinate.longitude != 0 {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let geocoder = CLGeocoder()
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("[Watch Debug] 逆地理编码失败: \(error.localizedDescription)")
                        self.currentLocation = "位置获取失败"
                        return
                    }
                    
                    if let placemark = placemarks?.first {
                        var addressComponents: [String] = []
                        
                        if let subLocality = placemark.subLocality {
                            addressComponents.append(subLocality)
                        }
                        if let name = placemark.name {
                            addressComponents.append(name)
                        }
                        
                        if addressComponents.isEmpty {
                            self.currentLocation = "位置解析失败"
                        } else {
                            self.currentLocation = addressComponents.joined(separator: " ")
                        }
                        print("[Watch Debug] 地址解析成功: \(self.currentLocation)")
                    } else {
                        self.currentLocation = "位置解析失败"
                    }
                }
            }
        } else {
            print("[Watch Debug] GPS坐标无效，跳过地址解析")
            self.currentLocation = "GPS数据无效"
        }
    }
    
    // MARK: - 计算属性
    
    /// 剩余里程
    private var remainingMileage: Int {
        return carModel?.acOnMile ?? 0
    }
    
    /// SOC百分比
    private var socPercentage: Int {
        return carModel?.soc ?? 0
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
    
    /// VIN码 - 从App Groups获取
    private var vinCode: String {
        return watchConnectivityManager.getCurrentVin() ?? "未获取"
    }
    
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
}
