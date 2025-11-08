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
            make.height.equalTo(100)
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
        
        // 准备数据
        var socEntries: [ChartDataEntry] = []
        var rangeEntries: [ChartDataEntry] = []
        
        let startTime = dataPoints.first?.timestamp?.timeIntervalSince1970 ?? 0
        
        for (_, point) in dataPoints.enumerated() {
            let timeOffset = (point.timestamp?.timeIntervalSince1970 ?? 0) - startTime
            let minutes = timeOffset / 60.0
            
            socEntries.append(ChartDataEntry(x: minutes, y: Double(point.soc)))
            rangeEntries.append(ChartDataEntry(x: minutes, y: Double(point.remainingRangeKm)))
        }
        
        // SOC数据集（主曲线）
        let socDataSet = LineChartDataSet(entries: socEntries, label: "电量 (%)")
        configureSocDataSet(socDataSet)
        
        // 续航数据集（辅助曲线）
        let rangeDataSet = LineChartDataSet(entries: rangeEntries, label: "续航 (km)")
        configureRangeDataSet(rangeDataSet)
        
        // 设置数据
        let data = LineChartData(dataSets: [socDataSet, rangeDataSet])
        chartView.data = data
        
        // 配置坐标轴
        configureAxes()
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
        dataSet.lineWidth = 2.0
        dataSet.colors = [.systemOrange]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawFilledEnabled = false
        
        // 禁用高亮
        dataSet.highlightEnabled = false
        
        // 使用右轴
        dataSet.axisDependency = .right
    }
    
    private func configureAxes() {
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
        
        // Y轴左（SOC%）
        let leftAxis = chartView.leftAxis
        leftAxis.labelFont = .systemFont(ofSize: 12, weight: .medium)
        leftAxis.labelTextColor = .systemGreen
        leftAxis.axisMinimum = Double(chargeRecord.startSoc) - 5
        leftAxis.axisMaximum = Double(chargeRecord.endSoc) + 5
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = .systemGray6
        leftAxis.valueFormatter = PercentAxisValueFormatter()
        
        // Y轴右（续航km）
        let rightAxis = chartView.rightAxis
        rightAxis.enabled = true
        rightAxis.labelFont = .systemFont(ofSize: 12)
        rightAxis.labelTextColor = .systemOrange
        rightAxis.axisMinimum = Double(chargeRecord.startKm) - 10
        rightAxis.axisMaximum = Double(chargeRecord.endKm) + 10
        rightAxis.drawGridLinesEnabled = false
        rightAxis.valueFormatter = RangeAxisValueFormatter()
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
        // 计算统计数据
        let socGain = chargeRecord.endSoc - chargeRecord.startSoc
        let rangeGain = chargeRecord.endKm - chargeRecord.startKm
        let duration = chargeRecord.chargeDuration
        
        // 创建统计项
        let socStat = createStatView(
            icon: "bolt.fill",
            iconColor: .systemGreen,
            title: "SOC增加",
            value: "\(chargeRecord.startSoc)% → \(chargeRecord.endSoc)%",
            subtitle: "+\(socGain)%"
        )
        
        let rangeStat = createStatView(
            icon: "speedometer",
            iconColor: .systemOrange,
            title: "续航增加",
            value: "+\(rangeGain) km",
            subtitle: "\(chargeRecord.startKm) → \(chargeRecord.endKm)"
        )
        
        let timeStat = createStatView(
            icon: "clock.fill",
            iconColor: .systemBlue,
            title: "充电时长",
            value: duration,
            subtitle: dataPoints.isEmpty ? "" : "\(dataPoints.count) 个数据点"
        )
        
        statsStackView.addArrangedSubview(socStat)
        statsStackView.addArrangedSubview(rangeStat)
        statsStackView.addArrangedSubview(timeStat)
    }
    
    private func createStatView(icon: String, iconColor: UIColor, title: String, value: String, subtitle: String) -> UIView {
        let container = UIView()
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 0
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, valueLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.alignment = .center
        
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        iconView.snp.makeConstraints { make in
            make.height.width.equalTo(24)
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

