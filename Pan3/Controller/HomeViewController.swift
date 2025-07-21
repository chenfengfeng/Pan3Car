//
//  HomeViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import MapKit
import QMUIKit
import MJRefresh
import CoreImage
import WidgetKit
import CoreLocation
import SwifterSwift

class HomeViewController: UIViewController, MKMapViewDelegate, UIScrollViewDelegate, CarDataRefreshable {
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    @IBOutlet weak var mile: UILabel!
    @IBOutlet weak var unit: UILabel!
    @IBOutlet weak var soc: UIProgressView!
    @IBOutlet weak var totalMileage: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var chargeView: UIStackView!
    @IBOutlet weak var leftChargeTime: UILabel!
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var lockBtn: QMUIButton!
    @IBOutlet weak var lockLabel: UILabel!// 开锁/关锁
    @IBOutlet weak var acBtn: QMUIButton!
    @IBOutlet weak var acLabel: UILabel!// 开空调/关空调
    @IBOutlet weak var windowBtn: QMUIButton!
    @IBOutlet weak var windowLabel: UILabel!// 开窗/关窗
    @IBOutlet weak var callBtn: QMUIButton!
    @IBOutlet weak var callLabel: UILabel!// 寻车
    
    // 门锁状态
    @IBOutlet weak var leftTopDoorStatus: UILabel!//示例：左前门：关闭
    @IBOutlet weak var rightTopDoorStatus: UILabel!//示例：右前门：关闭
    @IBOutlet weak var leftBottomDoorStatus: UILabel!//示例：左后门：关闭
    @IBOutlet weak var rightBottomDoorStatus: UILabel!//示例：右后门：关闭
    @IBOutlet weak var tailDoorStatus: UILabel!//后尾箱
    
    // 车窗状态
    @IBOutlet weak var leftTopWindowStatus: UILabel!//示例：左前窗：关闭
    @IBOutlet weak var rightTopWindowStatus: UILabel!//示例：右前窗：关闭
    @IBOutlet weak var leftBottomWindowStatus: UILabel!//示例：左后窗：关闭
    @IBOutlet weak var rightBottomWindowStatus: UILabel!//示例：右后窗：关闭
    
    // 胎压数值
    @IBOutlet weak var leftTopTPStatus: UILabel!//示例：左前胎压：240
    @IBOutlet weak var rightTopTPStatus: UILabel!//示例：右前胎压：240
    @IBOutlet weak var leftBottomTPStatus: UILabel!//示例：左后胎压：240
    @IBOutlet weak var rightBottomTPStatus: UILabel!//示例：右后胎压：240
    
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var carAddress: UILabel!//车地址，格式：地区+具体地址
    @IBOutlet weak var mapBottomView: UIView!
    
    @IBOutlet weak var carTemperature: UILabel!//车内温度，格式：24˚
    @IBOutlet weak var presetTemperature: UILabel!// 预设温度
    @IBOutlet weak var acStatus: UILabel!//空调状态
    
    
    // 标记是否是首次加载数据
    var isFirstDataLoad = true
    
    // 缓存原始背景图像
    private var originalBackgroundImage: UIImage?
    private var lastBlurRadius: CGFloat = -1
    
    // 小组件刷新频率控制
    private var lastWidgetRefreshTime: Date = Date(timeIntervalSince1970: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 设置导航栏
        setupNavigationBar()
        
        // 设置UI
        setupUI()
        
        // 获取车辆信息
        fetchCarInfoAndValidateLogin()
        
        // 进入页面的时候通知
        registerAppDidBecomeActiveNotification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !isFirstDataLoad {
            fetchCarInfo()
        }
        let shouldEnableExperimental = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        topView.isHidden = !shouldEnableExperimental
    }

    
    // MARK: - 设置导航栏
    func setupNavigationBar() {
        updateNavigationTitle()
        
        // 监听欢迎词更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNavigationTitle),
            name: NSNotification.Name("UpdateGreeting"),
            object: nil
        )
    }
    
    @objc func updateNavigationTitle() {
        let greetingType = UserDefaults.standard.string(forKey: "GreetingType") ?? "nickname"
        
        switch greetingType {
        case "nickname":
            let name = UserManager.shared.userInfo?.userName ?? ""
            navigationItem.title = "尊贵的\(name)车主"
        case "carNumber":
            let carNumber = UserManager.shared.userInfo?.plateLicenseNo ?? ""
            navigationItem.title = "尊贵的\(carNumber)车主"
        case "custom":
            let customGreeting = UserDefaults.standard.string(forKey: "CustomGreeting") ?? ""
            navigationItem.title = "尊贵的\(customGreeting)车主"
        case "none":
            navigationItem.title = "胖3汽车"
        default:
            let name = UserManager.shared.userInfo?.userName ?? ""
            navigationItem.title = "尊贵的\(name)车主"
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - CarDataRefreshable Protocol Implementation
    func refreshCarData() {
        fetchCarInfo()
    }
    
    @objc func handleAppDidBecomeActive() {
        print("APP重新进入前台了 - HomeViewController")
        if !isFirstDataLoad {
            refreshCarData()
        }
    }
    
    // MARK: - 设置UI
    func setupUI() {
        // scrollview 偏移
        scrollView.contentInset = UIEdgeInsets(top: 160, left: 0, bottom: 0, right: 0)
        
        // 设置scrollView代理
        scrollView.delegate = self
        
        // 缓存原始背景图像
        originalBackgroundImage = backgroundImageView.image
        
        // 设置地图代理
        mapView.delegate = self
        
        // 设置里程点击
        mile.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changeMile)))
        
        // 设置风扇按钮图标
        let config = UIImage.SymbolConfiguration(scale: .large)
        if #available(iOS 17.0, *) {
            let fanImage = UIImage(systemName: "fan.fill", withConfiguration: config)
            acBtn.setImage(fanImage, for: .normal)
            
            let winImage = UIImage(systemName: "arrowtriangle.up.arrowtriangle.down.window.right", withConfiguration: config)
            windowBtn.setImage(winImage, for: .normal)
            
            let callImage = UIImage(systemName: "car.front.waves.up", withConfiguration: config)
            callBtn.setImage(callImage, for: .normal)
            mapView.showsUserTrackingButton = false
        }
        
        let mj_header = MJRefreshNormalHeader(refreshingBlock: {
            self.fetchCarInfo()
        })
        mj_header.ignoredScrollViewContentInsetTop = 170
        mj_header.lastUpdatedTimeLabel?.isHidden = true
        scrollView.mj_header = mj_header
        
        mapView.showsScale = false
        mapView.showsCompass = false
        mapView.showsUserLocation = false
        
        mapBottomView.az_setGradientBackground(with: [.clear, .black], start: CGPoint.zero, end: CGPoint(x: 0, y: 0.5))
    }
    
    // MARK: - 按键事件
    @objc func changeMile() {
        guard let model = UserManager.shared.carModel else { return }
        
        if unit.text == "km" {
            mile.text = model.soc
            unit.text = "%"
        }else{
            mile.text = model.acOnMile.string
            unit.text = "km"
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func actionLock(_ sender: QMUIButton) {
        guard let model = UserManager.shared.carModel else { return }
        
        let isLocked = model.mainLockStatus == 0
        let operation = isLocked ? 2 : 1  // 2=开锁, 1=关锁
        let actionText = isLocked ? "开锁" : "关锁"
        
        executeCarControl(
            loadingText: "\(actionText)中...",
            successText: "\(actionText)指令发送成功",
            failureText: "\(actionText)失败",
            expectedStatusChange: { oldModel, newModel in
                return oldModel.mainLockStatus != newModel.mainLockStatus
            },
            controlAction: { completion in
                NetworkManager.shared.energyLock(operation: operation, completion: completion)
            }
        )
    }
    
    @IBAction func actionAC(_ sender: QMUIButton) {
        guard let model = UserManager.shared.carModel else { return }
        
        let isOff = model.acStatus == 2
        
        if isOff {
            // 空调关闭时，弹出选择界面
            ACSelectView.show(from: self) { [weak self] temperature, time in
                self?.startAirConditioner(temperature: temperature, time: time)
            }
        } else {
            // 空调开启时，直接关闭
            closeAirConditioner()
        }
    }
    
    // MARK: - 开启空调
    private func startAirConditioner(temperature: Int, time: Int) {
        // 保存用户选择的温度到UserDefaults
        UserDefaults.standard.set(temperature, forKey: "PresetTemperature")
        
        // 立即更新预设温度显示
        presetTemperature.text = "预设温度 \(temperature)˚"
        
        executeCarControl(
            loadingText: "打开空调中...",
            successText: "打开空调指令发送成功",
            failureText: "打开空调失败",
            expectedStatusChange: { oldModel, newModel in
                return oldModel.acStatus != newModel.acStatus
            },
            controlAction: { completion in
                NetworkManager.shared.energyAirConditioner(operation: 2, temperature: temperature, duringTime: time, completion: completion)
            }
        )
    }
    
    // MARK: - 关闭空调
    private func closeAirConditioner() {
        executeCarControl(
            loadingText: "关闭空调中...",
            successText: "关闭空调指令发送成功",
            failureText: "关闭空调失败",
            expectedStatusChange: { oldModel, newModel in
                return oldModel.acStatus != newModel.acStatus
            },
            controlAction: { completion in
                NetworkManager.shared.energyAirConditioner(operation: 1, temperature: 26, duringTime: 30, completion: completion)
            }
        )
    }
    
    @IBAction func actionWindow(_ sender: QMUIButton) {
        guard let model = UserManager.shared.carModel else {
            QMUITips.show(withText: "车辆信息不可用", in: view, hideAfterDelay: 2.0)
            return
        }
        
        // 判断当前车窗状态
        let allWindowsClosed = model.lfWindowOpen == 0 && model.rfWindowOpen == 0 &&
                               model.lrWindowOpen == 0 && model.rrWindowOpen == 0
        
        let operation = allWindowsClosed ? 2 : 1  // 2开启，1关闭
        let openLevel = allWindowsClosed ? 2 : 0  // 2完全打开，0关闭
        let actionText = allWindowsClosed ? "开窗" : "关窗"
        
        executeCarControl(
            loadingText: "\(actionText)中...",
            successText: "\(actionText)指令发送成功",
            failureText: "\(actionText)失败",
            expectedStatusChange: { oldModel, newModel in
                return oldModel.lfWindowOpen != newModel.lfWindowOpen &&
                       oldModel.rfWindowOpen != newModel.rfWindowOpen &&
                       oldModel.lrWindowOpen != newModel.lrWindowOpen &&
                       oldModel.rrWindowOpen != newModel.rrWindowOpen
            },
            controlAction: { completion in
                NetworkManager.shared.energyWindow(operation: operation, openLevel: openLevel, completion: completion)
            }
        )
    }
    
    @IBAction func actionCall(_ sender: QMUIButton) {
        QMUITips.showLoading("鸣笛寻车指令发送中...", in: view)
        NetworkManager.shared.energyFind { result in
            QMUITips.hideAllTips()
            switch result {
            case .success(_):
                QMUITips.show(withText: "鸣笛指令发送成功")
            default:
                break
            }
        }
    }
    
    @IBAction func actionMap(_ sender: QMUIButton) {
        guard let model = UserManager.shared.carModel else { return }
        
        let alertController = UIAlertController(title: "导航到我的车", message: "请选择要使用的地图应用", preferredStyle: .actionSheet)
        
        // 检查是否安装了高德地图
        if let amapURL = URL(string: "iosamap://"), UIApplication.shared.canOpenURL(amapURL) {
            let amapAction = UIAlertAction(title: "高德地图", style: .default) { _ in
                self.openAmapNavigation(model: model)
            }
            alertController.addAction(amapAction)
        }
        
        // 苹果地图选项
        let appleMapAction = UIAlertAction(title: "苹果地图", style: .default) { _ in
            self.openAppleMapNavigation(model: model)
        }
        alertController.addAction(appleMapAction)
        
        // 取消选项
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        // 为iPad设置popover
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - 打开高德地图查看位置
    private func openAmapNavigation(model: CarModel) {
        let amapURLString = "iosamap://viewMap?sourceApplication=胖3汽车&backScheme=pan3&lat=\(model.latitude)&lon=\(model.longitude)&poiname=我的车&dev=0"
        if let amapURL = URL(string: amapURLString) {
            UIApplication.shared.open(amapURL, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: - 打开苹果地图导航
    private func openAppleMapNavigation(model: CarModel) {
        let coordinate = CLLocationCoordinate2D(latitude: model.latitude.nsString.doubleValue, longitude: model.longitude.nsString.doubleValue)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "我的车"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // MARK: - 获取车辆信息并验证登录状态
    func fetchCarInfoAndValidateLogin() {
        let userManager = UserManager.shared
        guard let _ = userManager.timaToken else {
            // 没有token，跳转到登录页面
            navigateToLogin()
            return
        }
        
        // 获取车辆信息
        fetchCarInfo(showSuccessMessage: false)
    }
    
    // MARK: - 尝试自动重新登录
    func attemptAutoRelogin() {
        guard let credentials = UserManager.shared.savedCredentials else {
            // 没有保存的账户密码，跳转到登录页面
            QMUITips.show(withText: "登录已过期，请重新登录", in: view, hideAfterDelay: 2.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.navigateToLogin()
            }
            return
        }
        
        QMUITips.showLoading(in: self.view)
        QMUITips.show(withText: "正在自动重新登录...", in: view, hideAfterDelay: 1.0)
        
        // 使用保存的账户密码自动登录
        let encryptedPassword = credentials.password.qmui_md5
        NetworkManager.shared.login(userCode: credentials.phone, password: encryptedPassword) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                switch result {
                case .success(let authResponse):
                    // 登录成功，更新认证响应信息
                    UserManager.shared.authResponse = authResponse
                    
                    // 登录成功，直接设置车辆数据（新接口已包含所有信息）
                    self.fetchCarInfo(showSuccessMessage: false)
                    QMUITips.show(withText: "自动登录成功", in: self.view, hideAfterDelay: 1.0)
                    
                case .failure(let error):
                    QMUITips.show(withText: "自动登录失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.navigateToLogin()
                    }
                }
            }
        }
    }
    
    // MARK: - 获取车辆信息
    func fetchCarInfo(showSuccessMessage: Bool = false) {
        NetworkManager.shared.getInfo { [weak self] result in
            guard let self else {return}
            self.scrollView.mj_header?.endRefreshing()
            if showSuccessMessage {
                QMUITips.hideAllTips()
            }
            switch result {
            case .success(let json):
                // 保存车辆信息
                let model = CarModel(json: json)
                UserManager.shared.updateCarInfo(with: model)
                self.setupCarData()
                
                // 刷新小组件
                self.refreshWidget()
            case .failure(let error):
                if showSuccessMessage {
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                } else {
                    print("车辆信息获取失败: \(error.localizedDescription)")
                    // 获取失败，可能是登录过期，尝试自动重新登录
                    self.attemptAutoRelogin()
                }
            }
        }
    }
    
    // MARK: - 跳转到登录页面
    func navigateToLogin() {
        QMUITips.show(withText: "发生了奇怪的错误")
    }
    
    // MARK: - 配置信息
    func setupCarData() {
        guard let model = UserManager.shared.carModel else { return }
        
        let targetMileValue = model.acOnMile
        let targetSocValue = model.soc.nsString.floatValue / 100
        
        if isFirstDataLoad {
            // 首次加载 - 激活实时活动
            getTaskStatus()
            // 首次加载 - 执行动画
            animateMileage(to: targetMileValue)
            animateSOC(to: targetSocValue)
            // 首次加载时设置默认显示为里程
            unit.text = "km"
            isFirstDataLoad = false
        } else {
            // 后续更新 - 根据当前显示状态设置对应数值
            if unit.text == "km" {
                // 当前显示里程，更新为最新里程数据
                mile.text = "\(targetMileValue)"
            } else {
                // 当前显示电量，更新为最新电量数据
                mile.text = model.soc
            }
            soc.progress = targetSocValue
            
            // 根据SOC值设置进度条颜色
            let percentage = targetSocValue * 100
            if percentage < 10 {
                soc.progressTintColor = .systemRed
            } else if percentage < 20 {
                soc.progressTintColor = .systemOrange
            } else {
                soc.progressTintColor = .systemGreen
            }
        }
        
        // 总里程直接设置
        totalMileage.text = "总里程：\(model.totalMileage)km"
        
        // 充电状态
        if model.chgStatus == 2 {
            chargeView.isHidden = true
        }else{
            chargeView.isHidden = false
            leftChargeTime.text = "预计充满："+formatTime(minutes: model.quickChgLeftTime.float)
        }
        
        // 设置风扇按钮图标和文字
        let config = UIImage.SymbolConfiguration(scale: .large)
        if #available(iOS 17.0, *) {
            let fanImage = UIImage(systemName: "fan.fill", withConfiguration: config)
            acBtn.setImage(fanImage, for: .normal)
            
            if model.acStatus == 1 {
                // 开启空调 - 添加360度旋转动画
                startFanRotationAnimation()
                acLabel.text = "关空调"
                acStatus.text = "空调已开启"
            }else{
                // 关闭空调 - 停止旋转动画
                stopFanRotationAnimation()
                acLabel.text = "开空调"
                acStatus.text = "空调已关闭"
            }
        }
        
        // 判断是否在充电
        if model.chgStatus == 2 {
            backgroundImageView.image = UIImage(named: "my_car")
        }else{
            backgroundImageView.image = UIImage(named: "my_car_charge")
        }
        originalBackgroundImage = backgroundImageView.image
        
        // 设置车锁按钮图标和文字
        let imageName = model.mainLockStatus == 0 ? "lock.fill" : "lock.open.fill"
        let image = UIImage(systemName: imageName, withConfiguration: config)
        lockBtn.setImage(image, for: .normal)
        lockLabel.text = model.mainLockStatus == 0 ? "开锁" : "关锁"
        
        // 设置车窗按钮文字（根据所有车窗状态判断）
        let allWindowsClosed = model.lfWindowOpen == 0 && model.rfWindowOpen == 0 &&
        model.lrWindowOpen == 0 && model.rrWindowOpen == 0
        windowLabel.text = allWindowsClosed ? "开窗" : "关窗"
        
        // 寻车按钮文字（固定）
        callLabel.text = "寻车"
        
        // 更新车辆状态信息
        updateCarStatusInfo(with: model)
        
        // 更新地图位置
        updateMapLocation(with: model)
    }
    
    // MARK: - 更新车辆状态信息
    private func updateCarStatusInfo(with model: CarModel) {
        // 车门状态
        leftTopDoorStatus.text = "左前门：\(model.doorStsFrontLeft == 0 ? "关闭" : "开启")"
        rightTopDoorStatus.text = "右前门：\(model.doorStsFrontRight == 0 ? "关闭" : "开启")"
        leftBottomDoorStatus.text = "左后门：\(model.doorStsRearLeft == 0 ? "关闭" : "开启")"
        rightBottomDoorStatus.text = "右后门：\(model.doorStsRearRight == 0 ? "关闭" : "开启")"
        
        // 车窗状态
        leftTopWindowStatus.text = "左前窗：\(model.lfWindowOpen == 0 ? "关闭" : "开启")"
        rightTopWindowStatus.text = "右前窗：\(model.rfWindowOpen == 0 ? "关闭" : "开启")"
        leftBottomWindowStatus.text = "左后窗：\(model.lrWindowOpen == 0 ? "关闭" : "开启")"
        rightBottomWindowStatus.text = "右后窗：\(model.rrWindowOpen == 0 ? "关闭" : "开启")"
        
        // 后备箱状态
        tailDoorStatus.text = "后尾箱：\(model.trunkLockStatus == 0 ? "关闭" : "开启")"
        
        // 胎压状态（数据为0时显示--）
        leftTopTPStatus.text = "左前胎压：\(model.lfTirePresure == 0 ? "--" : "\(model.lfTirePresure)")"
        rightTopTPStatus.text = "右前胎压：\(model.rfTirePresure == 0 ? "--" : "\(model.rfTirePresure)")"
        leftBottomTPStatus.text = "左后胎压：\(model.lrTirePresure == 0 ? "--" : "\(model.lrTirePresure)")"
        rightBottomTPStatus.text = "右后胎压：\(model.rrTirePresure == 0 ? "--" : "\(model.rrTirePresure)")"
        
        // 车内温度（数据为0或大于100度时显示--）
        if model.temperatureInCar == 0 || model.temperatureInCar > 100 {
            carTemperature.text = "--˚"
        } else {
            carTemperature.text = "\(model.temperatureInCar)˚"
        }
        
        // 预设温度（从UserDefaults获取，默认26度）
        let savedTemperature = UserDefaults.standard.integer(forKey: "PresetTemperature")
        let displayTemperature = savedTemperature == 0 ? 26 : savedTemperature
        presetTemperature.text = "预设温度\(displayTemperature)˚"
    }
    
    // MARK: - 更新地图位置
    private func updateMapLocation(with model: CarModel) {
        // 检查经纬度是否有效
        guard let lat = Double(model.latitude), let lng = Double(model.longitude),
              lat != 0, lng != 0 else {
            carAddress.text = "位置信息不可用"
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        // 设置地图区域（最大缩放等级）
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 100, longitudinalMeters: 100)
        mapView.setRegion(region, animated: true)
        
        // 移除之前的标注
        mapView.removeAnnotations(mapView.annotations)
        
        // 添加车辆位置标注
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "车辆位置"
        mapView.addAnnotation(annotation)
        
        // 反向地理编码获取地址
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lng)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let address = [placemark.subLocality, placemark.name]
                        .compactMap { $0 }
                        .joined(separator: "")
                    self?.carAddress.text = address.isEmpty ? "位置解析中..." : address
                } else {
                    self?.carAddress.text = "位置解析失败"
                }
            }
        }
    }
    
    // MARK: - 配置信息
    func formatTime(minutes: Float) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return "\(hours)小时\(mins)分钟\(secs)秒"
    }
    
    // MARK: - 里程动画
    private func animateMileage(to targetValue: Int) {
        let duration: TimeInterval = 1.5
        let startTime = CACurrentMediaTime()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(updateMileageAnimation))
        displayLink.add(to: .main, forMode: .common)
        
        // 存储动画参数
        objc_setAssociatedObject(self, &AssociatedKeys.mileageStartTime, startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageDuration, duration, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageTargetValue, targetValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageDisplayLink, displayLink, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc private func updateMileageAnimation() {
        guard let startTime = objc_getAssociatedObject(self, &AssociatedKeys.mileageStartTime) as? TimeInterval,
              let duration = objc_getAssociatedObject(self, &AssociatedKeys.mileageDuration) as? TimeInterval,
              let targetValue = objc_getAssociatedObject(self, &AssociatedKeys.mileageTargetValue) as? Int,
              let displayLink = objc_getAssociatedObject(self, &AssociatedKeys.mileageDisplayLink) as? CADisplayLink else {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - startTime
        let progress = min(elapsed / duration, 1.0)
        
        // 使用缓动函数
        let easedProgress = easeOutQuart(progress)
        let currentValue = Int(Double(targetValue) * easedProgress)
        
        mile.text = "\(currentValue)"
        
        if progress >= 1.0 {
            displayLink.invalidate()
            objc_setAssociatedObject(self, &AssociatedKeys.mileageDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: - SOC动画
    private func animateSOC(to targetValue: Float) {
        // 重置进度条
        soc.progress = 0.0
        soc.progressTintColor = .systemRed // 初始颜色为红色
        
        let duration: TimeInterval = 1.5
        let startTime = CACurrentMediaTime()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(updateSOCAnimation))
        displayLink.add(to: .main, forMode: .common)
        
        // 存储动画参数
        objc_setAssociatedObject(self, &AssociatedKeys.socStartTime, startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socDuration, duration, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socTargetValue, targetValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socDisplayLink, displayLink, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc private func updateSOCAnimation() {
        guard let startTime = objc_getAssociatedObject(self, &AssociatedKeys.socStartTime) as? TimeInterval,
              let duration = objc_getAssociatedObject(self, &AssociatedKeys.socDuration) as? TimeInterval,
              let targetValue = objc_getAssociatedObject(self, &AssociatedKeys.socTargetValue) as? Float,
              let displayLink = objc_getAssociatedObject(self, &AssociatedKeys.socDisplayLink) as? CADisplayLink else {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - startTime
        let progress = min(elapsed / duration, 1.0)
        
        // 使用缓动函数
        let easedProgress = easeOutQuart(progress)
        let currentValue = targetValue * Float(easedProgress)
        let currentPercentage = currentValue * 100
        
        // 更新进度条值
        soc.progress = currentValue
        
        // 根据当前进度动态设置颜色
        if currentPercentage < 10 {
            soc.progressTintColor = .systemRed
        } else if currentPercentage < 20 {
            soc.progressTintColor = .systemOrange
        } else {
            soc.progressTintColor = .systemGreen
        }
        
        if progress >= 1.0 {
            displayLink.invalidate()
            objc_setAssociatedObject(self, &AssociatedKeys.socDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: - 缓动函数
    private func easeOutQuart(_ t: Double) -> Double {
        return 1 - pow(1 - t, 4)
    }
    
    // MARK: - 风扇旋转动画
    private func startFanRotationAnimation() {
        // 停止之前的动画
        stopFanRotationAnimation()
        
        // 创建360度旋转动画
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2 // 360度
        rotationAnimation.duration = 1.0 // 1秒完成一次旋转
        rotationAnimation.repeatCount = Float.infinity // 无限循环
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .linear) // 线性动画
        
        // 添加动画到风扇按钮的图层
        acBtn.layer.add(rotationAnimation, forKey: "fanRotation")
    }
    
    private func stopFanRotationAnimation() {
        // 移除旋转动画
        acBtn.layer.removeAnimation(forKey: "fanRotation")
    }
    
    // MARK: - 通用车辆控制方法
    private func executeCarControl(
        loadingText: String,
        successText: String,
        failureText: String,
        expectedStatusChange: @escaping (CarModel, CarModel) -> Bool,
        controlAction: @escaping (@escaping (Result<Bool, Error>) -> Void) -> Void
    ) {
        guard let originalModel = UserManager.shared.carModel else { return }
        
        QMUITips.showLoading(loadingText, in: view)
        
        controlAction { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                
                switch result {
                case .success(_):
                    QMUITips.show(withText: successText)
                    // 开始轮询状态变化
                    self.startPollingForStatusChange(
                        originalModel: originalModel,
                        expectedChange: expectedStatusChange
                    )
                    // 刷新小组件
                    self.refreshWidget()
                    
                case .failure(let error):
                    QMUITips.show(withText: "\(failureText): \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                }
            }
        }
    }
    
    // MARK: - 轮询状态变化
    private func startPollingForStatusChange(
        originalModel: CarModel,
        expectedChange: @escaping (CarModel, CarModel) -> Bool
    ) {
        var pollCount = 0
        let maxPollCount = 10 // 最多轮询10次
        
        func pollStatus() {
            pollCount += 1
            
            fetchCarInfo(showSuccessMessage: false)
            
            // 延迟检查状态变化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let newModel = UserManager.shared.carModel else {
                    if pollCount < maxPollCount {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            pollStatus()
                        }
                    }
                    return
                }
                
                // 检查状态是否发生了预期的变化
                if expectedChange(originalModel, newModel) {
                    // 状态已变化，停止轮询
                    print("状态变化检测到，停止轮询")
                    return
                }
                
                // 如果还没有达到最大轮询次数，继续轮询
                if pollCount < maxPollCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        pollStatus()
                    }
                } else {
                    print("轮询超时，停止轮询")
                }
            }
        }
        
        // 开始第一次轮询
        pollStatus()
    }
    
    // MARK: - 刷新小组件
    private func refreshWidget() {
        // 检查刷新频率限制（30秒最小间隔）
        let now = Date()
        let minimumInterval: TimeInterval = 30
        
        if now.timeIntervalSince(lastWidgetRefreshTime) < minimumInterval {
            print("小组件刷新频率限制，跳过本次刷新")
            return
        }
        
        // 更新最后刷新时间
        lastWidgetRefreshTime = now
        
        // 刷新所有小组件
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 获取最新充电任务激活实时活动
    private func getTaskStatus() {
        NetworkManager.shared.getChargeStatus { result in
            switch result {
            case .success(let response):
                if response.hasRunningTask {
                    // 当前有正在充电的任务
                    if let task = response.task {
                        LiveActivityManager.shared.startChargeActivity(with: task)
                    }
                }
            default:
                break
            }
        }
    }
}

// MARK: - MKMapViewDelegate
extension HomeViewController {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        let identifier = "CarLocationAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        // 设置自定义图标
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light)
        let image = UIImage(systemName: "location.fill", withConfiguration: config)
        annotationView?.image = image?.qmui_image(withTintColor: .systemBlue)
        
        return annotationView
    }
}

// MARK: - UIScrollViewDelegate
extension HomeViewController {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 获取滚动偏移量
        let offsetY = scrollView.contentOffset.y + scrollView.contentInset.top
        
        // 只在向上滚动时应用模糊效果
        if offsetY > 0 {
            // 计算模糊程度，最大模糊半径为20
            let maxBlurRadius: CGFloat = 20.0
            let maxScrollDistance: CGFloat = 200.0 // 滚动200点达到最大模糊
            
            let blurRadius = min(maxBlurRadius, (offsetY / maxScrollDistance) * maxBlurRadius)
            
            // 应用模糊效果
            applyBlurEffect(radius: blurRadius)
        } else {
            // 向下滚动或在顶部时，移除模糊效果
            removeBlurEffect()
        }
    }
    
    private func applyBlurEffect(radius: CGFloat) {
        // 避免重复计算相同的模糊半径
        if abs(radius - lastBlurRadius) < 0.5 {
            return
        }
        lastBlurRadius = radius
        
        guard let originalImage = originalBackgroundImage else { return }
        
        // 如果模糊半径为0，直接设置原图
        if radius <= 0 {
            backgroundImageView.image = originalImage
            return
        }
        
        // 在后台队列处理图像模糊
        DispatchQueue.global(qos: .userInteractive).async {
            // 创建Core Image上下文
            let context = CIContext(options: [.useSoftwareRenderer: false])
            
            // 将UIImage转换为CIImage
            guard let ciImage = CIImage(image: originalImage) else { return }
            
            // 创建高斯模糊滤镜
            guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
            blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
            blurFilter.setValue(radius, forKey: kCIInputRadiusKey)
            
            // 获取模糊后的图像
            guard let outputImage = blurFilter.outputImage else { return }
            
            // 裁剪图像以匹配原始尺寸
            let croppedImage = outputImage.cropped(to: ciImage.extent)
            
            // 将CIImage转换回UIImage
            guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else { return }
            let blurredImage = UIImage(cgImage: cgImage)
            
            // 在主线程更新UI
            DispatchQueue.main.async {
                self.backgroundImageView.image = blurredImage
            }
        }
    }
    
    private func removeBlurEffect() {
        lastBlurRadius = -1
        // 恢复原始图像
        if let originalImage = originalBackgroundImage {
            backgroundImageView.image = originalImage
        }
    }
}

// MARK: - Associated Keys for Animation
private struct AssociatedKeys {
    static var mileageStartTime: UInt8 = 0
    static var mileageDuration: UInt8 = 0
    static var mileageTargetValue: UInt8 = 0
    static var mileageDisplayLink: UInt8 = 0
    static var socStartTime: UInt8 = 0
    static var socDuration: UInt8 = 0
    static var socTargetValue: UInt8 = 0
    static var socDisplayLink: UInt8 = 0
}
