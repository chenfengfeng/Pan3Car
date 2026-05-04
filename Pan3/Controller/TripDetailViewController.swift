//
//  TripDetailViewController.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import UIKit
import MapKit
import SnapKit

class TripDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    private var tripRecord: TripRecord
    private var dataPoints: [TripDataPoint] = []
    
    // MARK: - Animation Properties
    private var animationTimer: Timer?
    private var currentAnimationStep: Int = 0
    private var previousAnimationOverlay: MKPolyline?
    private var isAnimating: Bool = false
    private var fullRouteCoordinates: [CLLocationCoordinate2D] = []
    private var pointsPerStep: Int = 1  // 每步增加的点数
    private var hasRenderedMap = false
    
    // MARK: - UI Components
    
    private lazy var mapView: MKMapView = {
        let map = MKMapView()
        map.mapType = .standard
        map.showsUserLocation = false
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        return map
    }()
    
    // 底部渐变信息视图
    private lazy var bottomInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    // APP名称标签（仅在分享截图时显示）
    private lazy var appNameLabel: UILabel = {
        let label = UILabel()
        label.text = "胖3助手APP"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.isHidden = true  // 默认隐藏
        return label
    }()
    
    // 主水平容器
    private lazy var mainHorizontalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        stack.distribution = .fillEqually
        return stack
    }()
    
    // 左侧容器（行驶里程 + 能耗 + 达成率）
    private lazy var leftVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.alignment = .leading
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    // 左侧：行驶里程标签
    private lazy var distanceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 36, weight: .bold)
        label.textAlignment = .left
        label.textColor = .white
        return label
    }()
    
    // 左侧：能耗标签
    private lazy var energyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .left
        return label
    }()
    
    // 左侧：达成率标签
    private lazy var achievementRateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .left
        return label
    }()
    
    // 右侧网格容器
    private lazy var rightGridStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fillEqually
        return stack
    }()

    private lazy var loadingContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.layer.cornerRadius = 8
        view.isHidden = true
        return view
    }()

    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "轨迹加载中 0%"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        view.progressTintColor = .systemGreen
        return view
    }()
    
    // MARK: - Initialization
    
    init(tripRecord: TripRecord) {
        self.tripRecord = tripRecord
        super.init(nibName: nil, bundle: nil)
        // 隐藏底部TabBar
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 隐藏导航标题
        title = ""
        
        setupUI()
        setupInfo()
        setupNavigationBar()
        loadAndRenderRoute()
    }
    
    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBar() {
        // 分享按钮
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        shareButton.tintColor = .white
        navigationItem.rightBarButtonItem = shareButton
        
        // 返回按钮设置为白色
        navigationController?.navigationBar.tintColor = .white
        
        // 导航栏透明
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 清理动画 timer，避免内存泄漏
        animationTimer?.invalidate()
        animationTimer = nil
        
        // 恢复导航栏
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.addSubview(mapView)
        view.addSubview(bottomInfoView)
        view.addSubview(loadingContainerView)
        
        // 添加渐变层
        bottomInfoView.az_setGradientBackground(with: [.clear, .black.withAlphaComponent(0.5), .black.withAlphaComponent(0.8), .black], start: CGPoint(), end: CGPoint(x: 0, y: 1))
        
        // 添加主容器
        bottomInfoView.addSubview(mainHorizontalStack)
        
        // 添加APP名称标签（用于分享截图）
        bottomInfoView.addSubview(appNameLabel)

        loadingContainerView.addSubview(loadingLabel)
        loadingContainerView.addSubview(progressView)
        
        // 添加左侧组件
        leftVerticalStack.addArrangedSubview(distanceLabel)
        leftVerticalStack.addArrangedSubview(energyLabel)
        leftVerticalStack.addArrangedSubview(achievementRateLabel)
        mainHorizontalStack.addArrangedSubview(leftVerticalStack)
        
        // 添加右侧网格容器
        mainHorizontalStack.addArrangedSubview(rightGridStack)
        
        // MapView - 全屏显示，从状态栏顶部开始
        mapView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // BottomInfoView - 底部信息区域
        bottomInfoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(200)
        }
        
        // MainHorizontalStack - 主容器
        mainHorizontalStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        
        // AppNameLabel - APP名称标签（底部居中）
        appNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }

        loadingContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.width.equalTo(180)
            make.height.equalTo(56)
        }

        loadingLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(10)
        }

        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.top.equalTo(loadingLabel.snp.bottom).offset(8)
        }
    }
    
    // MARK: - Map Setup
    
    private func setupMap() {
        hasRenderedMap = true
        // 设置地图代理
        mapView.delegate = self
        
        guard !dataPoints.isEmpty else {
            // 如果没有数据点，显示起止点
            showStartEndPoints()
            return
        }
        
        // 创建轨迹坐标
        let coordinates = dataPoints.compactMap { point -> CLLocationCoordinate2D? in
            guard point.lat != 0, point.lon != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        }
        
        guard !coordinates.isEmpty else {
            showStartEndPoints()
            return
        }
        
        // 保存完整坐标用于动画
        fullRouteCoordinates = coordinates
        
        // 添加起点和终点标注
        addStartEndAnnotations()
        
        // 设置地图显示区域（使用完整轨迹计算）
        let tempPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        let region = MKCoordinateRegion(tempPolyline.boundingMapRect)
        let adjustedRegion = mapView.regionThatFits(region)
        mapView.setRegion(adjustedRegion, animated: false)
        
        // 添加一些边距
        let edgePadding = UIEdgeInsets(top: 100, left: 50, bottom: 250, right: 50)
        mapView.setVisibleMapRect(tempPolyline.boundingMapRect, edgePadding: edgePadding, animated: false)
        
        // 启动动画（而不是直接显示完整轨迹）
        startRouteAnimation()
    }
    
    private func showStartEndPoints() {
        // 只显示起点和终点
        addStartEndAnnotations()
        
        // 计算中心点
        let centerLat = (tripRecord.startLat + tripRecord.endLat) / 2
        let centerLon = (tripRecord.startLon + tripRecord.endLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // 计算跨度
        let latDelta = abs(tripRecord.endLat - tripRecord.startLat) * 2
        let lonDelta = abs(tripRecord.endLon - tripRecord.startLon) * 2
        let span = MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
        
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }
    
    private func addStartEndAnnotations() {
        // 起点标注
        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = CLLocationCoordinate2D(latitude: tripRecord.startLat, longitude: tripRecord.startLon)
        startAnnotation.title = "起点"
        startAnnotation.subtitle = tripRecord.displayStartAddress
        mapView.addAnnotation(startAnnotation)
        
        // 终点标注
        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = CLLocationCoordinate2D(latitude: tripRecord.endLat, longitude: tripRecord.endLon)
        endAnnotation.title = "终点"
        endAnnotation.subtitle = tripRecord.displayEndAddress
        mapView.addAnnotation(endAnnotation)
    }
    
    // MARK: - Data Loading
    
    private func loadDataPoints() {
        dataPoints = CoreDataManager.shared.fetchTripDataPoints(for: tripRecord)
        print("[TripDetail] 加载了 \(dataPoints.count) 个数据点")
    }

    private func loadAndRenderRoute() {
        loadDataPoints()
        guard dataPoints.isEmpty, let clientTripID = tripRecord.clientTripID, !clientTripID.isEmpty else {
            setupMap()
            return
        }

        setLoadingProgress(0)
        loadingContainerView.isHidden = false
        print("[TripDetail] 本地无轨迹点，开始按需导入：\(clientTripID)")

        DataSyncManager.shared.importTripPoints(
            clientTripID: clientTripID,
            progress: { [weak self] progress in
                self?.setLoadingProgress(progress)
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.loadingContainerView.isHidden = true

                switch result {
                case .success(let count):
                    CoreDataManager.shared.viewContext.refresh(self.tripRecord, mergeChanges: true)
                    self.loadDataPoints()
                    print("[TripDetail] 按需导入轨迹点完成：\(count) 个，当前本地 \(self.dataPoints.count) 个")
                case .failure(let error):
                    print("[TripDetail] 按需导入轨迹点失败：\(error.localizedDescription)")
                    QMUITips.showError("轨迹加载失败")
                }

                if !self.hasRenderedMap {
                    self.setupMap()
                }
            }
        )
    }

    private func setLoadingProgress(_ progress: Double) {
        let clamped = max(0, min(1, progress))
        progressView.setProgress(Float(clamped), animated: true)
        loadingLabel.text = "轨迹加载中 \(Int((clamped * 100).rounded()))%"
    }
    
    // MARK: - Info Setup
    
    private func setupInfo() {
        // 判断数据来源类型
        let isDeviceTrack = tripRecord.trackSource == "device"
        
        // 设置左侧数据：行驶里程
        distanceLabel.text = String(format: "%.1f km", tripRecord.totalDistance)
        
        // 设置左侧数据：能耗（根据数据来源显示不同内容）
        if isDeviceTrack, let energyPer100km = tripRecord.energyConsumptionPer100km {
            // 车机GPS模式：显示准确的里程能耗
            energyLabel.text = String(format: "%.1f kWh/100km", energyPer100km)
        } else {
            // 轮询模式：显示原有能耗计算
            energyLabel.text = String(format: "%.2f kWh/100km", tripRecord.energyEfficiency)
        }
        
        // 设置左侧数据：达成率
        achievementRateLabel.text = String(format: "%.1f%% 达成率", tripRecord.achievementRate)
        
        // 清空右侧网格现有内容
        rightGridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 创建右侧上排（开始里程 | 结束里程）
        let topRowStack = UIStackView()
        topRowStack.axis = .horizontal
        topRowStack.spacing = 12
        topRowStack.alignment = .fill
        topRowStack.distribution = .fillEqually
        
        let startRangeView = createDataItemView(
            title: "开始里程",
            value: "\(tripRecord.startRangeKm)km"
        )
        let endRangeView = createDataItemView(
            title: "结束里程",
            value: "\(tripRecord.endRangeKm)km"
        )
        
        topRowStack.addArrangedSubview(startRangeView)
        topRowStack.addArrangedSubview(endRangeView)
        
        // 创建右侧下排（平均速度 | 最高速度）
        let bottomRowStack = UIStackView()
        bottomRowStack.axis = .horizontal
        bottomRowStack.spacing = 12
        bottomRowStack.alignment = .fill
        bottomRowStack.distribution = .fillEqually
        
        let avgSpeedView = createDataItemView(
            title: "平均速度",
            value: "\(tripRecord.avgSpeed)km/h"
        )
        let maxSpeedView = createDataItemView(
            title: "最高速度",
            value: "\(tripRecord.maxSpeed)km/h"
        )
        
        bottomRowStack.addArrangedSubview(avgSpeedView)
        bottomRowStack.addArrangedSubview(maxSpeedView)
        
        // 添加到右侧网格
        rightGridStack.addArrangedSubview(topRowStack)
        rightGridStack.addArrangedSubview(bottomRowStack)
    }
    
    /// 创建右侧网格的单个数据项视图
    /// - Parameters:
    ///   - title: 标题文本（例如"开始里程"）
    ///   - value: 数值文本（例如"8843km"）
    /// - Returns: 配置好的数据项视图
    private func createDataItemView(title: String, value: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .white.withAlphaComponent(0.7)
        titleLabel.textAlignment = .center
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        valueLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func shareTapped() {
        // 截取整个页面
        guard let image = captureScreenshot() else {
            QMUITips.showError("生成截图失败")
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityVC, animated: true)
    }
    
    /// 截取整个页面为图片
    private func captureScreenshot() -> UIImage? {
        // 使用整个view的bounds
        let bounds = view.bounds
        
        // 截图前：显示APP名称标签
        appNameLabel.isHidden = false
        
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { context in
            // 使用 drawHierarchy 而不是 layer.render，可以正确捕获 MKMapView 等硬件加速视图
            view.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        
        // 截图后：隐藏APP名称标签
        appNameLabel.isHidden = true
        
        return image
    }
    
    // MARK: - Animation Methods
    
    /// 启动路径动画
    private func startRouteAnimation() {
        guard !fullRouteCoordinates.isEmpty else {
            print("[TripDetail] 没有坐标数据，无法启动动画")
            return
        }
        
        // 禁用地图交互
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        
        // 重置动画状态
        currentAnimationStep = 0
        previousAnimationOverlay = nil
        isAnimating = true
        
        // 动画配置
        let targetFPS = 30.0        // 目标帧率（固定30 FPS）
        let minDuration = 2.0       // 最短时长
        let maxDuration = 5.0       // 最长时长
        
        // 计算动态时长
        let pointCount = fullRouteCoordinates.count
        let idealDuration = Double(pointCount) / targetFPS
        let actualDuration = min(max(idealDuration, minDuration), maxDuration)
        
        // 计算帧数和每步点数
        let totalFrames = actualDuration * targetFPS
        pointsPerStep = max(1, Int(ceil(Double(pointCount) / totalFrames)))
        
        // 固定帧间隔（30 FPS）
        let frameInterval = 1.0 / targetFPS
        
        print("[TripDetail] 启动动画：总点数 \(pointCount)，动画时长 \(actualDuration)秒，每步 \(pointsPerStep) 个点，帧率 \(targetFPS) FPS")
        
        // 创建并启动 Timer
        animationTimer = Timer.scheduledTimer(
            timeInterval: frameInterval,
            target: self,
            selector: #selector(animationStep),
            userInfo: nil,
            repeats: true
        )
    }
    
    /// 动画步进方法（每个 timer 触发时调用）
    @objc private func animationStep() {
        // 增加步进计数（按配置的点数增加）
        currentAnimationStep += pointsPerStep
        
        // 检查是否完成（确保不超过总点数）
        if currentAnimationStep >= fullRouteCoordinates.count {
            // 最后一帧：显示所有剩余点
            currentAnimationStep = fullRouteCoordinates.count
            finishAnimation()
            return
        }
        
        // 创建当前步长的子坐标数组（从起点到当前点）
        let segmentCoords = Array(fullRouteCoordinates.prefix(upTo: currentAnimationStep))
        
        // 创建新的 MKPolyline 对象（至少有2个点）
        guard segmentCoords.count >= 2 else {
            // 第一帧可能只有1个点，等待下一帧
            return
        }
        
        let newSegment = MKPolyline(coordinates: segmentCoords, count: segmentCoords.count)
        
        // 移除旧路径
        if let oldSegment = previousAnimationOverlay {
            mapView.removeOverlay(oldSegment)
        }
        
        // 添加新路径
        mapView.addOverlay(newSegment)
        
        // 更新引用
        previousAnimationOverlay = newSegment
    }
    
    /// 完成动画并显示最终的渐变轨迹
    private func finishAnimation() {
        print("[TripDetail] 动画完成，显示渐变轨迹")
        
        // 停止并清理 timer
        animationTimer?.invalidate()
        animationTimer = nil
        
        // 移除动画用的 overlay
        if let oldSegment = previousAnimationOverlay {
            mapView.removeOverlay(oldSegment)
        }
        previousAnimationOverlay = nil
        
        // 标记动画已结束
        isAnimating = false
        
        // 添加最终的完整轨迹（会触发渲染器返回渐变版本）
        let finalPolyline = MKPolyline(coordinates: fullRouteCoordinates, count: fullRouteCoordinates.count)
        mapView.addOverlay(finalPolyline)
        
        // 恢复地图交互
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
    }
}

// MARK: - Custom Annotation View

class StartPointAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // 背景大小
        let backgroundSize: CGFloat = 36
        let imageSize: CGFloat = 30
        
        // 创建浅蓝色背景容器
        let backgroundView = UIView()
        backgroundView.frame = CGRect(x: 0, y: 0, width: backgroundSize, height: backgroundSize)
        backgroundView.backgroundColor = UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0) // 浅蓝色
        backgroundView.layer.cornerRadius = backgroundSize / 2
        backgroundView.layer.borderWidth = 2
        backgroundView.layer.borderColor = UIColor.white.cgColor
        backgroundView.clipsToBounds = true
        addSubview(backgroundView)
        
        // 添加车辆图片到背景中心
        let imageView = UIImageView()
        if let image = UIImage(named: "start_car") {
            // 确保使用原始渲染模式
            imageView.image = image.withRenderingMode(.alwaysOriginal)
            imageView.contentMode = .scaleAspectFit
            let imagePadding = (backgroundSize - imageSize) / 2
            imageView.frame = CGRect(x: imagePadding, y: imagePadding, width: imageSize, height: imageSize)
            backgroundView.addSubview(imageView)
        } else {
            // 如果图片加载失败，显示备用文本
            let label = UILabel()
            label.text = "🚗"
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            let imagePadding = (backgroundSize - imageSize) / 2
            label.frame = CGRect(x: imagePadding, y: imagePadding, width: imageSize, height: imageSize)
            backgroundView.addSubview(label)
        }
        
        // 创建标签容器
        let labelContainer = UIView()
        labelContainer.frame = CGRect(x: -15, y: backgroundSize + 2, width: backgroundSize + 30, height: 16)
        
        // 创建"起点"标签
        let label = UILabel()
        label.text = "起点"
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = labelContainer.bounds
        labelContainer.addSubview(label)
        
        // 添加到视图
        addSubview(labelContainer)
        
        // 设置视图大小
        frame = CGRect(x: 0, y: 0, width: backgroundSize, height: backgroundSize + 20)
        
        // 设置锚点（标注点在背景中心）
        centerOffset = CGPoint(x: 0, y: -backgroundSize / 2)
    }
}

// MARK: - MKMapViewDelegate

extension TripDetailViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // 统一使用绿色圆滑渲染器
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemGreen
        renderer.lineWidth = 5
        renderer.lineCap = .round      // 圆滑端点
        renderer.lineJoin = .round     // 圆滑转角
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.title == "起点" {
            let identifier = "StartAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? StartPointAnnotationView
            
            if annotationView == nil {
                annotationView = StartPointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        } else if annotation.title == "终点" {
            let identifier = "EndAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView {
                markerView.markerTintColor = .systemRed
                markerView.glyphText = "🏁"
            }
            
            return annotationView
        }
        
        return nil
    }
}
