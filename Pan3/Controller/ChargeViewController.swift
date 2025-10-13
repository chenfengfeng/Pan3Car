//
//  ChargeViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import GRDB
import UIKit
import QMUIKit
import MJRefresh
import SwifterSwift

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
        
        // 注册充电任务推送通知
        registerChargeTaskPushNotification()
        
        // 主动获取最新的充电任务状态
        checkAndUpdateRunningTaskStatus()
        
        loadChargeList()
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
            // 下拉刷新：请求API获取最新数据来更新数据库
            self.refreshDataFromAPI()
        })
        mj_header.ignoredScrollViewContentInsetTop = 20
        mj_header.lastUpdatedTimeLabel?.isHidden = true
        tableView.mj_header = mj_header
        
        // 上拉加载更多
        tableView.mj_footer = MJRefreshAutoNormalFooter {
            guard self.currentPage < self.totalPages else {
                self.tableView.mj_footer?.endRefreshingWithNoMoreData()
                return
            }
            self.loadChargeList(page: self.currentPage + 1)
        }
    }
    
    /// 下拉刷新时调用API获取最新数据
    private func refreshDataFromAPI() {
        guard let vin = UserManager.shared.defaultVin else {
            print("无法获取默认VIN，跳过状态检查")
            DispatchQueue.main.async {
                self.tableView.mj_header?.endRefreshing()
            }
            return
        }
        
        // 同时请求充电状态和车辆信息
        let group = DispatchGroup()
        
        // 请求充电状态
        group.enter()
        NetworkManager.shared.getChargeStatus { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let response):
                self?.handleChargeStatusResponse(response, for: vin)
            case .failure(let error):
                print("获取充电状态失败: \(error)")
                // 网络请求失败时，仍然检查本地是否有长时间未更新的任务
                self?.checkAndUpdateStaleLocalTasks(for: vin)
            }
        }
        
        // 请求车辆信息
        group.enter()
        self.fetchCarInfo()
        group.leave()
        
        // 所有请求完成后结束刷新
        group.notify(queue: .main) {
            self.tableView.mj_header?.endRefreshing()
        }
    }
    
    private func setupMonitorButton() {
        let menu = UIMenu(
            title: "选择监听模式",
            options: .displayInline,
            children: [
                // 选项1: 按时间监听
                UIAction(
                    title: "按时间监听",
                    subtitle: "达到设定的充电时长后，将发送通知提醒",
                    image: UIImage(systemName: "timer")) { [weak self] _ in
                        self?.handleMonitorByTime()
                    },
                // 选项2: 按充电金额监听
                UIAction(
                    title: "按充电金额监听",
                    subtitle: "根据电价和目标金额计算，到达后发送通知",
                    image: UIImage(systemName: "dollarsign.circle")) { [weak self] _ in
                        self?.handleMonitorByAmount()
                    },
                // 选项3: 按充电度数监听
                UIAction(
                    title: "按充电度数监听",
                    subtitle: "达到设定的充电度数(kWh)后，将发送通知",
                    image: UIImage(systemName: "bolt.fill")) { [weak self] _ in
                        self?.handleMonitorByKwh()
                    },
                // 选项4: 按服务费监听
                UIAction(
                    title: "按服务费监听",
                    subtitle: "达到设定的服务费总额后，将发送通知",
                    image: UIImage(systemName: "creditcard")) { [weak self] _ in
                        self?.handleMonitorByServiceFee()
                    }
            ]
        )
        
        // 将菜单赋值给按钮
        monitorButton.menu = menu
        monitorButton.showsMenuAsPrimaryAction = true
        
        // --- 按钮样式配置 (使用 UIButton.Configuration) ---
        // 这是 iOS 15+ 推荐的按钮样式配置方法，非常灵活。
        var config = UIButton.Configuration.filled()
        config.title = "充电监听"
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
            self.startMonitoringWithKwh(kwhToCharge)
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
            self.startMonitoringWithKwh(kwhToCharge)
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
            self.startMonitoringWithKwh(kwhToCharge)
        }))
        present(alert, animated: true)
    }
    
    /// 通用辅助函数，用于将 "需要充电的度数" 转换为 "目标续航里程" 并启动监听
    private func startMonitoringWithKwh(_ kwhToCharge: Double) {
        guard let carModel = UserManager.shared.carModel else {
            QMUITips.showError("无法获取车辆信息")
            return
        }
        
        // --- 使用工具类进行核心计算逻辑 ---
        
        // 1. 获取电池总容量和当前SOC
        let batteryCapacity = BatteryCalculationUtility.getBatteryCapacity(from: carModel)
        let currentSoc = BatteryCalculationUtility.getCurrentSoc(from: carModel)
        
        // 2. 计算当前电量
        let currentKwh = BatteryCalculationUtility.calculateCurrentKwh(soc: currentSoc, batteryCapacity: batteryCapacity)
        
        // 3. 计算目标电量，考虑充电损耗
        let targetKwh = BatteryCalculationUtility.calculateTargetKwh(currentKwh: currentKwh, chargeAmount: kwhToCharge)
        
        // 4. 计算目标SOC百分比
        let targetSoc = BatteryCalculationUtility.calculateSoc(currentKwh: targetKwh, batteryCapacity: batteryCapacity)
        
        // 5. 根据能耗估算目标续航里程
        let targetRange = BatteryCalculationUtility.calculateRange(soc: targetSoc, carModel: carModel)
        
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
                // 调用统一的处理函数
                self.handleSuccessfulMonitoringStart(
                    mode: "range",
                    targetValue: Int(targetRange).string,
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
        guard let vin = UserManager.shared.defaultVin,
              let carModel = UserManager.shared.carModel else {
            QMUITips.showError("无法获取车辆信息以创建本地任务")
            return
        }
        
        // --- 1. 创建本地数据库记录 ---
        let newRecord = ChargeTaskRecord(
            vin: vin,
            monitoringMode: mode,
            targetValue: targetValue,
            autoStopCharge: autoStopCharge,
            finalStatus: "PREPARING",
            startTime: Date(),
            startSoc: Int(carModel.soc),
            startRange: carModel.acOffMile
        )
        
        do {
            try AppDatabase.dbQueue.write { db in
                try newRecord.save(db)
                print("新的充电任务记录已成功存入数据库")
                print(db)
            }
        } catch {
            print("存入数据库失败: \(error)")
            QMUITips.showError("创建本地任务记录失败")
            return // 如果数据库写入失败，就不启动实时活动
        }
        
        // --- 2. 启动实时活动 ---
        // LiveActivityManager 单例来处理实时活动的启动和更新
        // 实时活动的 Attribute 和 ContentState 结构来传递正确的初始值
        let newModel = ChargeTaskModel(from: newRecord, carModel: carModel)
        let attributes = newModel.toCarWidgetAttributes()
        let contentState = newModel.toContentState()
        LiveActivityManager.shared.startChargeActivity(attributes: attributes, initialState: contentState)
        
        print("本地数据库记录已创建，下一步应启动实时活动。")
        QMUITips.showSucceed("监听已成功启动")
        
        // 刷新充电列表以显示新创建的记录
        loadChargeList()
        
        getTaskStatus()
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
                
                // 将数据库模型转换为视图模型
                guard let carModel = UserManager.shared.carModel else {
                    // 如果没有车辆信息，无法进行计算，直接返回空
                    self.handleLocalChargeListResponse([], page: page, hasMore: false)
                    return
                }
                
                let viewModels = records.map { ChargeTaskModel(from: $0, carModel: carModel) }
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
            DispatchQueue.main.async {
                switch result {
                case .success(let json):
                    // 保存车辆信息
                    let model = CarModel(json: json)
                    UserManager.shared.updateCarInfo(with: model)
                    self.mileageHeaderView.setupCarModel(false)
                case .failure(let error):
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                }
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
    
    // MARK: - 充电功能
    
    /// 主动检查并更新正在运行的充电任务状态
    private func checkAndUpdateRunningTaskStatus() {
        guard let vin = UserManager.shared.defaultVin else {
            print("无法获取默认VIN，跳过状态检查")
            return
        }
        
        NetworkManager.shared.getChargeStatus { [weak self] result in
            switch result {
            case .success(let response):
                self?.handleChargeStatusResponse(response, for: vin)
            case .failure(let error):
                print("获取充电状态失败: \(error)")
                // 网络请求失败时，仍然检查本地是否有长时间未更新的任务
                self?.checkAndUpdateStaleLocalTasks(for: vin)
            }
        }
    }
    
    /// 处理充电状态API响应
    private func handleChargeStatusResponse(_ response: ChargeStatusResponse, for vin: String) {
        if response.hasRunningTask {
            // 服务器端有正在运行的任务，检查本地数据库是否同步
            if let serverTask = response.task {
                print("服务器端有正在运行的充电任务: \(serverTask.status)")
                // 可以在这里同步服务器状态到本地数据库
                syncServerTaskToLocal(serverTask, for: vin)
            }
        } else {
            // 服务器端没有正在运行的任务，检查本地是否有未完成的任务需要更新
            print("服务器端没有正在运行的充电任务，检查本地数据库")
            updateLocalTasksWhenNoServerTask(for: vin)
        }
    }
    
    /// 当服务器端没有运行中任务时，更新本地数据库中的未完成任务
    private func updateLocalTasksWhenNoServerTask(for vin: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppDatabase.dbQueue.write { db in
                    // 查找所有未完成的任务
                    let unfinishedTasks = try ChargeTaskRecord.filter(
                        Column("vin") == vin &&
                        (Column("finalStatus") == "PREPARING" || Column("finalStatus") == "CHARGING" || Column("finalStatus") == "RUNNING")
                    ).fetchAll(db)
                    
                    if !unfinishedTasks.isEmpty {
                        print("发现 \(unfinishedTasks.count) 个本地未完成任务，服务器端已无运行中任务，将其标记为完成")
                        
                        // 批量更新所有未完成的任务为完成状态
                        let updateSql = """
                            UPDATE chargeTask 
                            SET finalStatus = 'COMPLETED', endTime = ? 
                            WHERE vin = ? AND finalStatus IN ('PREPARING', 'CHARGING', 'RUNNING')
                        """
                        
                        let updatedCount = try db.execute(sql: updateSql, arguments: [Date(), vin])
                        print("已将 \(updatedCount) 个未完成任务标记为完成")
                        
                        // 在主线程刷新UI
                        DispatchQueue.main.async {
                            self?.loadChargeList(page: 1)
                        }
                    }
                }
            } catch {
                print("更新本地任务状态失败: \(error)")
            }
        }
    }
    
    /// 同步服务器任务状态到本地数据库
    private func syncServerTaskToLocal(_ serverTask: ChargeTaskModel, for vin: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppDatabase.dbQueue.write { db in
                    // 查找最新的未完成任务
                    let sql = """
                        SELECT * FROM chargeTask 
                        WHERE vin = ? AND finalStatus IN ('PREPARING', 'RUNNING', 'CHARGING')
                        ORDER BY startTime DESC 
                        LIMIT 1
                    """
                    
                    if var record = try ChargeTaskRecord.fetchOne(db, sql: sql, arguments: [vin]) {
                        // 更新本地任务状态以匹配服务器状态
                        record.finalStatus = serverTask.status
                        if serverTask.status == "COMPLETED" || serverTask.status == "CANCELLED" || serverTask.status == "FAILED" {
                            record.endTime = Date()
                        }
                        
                        try record.save(db)
                        print("已同步服务器任务状态到本地: \(serverTask.status)")
                        
                        // 在主线程刷新UI
                        DispatchQueue.main.async {
                            self?.loadChargeList(page: 1)
                        }
                    }
                }
            } catch {
                print("同步服务器任务状态失败: \(error)")
            }
        }
    }
    
    /// 检查并更新长时间未更新的本地任务（网络请求失败时的备用方案）
    private func checkAndUpdateStaleLocalTasks(for vin: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppDatabase.dbQueue.read { db in
                    // 查找超过30分钟未更新的准备中或充电中任务
                    let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
                    let staleTasks = try ChargeTaskRecord.filter(
                        Column("vin") == vin &&
                        (Column("finalStatus") == "PREPARING" || Column("finalStatus") == "CHARGING") &&
                        Column("startTime") < thirtyMinutesAgo
                    ).fetchAll(db)
                    
                    if !staleTasks.isEmpty {
                        print("发现 \(staleTasks.count) 个可能已过期的本地任务")
                        // 这里可以选择性地更新这些任务，或者等待下次网络请求成功时处理
                    }
                }
            } catch {
                print("检查过期任务失败: \(error)")
            }
        }
    }
    
    // 获取充电任务状态
    private func getTaskStatus() {
        NetworkManager.shared.getChargeStatus { result in
            
        }
    }
    
    // 取消充电任务
    private func cancelCharge() {
        // 这个方法已被新的取消逻辑替代，保留以防其他地方调用
        let alert = UIAlertController(title: "确认取消", message: "确定要取消当前的充电任务吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { _ in
            NetworkManager.shared.stopChargeMonitoring { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        self.getTaskStatus()
                        LiveActivityManager.shared.cleanupAllActivities()
                        self.showAlert(title: "取消成功", message: "充电任务已成功取消")
                    case .failure(let error):
                        self.showAlert(title: "取消失败", message: error.localizedDescription)
                    }
                }
            }
        }))
        
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 充电任务推送通知处理
    
    /// 注册充电任务推送通知
    private func registerChargeTaskPushNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChargeTaskPushNotification(_:)),
            name: NSNotification.Name("ChargeTaskPushReceived"),
            object: nil
        )
    }
    
    /// 处理充电任务推送通知
    @objc private func handleChargeTaskPushNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let vin = userInfo["vin"] as? String,
              let status = userInfo["status"] as? String,
              let operationType = userInfo["operationType"] as? String,
              let extData = userInfo["extData"] as? [String: Any] else {
            print("充电任务推送通知数据格式错误")
            return
        }
        
        print("ChargeViewController收到充电任务推送 - VIN: \(vin), 状态: \(status), 操作类型: \(operationType)")
        
        // 更新本地数据库中对应VIN的充电任务状态
        updateChargeTaskStatusInDatabase(vin: vin, status: status, extData: extData)
        
        // 刷新充电列表显示
        DispatchQueue.main.async {
            self.loadChargeList(page: 1)
        }
        
        // 根据状态显示相应的提示
        DispatchQueue.main.async {
            switch operationType {
            case "charge_task_completed":
                if let reason = extData["reason"] as? String {
                    let message = reason == "target_reached" ? "充电目标已达成" : "充电任务已完成"
                    QMUITips.showSucceed(message, in: self.view)
                } else {
                    QMUITips.showSucceed("充电任务已完成", in: self.view)
                }
                
            case "charge_task_failed":
                if let reason = extData["reason"] as? String {
                    let message: String
                    switch reason {
                    case "vehicle_data_error":
                        message = "车辆数据获取失败，充电监控中断"
                    case "timeout":
                        message = "充电监控超时"
                    default:
                        message = "充电任务失败：\(reason)"
                    }
                    QMUITips.showError(message, in: self.view)
                } else {
                    QMUITips.showError("充电任务失败", in: self.view)
                }
                
            case "charge_task_cancelled":
                QMUITips.showInfo("充电任务已取消", in: self.view)
                
            default:
                break
            }
        }
    }
    
    /// 根据VIN更新数据库中的充电任务状态
    private func updateChargeTaskStatusInDatabase(vin: String, status: String, extData: [String: Any]) {
        do {
            try AppDatabase.dbQueue.write { db in
                // 查找该VIN最新的未完成任务
                let sql = """
                    SELECT * FROM chargeTask 
                    WHERE vin = ? AND finalStatus IN ('PREPARING', 'RUNNING', 'CHARGING')
                    ORDER BY startTime DESC 
                    LIMIT 1
                """
                
                var latestTaskId: Int64? = nil
                
                if var record = try ChargeTaskRecord.fetchOne(db, sql: sql, arguments: [vin]) {
                    latestTaskId = record.id
                    
                    // 更新任务状态
                    record.finalStatus = status
                    record.endTime = Date()
                    
                    // 如果推送包含最终的车辆数据，更新相关字段
                    if let finalSoc = extData["finalSoc"] as? Int {
                        record.endSoc = finalSoc
                    }
                    if let finalRange = extData["finalRange"] as? Double {
                        record.endRange = Int(finalRange)
                    }
                    if let reason = extData["reason"] as? String {
                        record.finalMessage = reason
                    }
                    
                    try record.save(db)
                    print("已更新VIN \(vin) 的最新充电任务状态为: \(status)")
                } else {
                    print("未找到VIN \(vin) 的活跃充电任务")
                }
                
                // 处理老数据：将除最新任务外的所有"准备中"或"充电中"状态的任务标记为"完成"
                let updateOldTasksSql: String
                let arguments: [DatabaseValueConvertible]
                
                if let taskId = latestTaskId {
                    // 如果找到了最新任务，排除它
                    updateOldTasksSql = """
                        UPDATE chargeTask 
                        SET finalStatus = 'COMPLETED', endTime = ? 
                        WHERE vin = ? AND finalStatus IN ('PREPARING', 'CHARGING') AND id != ?
                    """
                    arguments = [Date(), vin, taskId]
                } else {
                    // 如果没有找到最新任务，更新所有老的准备中或充电中的任务
                    updateOldTasksSql = """
                        UPDATE chargeTask 
                        SET finalStatus = 'COMPLETED', endTime = ? 
                        WHERE vin = ? AND finalStatus IN ('PREPARING', 'CHARGING')
                    """
                    arguments = [Date(), vin]
                }
                
                let updatedCount = try db.execute(sql: updateOldTasksSql, arguments: StatementArguments(arguments))
                print("已将VIN \(vin) 的 \(updatedCount) 个老的准备中/充电中任务标记为完成")
            }
        } catch {
            print("更新充电任务状态失败: \(error)")
        }
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
        
        let task = chargeTasks[indexPath.row]
        
        // 检查任务状态，如果是正在准备或充电中，显示取消选项
        if task.status == "PREPARING" || task.status == "RUNNING" || task.status == "CHARGING" {
            showCancelChargeConfirmation(for: task)
        } else {
            showTaskDetail(task)
        }
    }
    
    // MARK: - 侧滑删除功能
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let task = chargeTasks[indexPath.row]
        // 只有已完成、已取消或失败的任务才能删除
        return task.status == "COMPLETED" || task.status == "CANCELLED" || task.status == "FAILED"
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
    
    private func showCancelChargeConfirmation(for task: ChargeTaskModel) {
        let alert = UIAlertController(
            title: "取消充电任务", 
            message: "确定要取消当前的充电任务吗？", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { _ in
            self.cancelChargeTask(task)
        }))
        
        present(alert, animated: true)
    }
    
    private func cancelChargeTask(_ task: ChargeTaskModel) {
        NetworkManager.shared.stopChargeMonitoring { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    if success {
                        // 更新本地数据库状态为已取消
                        self?.updateChargeTaskInDatabase(taskId: task.id, status: "CANCELLED", endTime: Date())
                        
                        // 刷新充电列表
                        self?.loadChargeList(page: 1)
                        
                        // 清理Live Activity
                        LiveActivityManager.shared.cleanupAllActivities()
                        
                        self?.showAlert(title: "取消成功", message: "充电任务已成功取消")
                    } else {
                        self?.showAlert(title: "取消失败", message: "服务器返回失败状态")
                    }
                case .failure(let error):
                    self?.showAlert(title: "取消失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    /// 更新本地数据库中的充电任务状态
    private func updateChargeTaskInDatabase(taskId: Int, status: String, endTime: Date? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AppDatabase.dbQueue.write { db in
                    // 查找对应的任务记录
                    if var record = try ChargeTaskRecord.fetchOne(db, key: taskId) {
                        // 更新状态和结束时间
                        record.finalStatus = status
                        if let endTime = endTime {
                            record.endTime = endTime
                        }
                        
                        // 保存更新
                        try record.save(db)
                        print("任务 \(taskId) 状态已更新为: \(status)")
                        
                        // 在主线程更新UI
                        DispatchQueue.main.async {
                            self?.loadChargeList(page: 1) // 刷新列表显示最新状态
                        }
                    } else {
                        print("未找到任务ID为 \(taskId) 的记录")
                    }
                }
            } catch {
                print("更新数据库失败: \(error)")
                DispatchQueue.main.async {
                    self?.showAlert(title: "数据库更新失败", message: "无法更新本地任务状态")
                }
            }
        }
    }
    
    private func showTaskDetail(_ task: ChargeTaskModel) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var detailText = ""
        detailText += "任务ID: \(task.id)\n"
        detailText += "车辆VIN: \(task.vin)\n"
        detailText += "目标里程: \(String(format: "%.1f", task.targetKm)) km\n"
        detailText += "初始里程: \(String(format: "%.1f", task.initialKm)) km\n"
        detailText += "起始电量: \(String(format: "%.1f", task.initialKwh)) kWh\n"
        detailText += "目标电量: \(String(format: "%.1f", task.targetKwh)) kWh\n"
        detailText += "已充电量: \(String(format: "%.1f", task.chargedKwh)) kWh\n"
        detailText += "任务状态: \(task.statusText)\n"
        detailText += "创建时间: \(task.createdAt)\n"
        
        if let finishTime = task.finishTime, !finishTime.isEmpty {
            detailText += "完成时间: \(finishTime)\n"
        }
        
        detailText += "充电时长: \(task.chargeDuration)\n"
        
        if let message = task.message, !message.isEmpty {
            detailText += "\n备注信息:\n\(message)"
        }
        
        let modal = ModalView()
        modal.text = detailText
        modal.show()
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
                    print("充电任务记录 \(task.id) 已从数据库中删除")
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
        picker.maximumDate = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        picker.minuteInterval = 5
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
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .center
        
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
        switchControlStack.axis = .vertical
        switchControlStack.spacing = 4
        switchControlStack.alignment = .fill
        
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
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
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
