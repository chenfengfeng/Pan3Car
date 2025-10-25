//
//  ChargeViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import GRDB
import UIKit
import MapKit
import QMUIKit
import MJRefresh
import SwifterSwift
import CoreLocation

class ChargeViewController: UIViewController {
    private lazy var spaceView: UIView = {
        let view = UIView()
        return view
    }()
    // 顶部里程数据容器视图
    private lazy var mileageHeaderView: MileageView = {
        let view = MileageView()
        return view
    }()
    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.delegate = self
        view.dataSource = self
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.estimatedRowHeight = 160
        view.rowHeight = UITableView.automaticDimension
        view.register(cellWithClass: ChargeListCell.self)
        view.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)
        view.scrollIndicatorInsets = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)
        return view
    }()
    private lazy var monitorButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitleColor(.white, for: .normal)
        return btn
    }()
    private var chargeTasks: [ChargeTaskModel] = []
    private var currentPage = 1
    private var totalPages = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "充电助手"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        
        setupUIView()
        setupMonitorButton()
        setupRefreshControl()
        mileageHeaderView.setupUI()
        mileageHeaderView.setupCarModel(false)
        
        // 加载本地数据库数据
        loadChargeList()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 切换到该 Tab 页面时，刷新头部和下方列表（重新读取数据库）
        mileageHeaderView.setupCarModel(false)
        currentPage = 1
        tableView.mj_footer?.resetNoMoreData()
        loadChargeList(page: 1)
    }
    
    private func setupUIView() {
        view.addSubview(spaceView)
        view.addSubview(tableView)
        view.addSubview(mileageHeaderView)
        
        spaceView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(20)
        }
        mileageHeaderView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(100)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(mileageHeaderView.snp.top)
            make.trailing.bottom.leading.equalToSuperview()
        }
        
        let leftBtn = UIBarButtonItem(title: "电池信息", style: .plain, target: self, action: #selector(clickBatteryInfo))
        navigationItem.leftBarButtonItem = leftBtn
        let rightBtn = UIBarButtonItem(customView: monitorButton)
        navigationItem.rightBarButtonItem = rightBtn
    }
    
    private func setupRefreshControl() {
        // 设置刷新控件的偏移量，避免与大标题导航栏遮挡
        let mj_header = MJRefreshNormalHeader(refreshingBlock: {
            // 下拉刷新：请求API获取最新车辆信息 + 列表重新读取本地数据库
            self.fetchCarInfo()
            // 重新从第一页加载数据库列表
            self.currentPage = 1
            self.tableView.mj_footer?.resetNoMoreData()
            self.loadChargeList(page: 1)
        })
        mj_header.ignoredScrollViewContentInsetTop = 20
        mj_header.lastUpdatedTimeLabel?.isHidden = true
        tableView.mj_header = mj_header
        
        // 上拉加载更多（本地数据库分页）
        tableView.mj_footer = MJRefreshAutoNormalFooter { [weak self] in
            guard let self = self else { return }
            self.loadChargeList(page: self.currentPage + 1)
        }
    }
    
    private func setupMonitorButton() {
        let menu = UIMenu(
            title: "选择通知模式",
            options: .displayInline,
            children: [
                // 选项1: 按时间监听
                UIAction(
                    title: "时间通知",
                    subtitle: "达到设定的充电时长后，将发送通知提醒",
                    image: UIImage(systemName: "timer")) { [weak self] _ in
                        self?.checkActiveMonitoringBeforeAction {
                            self?.handleMonitorByTime()
                        }
                    },
                // 选项2: 按充电金额监听
                UIAction(
                    title: "充电金额通知",
                    subtitle: "根据电价和目标金额计算，到达后发送通知",
                    image: UIImage(systemName: "dollarsign.circle")) { [weak self] _ in
                        self?.checkActiveMonitoringBeforeAction {
                            self?.handleMonitorByAmount()
                        }
                    },
                // 选项3: 按充电度数监听
                UIAction(
                    title: "充电度数通知",
                    subtitle: "达到设定的充电度数(kWh)后，将发送通知",
                    image: UIImage(systemName: "bolt.fill")) { [weak self] _ in
                        self?.checkActiveMonitoringBeforeAction {
                            self?.handleMonitorByKwh()
                        }
                    },
                // 选项4: 按服务费监听
                UIAction(
                    title: "服务费通知",
                    subtitle: "达到设定的服务费总额后，将发送通知",
                    image: UIImage(systemName: "creditcard")) { [weak self] _ in
                        self?.checkActiveMonitoringBeforeAction {
                            self?.handleMonitorByServiceFee()
                        }
                    }
            ]
        )
        
        // 将菜单赋值给按钮
        monitorButton.menu = menu
        monitorButton.showsMenuAsPrimaryAction = true
        
        // --- 按钮样式配置 (使用 UIButton.Configuration) ---
        // 这是 iOS 15+ 推荐的按钮样式配置方法，非常灵活。
        var config = UIButton.Configuration.filled()
        config.title = "充电通知"
        config.image = UIImage(systemName: "powerplug.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = .systemGreen
        config.cornerStyle = .capsule // 胶囊形状
        monitorButton.configuration = config
    }
    
    // MARK: - Menu Action Handlers
    private func handleMonitorByTime() {
        let vc = SetTimeMonitorViewController()
        vc.completion = { [weak self] targetDate, stopAutomatically in
            guard let self = self, let targetDate = targetDate else { return }
            
            // 将 Date 转换为 Unix 时间戳 (秒)
            let targetTimestamp = targetDate.timeIntervalSince1970
            
            QMUITips.showLoading("正在启动时间监听...", in: self.view)
            NetworkManager.shared.startChargeMonitoring(
                mode: "time",
                targetTimestamp: targetTimestamp,
                autoStopCharge: stopAutomatically
            ) { result in
                QMUITips.hideAllTips()
                switch result {
                    case .success:
                        QMUITips.showSucceed("时间监听已成功启动")
                        // 调用统一的处理函数
                        self.handleSuccessfulMonitoringStart(
                            mode: "time",
                            targetValue: targetTimestamp.string,
                            autoStopCharge: stopAutomatically
                        )
                    case .failure(let error):
                        QMUITips.showError("启动失败: \(error.localizedDescription)")
                }
            }
        }
        
        if let sheet = vc.sheetPresentationController {
            let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("customHeight")) { _ in return 500 }
            sheet.detents = [customDetent]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }
    
    private func handleMonitorByAmount() {
        let alert = UIAlertController(title: "按金额监听", message: "请输入每度电单价和目标总额", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "每度电单价(元)"; $0.keyboardType = .decimalPad }
        alert.addTextField { $0.placeholder = "目标总金额(元)"; $0.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let unitPriceText = alert.textFields?[0].text, let unitPrice = Double(unitPriceText), unitPrice > 0,
                  let totalAmountText = alert.textFields?[1].text, let totalAmount = Double(totalAmountText) else {
                QMUITips.showError("请输入有效的数字")
                return
            }
            
            // 计算需要充多少度电
            let kwhToCharge = totalAmount / unitPrice
            self.startMonitoringWithKwh(kwhToCharge, monitoringType: "amount", originalValue: totalAmount)
        }))
        present(alert, animated: true)
    }
    
    private func handleMonitorByKwh() {
        let alert = UIAlertController(title: "按度数监听", message: "请输入目标充电度数(kWh)", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "例如：20"; $0.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let kwhText = alert.textFields?.first?.text, let kwhToCharge = Double(kwhText) else {
                QMUITips.showError("请输入有效的度数")
                return
            }
            self.startMonitoringWithKwh(kwhToCharge, monitoringType: "kwh", originalValue: kwhToCharge)
        }))
        present(alert, animated: true)
    }
    
    private func handleMonitorByServiceFee() {
        let alert = UIAlertController(title: "按服务费监听", message: "请输入每度电服务费和目标总服务费", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "每度电服务费(元)"; $0.keyboardType = .decimalPad }
        alert.addTextField { $0.placeholder = "目标总服务费(元)"; $0.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let unitFeeText = alert.textFields?[0].text, let unitFee = Double(unitFeeText), unitFee > 0,
                  let totalFeeText = alert.textFields?[1].text, let totalFee = Double(totalFeeText) else {
                QMUITips.showError("请输入有效的数字")
                return
            }
            // 计算需要充多少度电
            let kwhToCharge = totalFee / unitFee
            self.startMonitoringWithKwh(kwhToCharge, monitoringType: "serviceFee", originalValue: totalFee)
        }))
        present(alert, animated: true)
    }
    
    /// 通用辅助函数，用于将 "需要充电的度数" 转换为 "目标续航里程" 并启动监听
    private func startMonitoringWithKwh(_ kwhToCharge: Double, monitoringType: String = "kwh", originalValue: Double = 0) {
        guard let carModel = UserManager.shared.carModel else {
            QMUITips.showError("无法获取车辆信息")
            return
        }
        
        // --- 使用工具类进行核心计算逻辑 ---
        
        // 1. 获取电池总容量和当前SOC
        let batteryCapacity = BatteryCalculationUtility.getBatteryCapacity(from: carModel)//获取数据34.5
        let currentSoc = BatteryCalculationUtility.getCurrentSoc(from: carModel)//获取数据61
        
        // 2. 计算当前电量
        let currentKwh = BatteryCalculationUtility.calculateCurrentKwh(soc: currentSoc, batteryCapacity: batteryCapacity)//获取数据21.04
        
        // 3. 计算目标电量，考虑充电损耗
        let targetKwh = BatteryCalculationUtility.calculateTargetKwh(currentKwh: currentKwh, chargeAmount: kwhToCharge)// 获取数据23.2
        
        // 4. 计算目标SOC百分比
        let targetSoc = BatteryCalculationUtility.calculateSoc(currentKwh: targetKwh, batteryCapacity: batteryCapacity)//获取数据67.26
        
        // 5. 根据能耗估算目标续航里程
        let targetRange = BatteryCalculationUtility.calculateRange(soc: targetSoc, carModel: carModel)//这里出错了，这里数据有336，2度电怎么怎么可能增加这么多里程
        
        let currentKm = carModel.acOnMile
        
        // --- 计算结束 ---
        QMUITips.showLoading("正在启动里程监听...", in: self.view)
        NetworkManager.shared.startChargeMonitoring(
            mode: "range",
            targetRange: Int(targetRange)
        ) { result in
            QMUITips.hideAllTips()
            switch result {
                case .success:
                    QMUITips.showSucceed("里程监听已成功启动")
                    // 根据监控类型生成不同的显示文本
                    let displayText: String
                    switch monitoringType {
                    case "amount":
                        displayText = "设定充电价格: \(originalValue)元 (大约可以充电\(Int(targetRange-currentKm))公里)"
                    case "kwh":
                        displayText = "设定充电度数: \(originalValue)kWh (大约可以充电\(Int(targetRange-currentKm))公里)"
                    case "serviceFee":
                        displayText = "设定电量服务费: \(originalValue)元 (大约可以充电\(Int(targetRange-currentKm))公里)"
                    default:
                        displayText = "\(Int(targetRange))公里"
                    }
                    
                    // 调用统一的处理函数
                    self.handleSuccessfulMonitoringStart(
                        mode: "range",
                        targetValue: displayText,
                        autoStopCharge: false, // 里程模式下，我们不自动停止充电
                        targetKm: Double(targetRange)
                    )
                case .failure(let error):
                    QMUITips.showError("启动失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 处理监控任务成功启动后的本地操作
    private func handleSuccessfulMonitoringStart(mode: String, targetValue: String, autoStopCharge: Bool, targetKm: Double? = 0) {
        // 保存监控信息到UserDefaults
        saveMonitoringInfo(mode: mode, targetValue: targetValue, autoStopCharge: autoStopCharge, targetKm: targetKm)
        
        // 启动实时活动
        if mode == "range" {
            startLiveActivity(mode: mode, targetValue: targetValue, targetKm: targetKm)
            showAlert(title: "成功开启里程通知", message: targetValue)
        }
        if mode == "time" {
            let date = Date(timeIntervalSince1970: targetValue.double() ?? 0)
            showAlert(title: "成功开启时间通知", message: "当到达"+date.string(withFormat: "MM月dd日 HH:mm")+"后通知你")
        }
    }
    
    // MARK: - Monitoring Task Management
    
    /// 保存监控信息到UserDefaults
    private func saveMonitoringInfo(mode: String, targetValue: String, autoStopCharge: Bool, targetKm: Double?) {
        let defaults = UserDefaults.standard
        defaults.set(mode, forKey: "activeMonitoringMode")
        defaults.set(targetValue, forKey: "activeMonitoringTargetValue")
        defaults.set(autoStopCharge, forKey: "activeMonitoringAutoStop")
        
        // 根据模式保存不同的详细信息
        switch mode {
        case "time":
            // 时间模式：保存目标时间戳，转换为可读时间
            if let timestamp = Double(targetValue) {
                let targetDate = Date(timeIntervalSince1970: timestamp)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                let timeString = formatter.string(from: targetDate)
                defaults.set(timeString, forKey: "activeMonitoringDetails")
            }
        case "range":
            // 续航模式：直接使用传入的targetValue（已经包含完整信息）
            defaults.set(targetValue, forKey: "activeMonitoringDetails")
        default:
            defaults.set(targetValue, forKey: "activeMonitoringDetails")
        }
        
        defaults.synchronize()
    }
    
    /// 检查是否有活跃的监控任务
    /// 在执行监听操作前检查是否有活跃的监听任务
    private func checkActiveMonitoringBeforeAction(completion: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        
        // 检查是否有活跃的监听任务
        if let mode = defaults.string(forKey: "activeMonitoringMode"),
           let details = defaults.string(forKey: "activeMonitoringDetails") {
            // 有活跃任务，显示提醒弹窗
            showMonitoringAlert(mode: mode, details: "当到达\(details)后通知你")
        } else {
            // 没有活跃任务，执行新的监听操作
            completion()
        }
    }
    
    private func checkActiveMonitoringTask() {
        let defaults = UserDefaults.standard
        
        guard let mode = defaults.string(forKey: "activeMonitoringMode"),
              let details = defaults.string(forKey: "activeMonitoringDetails") else {
            return
        }
        
        // 显示监控状态提醒弹窗
        showMonitoringAlert(mode: mode, details: details)
    }
    
    /// 显示监控状态提醒弹窗
    private func showMonitoringAlert(mode: String, details: String) {
        let modeTitle: String
        switch mode {
        case "time":
            modeTitle = "时间通知"
        case "range":
            modeTitle = "续航通知"
        case "amount":
            modeTitle = "充电金额通知"
        case "kwh":
            modeTitle = "充电度数通知"
        case "serviceFee":
            modeTitle = "服务费通知"
        default:
            modeTitle = "充电通知"
        }
        
        let alert = UIAlertController(
            title: modeTitle,
            message: details,
            preferredStyle: .alert
        )
        
        // 取消通知按钮
        let cancelAction = UIAlertAction(title: "取消通知", style: .destructive) { [weak self] _ in
            self?.cancelActiveMonitoring(mode: mode)
        }
        
        // 确定按钮
        let confirmAction = UIAlertAction(title: "确定", style: .default) { _ in
            // 仅关闭弹窗，不做其他操作
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        
        present(alert, animated: true)
    }
    
    /// 取消活跃的监控任务
    private func cancelActiveMonitoring(mode: String) {
        clearMonitoringInfo()
        QMUITips.showLoading("正在取消监控...", in: self.view)
        
        NetworkManager.shared.stopChargeMonitoring(mode: mode) { [weak self] result in
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                
                switch result {
                case .success:
                    QMUITips.showSucceed("监控已取消")
                    self?.clearMonitoringInfo()
                case .failure(let error):
                    QMUITips.showError("取消失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 清除监控信息
    private func clearMonitoringInfo() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "activeMonitoringMode")
        defaults.removeObject(forKey: "activeMonitoringTargetValue")
        defaults.removeObject(forKey: "activeMonitoringAutoStop")
        defaults.removeObject(forKey: "activeMonitoringDetails")
        
        // 清除实时活动数据
        defaults.removeObject(forKey: "LiveActivityData")
        
        defaults.synchronize()
        
        // 停止实时活动
        LiveActivityManager.shared.endCurrentActivity()
    }

    // MARK: - Data Loading
    private func loadChargeList(page: Int = 1) {
        // 在后台线程执行数据库读取操作，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 在数据库队列中执行读取
                let records = try AppDatabase.dbQueue.read { db -> [ChargeTaskRecord] in
                    // 根据分页参数计算偏移量
                    let pageSize = 20 // 假设每页加载20条
                    let offset = (page - 1) * pageSize
                    
                    // 从数据库查询 ChargeTaskRecord，按开始时间降序排列
                    return try ChargeTaskRecord
                        .order(Column("startTime").desc)
                        .limit(pageSize, offset: offset)
                        .fetchAll(db)
                }
                
                let viewModels = records.map { ChargeTaskModel(from: $0) }
                let hasMore = viewModels.count == 20 // 如果返回的数量等于页大小，则认为还有更多数据
                
                // 将处理结果切换回主线程来更新UI
                self.handleLocalChargeListResponse(viewModels, page: page, hasMore: hasMore)
            } catch {
                // 处理数据库读取错误
                DispatchQueue.main.async {
                    self.tableView.mj_header?.endRefreshing()
                    self.tableView.mj_footer?.endRefreshing()
                    self.handleError(error)
                }
            }
        }
    }
    
    /// 处理从本地数据库加载的数据
    private func handleLocalChargeListResponse(_ newTasks: [ChargeTaskModel], page: Int, hasMore: Bool) {
        DispatchQueue.main.async {
            self.tableView.mj_header?.endRefreshing()
            
            if page == 1 {
                // 下拉刷新，替换所有数据
                self.chargeTasks = newTasks
            } else {
                // 上拉加载，追加新数据
                self.chargeTasks.append(contentsOf: newTasks)
            }
            
            self.tableView.reloadData()
            
            // 更新上拉加载footer的状态
            if hasMore {
                self.tableView.mj_footer?.endRefreshing()
                self.currentPage = page // 更新当前页码
            } else {
                self.tableView.mj_footer?.endRefreshingWithNoMoreData()
            }
            
            // 检查是否显示空状态
            if self.chargeTasks.isEmpty {
                self.showEmptyState()
            } else {
                self.hideEmptyState()
            }
        }
    }
    
    private func handleChargeListResponse(_ response: ChargeListResponse, page: Int) {
        currentPage = response.pagination.currentPage
        totalPages = response.pagination.totalPages
        
        if page == 1 {
            // 刷新数据
            chargeTasks = response.tasks
        } else {
            // 加载更多
            chargeTasks.append(contentsOf: response.tasks)
        }
        
        tableView.reloadData()
        
        // 更新footer状态
        if currentPage >= totalPages {
            tableView.mj_footer?.endRefreshingWithNoMoreData()
        } else {
            tableView.mj_footer?.resetNoMoreData()
        }
        
        // 如果没有数据，显示空状态
        if chargeTasks.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private func handleError(_ error: Error) {
        QMUITips.showError("加载失败: \(error.localizedDescription)")
    }
    
    // MARK: - Empty State
    private func showEmptyState() {
        let emptyView = createEmptyStateView()
        tableView.backgroundView = emptyView
    }
    
    private func hideEmptyState() {
        tableView.backgroundView = nil
    }
    
    private func createEmptyStateView() -> UIView {
        let containerView = UIView()
        
        let imageView = UIImageView(image: UIImage(systemName: "battery.0"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = "暂无充电记录"
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .systemGray2
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "开始您的第一次充电任务吧"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray3
        subtitleLabel.textAlignment = .center
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(80)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        return containerView
    }
    
    // MARK: - 获取车辆信息
    func fetchCarInfo() {
        NetworkManager.shared.getInfo(completion: { [weak self] result in
            guard let self else { return }
            self.tableView.mj_header?.endRefreshing()
            switch result {
                case .success(let model):
                    // 保存车辆信息
                    self.tableView.mj_header?.endRefreshing()
                    UserManager.shared.updateCarInfo(with: model)
                    self.mileageHeaderView.setupCarModel(false)
                case .failure(let error):
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
            }
        })
    }
    
    // MARK: - 配置信息
    func formatTime(minutes: Float) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return "\(hours)小时\(mins)分钟\(secs)秒"
    }
    
    // MARK: - 点击事件
    @objc func clickBatteryInfo() {
        guard let model = UserManager.shared.carModel else { return }
        
        // 使用工具类获取电池信息
        let batteryCapacity = BatteryCalculationUtility.getBatteryCapacity(from: model)
        let currentSoc = BatteryCalculationUtility.getCurrentSoc(from: model)
        let remainingKWh = BatteryCalculationUtility.calculateCurrentKwh(soc: currentSoc, batteryCapacity: batteryCapacity)
        let remainingTo90KWh = max(0, batteryCapacity * 0.9 - remainingKWh)
        
        // 获取车型信息
        let estimated = model.estimatedModelAndCapacity
        
        var fastChargeTimeToFull: Float = 0
        var slowChargeTimeToFull: Float = 0
        var fastChargePower: Float = 0
        var slowChargePower: Float = 0
        
        switch estimated.model {
            case "330":
                fastChargeTimeToFull = 0.58
                slowChargeTimeToFull = 12
                fastChargePower = 34.5 * 0.5 / fastChargeTimeToFull // ≈29.7
                slowChargePower = 34.5 / slowChargeTimeToFull
            case "405":
                fastChargeTimeToFull = 0.5
                slowChargeTimeToFull = 7.5
                fastChargePower = 41 * 0.5 / fastChargeTimeToFull // ≈41
                slowChargePower = 41 / slowChargeTimeToFull
            case "505":
                fastChargeTimeToFull = 0.5
                slowChargeTimeToFull = 9
                fastChargePower = 51.5 * 0.5 / fastChargeTimeToFull // ≈51.5
                slowChargePower = 51.5 / slowChargeTimeToFull
            default:
                break
        }
        
        let fastMinutesTo90 = fastChargePower > 0 ? remainingTo90KWh / Double(fastChargePower) * 60 : 0
        let slowMinutesTo90 = slowChargePower > 0 ? remainingTo90KWh / Double(slowChargePower) * 60 : 0
        
        let text = """
        当前车型：\(estimated.model) km
        电池总容量：\(String(format: "%.1f", batteryCapacity)) kWh
        
        当前电量：\(String(format: "%.1f", remainingKWh)) kWh
        距离100%可再充：\(String(format: "%.1f", batteryCapacity-remainingKWh)) kWh
        
        预计充到90%时间：
        快充约需：\(formatTime(minutes: Float(fastMinutesTo90)))
        慢充约需：\(formatTime(minutes: Float(slowMinutesTo90)))
        
        \(model.chgStatus != 2 ? "当前正在充电\n充满需要：\(formatTime(minutes: model.quickChgLeftTime.float))" : "")
        """
        let modal = ModalView()
        modal.text = text
        modal.show()
    }
    
    // MARK: - Live Activity Management
    
    /// 启动实时活动
    @available(iOS 16.1, *)
    private func startLiveActivity(mode: String, targetValue: String, targetKm: Double?) {
        // 获取当前车辆信息
        guard let carInfo = UserManager.shared.carModel else {
            print("无法获取车辆信息，无法启动实时活动")
            return
        }
        
        // 创建 ChargeAttributes
        let attributes = ChargeAttributes(
            vin: UserManager.shared.defaultVin ?? "",
            startKm: carInfo.acOnMile,        // 使用当前里程作为起始里程
            endKm: Int(targetKm ?? Double(carInfo.acOnMile)), // 目标里程，如果没有则使用当前里程
            initialSoc: carInfo.soc          // 使用当前SOC作为初始SOC
        )
        
        // 创建初始状态 - 使用当前车辆数据作为初始值
        let initialState = ChargeAttributes.ContentState(
            currentKm: carInfo.acOnMile,           // 当前里程作为初始里程
            currentSoc: carInfo.soc,              // 当前SOC作为初始SOC
            chargeProgress: 0,                    // 充电进度从0开始
            message: "充电监控已启动"              // 初始消息
        )
        
        // 保存实时活动数据到 UserDefaults
        saveLiveActivityData(mode: mode, targetValue: targetValue, targetKm: targetKm, attributes: attributes, initialState: initialState)
        
        // 使用 LiveActivityManager 启动实时活动
        LiveActivityManager.shared.manageActivityForTask(attributes: attributes, state: initialState)
        
        print("实时活动已启动 - 模式: \(mode), 目标值: \(targetValue)")
    }
    
    /// 保存实时活动数据到 UserDefaults
    private func saveLiveActivityData(mode: String, targetValue: String, targetKm: Double?, attributes: ChargeAttributes, initialState: ChargeAttributes.ContentState) {
        let liveActivityData: [String: Any] = [
            "mode": mode,
            "targetValue": targetValue,
            "targetKm": targetKm ?? 0,
            "vin": attributes.vin,
            "startKm": attributes.startKm,
            "endKm": attributes.endKm,
            "initialSoc": attributes.initialSoc,
            "currentKm": initialState.currentKm,
            "currentSoc": initialState.currentSoc,
            "chargeProgress": initialState.chargeProgress,
            "message": initialState.message ?? "",
            "isActive": true
        ]
        
        UserDefaults.standard.set(liveActivityData, forKey: "LiveActivityData")
        UserDefaults.standard.synchronize()
        
        print("实时活动数据已保存到 UserDefaults")
    }
}

// MARK: - UITableViewDataSource
extension ChargeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chargeTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChargeListCell.identifier, for: indexPath) as! ChargeListCell
        let task = chargeTasks[indexPath.row]
        cell.configure(with: task)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChargeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 获取选中的充电任务
        let task = chargeTasks[indexPath.row]
        
        showNavigationOptions(for: task)
    }
    
    // MARK: - 侧滑删除功能
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let task = chargeTasks[indexPath.row]
            deleteChargeTask(task, at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "删除"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - 导航相关方法
    private func showNavigationOptions(for task: ChargeTaskModel) {
        // 使用guard确保经纬度不为空
        guard let lat = task.lat, let lon = task.lon else {
            QMUITips.showError("该充电记录没有位置信息")
            return
        }
        
        let alert = UIAlertController(title: "选择导航方式", message: "请选择您要使用的导航应用", preferredStyle: .actionSheet)
        
        // 苹果地图
        alert.addAction(UIAlertAction(title: "苹果地图", style: .default) { _ in
            self.openAppleMaps(lat: lat, lon: lon, name: task.address ?? "充电站")
        })
        
        // 高德地图
        alert.addAction(UIAlertAction(title: "高德地图", style: .default) { _ in
            self.openAMap(lat: lat, lon: lon, name: task.address ?? "充电站")
        })
        
        // 百度地图
        alert.addAction(UIAlertAction(title: "百度地图", style: .default) { _ in
            self.openBaiduMap(lat: lat, lon: lon, name: task.address ?? "充电站")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 适配iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func openAppleMaps(lat: Double, lon: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func openAMap(lat: Double, lon: Double, name: String) {
        let urlString = "iosamap://navi?sourceApplication=Pan3&poiname=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&poiid=BGVIS&lat=\(lat)&lon=\(lon)&dev=0&style=2"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装高德地图，跳转到App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/id461703208") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    private func openBaiduMap(lat: Double, lon: Double, name: String) {
        // 将高德坐标转换为百度坐标
        let convertedCoordinate = convertGCJ02ToBD09(lat: lat, lon: lon)
        let urlString = "baidumap://map/direction?destination=latlng:\(convertedCoordinate.lat),\(convertedCoordinate.lon)|name:\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mode=driving&src=Pan3"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装百度地图，跳转到App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/id452186370") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    // MARK: - 坐标转换方法
    /// 将GCJ02坐标(高德坐标)转换为BD09坐标(百度坐标)
    private func convertGCJ02ToBD09(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        let x = lon
        let y = lat
        let z = sqrt(x * x + y * y) + 0.00002 * sin(y * Double.pi)
        let theta = atan2(y, x) + 0.000003 * cos(x * Double.pi)
        let bdLon = z * cos(theta) + 0.0065
        let bdLat = z * sin(theta) + 0.006
        return (lat: bdLat, lon: bdLon)
    }
    
    // MARK: - 删除充电任务
    private func deleteChargeTask(_ task: ChargeTaskModel, at indexPath: IndexPath) {
        // 显示确认删除的弹窗
        let alert = UIAlertController(
            title: "删除充电记录",
            message: "确定要删除这条充电记录吗？删除后无法恢复。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
            self?.performDeleteTask(task, at: indexPath)
        }))
        
        present(alert, animated: true)
    }
    
    private func performDeleteTask(_ task: ChargeTaskModel, at indexPath: IndexPath) {
        // 在后台线程执行数据库删除操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppDatabase.dbQueue.write { db in
                    // 从数据库中删除记录
                    try ChargeTaskRecord.deleteOne(db, key: task.id)
                    print("充电任务记录已从数据库中删除")
                }
                
                // 在主线程更新UI
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // 从数据源中移除任务
                    self.chargeTasks.remove(at: indexPath.row)
                    
                    // 删除表格行，带动画效果
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                    // 如果删除后列表为空，显示空状态
                    if self.chargeTasks.isEmpty {
                        self.showEmptyState()
                    }
                    
                    QMUITips.showSucceed("删除成功")
                }
                
            } catch {
                print("删除充电任务失败: \(error)")
                DispatchQueue.main.async {
                    self?.showAlert(title: "删除失败", message: "无法删除充电记录，请稍后重试")
                }
            }
        }
    }
}

// MARK: - 自定义输入视图控制器
// 这是一个专门用于“按时间监听”设置的视图控制器。
class SetTimeMonitorViewController: UIViewController {
    
    // 定义一个闭包，用于将数据传递回上一个页面
    var completion: ((_ targetDate: Date?, _ stopAutomatically: Bool) -> Void)?
    
    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Date()
        picker.maximumDate = Calendar.current.date(byAdding: .hour, value: 36, to: Date())
        picker.minuteInterval = 5
        // 默认时间选择在当前时间基础上+5分钟
        if let defaultDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) {
            picker.date = defaultDate
        }
        return picker
    }()
    
    private let autoStopSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = true
        return switchControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupLayout()
    }
    
    private func setupBackground() {
        // 将背景设置为透明，以便显示下方的模糊效果
        view.backgroundColor = .clear
        
        // UIVisualEffectView 是实现模糊和半透明效果的标准方式。
        // 从iOS 16+开始，系统材质（如 .systemMaterial）会自动适应操作系统的设计语言。
        // 在 iOS 26 上，它将自动呈现为“液态玻璃”效果。
        // 这种方式是苹果推荐的，可以保证未来的兼容性。
        let effect = UIBlurEffect(style: .systemMaterial)
        let effectView = UIVisualEffectView(effect: effect)
        
        view.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupLayout() {
        // --- 标题 ---
        let titleLabel = UILabel()
        titleLabel.text = "设置监听时间"
        titleLabel.font = .boldSystemFont(ofSize: 20)
        
        let subtitleForTitle = UILabel()
        subtitleForTitle.text = "最长设置24小时"
        subtitleForTitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitleForTitle.textColor = .secondaryLabel
        
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleForTitle])
        titleStack.alignment = .center
        titleStack.axis = .vertical
        titleStack.spacing = 4
        
        // --- 开关和它的描述标签 ---
        let switchLabel = UILabel()
        switchLabel.text = "到达时间后自动停止充电"
        switchLabel.font = .systemFont(ofSize: 16)
        
        let switchStack = UIStackView(arrangedSubviews: [switchLabel, autoStopSwitch])
        switchStack.axis = .horizontal
        switchStack.spacing = 8
        switchStack.alignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "自动停止充电条件，锁车状态并且是慢充模式"
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        
        let switchControlStack = UIStackView(arrangedSubviews: [switchStack, subtitleLabel])
        switchControlStack.alignment = .fill
        switchControlStack.axis = .vertical
        switchControlStack.spacing = 4
        
        // --- 确定和取消按钮 ---
        let confirmButton = UIButton(type: .system)
        var confirmConfig = UIButton.Configuration.filled()
        confirmConfig.baseBackgroundColor = .systemGreen
        confirmConfig.title = "确定"
        confirmButton.configuration = confirmConfig
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        
        let cancelButton = UIButton(type: .system)
        var cancelConfig = UIButton.Configuration.gray()
        cancelConfig.title = "取消"
        cancelButton.configuration = cancelConfig
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonStack.distribution = .fillEqually
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        
        // --- 主堆栈视图 ---
        let mainStack = UIStackView(arrangedSubviews: [titleStack, datePicker, switchControlStack, buttonStack])
        mainStack.axis = .vertical
        mainStack.spacing = 20
        
        view.addSubview(mainStack)
        
        // --- 使用 SnapKit 设置布局 ---
        mainStack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        cancelButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }
    
    @objc private func confirmTapped() {
        completion?(datePicker.date, autoStopSwitch.isOn)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
