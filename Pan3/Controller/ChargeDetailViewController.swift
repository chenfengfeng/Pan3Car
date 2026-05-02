//
//  ChargeDetailViewController.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import UIKit
import MapKit
import DGCharts
import SnapKit

class ChargeDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    private var chargeRecord: ChargeTaskRecord
    private var dataPoints: [ChargeDataPoint] = []
    
    // MARK: - UI Components
    
    private lazy var mapView: MKMapView = {
        let map = MKMapView()
        map.mapType = .standard
        map.showsUserLocation = false
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        return map
    }()
    
    private lazy var chartView: LineChartView = {
        let chart = LineChartView()
        chart.backgroundColor = .systemBackground
        
        // 禁用交互
        chart.dragEnabled = false
        chart.setScaleEnabled(false)
        chart.pinchZoomEnabled = false
        chart.doubleTapToZoomEnabled = false
        chart.highlightPerTapEnabled = false
        chart.highlightPerDragEnabled = false
        
        // 图例配置
        chart.legend.enabled = true
        chart.legend.form = .line
        chart.legend.font = .systemFont(ofSize: 12)
        chart.legend.textColor = .label
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .top
        
        // 描述文字
        chart.chartDescription.enabled = false
        
        // 边距
        chart.extraTopOffset = 20
        chart.extraBottomOffset = 10
        chart.extraLeftOffset = 10
        chart.extraRightOffset = 10
        
        return chart
    }()
    
    private lazy var statsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var statsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()
    
    
    // MARK: - Initialization
    
    init(chargeRecord: ChargeTaskRecord) {
        self.chargeRecord = chargeRecord
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
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupUI()
        loadDataPoints()
        setupMap()
        setupChart()
        setupStats()
        
        // 初始时隐藏图表，等待动画
        chartView.alpha = 0
    }
    
    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBar() {
        // 创建导航按钮
        let navigationButton = UIBarButtonItem(
            image: UIImage(systemName: "location.fill"),
            menu: createNavigationMenu()
        )
        navigationItem.rightBarButtonItem = navigationButton
    }
    
    private func createNavigationMenu() -> UIMenu {
        return UIMenu(title: "选择导航", children: [
            UIAction(title: "高德地图", image: UIImage(systemName: "map.fill")) { [weak self] _ in
                self?.openAMap()
            },
            UIAction(title: "百度地图", image: UIImage(systemName: "map.fill")) { [weak self] _ in
                self?.openBaiduMap()
            },
            UIAction(title: "苹果地图", image: UIImage(systemName: "map.fill")) { [weak self] _ in
                self?.openAppleMaps()
            }
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 延迟执行动画，让页面先显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // 先显示图表
            UIView.animate(withDuration: 0.3) {
                self.chartView.alpha = 1.0
            }
            // 然后执行绘制动画
            self.animateChart()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.addSubview(mapView)
        view.addSubview(chartView)
        view.addSubview(statsContainerView)
        // 先添加statsStackView，后续根据模式动态切换
        statsContainerView.addSubview(statsStackView)
        
        // MapView - 延伸到状态栏顶部（占50%屏幕高度）
        mapView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(view.snp.height).multipliedBy(0.5)
        }
        
        // ChartView - 下半部分，紧贴地图
        chartView.snp.makeConstraints { make in
            make.top.equalTo(mapView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(statsContainerView.snp.top).offset(-8)
        }
        
        // 统计信息容器
        statsContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(70)
        }
        
        statsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }
    
    // MARK: - Map Setup
    
    private func setupMap() {
        // 添加标记点
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(
            latitude: chargeRecord.lat,
            longitude: chargeRecord.lon
        )
        annotation.title = "充电位置"
        annotation.subtitle = chargeRecord.address ?? "未知地址"
        mapView.addAnnotation(annotation)
        
        // 设置地图区域
        let region = MKCoordinateRegion(
            center: annotation.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        mapView.setRegion(region, animated: false)
    }
    
    
    // MARK: - Data Loading
    
    private func loadDataPoints() {
        // 从Core Data获取数据点
        if let points = chargeRecord.dataPoints?.allObjects as? [ChargeDataPoint] {
            dataPoints = points.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
            print("[ChargeDetail] 加载了 \(dataPoints.count) 个数据点")
        }
    }
    
    // MARK: - Chart Setup
    
    private func setupChart() {
        guard !dataPoints.isEmpty else {
            print("[ChargeDetail] 没有数据点，无法绘制图表")
            return
        }
        
        // 判断数据源
        let isDeviceMode = chargeRecord.dataSource == "device"
        
        // 准备数据
        let startTime = dataPoints.first?.timestamp?.timeIntervalSince1970 ?? 0
        
        if isDeviceMode {
            // 车机模式：显示功率线
            setupDeviceModeChart(startTime: startTime)
        } else {
            // 传统轮询模式：显示续航线
            setupJACModeChart(startTime: startTime)
        }
        
        // 配置坐标轴（两种模式都使用SOC和续航作为基点）
        configureAxes(isDeviceMode: isDeviceMode)
    }
    
    private func setupJACModeChart(startTime: TimeInterval) {
        // 传统轮询模式：显示续航轨迹线
        var rangeEntries: [ChartDataEntry] = []
        
        for point in dataPoints {
            let timeOffset = (point.timestamp?.timeIntervalSince1970 ?? 0) - startTime
            let minutes = timeOffset / 60.0
            rangeEntries.append(ChartDataEntry(x: minutes, y: Double(point.remainingRangeKm)))
        }
        
        // 续航数据集
        let rangeDataSet = LineChartDataSet(entries: rangeEntries, label: "续航 (km)")
        configureRangeDataSet(rangeDataSet)
        
        // 设置数据
        let data = LineChartData(dataSets: [rangeDataSet])
        chartView.data = data
    }
    
    private func setupDeviceModeChart(startTime: TimeInterval) {
        // 车机模式：显示功率线
        var powerEntries: [ChartDataEntry] = []
        
        for point in dataPoints {
            let timeOffset = (point.timestamp?.timeIntervalSince1970 ?? 0) - startTime
            let minutes = timeOffset / 60.0
            powerEntries.append(ChartDataEntry(x: minutes, y: point.power))
        }
        
        // 功率数据集
        let powerDataSet = LineChartDataSet(entries: powerEntries, label: "功率 (kW)")
        configurePowerDataSet(powerDataSet)
        
        // 设置数据
        let data = LineChartData(dataSets: [powerDataSet])
        chartView.data = data
    }
    
    private func configureSocDataSet(_ dataSet: LineChartDataSet) {
        // 圆滑曲线 - 数据点少时降低平滑度
        dataSet.mode = .cubicBezier
        let smoothness: CGFloat = dataPoints.count < 10 ? 0.1 : 0.25
        dataSet.cubicIntensity = smoothness
        
        // 线条样式
        dataSet.lineWidth = 3.0
        dataSet.colors = [.systemGreen]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        
        // 渐变填充
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        let gradientColors = [
            UIColor.systemGreen.withAlphaComponent(0.5).cgColor,
            UIColor.systemGreen.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let colorLocations: [CGFloat] = [1.0, 0.0]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors,
            locations: colorLocations
        ) {
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        }
        
        // 禁用高亮
        dataSet.highlightEnabled = false
        
        // 使用左轴
        dataSet.axisDependency = .left
    }
    
    private func configureRangeDataSet(_ dataSet: LineChartDataSet) {
        // 圆滑曲线 - 数据点少时降低平滑度
        dataSet.mode = .cubicBezier
        let smoothness: CGFloat = dataPoints.count < 10 ? 0.1 : 0.25
        dataSet.cubicIntensity = smoothness
        
        // 线条样式
        dataSet.lineWidth = 3.0
        dataSet.colors = [.systemOrange]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        
        // 渐变填充
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        let gradientColors = [
            UIColor.systemOrange.withAlphaComponent(0.5).cgColor,
            UIColor.systemOrange.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let colorLocations: [CGFloat] = [1.0, 0.0]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors,
            locations: colorLocations
        ) {
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        }
        
        // 禁用高亮
        dataSet.highlightEnabled = false
        
        // 使用右轴（续航）
        dataSet.axisDependency = .right
    }
    
    private func configurePowerDataSet(_ dataSet: LineChartDataSet) {
        // 圆滑曲线 - 数据点少时降低平滑度
        dataSet.mode = .cubicBezier
        let smoothness: CGFloat = dataPoints.count < 10 ? 0.1 : 0.25
        dataSet.cubicIntensity = smoothness
        
        // 线条样式
        dataSet.lineWidth = 3.0
        dataSet.colors = [.systemBlue]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        
        // 渐变填充
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        let gradientColors = [
            UIColor.systemBlue.withAlphaComponent(0.5).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let colorLocations: [CGFloat] = [1.0, 0.0]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors,
            locations: colorLocations
        ) {
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        }
        
        // 禁用高亮
        dataSet.highlightEnabled = false
        
        // 使用右轴（功率值会映射到右轴范围）
        dataSet.axisDependency = .right
    }
    
    private func configureAxes(isDeviceMode: Bool) {
        // X轴（时间）
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = true
        xAxis.gridLineWidth = 0.5
        xAxis.gridColor = .systemGray5
        xAxis.labelFont = .systemFont(ofSize: 11)
        xAxis.labelTextColor = .secondaryLabel
        xAxis.valueFormatter = TimeAxisValueFormatter()
        xAxis.granularity = 10 // 每10分钟一个标签
        
        // Y轴左（SOC%）- 两种模式都显示
        let leftAxis = chartView.leftAxis
        leftAxis.enabled = true
        leftAxis.labelFont = .systemFont(ofSize: 12, weight: .medium)
        leftAxis.labelTextColor = .systemGreen
        leftAxis.axisMinimum = Double(chargeRecord.startSoc) - 5
        leftAxis.axisMaximum = Double(chargeRecord.endSoc) + 5
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = .systemGray6
        leftAxis.valueFormatter = PercentAxisValueFormatter()
        
        // Y轴右
        let rightAxis = chartView.rightAxis
        rightAxis.enabled = true
        rightAxis.drawGridLinesEnabled = false
        
        if isDeviceMode {
            // 车机模式：右轴显示功率范围（功率线使用右轴）
            rightAxis.labelFont = .systemFont(ofSize: 12)
            rightAxis.labelTextColor = .systemBlue
            // 计算功率范围
            let powerValues = dataPoints.map { $0.power }
            let minPower = powerValues.min() ?? 0
            let maxPower = powerValues.max() ?? 0
            rightAxis.axisMinimum = max(0, minPower - 2)
            rightAxis.axisMaximum = maxPower + 2
            rightAxis.valueFormatter = PowerAxisValueFormatter()
        } else {
            // JAC模式：右轴显示续航范围
            rightAxis.labelFont = .systemFont(ofSize: 12)
            rightAxis.labelTextColor = .systemOrange
            rightAxis.axisMinimum = Double(chargeRecord.startKm) - 10
            rightAxis.axisMaximum = Double(chargeRecord.endKm) + 10
            rightAxis.valueFormatter = RangeAxisValueFormatter()
        }
    }
    
    private func animateChart() {
        // 根据数据点数量调整动画时长
        let duration = dataPoints.count < 10 ? 1.2 : 2.0
        
        // 从左到右绘制动画 + 轻微的Y轴弹性效果
        chartView.animate(
            xAxisDuration: duration,
            yAxisDuration: duration * 0.6,
            easingOptionX: .easeInOutCubic,
            easingOptionY: .easeOutBack
        )
    }
    
    // MARK: - Stats Setup
    
    private func setupStats() {
        // 判断数据源
        let isDeviceMode = chargeRecord.dataSource == "device"
        
        // 计算统计数据
        let socGain = chargeRecord.endSoc - chargeRecord.startSoc
        let rangeGain = chargeRecord.endKm - chargeRecord.startKm
        let duration = chargeRecord.chargeDuration
        
        if isDeviceMode {
            // 车机模式：显示4个数据项
            setupDeviceModeStats(socGain: socGain, rangeGain: rangeGain, duration: duration)
        } else {
            // 传统轮询模式：显示3个数据项
            setupJACModeStats(socGain: socGain, rangeGain: rangeGain, duration: duration)
        }
    }
    
    private func setupJACModeStats(socGain: Int16, rangeGain: Int64, duration: String) {
        // 传统轮询模式：3个数据项，单行显示
        
        let socStat = createStatView(
            icon: "bolt.fill",
            iconColor: .systemGreen,
            title: "SOC增加",
            value: "+\(socGain)%"
        )
        
        let rangeStat = createStatView(
            icon: "speedometer",
            iconColor: .systemOrange,
            title: "续航增加",
            value: "+\(rangeGain) km"
        )
        
        let timeStat = createStatView(
            icon: "clock.fill",
            iconColor: .systemBlue,
            title: "充电时长",
            value: duration
        )
        
        // 清除旧视图
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        statsStackView.addArrangedSubview(socStat)
        statsStackView.addArrangedSubview(rangeStat)
        statsStackView.addArrangedSubview(timeStat)
    }
    
    private func setupDeviceModeStats(socGain: Int16, rangeGain: Int64, duration: String) {
        // 车机模式：4个数据项，单行显示
        
        // 计算电量增加（度电）
        let energyGain = calculateEnergyGain()
        
        let socStat = createStatView(
            icon: "bolt.fill",
            iconColor: .systemGreen,
            title: "SOC增加",
            value: "+\(socGain)%"
        )
        
        let energyStat = createStatView(
            icon: "battery.100",
            iconColor: .systemBlue,
            title: "电量增加",
            value: "+\(String(format: "%.2f", energyGain))度电"
        )
        
        let rangeStat = createStatView(
            icon: "speedometer",
            iconColor: .systemOrange,
            title: "续航增加",
            value: "+\(rangeGain) km"
        )
        
        let timeStat = createStatView(
            icon: "clock.fill",
            iconColor: .systemPurple,
            title: "充电时长",
            value: duration
        )
        
        // 清除旧视图
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        statsStackView.addArrangedSubview(socStat)
        statsStackView.addArrangedSubview(energyStat)
        statsStackView.addArrangedSubview(rangeStat)
        statsStackView.addArrangedSubview(timeStat)
    }
    
    /// 计算电量增加（度电）- 累加功率×时间间隔
    private func calculateEnergyGain() -> Double {
        guard dataPoints.count >= 2 else { return 0.0 }
        
        var totalEnergy: Double = 0.0
        
        for i in 0..<(dataPoints.count - 1) {
            let currentPoint = dataPoints[i]
            let nextPoint = dataPoints[i + 1]
            
            guard let currentTime = currentPoint.timestamp,
                  let nextTime = nextPoint.timestamp else {
                continue
            }
            
            // 计算时间间隔（小时）
            let timeIntervalHours = nextTime.timeIntervalSince(currentTime) / 3600.0
            
            // 使用平均功率
            let avgPower = (currentPoint.power + nextPoint.power) / 2.0
            
            // 累加能量：功率(kW) × 时间(小时) = 能量(kWh)
            totalEnergy += avgPower * timeIntervalHours
        }
        
        return max(0.0, totalEnergy)
    }
    
    private func createStatView(icon: String, iconColor: UIColor, title: String, value: String) -> UIView {
        let container = UIView()
        
        // 图标
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1
        
        // 第一行：图标 + 标题
        let topStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        topStack.axis = .horizontal
        topStack.spacing = 4
        topStack.alignment = .center
        
        // 数值
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        
        // 整体垂直布局：第一行（图标+标题）+ 第二行（数值）
        let stack = UIStackView(arrangedSubviews: [topStack, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        iconView.snp.makeConstraints { make in
            make.height.width.equalTo(20)
        }
        
        return container
    }
    
    // MARK: - Navigation Methods
    
    private func openAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: chargeRecord.lat, longitude: chargeRecord.lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = chargeRecord.address ?? "充电位置"
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func openAMap() {
        let name = chargeRecord.address ?? "充电位置"
        let urlString = "iosamap://navi?sourceApplication=Pan3&poiname=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&poiid=BGVIS&lat=\(chargeRecord.lat)&lon=\(chargeRecord.lon)&dev=0&style=2"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/id461703208") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    private func openBaiduMap() {
        let name = chargeRecord.address ?? "充电位置"
        let convertedCoordinate = convertGCJ02ToBD09(lat: chargeRecord.lat, lon: chargeRecord.lon)
        let urlString = "baidumap://map/direction?destination=latlng:\(convertedCoordinate.lat),\(convertedCoordinate.lon)|name:\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mode=driving&src=Pan3"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/id452186370") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    private func convertGCJ02ToBD09(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        let x = lon
        let y = lat
        let z = sqrt(x * x + y * y) + 0.00002 * sin(y * Double.pi)
        let theta = atan2(y, x) + 0.000003 * cos(x * Double.pi)
        let bdLon = z * cos(theta) + 0.0065
        let bdLat = z * sin(theta) + 0.006
        return (lat: bdLat, lon: bdLon)
    }
}


// MARK: - Custom Value Formatters

class TimeAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let minutes = Int(value)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return String(format: "%dh%02dm", hours, mins)
        } else {
            return String(format: "%dm", mins)
        }
    }
}

class PercentAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return String(format: "%.0f%%", value)
    }
}

class RangeAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return String(format: "%.0fkm", value)
    }
}

class PowerAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return String(format: "%.1fkW", value)
    }
}

