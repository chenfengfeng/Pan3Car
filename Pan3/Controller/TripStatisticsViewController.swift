//
//  TripStatisticsViewController.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import UIKit
import DGCharts
import SnapKit
import CoreData

class TripStatisticsViewController: UIViewController {
    
    // MARK: - Properties
    
    private var allTripRecords: [TripRecord] = []
    private var filteredRecords: [TripRecord] = []
    
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
        label.text = "📈 行程趋势（按月）"
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
    
    // 能耗分布图容器
    private lazy var energyDistributionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var energyDistributionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "⚡ 能耗分布"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    // 能耗分布图
    private lazy var energyDistributionChartView: PieChartView = {
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
    
    // 效率分析卡片
    private lazy var efficiencyView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "行程统计"
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
        contentView.addSubview(energyDistributionContainerView)
        energyDistributionContainerView.addSubview(energyDistributionTitleLabel)
        energyDistributionContainerView.addSubview(energyDistributionChartView)
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
        
        energyDistributionContainerView.snp.makeConstraints { make in
            make.top.equalTo(trendChartContainerView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(310)
        }
        
        energyDistributionTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        energyDistributionChartView.snp.makeConstraints { make in
            make.top.equalTo(energyDistributionTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        
        efficiencyView.snp.makeConstraints { make in
            make.top.equalTo(energyDistributionContainerView.snp.bottom).offset(20)
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
        // 从Core Data加载所有行程记录
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<TripRecord> = TripRecord.fetchRequest()
        request.predicate = NSPredicate(format: "endTime != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        do {
            allTripRecords = try context.fetch(request)
            print("[统计] 加载了 \(allTripRecords.count) 条行程记录")
            filterRecords()
        } catch {
            print("[统计] 加载行程记录失败: \(error)")
            allTripRecords = []
            filteredRecords = []
        }
    }
    
    private func filterRecords() {
        let calendar = Calendar.current
        let now = Date()
        
        switch currentFilter {
        case .thisMonth:
            filteredRecords = allTripRecords.filter { record in
                calendar.isDate(record.startTime, equalTo: now, toGranularity: .month)
            }
        case .thisYear:
            filteredRecords = allTripRecords.filter { record in
                calendar.isDate(record.startTime, equalTo: now, toGranularity: .year)
            }
        case .all:
            filteredRecords = allTripRecords
        }
        
        print("[统计] 筛选后: \(filteredRecords.count) 条记录")
        updateUI()
    }
    
    // MARK: - UI Update
    
    private func updateUI() {
        setupOverviewCards()
        setupTrendChart()
        setupEnergyDistributionChart()
        setupEfficiencyAnalysis()
    }
    
    private func setupOverviewCards() {
        // 清空现有卡片
        overviewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 计算统计数据
        let totalCount = filteredRecords.count
        let totalDistance = filteredRecords.reduce(0.0) { $0 + $1.totalDistance }
        let avgSpeed = filteredRecords.isEmpty ? 0 : filteredRecords.reduce(0) { $0 + Int($1.avgSpeed) } / filteredRecords.count
        
        // 创建卡片
        let countCard = createOverviewCard(
            icon: "car.fill",
            iconColor: .systemBlue,
            value: "\(totalCount)",
            unit: "次",
            title: "总次数"
        )
        
        let distanceCard = createOverviewCard(
            icon: "road.lanes",
            iconColor: .systemGreen,
            value: String(format: "%.1f", totalDistance),
            unit: "km",
            title: "总里程"
        )
        
        let speedCard = createOverviewCard(
            icon: "speedometer",
            iconColor: .systemOrange,
            value: "\(avgSpeed)",
            unit: "km/h",
            title: "平均速度"
        )
        
        overviewStackView.addArrangedSubview(countCard)
        overviewStackView.addArrangedSubview(distanceCard)
        overviewStackView.addArrangedSubview(speedCard)
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
        // 按月统计行程次数
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
            trendChartView.data = nil
            trendChartView.noDataText = "暂无行程数据"
            trendChartView.noDataFont = .systemFont(ofSize: 14)
            trendChartView.noDataTextColor = .secondaryLabel
            return
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "行程次数")
        dataSet.colors = [.systemBlue]
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
    
    private func setupEnergyDistributionChart() {
        // 按能耗范围分类
        var ranges: [String: Int] = [
            "优秀 <12": 0,
            "良好 12-15": 0,
            "一般 15-18": 0,
            "较高 >18": 0
        ]
        
        for record in filteredRecords {
            let efficiency = record.energyEfficiency
            if efficiency < 12 {
                ranges["优秀 <12"]! += 1
            } else if efficiency < 15 {
                ranges["良好 12-15"]! += 1
            } else if efficiency < 18 {
                ranges["一般 15-18"]! += 1
            } else {
                ranges["较高 >18"]! += 1
            }
        }
        
        let entries = ranges.map { key, value -> PieChartDataEntry in
            return PieChartDataEntry(value: Double(value), label: key)
        }.filter { $0.value > 0 }
        
        if entries.isEmpty {
            energyDistributionChartView.data = nil
            energyDistributionChartView.noDataText = "暂无能耗数据"
            energyDistributionChartView.noDataFont = .systemFont(ofSize: 14)
            energyDistributionChartView.noDataTextColor = .secondaryLabel
            return
        }
        
        let dataSet = PieChartDataSet(entries: entries, label: "")
        dataSet.colors = [
            .systemGreen,
            .systemYellow,
            .systemOrange,
            .systemRed
        ]
        dataSet.valueFont = .systemFont(ofSize: 12, weight: .medium)
        dataSet.valueTextColor = .white
        dataSet.valueFormatter = DefaultValueFormatter(decimals: 0)
        
        let data = PieChartData(dataSet: dataSet)
        energyDistributionChartView.data = data
        energyDistributionChartView.animate(xAxisDuration: 1.0, easingOption: .easeOutBack)
    }
    
    private func setupEfficiencyAnalysis() {
        // 清空现有内容
        efficiencyView.subviews.forEach { $0.removeFromSuperview() }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "📊 效率分析"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        efficiencyView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        // 计算统计数据
        let avgEnergy = filteredRecords.isEmpty ? 0 : filteredRecords.reduce(0.0) { $0 + $1.energyEfficiency } / Double(filteredRecords.count)
        let avgAchievement = filteredRecords.isEmpty ? 0 : filteredRecords.reduce(0.0) { $0 + $1.achievementRate } / Double(filteredRecords.count)
        let maxSpeed = filteredRecords.map { Int($0.maxSpeed) }.max() ?? 0
        
        // 创建数据行
        let data = [
            ("平均能耗", String(format: "%.2f kWh/100km", avgEnergy)),
            ("平均达成率", String(format: "%.1f%%", avgAchievement)),
            ("最高车速", "\(maxSpeed) km/h")
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
        view.layoutIfNeeded()
        contentView.layoutIfNeeded()
        scrollView.layoutIfNeeded()
        
        let contentSize = contentView.bounds.size
        let screenBounds = UIScreen.main.bounds
        
        let padding: CGFloat = 20
        let bottomPadding: CGFloat = 60
        
        let contentWidth = max(contentSize.width, screenBounds.width)
        let contentHeight = max(contentSize.height, scrollView.contentSize.height)
        
        let finalWidth = contentWidth + padding * 2
        let finalHeight = contentHeight + padding + bottomPadding
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: finalWidth, height: finalHeight))
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            drawGradientBackground(in: cgContext, size: CGSize(width: finalWidth, height: finalHeight))
            
            let savedOffset = scrollView.contentOffset
            scrollView.contentOffset = .zero
            scrollView.layoutIfNeeded()
            
            cgContext.saveGState()
            cgContext.translateBy(x: padding, y: padding)
            
            let cornerRadius: CGFloat = 16
            let contentRect = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            let roundedPath = UIBezierPath(roundedRect: contentRect, cornerRadius: cornerRadius).cgPath
            
            cgContext.addPath(roundedPath)
            cgContext.clip()
            
            UIColor.systemBackground.setFill()
            cgContext.fill(contentRect)
            
            let contentFrame = contentView.frame
            cgContext.translateBy(x: -contentFrame.origin.x, y: -contentFrame.origin.y)
            contentView.layer.render(in: cgContext)
            
            cgContext.restoreGState()
            
            scrollView.contentOffset = savedOffset
            
            drawAppNameText(in: cgContext, size: CGSize(width: finalWidth, height: finalHeight), bottomPadding: bottomPadding)
        }
        
        return image
    }
    
    private func drawGradientBackground(in context: CGContext, size: CGSize) {
        let colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor,
            UIColor.systemPink.cgColor,
            UIColor.systemOrange.cgColor
        ]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 0.33, 0.66, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: colorLocations) else {
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            return
        }
        
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: size.width, y: size.height)
        
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
    }
    
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
        
        let textX = (size.width - textSize.width) / 2
        let textY = size.height - bottomPadding + 20
        
        context.setShadow(
            offset: CGSize(width: 0, height: 1),
            blur: 2,
            color: UIColor.black.withAlphaComponent(0.3).cgColor
        )
        
        attributedString.draw(at: CGPoint(x: textX, y: textY))
        
        context.restoreGState()
    }
}

