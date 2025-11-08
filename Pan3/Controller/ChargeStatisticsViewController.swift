//
//  ChargeStatisticsViewController.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import UIKit
import DGCharts
import SnapKit
import CoreData
import CoreLocation

class ChargeStatisticsViewController: UIViewController {
    
    // MARK: - Properties
    
    private var allChargeRecords: [ChargeTaskRecord] = []
    private var filteredRecords: [ChargeTaskRecord] = []
    
    private enum TimeFilter: String {
        case thisMonth = "本月"
        case thisYear = "本年"
        case all = "全部"
    }
    
    private var currentFilter: TimeFilter = .thisMonth
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = true
        scroll.alwaysBounceVertical = true
        return scroll
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    // 顶部筛选器
    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = currentFilter.rawValue
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemGray5
        config.baseForegroundColor = .label
        button.configuration = config
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    // 总览卡片容器
    private lazy var overviewStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()
    
    // 趋势图表容器
    private lazy var trendChartContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var trendChartTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "📈 充电趋势（按月）"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    // 趋势图表
    private lazy var trendChartView: BarChartView = {
        let chart = BarChartView()
        chart.backgroundColor = .clear
        chart.chartDescription.enabled = false
        chart.legend.enabled = false
        chart.dragEnabled = false
        chart.setScaleEnabled(false)
        chart.pinchZoomEnabled = false
        chart.highlightPerTapEnabled = false
        return chart
    }()
    
    // 时段分布图容器
    private lazy var timeDistributionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var timeDistributionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "🕐 充电时段分布"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    // 时段分布图
    private lazy var timeDistributionChartView: PieChartView = {
        let chart = PieChartView()
        chart.backgroundColor = .clear
        chart.chartDescription.enabled = false
        chart.legend.enabled = true
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .bottom
        chart.legend.font = .systemFont(ofSize: 12)
        chart.holeRadiusPercent = 0.5
        chart.transparentCircleRadiusPercent = 0.55
        chart.drawEntryLabelsEnabled = false
        return chart
    }()
    
    // 常用地点卡片
    private lazy var topLocationsView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    // 充电效率卡片
    private lazy var efficiencyView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "充电统计"
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupUI()
        loadData()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        // 分享按钮
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        navigationItem.rightBarButtonItem = shareButton
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        // 添加子视图
        contentView.addSubview(filterButton)
        contentView.addSubview(overviewStackView)
        contentView.addSubview(trendChartContainerView)
        trendChartContainerView.addSubview(trendChartTitleLabel)
        trendChartContainerView.addSubview(trendChartView)
        contentView.addSubview(timeDistributionContainerView)
        timeDistributionContainerView.addSubview(timeDistributionTitleLabel)
        timeDistributionContainerView.addSubview(timeDistributionChartView)
        contentView.addSubview(topLocationsView)
        contentView.addSubview(efficiencyView)
        
        // 布局
        filterButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(36)
            make.width.greaterThanOrEqualTo(120)
        }
        
        overviewStackView.snp.makeConstraints { make in
            make.top.equalTo(filterButton.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(110)
        }
        
        trendChartContainerView.snp.makeConstraints { make in
            make.top.equalTo(overviewStackView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(280)
        }
        
        trendChartTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        trendChartView.snp.makeConstraints { make in
            make.top.equalTo(trendChartTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        
        timeDistributionContainerView.snp.makeConstraints { make in
            make.top.equalTo(trendChartContainerView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(310)
        }
        
        timeDistributionTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        timeDistributionChartView.snp.makeConstraints { make in
            make.top.equalTo(timeDistributionTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        
        topLocationsView.snp.makeConstraints { make in
            make.top.equalTo(timeDistributionContainerView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.greaterThanOrEqualTo(150)
        }
        
        efficiencyView.snp.makeConstraints { make in
            make.top.equalTo(topLocationsView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.greaterThanOrEqualTo(120)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        setupFilterMenu()
    }
    
    private func setupFilterMenu() {
        let menu = UIMenu(title: "选择时间范围", children: [
            UIAction(title: "本月", state: currentFilter == .thisMonth ? .on : .off) { [weak self] _ in
                self?.filterChanged(to: .thisMonth)
            },
            UIAction(title: "本年", state: currentFilter == .thisYear ? .on : .off) { [weak self] _ in
                self?.filterChanged(to: .thisYear)
            },
            UIAction(title: "全部", state: currentFilter == .all ? .on : .off) { [weak self] _ in
                self?.filterChanged(to: .all)
            }
        ])
        filterButton.menu = menu
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        // 从Core Data加载所有充电记录
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
        request.predicate = NSPredicate(format: "endTime != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        do {
            allChargeRecords = try context.fetch(request)
            print("[统计] 加载了 \(allChargeRecords.count) 条充电记录")
            filterRecords()
        } catch {
            print("[统计] 加载充电记录失败: \(error)")
            allChargeRecords = []
            filteredRecords = []
        }
    }
    
    private func filterRecords() {
        let calendar = Calendar.current
        let now = Date()
        
        switch currentFilter {
        case .thisMonth:
            filteredRecords = allChargeRecords.filter { record in
                calendar.isDate(record.startTime, equalTo: now, toGranularity: .month)
            }
        case .thisYear:
            filteredRecords = allChargeRecords.filter { record in
                calendar.isDate(record.startTime, equalTo: now, toGranularity: .year)
            }
        case .all:
            filteredRecords = allChargeRecords
        }
        
        print("[统计] 筛选后: \(filteredRecords.count) 条记录")
        updateUI()
    }
    
    // MARK: - UI Update
    
    private func updateUI() {
        setupOverviewCards()
        setupTrendChart()
        setupTimeDistributionChart()
        setupTopLocations()
        setupEfficiencyAnalysis()
    }
    
    private func setupOverviewCards() {
        // 清空现有卡片
        overviewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 计算统计数据
        let totalCount = filteredRecords.count
        let totalEnergy = filteredRecords.reduce(0.0) { result, record in
            let socGain = Double(record.endSoc - record.startSoc)
            let batteryCapacity = 34.5 // 简化处理，实际应根据车型
            return result + (socGain / 100.0 * batteryCapacity)
        }
        
        let totalDuration = filteredRecords.compactMap { record -> TimeInterval? in
            guard let endTime = record.endTime else { return nil }
            return endTime.timeIntervalSince(record.startTime)
        }.reduce(0, +)
        let avgDuration = totalCount > 0 ? totalDuration / Double(totalCount) / 3600.0 : 0
        
        // 创建卡片
        let countCard = createOverviewCard(
            icon: "bolt.fill",
            iconColor: .systemBlue,
            value: "\(totalCount)",
            unit: "次",
            title: "总次数"
        )
        
        let energyCard = createOverviewCard(
            icon: "battery.100",
            iconColor: .systemGreen,
            value: String(format: "%.0f", totalEnergy),
            unit: "kWh",
            title: "总电量"
        )
        
        let durationCard = createOverviewCard(
            icon: "clock.fill",
            iconColor: .systemOrange,
            value: String(format: "%.1f", avgDuration),
            unit: "小时",
            title: "平均时长"
        )
        
        overviewStackView.addArrangedSubview(countCard)
        overviewStackView.addArrangedSubview(energyCard)
        overviewStackView.addArrangedSubview(durationCard)
    }
    
    private func createOverviewCard(icon: String, iconColor: UIColor, value: String, unit: String, title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        
        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = .label
        
        let unitLabel = UILabel()
        unitLabel.font = .systemFont(ofSize: 14, weight: .medium)
        unitLabel.textColor = .secondaryLabel
        
        let valueStack = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        valueStack.axis = .horizontal
        valueStack.spacing = 4
        valueStack.alignment = .lastBaseline
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .tertiaryLabel
        titleLabel.textAlignment = .center
        
        // 设置数值
        valueLabel.text = value
        unitLabel.text = unit
        
        container.addSubview(iconView)
        container.addSubview(valueStack)
        container.addSubview(titleLabel)
        
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(28)
        }
        
        valueStack.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(valueStack.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(8)
        }
        
        return container
    }
    
    private func setupTrendChart() {
        // 按月统计充电次数
        let calendar = Calendar.current
        var monthlyData: [String: Int] = [:]
        
        for record in filteredRecords {
            let month = calendar.component(.month, from: record.startTime)
            let year = calendar.component(.year, from: record.startTime)
            let key = "\(year)-\(String(format: "%02d", month))"
            monthlyData[key, default: 0] += 1
        }
        
        // 排序并准备图表数据
        let sortedKeys = monthlyData.keys.sorted()
        let entries = sortedKeys.enumerated().map { index, key -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(index), y: Double(monthlyData[key] ?? 0))
        }
        
        if entries.isEmpty {
            // 显示空状态
            trendChartView.data = nil
            trendChartView.noDataText = "暂无充电数据"
            trendChartView.noDataFont = .systemFont(ofSize: 14)
            trendChartView.noDataTextColor = .secondaryLabel
            return
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "充电次数")
        dataSet.colors = [.systemGreen]
        dataSet.valueFont = .systemFont(ofSize: 10)
        dataSet.valueFormatter = DefaultValueFormatter(decimals: 0)
        
        let data = BarChartData(dataSet: dataSet)
        trendChartView.data = data
        
        // 配置X轴
        trendChartView.xAxis.labelPosition = .bottom
        trendChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: sortedKeys.map { key in
            let components = key.split(separator: "-")
            return String(components.last ?? "")
        })
        trendChartView.xAxis.granularity = 1
        trendChartView.xAxis.labelFont = .systemFont(ofSize: 10)
        
        // 配置Y轴
        trendChartView.leftAxis.axisMinimum = 0
        trendChartView.rightAxis.enabled = false
        
        trendChartView.animate(yAxisDuration: 1.0, easingOption: .easeOutBack)
    }
    
    private func setupTimeDistributionChart() {
        // 统计各时段充电次数
        var timeSlots: [String: Int] = [
            "深夜 00-06": 0,
            "上午 06-12": 0,
            "下午 12-18": 0,
            "夜间 18-24": 0
        ]
        
        let calendar = Calendar.current
        for record in filteredRecords {
            let hour = calendar.component(.hour, from: record.startTime)
            switch hour {
            case 0..<6:
                timeSlots["深夜 00-06"]! += 1
            case 6..<12:
                timeSlots["上午 06-12"]! += 1
            case 12..<18:
                timeSlots["下午 12-18"]! += 1
            default:
                timeSlots["夜间 18-24"]! += 1
            }
        }
        
        let entries = timeSlots.map { key, value -> PieChartDataEntry in
            return PieChartDataEntry(value: Double(value), label: key)
        }.filter { $0.value > 0 }
        
        if entries.isEmpty {
            timeDistributionChartView.data = nil
            timeDistributionChartView.noDataText = "暂无充电数据"
            timeDistributionChartView.noDataFont = .systemFont(ofSize: 14)
            timeDistributionChartView.noDataTextColor = .secondaryLabel
            return
        }
        
        let dataSet = PieChartDataSet(entries: entries, label: "")
        dataSet.colors = [
            .systemPurple,
            .systemYellow,
            .systemOrange,
            .systemIndigo
        ]
        dataSet.valueFont = .systemFont(ofSize: 12, weight: .medium)
        dataSet.valueTextColor = .white
        dataSet.valueFormatter = DefaultValueFormatter(decimals: 0)
        
        let data = PieChartData(dataSet: dataSet)
        timeDistributionChartView.data = data
        timeDistributionChartView.animate(xAxisDuration: 1.0, easingOption: .easeOutBack)
    }
    
    private func setupTopLocations() {
        // 清空现有内容
        topLocationsView.subviews.forEach { $0.removeFromSuperview() }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "📍 常用充电地点 TOP 3"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        topLocationsView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        // 地址聚合（100米范围）
        let clusteredLocations = clusterLocations(records: filteredRecords, radius: 100)
        let sortedLocations = clusteredLocations.sorted { $0.count > $1.count }.prefix(3)
        
        if sortedLocations.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "暂无充电地点数据"
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.textAlignment = .center
            topLocationsView.addSubview(emptyLabel)
            
            emptyLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(16)
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().offset(-16)
            }
            return
        }
        
        var lastView: UIView = titleLabel
        
        for (index, location) in sortedLocations.enumerated() {
            let locationView = createLocationRow(
                rank: index + 1,
                address: location.address,
                count: location.count
            )
            topLocationsView.addSubview(locationView)
            
            locationView.snp.makeConstraints { make in
                make.top.equalTo(lastView.snp.bottom).offset(12)
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(40)
                
                if index == sortedLocations.count - 1 {
                    make.bottom.equalToSuperview().offset(-16)
                }
            }
            
            lastView = locationView
        }
    }
    
    private func createLocationRow(rank: Int, address: String, count: Int) -> UIView {
        let container = UIView()
        
        let rankLabel = UILabel()
        rankLabel.text = "\(rank)"
        rankLabel.font = .systemFont(ofSize: 18, weight: .bold)
        rankLabel.textColor = rank == 1 ? .systemYellow : (rank == 2 ? .systemGray : .systemGray2)
        rankLabel.textAlignment = .center
        
        let addressLabel = UILabel()
        addressLabel.text = address
        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .label
        
        let countLabel = UILabel()
        countLabel.text = "\(count)次"
        countLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countLabel.textColor = .secondaryLabel
        
        container.addSubview(rankLabel)
        container.addSubview(addressLabel)
        container.addSubview(countLabel)
        
        rankLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(30)
        }
        
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(rankLabel.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(countLabel.snp.leading).offset(-12)
        }
        
        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(50)
        }
        
        return container
    }
    
    private func setupEfficiencyAnalysis() {
        // 清空现有内容
        efficiencyView.subviews.forEach { $0.removeFromSuperview() }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "⚡ 充电效率分析"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        efficiencyView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        // 计算统计数据
        let avgStartSoc = filteredRecords.isEmpty ? 0 : filteredRecords.reduce(0) { $0 + Int($1.startSoc) } / filteredRecords.count
        let avgEndSoc = filteredRecords.isEmpty ? 0 : filteredRecords.reduce(0) { $0 + Int($1.endSoc) } / filteredRecords.count
        
        // 计算平均充电速度
        var totalSpeed = 0.0
        var validCount = 0
        for record in filteredRecords {
            guard let endTime = record.endTime else { continue }
            let duration = endTime.timeIntervalSince(record.startTime) / 3600.0 // 小时
            if duration > 0 {
                let socGain = Double(record.endSoc - record.startSoc)
                totalSpeed += socGain / duration
                validCount += 1
            }
        }
        let avgSpeed = validCount > 0 ? totalSpeed / Double(validCount) : 0
        
        // 找最快充电
        var fastestCharge: (soc: Int, duration: String) = (0, "")
        var maxSpeed = 0.0
        for record in filteredRecords {
            guard let endTime = record.endTime else { continue }
            let duration = endTime.timeIntervalSince(record.startTime) / 60.0 // 分钟
            if duration > 0 {
                let socGain = Double(record.endSoc - record.startSoc)
                let speed = socGain / (duration / 60.0)
                if speed > maxSpeed {
                    maxSpeed = speed
                    fastestCharge = (Int(socGain), String(format: "%.0f分钟", duration))
                }
            }
        }
        
        // 创建数据行
        let data = [
            ("平均充电速度", String(format: "%.1f%% / 小时", avgSpeed)),
            ("最快充电", "\(fastestCharge.soc)% (\(fastestCharge.duration))"),
            ("平均起始SOC", "\(avgStartSoc)%"),
            ("平均结束SOC", "\(avgEndSoc)%")
        ]
        
        var lastView: UIView = titleLabel
        
        for (label, value) in data {
            let rowView = createDataRow(label: label, value: value)
            efficiencyView.addSubview(rowView)
            
            rowView.snp.makeConstraints { make in
                make.top.equalTo(lastView.snp.bottom).offset(12)
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(24)
            }
            
            lastView = rowView
        }
        
        lastView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
    private func createDataRow(label: String, value: String) -> UIView {
        let container = UIView()
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        labelView.textColor = .secondaryLabel
        
        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 14, weight: .medium)
        valueView.textColor = .label
        valueView.textAlignment = .right
        
        container.addSubview(labelView)
        container.addSubview(valueView)
        
        labelView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        valueView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        
        return container
    }
    
    // MARK: - Location Clustering
    
    struct LocationCluster {
        var centerLat: Double
        var centerLon: Double
        var address: String
        var count: Int
    }
    
    /// 将充电地点聚合（100米范围内算同一个地点）
    private func clusterLocations(records: [ChargeTaskRecord], radius: Double) -> [LocationCluster] {
        var clusters: [LocationCluster] = []
        
        for record in records {
            guard record.lat != 0, record.lon != 0 else { continue }
            
            // 查找是否有邻近的聚类
            var found = false
            for i in 0..<clusters.count {
                let distance = calculateDistance(
                    lat1: record.lat,
                    lon1: record.lon,
                    lat2: clusters[i].centerLat,
                    lon2: clusters[i].centerLon
                )
                
                if distance <= radius {
                    // 更新聚类
                    clusters[i].count += 1
                    // 优先使用最常见的地址
                    found = true
                    break
                }
            }
            
            // 如果没有找到邻近聚类，创建新的
            if !found {
                clusters.append(LocationCluster(
                    centerLat: record.lat,
                    centerLon: record.lon,
                    address: record.address ?? "未知地点",
                    count: 1
                ))
            }
        }
        
        return clusters
    }
    
    /// 计算两点之间的距离（米）
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2)
    }
    
    // MARK: - Actions
    
    private func filterChanged(to filter: TimeFilter) {
        currentFilter = filter
        var config = filterButton.configuration
        config?.title = filter.rawValue
        filterButton.configuration = config
        
        setupFilterMenu()
        filterRecords()
    }
    
    @objc private func shareTapped() {
        // 截取整个统计页面
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
    
    /// 截取整个统计页面为图片
    private func captureScreenshot() -> UIImage? {
        // 确保所有视图都已布局完成
        view.layoutIfNeeded()
        contentView.layoutIfNeeded()
        scrollView.layoutIfNeeded()
        
        // 获取内容视图的实际大小（确保包含所有内容）
        let contentSize = contentView.bounds.size
        let screenBounds = UIScreen.main.bounds
        
        // 边距设置
        let padding: CGFloat = 20
        let bottomPadding: CGFloat = 60 // 底部留更多空间给文字
        
        // 先计算内容区域大小
        let contentWidth = max(contentSize.width, screenBounds.width)
        let contentHeight = max(contentSize.height, scrollView.contentSize.height)
        
        // 计算最终图片大小（包含边距和底部文字区域）
        let finalWidth = contentWidth + padding * 2
        let finalHeight = contentHeight + padding + bottomPadding
        
        // 使用高分辨率渲染
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: finalWidth, height: finalHeight))
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. 绘制渐变背景
            drawGradientBackground(in: cgContext, size: CGSize(width: finalWidth, height: finalHeight))
            
            // 2. 保存当前的scrollView偏移量
            let savedOffset = scrollView.contentOffset
            
            // 3. 临时设置scrollView到顶部
            scrollView.contentOffset = .zero
            scrollView.layoutIfNeeded()
            
            // 4. 绘制内容视图（在边距内，带圆角）
            cgContext.saveGState()
            cgContext.translateBy(x: padding, y: padding)
            
            // 创建圆角矩形路径
            let cornerRadius: CGFloat = 16
            let contentRect = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            let roundedPath = UIBezierPath(
                roundedRect: contentRect,
                cornerRadius: cornerRadius
            ).cgPath
            
            // 裁剪到圆角矩形
            cgContext.addPath(roundedPath)
            cgContext.clip()
            
            // 绘制白色/系统背景色作为内容背景
            UIColor.systemBackground.setFill()
            cgContext.fill(contentRect)
            
            // 绘制contentView
            let contentFrame = contentView.frame
            cgContext.translateBy(x: -contentFrame.origin.x, y: -contentFrame.origin.y)
            contentView.layer.render(in: cgContext)
            
            cgContext.restoreGState()
            
            // 5. 恢复scrollView偏移量
            scrollView.contentOffset = savedOffset
            
            // 6. 绘制底部文字 "胖3助手"
            drawAppNameText(in: cgContext, size: CGSize(width: finalWidth, height: finalHeight), bottomPadding: bottomPadding)
        }
        
        return image
    }
    
    /// 绘制渐变背景
    private func drawGradientBackground(in context: CGContext, size: CGSize) {
        // 创建渐变（多色）
        let colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor,
            UIColor.systemPink.cgColor,
            UIColor.systemOrange.cgColor
        ]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 0.33, 0.66, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: colorLocations) else {
            // 如果创建渐变失败，使用单一背景色
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            return
        }
        
        // 从左上到右下绘制渐变
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: size.width, y: size.height)
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
    }
    
    /// 绘制底部App名称文字
    private func drawAppNameText(in context: CGContext, size: CGSize, bottomPadding: CGFloat) {
        context.saveGState()
        
        let text = "胖3助手"
        let font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        // 计算文字位置（底部居中）
        let textX = (size.width - textSize.width) / 2
        let textY = size.height - bottomPadding + 20 // 距离底部留一定空间
        
        // 添加文字阴影效果（更清晰）
        context.setShadow(
            offset: CGSize(width: 0, height: 1),
            blur: 2,
            color: UIColor.black.withAlphaComponent(0.3).cgColor
        )
        
        // 绘制文字
        attributedString.draw(at: CGPoint(x: textX, y: textY))
        
        context.restoreGState()
    }
}

