//
//  HomeViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import MapKit
import SnapKit
import MJRefresh
import WidgetKit
import CoreLocation
import SwifterSwift

class HomeViewController: UIViewController, CarDataRefreshable {
    // 背景图片
    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "my_car")
        return imageView
    }()
    private lazy var backgroundBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView()
        return view
    }()
    
    // 顶部里程数据容器视图
    private lazy var mileageHeaderView: MileageView = {
        let view = MileageView()
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 200, left: 0, bottom: 0, right: 0)
        return scrollView
    }()
    
    // 主StackView - scrollView的唯一子视图
    private lazy var mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 20
        stackView.axis = .vertical
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 16, right: 20)
        return stackView
    }()
    
    private lazy var chargeTimeTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.text = "⚡️正在充电"
        return label
    }()
    
    private lazy var leftChargeTime: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .right
        label.textColor = .white
        return label
    }()
    
    // 控制按钮StackView
    private lazy var controlButtonsStackView: ControllButtonView = {
        let stackView = ControllButtonView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.layer.cornerRadius = 12
        stackView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return stackView
    }()
    
    // 地图和温度信息的水平容器StackView
    private lazy var mapTemperatureHorizontalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 20
        return stackView
    }()
    
    // 地图信息卡片mapInfoView
    private lazy var mapInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        let mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped))
        view.addGestureRecognizer(mapTapGesture)
        return view
    }()
    
    private lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.layer.cornerRadius = 8
        mapView.clipsToBounds = true
        mapView.delegate = self
        mapView.showsScale = false
        mapView.showsCompass = false
        mapView.showsUserLocation = false
        mapView.isUserInteractionEnabled = false
        if #available(iOS 17.0, *) {
            mapView.showsUserTrackingButton = false
        }
        return mapView
    }()
    
    private lazy var carAddress: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 0
        label.text = "车辆位置\n位置"
        return label
    }()
    
    private lazy var mapBottomView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            view.az_setGradientBackground(with: [.clear, .black], start: CGPoint.zero, end: CGPoint(x: 0, y: 0.5))
        }
        return view
    }()
    
    // 温度信息卡片StackView
    private lazy var temperatureInfoView: UIView = {
        let view = UIView()
        view.layerCornerRadius = 12
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return view
    }()
    
    private lazy var carTemperatureStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        stackView.axis = .vertical
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return stackView
    }()
    
    private lazy var carTemperature: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.text = "--˚"
        return label
    }()
    
    private lazy var carTemperatureLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "车内温度"
        return label
    }()
    
    private lazy var acTemperatureStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        stackView.axis = .vertical
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return stackView
    }()
    
    private lazy var presetTemperature: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "预设温度 26˚"
        return label
    }()
    
    private lazy var acStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .lightGray
        label.text = "空调已关闭"
        return label
    }()
    
    // 车窗状态
    private lazy var windowStatusTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "车窗状态"
        return label
    }()
    private lazy var windowStatusView: VehicleStatusView = {
        let view = VehicleStatusView()
        view.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.isLayoutMarginsRelativeArrangement = true
        view.alignment = .center
        view.axis = .vertical
        view.spacing = 8
        view.setupWindowUI()
        return view
    }()
    
    // 车门状态
    private lazy var doorStatusTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "车门状态"
        return label
    }()
    private lazy var doorStatusView: VehicleStatusView = {
        let view = VehicleStatusView()
        view.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.isLayoutMarginsRelativeArrangement = true
        view.alignment = .center
        view.axis = .vertical
        view.spacing = 8
        view.setupDoorUI()
        return view
    }()
    
    // 胎压状态
    private lazy var tpStatusTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "胎压状态"
        return label
    }()
    private lazy var tpStatusView: VehicleStatusView = {
        let view = VehicleStatusView()
        view.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.isLayoutMarginsRelativeArrangement = true
        view.alignment = .center
        view.axis = .vertical
        view.spacing = 8
        view.setupTPUI()
        return view
    }()
    
    // 标记是否是首次加载数据
    var isFirstDataLoad = true
    // 添加标志位防止重复调用
    private var isAutoReloginInProgress = false
    
    // 防止无限重试的计数器
    private var autoReloginAttempts = 0
    private let maxAutoReloginAttempts = 3
    private var lastAutoReloginTime: Date = Date(timeIntervalSince1970: 0)
    
    // 添加数据获取尝试计数器
    private var dataFetchAttempts = 0
    private let maxDataFetchAttempts = 3
    private var lastDataFetchTime: Date = Date(timeIntervalSince1970: 0)
    
    /// 视图加载后进行 UI 初始化、获取车辆信息并设置通知
    override func viewDidLoad() {
        super.viewDidLoad()
        // 设置导航栏
        setupNavigationBar()
        
        // 设置UI
        setupUI()
        
        // 更新推送Token（如果已登录）
        updatePushTokenIfNeeded()
        
        // 获取车辆信息
        fetchCarInfoAndValidateLogin()
        
        // 进入页面的时候通知
        registerAppDidBecomeActiveNotification()
        
        // 注册车辆数据更新通知
        registerCarDataUpdateNotification()
        
        // 检查是否需要显示首次使用教程
        checkAndShowFirstTimeTutorial()
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1, execute: {[weak self] in
            guard let self else {return}
            let gradientColors = [
                UIColor.white.withAlphaComponent(0.6),
                UIColor.white.withAlphaComponent(0.1),
                UIColor.white.withAlphaComponent(0.3),
                UIColor.white.withAlphaComponent(0.0)
            ]
            
            controlButtonsStackView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
            mapInfoView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
            temperatureInfoView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
            doorStatusView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
            windowStatusView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
            tpStatusView.addGradientBorder(colors: gradientColors, width: 1.0, cornerRadius: 12)
        })
    }
    
    /// 页面即将显示时刷新车辆信息
    override func viewWillAppear(_ animated: Bool) {
        if !isFirstDataLoad {
            fetchCarInfo()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 首次使用教程
    private func checkAndShowFirstTimeTutorial() {
        let hasShownTutorial = UserDefaults.standard.bool(forKey: "hasShownFirstTimeTutorial")
        
        if !hasShownTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showTutorialAlert()
            }
        }
    }
    
    private func showTutorialAlert() {
        let alert = UIAlertController(title: "欢迎使用胖3助手", message: "这是您第一次使用本应用，是否需要查看使用教程？", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "暂不需要", style: .cancel) { _ in
            // 标记已显示过教程弹窗，下次不再显示
            UserDefaults.standard.set(true, forKey: "hasShownFirstTimeTutorial")
        }
        
        let confirmAction = UIAlertAction(title: "查看教程", style: .default) { [weak self] _ in
            // 标记已显示过教程弹窗
            UserDefaults.standard.set(true, forKey: "hasShownFirstTimeTutorial")
            // 显示微信公众号弹窗
            self?.showWechatTutorial()
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        
        present(alert, animated: true)
    }
    
    private func showWechatTutorial() {
        WechatShowView.show(from: self)
    }
    
    // MARK: - 刷新小组件
    /// 刷新小组件时间线，遵循最小 10 秒刷新间隔
    private func refreshWidget() {
        // 刷新所有小组件
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - UI相关
extension HomeViewController {
    // MARK: - 设置导航栏
    /// 配置导航栏标题并注册欢迎词更新通知
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
    
    /// 根据用户设定动态更新导航栏欢迎词
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
            navigationItem.title = customGreeting
        case "none":
            navigationItem.title = "胖3助手"
        default:
            let name = UserManager.shared.userInfo?.userName ?? ""
            navigationItem.title = "尊贵的\(name)车主"
        }
    }
    
    /// 初始化并布局所有 UI 组件
    func setupUI() {
        // 设置UI层级结构
        setupViewHierarchy()
        
        // 设置Auto Layout约束
        setupConstraints()
        
        // 配置UI属性和事件
        configureUIProperties()
    }
    
    // MARK: - 设置视图层级
    /// 构建视图层级，将各个子视图添加到父视图
    private func setupViewHierarchy() {
        // 添加背景图片
        view.addSubview(backgroundImageView)
        // 添加模糊背景
        backgroundImageView.addSubview(backgroundBlurView)
        
        // 添加滚动视图
        view.addSubview(scrollView)
        
        // 添加顶部信息区域（在scrollView外面）
        view.addSubview(mileageHeaderView)
        mileageHeaderView.setupUI()
        
        // 添加主StackView作为scrollView的唯一子视图
        scrollView.addSubview(mainStackView)
        
        // 控制按钮区域 - 使用StackView
        mainStackView.addArrangedSubview(controlButtonsStackView)
        controlButtonsStackView.setupUI()
        
        // 地图和温度信息水平布局
        mainStackView.addArrangedSubview(mapTemperatureHorizontalStackView)
        
        // 地图信息卡片 - 使用StackView
        mapTemperatureHorizontalStackView.addArrangedSubview(mapInfoView)
        mapInfoView.addSubview(mapView)
        mapView.addSubview(mapBottomView)
        mapBottomView.addSubview(carAddress)
        
        // 温度信息卡片 - 使用StackView
        mapTemperatureHorizontalStackView.addArrangedSubview(temperatureInfoView)
        temperatureInfoView.addSubview(carTemperatureStackView)
        temperatureInfoView.addSubview(acTemperatureStackView)
        carTemperatureStackView.addArrangedSubview(carTemperature)
        carTemperatureStackView.addArrangedSubview(carTemperatureLabel)
        acTemperatureStackView.addArrangedSubview(presetTemperature)
        acTemperatureStackView.addArrangedSubview(acStatus)
        
        // 车窗状态区域 - 使用UIView
        mainStackView.addArrangedSubview(windowStatusTitle)
        mainStackView.addArrangedSubview(windowStatusView)
        mainStackView.setCustomSpacing(8, after: windowStatusTitle)
        
        // 车门状态区域 - 使用UIView
        mainStackView.addArrangedSubview(doorStatusTitle)
        mainStackView.addArrangedSubview(doorStatusView)
        mainStackView.setCustomSpacing(8, after: doorStatusTitle)
        
        // 胎压状态区域 - 使用UIView
        mainStackView.addArrangedSubview(tpStatusTitle)
        mainStackView.addArrangedSubview(tpStatusView)
        mainStackView.setCustomSpacing(8, after: tpStatusTitle)
    }
    
    private func addSpacingView() -> UIView {
        let label = UILabel()
        label.text = "  "
        return label
    }
    
    // MARK: - 设置约束
    /// 使用 SnapKit 为各个视图添加 Auto Layout 约束
    private func setupConstraints() {
        // 背景图片约束
        backgroundImageView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(30)
            make.height.equalTo(backgroundImageView.snp.width).multipliedBy(9.0/16.0)
        }
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 顶部信息区域约束（在导航顶部）
        mileageHeaderView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(100)
        }
        
        // 滚动视图约束（从headerView下方开始）
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // 主StackView约束 - 填充整个scrollView
        mainStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        // StackView子视图的约束现在由mainStackView自动管理
        // 只需要为控制按钮设置高度约束
        controlButtonsStackView.snp.makeConstraints { make in
            make.height.equalTo(80)
        }
        
        controlButtonsStackView.arrangedSubviews.forEach { containerView in
            containerView.snp.makeConstraints { make in
                make.height.equalTo(80)
            }
        }
        
        setupInfoCardConstraints()
    }
    
    private func setupInfoCardConstraints() {
        // 地图视图约束（在mapInfoStackView内）
        mapInfoView.snp.makeConstraints { make in
            make.height.equalTo(mapView.snp.width)
        }
        
        mapView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 地图底部渐变视图
        mapBottomView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(mapView)
            make.height.equalTo(60)
        }
        
        // 车辆地址
        carAddress.snp.makeConstraints { make in
            make.leading.equalTo(mapBottomView).offset(8)
            make.trailing.equalTo(mapBottomView).offset(-8)
            make.bottom.equalTo(mapBottomView).offset(-8)
        }
        
        // 温度模块
        temperatureInfoView.snp.makeConstraints { make in
            make.height.equalTo(temperatureInfoView.snp.width)
        }
        
        // 车内温度
        carTemperatureStackView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(8)
        }
        
        // 预设温度
        acTemperatureStackView.snp.makeConstraints { make in
            make.bottom.leading.equalToSuperview().inset(8)
        }
        
        // 空调状态
        acStatus.snp.makeConstraints { make in
            make.top.equalTo(presetTemperature.snp.bottom).offset(4)
            make.leading.trailing.equalTo(carTemperature)
            make.bottom.equalToSuperview().offset(-8)
        }
    }
    
    // MARK: - 配置UI属性
    private func configureUIProperties() {
        // 设置下拉刷新
        let mj_header = MJRefreshNormalHeader(refreshingBlock: {
            self.fetchCarInfo()
        })
        mj_header.ignoredScrollViewContentInsetTop = 150
        mj_header.lastUpdatedTimeLabel?.isHidden = true
        scrollView.mj_header = mj_header
    }
}

// MARK: - 点击事件
extension HomeViewController {
    @objc private func mapTapped() {
        actionMap(QMUIButton())
    }
    
    func actionMap(_ sender: QMUIButton) {
        guard let model = UserManager.shared.carModel else { return }
        
        let alertController = UIAlertController(title: "导航到我的车", message: "请选择要使用的地图应用", preferredStyle: .actionSheet)
        
        // 检查是否安装了高德地图
        if let amapURL = URL(string: "iosamap://"), UIApplication.shared.canOpenURL(amapURL) {
            let amapAction = UIAlertAction(title: "高德地图", style: .default) { _ in
                self.openAmapNavigation(model: model)
            }
            alertController.addAction(amapAction)
        }
        
        // 检查是否安装了百度地图
        if let baiduURL = URL(string: "baidumap://"), UIApplication.shared.canOpenURL(baiduURL) {
            let baiduAction = UIAlertAction(title: "百度地图", style: .default) { _ in
                self.openBaiduMapNavigation(model: model)
            }
            alertController.addAction(baiduAction)
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
            popover.sourceView = mapInfoView
            popover.sourceRect = mapInfoView.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - 打开高德地图查看位置
    private func openAmapNavigation(model: SharedCarModel) {
        let amapURLString = "iosamap://viewMap?sourceApplication=胖3汽车&backScheme=pan3&lat=\(model.latitude)&lon=\(model.longitude)&poiname=我的车&dev=0"
        if let amapURL = URL(string: amapURLString) {
            UIApplication.shared.open(amapURL, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: - 打开苹果地图导航
    private func openAppleMapNavigation(model: SharedCarModel) {
        let coordinate = CLLocationCoordinate2D(latitude: model.latitude, longitude: model.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "我的车"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // MARK: - 打开百度地图导航
    private func openBaiduMapNavigation(model: SharedCarModel) {
        // 将GCJ02坐标转换为BD09坐标
        let convertedCoordinate = convertGCJ02ToBD09(lat: model.latitude, lon: model.longitude)
        
        let baiduURLString = "baidumap://map/direction?destination=\(convertedCoordinate.lat),\(convertedCoordinate.lon)&mode=driving&coord_type=bd09ll&src=胖3汽车"
        
        if let baiduURL = URL(string: baiduURLString) {
            UIApplication.shared.open(baiduURL, options: [:]) { success in
                if !success {
                    // 如果打开失败，跳转到App Store
                    if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/百度地图/id452186370") {
                        UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - GCJ02转BD09坐标转换
    private func convertGCJ02ToBD09(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        let z = sqrt(lon * lon + lat * lat) + 0.00002 * sin(lat * Double.pi)
        let theta = atan2(lat, lon) + 0.000003 * cos(lon * Double.pi)
        let bdLon = z * cos(theta) + 0.0065
        let bdLat = z * sin(theta) + 0.006
        return (lat: bdLat, lon: bdLon)
    }
}

// MARK: - 网络请求
extension HomeViewController {
    // MARK: - 更新推送Token
    /// 更新推送Token到服务器（在登录状态下）
    func updatePushTokenIfNeeded() {
        // 检查用户是否已登录
        guard UserManager.shared.isLoggedIn else {
            print("[HomeViewController] 用户未登录，跳过更新推送Token")
            return
        }
        
        // 获取推送Token
        guard let pushToken = UserDefaults.standard.string(forKey: "pushToken"),
              !pushToken.isEmpty else {
            print("[HomeViewController] 未找到推送Token，跳过更新")
            return
        }
        
        print("[HomeViewController] 开始更新推送Token到服务器")
        
        // 调用更新推送Token的API
        NetworkManager.shared.updatePushToken(pushToken: pushToken) { result in
            switch result {
            case .success:
                print("[HomeViewController] 推送Token更新成功")
            case .failure(let error):
                print("[HomeViewController] 推送Token更新失败: \(error.localizedDescription)")
                // 静默失败，不影响用户体验
            }
        }
    }
    
    // MARK: - 获取车辆信息并验证登录状态
    func fetchCarInfoAndValidateLogin() {
        let userManager = UserManager.shared
        guard let _ = userManager.timaToken else {
            // 没有token，跳转到登录页面
            QMUITips.show(withText: "没有获取到登陆token")
            return
        }
        
        // 获取车辆信息
        fetchCarInfo(showSuccessMessage: false)
    }
    
    // MARK: - 尝试自动重新登录
    func attemptAutoRelogin() {
        // 防止重复调用
        if isAutoReloginInProgress {
            print("[HomeViewController] 自动重新登录正在进行中，忽略重复调用")
            return
        }
        
        // 检查重试次数和时间间隔，防止无限循环
        let now = Date()
        let timeSinceLastAttempt = now.timeIntervalSince(lastAutoReloginTime)
        
        print("[HomeViewController] attemptAutoRelogin 被调用 - 当前重试次数: \(autoReloginAttempts), 距离上次尝试: \(timeSinceLastAttempt)秒")
        
        // 如果距离上次尝试超过30秒，重置计数器
        if timeSinceLastAttempt > 30 {
            print("[HomeViewController] 距离上次尝试超过30秒，重置重试计数器")
            autoReloginAttempts = 0
        }
        
        // 检查是否超过最大重试次数
        if autoReloginAttempts >= maxAutoReloginAttempts {
            print("[HomeViewController] 自动重新登录已达到最大尝试次数(\(maxAutoReloginAttempts))，停止重试")
            QMUITips.show(withText: "登录失败次数过多，请手动重新登录", in: view, hideAfterDelay: 3.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                self.navigateToLogin()
            }
            return
        }
        
        guard let credentials = UserManager.shared.savedCredentials else {
            print("[HomeViewController] 没有保存的账户密码，跳转到登录页面")
            QMUITips.show(withText: "没有获取到账户或者密码", in: view, hideAfterDelay: 2.0)
            return
        }
        
        // 设置进行中标志
        isAutoReloginInProgress = true
        
        // 更新重试计数和时间
        autoReloginAttempts += 1
        lastAutoReloginTime = now
        
        print("[HomeViewController] 开始第\(autoReloginAttempts)次自动重新登录尝试")
        
        QMUITips.showLoading(in: self.view)
        QMUITips.show(withText: "正在自动重新登录...(\(autoReloginAttempts)/\(maxAutoReloginAttempts))", in: view, hideAfterDelay: 1.0)
        
        // 使用保存的账户密码自动登录
        let encryptedPassword = credentials.password.qmui_md5
        NetworkManager.shared.login(userCode: credentials.phone, password: encryptedPassword) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                // 重置进行中标志
                self.isAutoReloginInProgress = false
                QMUITips.hideAllTips()
                
                switch result {
                case .success(let authResponse):
                    print("[HomeViewController] 自动登录成功")
                    // 登录成功，但不重置重试计数器，等待数据获取成功后再重置
                    
                    // 登录成功，更新认证响应信息
                    UserManager.shared.authResponse = authResponse
                    
                    // 登录成功后，延迟一下再获取车辆信息，避免立即重试
                    print("[HomeViewController] 自动登录成功，1秒后获取车辆信息")
                    QMUITips.show(withText: "自动登录成功", in: self.view, hideAfterDelay: 1.0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.fetchCarInfo(showSuccessMessage: false)
                    }
                    
                case .failure(let error):
                    print("[HomeViewController] 自动登录失败: \(error.localizedDescription)")
                    print("[HomeViewController] 自动登录失败详情: \(error)")
                    QMUITips.show(withText: "自动登录失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                    
                    // 如果还有重试机会，等待一段时间后再次尝试
                    if self.autoReloginAttempts < self.maxAutoReloginAttempts {
                        print("[HomeViewController] 将在5秒后进行下一次重试")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.attemptAutoRelogin()
                        }
                    } else {
                        print("[HomeViewController] 已达到最大重试次数，跳转到登录页面")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            self.navigateToLogin()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 获取车辆信息
    func fetchCarInfo(showSuccessMessage: Bool = false) {
        print("[HomeViewController] 开始获取车辆信息，showSuccessMessage: \(showSuccessMessage)")
        print("[HomeViewController] 当前token状态: \(UserManager.shared.timaToken != nil ? "有效" : "无效")")
        print("[HomeViewController] 当前vin状态: \(UserManager.shared.defaultVin != nil ? "有效" : "无效")")
        
        // 更新数据获取尝试计数
        let now = Date()
        let timeSinceLastFetch = now.timeIntervalSince(lastDataFetchTime)
        
        // 如果距离上次尝试超过30秒，重置数据获取计数器
        if timeSinceLastFetch > 30 {
            print("[HomeViewController] 距离上次数据获取尝试超过30秒，重置数据获取计数器")
            dataFetchAttempts = 0
        }
        
        dataFetchAttempts += 1
        lastDataFetchTime = now
        print("[HomeViewController] 数据获取尝试次数: \(dataFetchAttempts)/\(maxDataFetchAttempts)")
        
        NetworkManager.shared.getInfo { [weak self] result in
            guard let self else {return}
            self.scrollView.mj_header?.endRefreshing()
            if showSuccessMessage {
                QMUITips.hideAllTips()
            }
            switch result {
            case .success(let model):
                print("[HomeViewController] 车辆信息获取成功")
                // 成功获取数据，重置所有重试计数器
                self.autoReloginAttempts = 0
                self.dataFetchAttempts = 0
                
                // 保存车辆信息
                UserManager.shared.updateCarInfo(with: model)
                self.setupCarData()
                
                // 刷新小组件
                self.refreshWidget()
            case .failure(let error):
                print("[HomeViewController] 车辆信息获取失败: \(error.localizedDescription)")
                print("[HomeViewController] 错误详情: \(error)")
                print("[HomeViewController] 错误类型: \(type(of: error))")
                
                // 检查是否是NSError，并打印更多信息
                if let nsError = error as NSError? {
                    print("[HomeViewController] NSError domain: \(nsError.domain), code: \(nsError.code)")
                    print("[HomeViewController] NSError userInfo: \(nsError.userInfo)")
                }
                
                if showSuccessMessage {
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                } else {
                    // 检查错误类型，修正错误检测逻辑
                    let errorDescription = error.localizedDescription.lowercased()
                    let errorDomain = (error as NSError).domain.lowercased()
                    let errorCode = (error as NSError).code
                    
                    print("[HomeViewController] 错误分析 - description: \(errorDescription), domain: \(errorDomain), code: \(errorCode)")
                    
                    // 更严格的认证错误检测，排除服务器内部错误
                    let isAuthError = (errorDescription.contains("unauthorized") ||
                                     errorDescription.contains("token") ||
                                     errorDescription.contains("authentication") ||
                                     errorDescription.contains("用户未登录") ||
                                     errorCode == 401 || errorCode == 403) &&
                                     errorCode != 500 // 排除服务器内部错误
                    
                    if isAuthError && !self.isAutoReloginInProgress {
                        print("[HomeViewController] 检测到认证相关错误，尝试自动重新登录")
                        self.attemptAutoRelogin()
                    } else if self.isAutoReloginInProgress {
                        print("[HomeViewController] 自动重新登录正在进行中，跳过重新登录")
                    } else {
                        print("[HomeViewController] 非认证错误或服务器错误，检查是否需要使用缓存数据")
                        
                        // 检查数据获取尝试次数
                        if self.dataFetchAttempts >= self.maxDataFetchAttempts {
                            print("[HomeViewController] 数据获取已达到最大尝试次数(\(self.maxDataFetchAttempts))，尝试使用缓存数据")
                            self.handleDataFetchFailure()
                        } else {
                            print("[HomeViewController] 网络请求失败，将在下次尝试重新获取: \(error.localizedDescription)")
                            QMUITips.show(withText: "网络请求失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 处理数据获取失败，尝试使用缓存数据
    private func handleDataFetchFailure() {
        print("[HomeViewController] 开始处理数据获取失败，尝试使用缓存数据")
        
        // 尝试从App Groups获取缓存的车辆数据
        if let sharedModel = UserManager.shared.loadCarModelFromAppGroups() {
            print("[HomeViewController] 找到缓存的车辆数据，使用缓存数据")
            
            // 使用缓存数据更新UI
            self.updateCarStatusInfo(with: sharedModel)
            self.updateMapLocation(with: sharedModel)
            
            // 提示用户这是缓存数据
            QMUITips.show(withText: "⚠️ 当前显示的是缓存数据，非实时数据", in: self.view, hideAfterDelay: 3.0)
            
            // 重置数据获取计数器
            self.dataFetchAttempts = 0
        } else {
            print("[HomeViewController] 没有找到缓存数据")
            
            // 没有缓存数据，提示用户
            let alert = UIAlertController(title: "数据获取失败", 
                                        message: "无法获取车辆信息，且没有可用的缓存数据。请检查网络连接或稍后重试。", 
                                        preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
                // 重置计数器并重试
                self.dataFetchAttempts = 0
                self.fetchCarInfo(showSuccessMessage: true)
            })
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                // 重置计数器
                self.dataFetchAttempts = 0
            })
            
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - 跳转到登录页面
    func navigateToLogin() {
        print("[HomeViewController] navigateToLogin 被调用")
        QMUITips.show(withText: "需要重新登录", in: view, hideAfterDelay: 2.0)
        
        // 清除当前的认证信息
        //        UserManager.shared.logout()
        
        // 这里应该跳转到登录页面，目前只是显示提示
        // 如果有登录页面的segue或者storyboard，可以在这里添加跳转逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // TODO: 添加实际的登录页面跳转逻辑
            print("[HomeViewController] 应该跳转到登录页面")
        }
    }
    
    // MARK: - 配置信息
    func setupCarData() {
        guard let model = UserManager.shared.carModel else { return }
        
        // 加载里程
        mileageHeaderView.setupCarModel(isFirstDataLoad)
        
        if isFirstDataLoad {
            isFirstDataLoad = false
            if model.chgStatus == 2 {
                // 清除实时活动数据
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "ChargeLiveActivityData")
                defaults.synchronize()
                
                // 停止实时活动
                LiveActivityManager.shared.closeChargeActivity()
            }
            if model.keyStatus == 2, model.mainLockStatus == 0 {
                // 清除实时活动数据
                guard let groupDefaults = UserDefaults(suiteName: "group.com.feng.pan3") else {
                    print("无法访问App Groups")
                    return
                }
                groupDefaults.removeObject(forKey: "TripLiveActivityData")
                groupDefaults.synchronize()
                
                // 停止实时活动
                LiveActivityManager.shared.closeTripActivity()
            }
        }
        
        // 控制按钮
        controlButtonsStackView.setupCarModel()
        controlButtonsStackView.blockTemperatureChange = { [weak self] temperature in
            self?.presetTemperature.text = "预设温度 \(temperature)˚"
        }
        
        // 充电状态
        if model.chgStatus == 2 {
            backgroundImageView.image = UIImage(named: "my_car")
        }else{
            backgroundImageView.image = UIImage(named: "my_car_charge")
        }
        
        // 温度显示
        if model.acStatus == 1 {
            acStatus.text = "空调已开启"
        }else{
            acStatus.text = "空调已关闭"
        }
        
        // 更新车辆状态信息
        updateCarStatusInfo(with: model)
        
        // 更新地图位置
        updateMapLocation(with: model)
    }
    
    // MARK: - CarDataRefreshable Protocol Implementation
    func refreshCarData() {
        fetchCarInfo()
    }
    
    @objc func handleAppDidBecomeActive() {
        print("APP重新进入前台了 - HomeViewController")
        if !isFirstDataLoad {
            // 延迟1秒后再请求，给网络连接时间稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("延迟后开始刷新车辆数据")
                self?.refreshCarData()
            }
        }
    }
    
    // MARK: - 小组件跳转处理
    /// 处理从小组件跳转到APP的操作
    func handleWidgetAction(_ action: String) {
        print("HomeViewController 收到小组件操作: \(action)")
        
        // 确保用户已登录且有车辆数据
        guard UserManager.shared.isLoggedIn,
              let _ = UserManager.shared.carModel else {
            print("用户未登录或无车辆数据，无法处理小组件操作")
            return
        }
        
        // 检查是否启用调试模式
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        guard shouldEnableDebug else {
            return
        }
        
        // 根据不同的action调用对应的控制方法
        switch action {
        case "lock":
            // 调用车锁控制
            controlButtonsStackView.widgetLockButtonTapped()
            print("执行车锁操作")
            
        case "ac":
            // 调用空调控制
            controlButtonsStackView.widgetAcButtonTapped()
            print("执行空调操作")
            
        case "window":
            // 调用车窗控制
            controlButtonsStackView.widgetWindowButtonTapped()
            print("执行车窗操作")
            
        case "call":
            // 调用寻车控制
            controlButtonsStackView.widgetCallButtonTapped()
            print("执行寻车操作")
            
        default:
            print("未知的小组件操作: \(action)")
        }
    }
    
    // MARK: - 更新车辆状态信息
    private func updateCarStatusInfo(with model: SharedCarModel) {
        // 车辆信息
        windowStatusView.updateWindowStatusInfo()
        doorStatusView.updateDoorStatusInfo()
        tpStatusView.updateTPStatusInfo()
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
    private func updateMapLocation(with model: SharedCarModel) {
        let coordinate = CLLocationCoordinate2D(latitude: model.latitude, longitude: model.longitude)
        
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
        let location = CLLocation(latitude: model.latitude, longitude: model.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let address = [placemark.subLocality, placemark.name]
                        .compactMap { $0 }
                        .joined(separator: "")
                    self?.carAddress.text = address.isEmpty ? "车辆位置\n位置解析中..." : "车辆位置\n\(address)"
                } else {
                    self?.carAddress.text = "车辆位置\n位置解析失败"
                }
            }
        }
    }
    

}

// MARK: - MKMapViewDelegate代理
extension HomeViewController: MKMapViewDelegate {
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

// MARK: - UIScrollViewDelegate代理
extension HomeViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 获取滚动偏移量
        let offsetY = scrollView.contentOffset.y + scrollView.contentInset.top
        
        // 只在向上滚动时应用模糊效果
        if offsetY > 0 {
            // 计算模糊程度，最大模糊半径为20
            let maxBlurRadius: CGFloat = 20.0
            let maxScrollDistance: CGFloat = 200.0 // 滚动200点达到最大模糊
            
            let blurRadius = min(maxBlurRadius, (offsetY / maxScrollDistance) * maxBlurRadius)
            
            // 应用模糊效果（确保半径非负）
            let effect = UIBlurEffect.qmui_effect(withBlurRadius: max(blurRadius - 1, 0))
            backgroundBlurView.effect = effect
        } else {
            // 向下滚动或在顶部时，移除模糊效果
            backgroundBlurView.effect = nil
        }
    }
}

// MARK: - UIView Extension for Gradient Border
extension UIView {
    func addGradientBorder(colors: [UIColor], width: CGFloat = 1.0, cornerRadius: CGFloat = 0) {
        // Remove existing gradient border if any
        layer.sublayers?.removeAll { $0 is CAGradientLayer && $0.name == "gradientBorder" }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "gradientBorder"
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = cornerRadius
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.lineWidth = width
        shapeLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width/2, dy: width/2), cornerRadius: cornerRadius).cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        gradientLayer.mask = shapeLayer
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
}
