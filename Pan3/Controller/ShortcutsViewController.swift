//
//  ShortcutsViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import SnapKit
import CoreNFC
import MJRefresh

class ShortcutsViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var siriView: UIScrollView!
    @IBOutlet weak var shortcutsView: UIScrollView!
    
    // MARK: - 行程记录相关属性
    private var tripRecords: [TripRecord] = []
    private var groupedTripRecords: [(date: String, trips: [TripRecord])] = []
    private var isLoading = false
    private var isSyncing = false
    private var isGeocoding = false  // 标记是否正在进行地址解析
    private var addressVisibilityButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationItems()
        setupTableView()
        setupNotifications()
        
        // 首次加载：先从CoreData加载本地数据，然后从服务器同步
        loadLocalTripRecords()
        syncTripRecordsFromServer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 每次页面显示时，检查是否有需要解析地址的记录
        checkAndTriggerGeocodingIfNeeded()
    }
    
    deinit {
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        // 监听地址解析完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddressUpdated),
            name: GeocodingService.addressDidUpdateNotification,
            object: nil
        )
    }
    
    @objc private func handleAddressUpdated() {
        print("[ShortcutsViewController] 收到地址更新通知，刷新列表")
        
        // 重置解析标记
        isGeocoding = false
        
        // 重新加载本地数据并刷新 UI
        loadLocalTripRecords()
    }
    
    // MARK: - Geocoding Management
    
    /// 检查并触发地址解析（如果需要）
    private func checkAndTriggerGeocodingIfNeeded() {
        // 如果正在解析，跳过
        guard !isGeocoding else {
            print("[ShortcutsViewController] 地址解析正在进行中，跳过")
            return
        }
        
        // 获取所有需要解析地址的记录
        let recordsNeedingGeocoding = CoreDataManager.shared.getTripRecordsNeedingGeocoding()
        
        guard !recordsNeedingGeocoding.isEmpty else {
            print("[ShortcutsViewController] 没有需要解析地址的记录")
            return
        }
        
        print("[ShortcutsViewController] 发现 \(recordsNeedingGeocoding.count) 条记录需要解析地址，开始解析...")
        
        // 标记为正在解析
        isGeocoding = true
        
        // 触发批量解析
        GeocodingService.shared.geocodeTripRecords(recordsNeedingGeocoding)
    }
    
    // MARK: - 点击事件
    @IBAction func changeSegment(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            siriView.isHidden = true
            tableView.isHidden = false
            shortcutsView.isHidden = true
        }else if sender.selectedSegmentIndex == 1 {
            siriView.isHidden = false
            tableView.isHidden = true
            shortcutsView.isHidden = true
        }else if sender.selectedSegmentIndex == 2 {
            siriView.isHidden = true
            tableView.isHidden = true
            shortcutsView.isHidden = false
        }
    }
    
    @IBAction func writeNFC(_ sender: Any) {
        // 检查设备是否支持NFC
        guard NFCNDEFReaderSession.readingAvailable else {
            let alert = UIAlertController(title: "不支持NFC", message: "此设备不支持NFC功能或NFC功能未启用", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "请将iPhone靠近NFC标签进行写入"
        session.begin()
    }
    
    @IBAction func openShortcuts(_ sender: Any) {
        if let url = URL(string: "shortcuts://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let alert = UIAlertController(title: "无法打开", message: "无法打开快捷指令App", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // 用户取消，不显示错误
                    break
                default:
                    let alert = UIAlertController(title: "NFC错误", message: nfcError.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // 检测到NDEF消息，但我们需要写入功能
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "未检测到有效的NFC标签")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "连接NFC标签失败: \(error.localizedDescription)")
                return
            }
            
            // 创建NDEF消息
            let payload = "Pan3_Car_Lock".data(using: .utf8)!
            let record = NFCNDEFPayload(format: .nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data(), payload: payload)
            let message = NFCNDEFMessage(records: [record])
            
            // 写入NDEF消息
            tag.writeNDEF(message) { error in
                if let error = error {
                    session.invalidate(errorMessage: "写入失败: \(error.localizedDescription)")
                } else {
                    session.alertMessage = "写入成功！"
                    session.invalidate()
                    
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "成功", message: "已成功写入到NFC标签", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - 行程记录相关方法
    
    /// 设置导航栏按钮
    private func setupNavigationItems() {
        // 左侧统计按钮（使用现代化 API）
        let statisticsBtn = UIButton(type: .system)
        var statsConfig = UIButton.Configuration.plain()
        statsConfig.image = UIImage(systemName: "chart.bar.fill")
        statsConfig.title = "行程统计"
        statsConfig.imagePadding = 4
        statsConfig.imagePlacement = .leading
        statsConfig.baseForegroundColor = .label
        statisticsBtn.configuration = statsConfig
        statisticsBtn.addTarget(self, action: #selector(showStatistics), for: .touchUpInside)
        
        let statisticsButton = UIBarButtonItem(customView: statisticsBtn)
        navigationItem.leftBarButtonItem = statisticsButton
        
        // 右侧隐藏地址按钮（使用现代化 API）
        addressVisibilityButton = UIButton(type: .system)
        addressVisibilityButton.addTarget(self, action: #selector(toggleAddressVisibility), for: .touchUpInside)
        
        // 使用 iOS 15+ 的 UIButton.Configuration API
        updateAddressVisibilityButton()
        
        let rightBarButton = UIBarButtonItem(customView: addressVisibilityButton)
        navigationItem.rightBarButtonItem = rightBarButton
    }
    
    @objc private func showStatistics() {
        let statisticsVC = TripStatisticsViewController()
        statisticsVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(statisticsVC, animated: true)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TripRecordCell.self, forCellReuseIdentifier: "TripRecordCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemGroupedBackground
        
        // 使用 MJRefresh 添加下拉刷新
        let header = MJRefreshNormalHeader { [weak self] in
            self?.refreshTripRecords()
        }
        header.lastUpdatedTimeLabel?.isHidden = true
        tableView.mj_header = header
    }
    
    /// 从CoreData加载本地行程记录
    private func loadLocalTripRecords() {
        tripRecords = CoreDataManager.shared.fetchTripRecords()
        groupTripRecordsByDate()
        tableView.reloadData()
        print("[ShortcutsVC] 从CoreData加载了 \(tripRecords.count) 条行程记录")
        
        // 检查是否显示空状态
        if tripRecords.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    /// 从服务器同步行程记录
    private func syncTripRecordsFromServer() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        NetworkManager.shared.getTripRecordsFromServer { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                self?.tableView.mj_header?.endRefreshing()
                
                switch result {
                case .success(let tripsData):
                    guard !tripsData.isEmpty else {
                        print("[ShortcutsVC] 服务器没有新的行程记录")
                        return
                    }
                    
                    print("[ShortcutsVC] 从服务器获取了 \(tripsData.count) 条行程记录，开始同步到CoreData...")
                    
                    // 保存到CoreData
                    let savedRecords = CoreDataManager.shared.syncTripRecordsFromServer(tripsData)
                    
                    if !savedRecords.isEmpty {
                        print("[ShortcutsVC] 成功同步 \(savedRecords.count) 条行程记录到CoreData")
                        
                        // ⚠️ 修复：只提取实际保存成功的记录ID，通知服务器删除
                        let tripIds = savedRecords.compactMap { record -> Int? in
                            return Int(record.recordID ?? "0")
                        }.filter { $0 > 0 }
                        
                        if !tripIds.isEmpty {
                            print("[ShortcutsVC] 通知服务器删除 \(tripIds.count) 条已同步的行程记录")
                            self?.confirmSyncComplete(tripIds: tripIds)
                        } else {
                            print("[ShortcutsVC] 警告：没有有效的recordID可确认")
                        }
                        
                        // 重新加载本地数据
                        self?.loadLocalTripRecords()
                    }
                    
                case .failure(let error):
                    print("[ShortcutsVC] 同步失败: \(error.localizedDescription)")
                    QMUITips.showError("同步失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 确认同步完成，通知服务器删除数据
    private func confirmSyncComplete(tripIds: [Int]) {
        NetworkManager.shared.confirmTripSyncComplete(tripIds: tripIds) { result in
            switch result {
            case .success(let stats):
                print("[ShortcutsVC] 服务器已删除 \(stats["deletedTrips"] ?? 0) 条行程记录")
            case .failure(let error):
                print("[ShortcutsVC] 确认同步失败: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func refreshTripRecords() {
        // 下拉刷新：从服务器同步最新数据
        syncTripRecordsFromServer()
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func toggleAddressVisibility() {
        // 切换状态
        let ud = UserDefaults.standard
        let currentState = ud.bool(forKey: "isBlurAddress")
        ud.set(!currentState, forKey: "isBlurAddress")
        
        // 更新按钮样式
        updateAddressVisibilityButton()
        
        // 刷新列表
        tableView.reloadData()
    }
    
    /// 更新地址可见性按钮的样式
    private func updateAddressVisibilityButton() {
        let isBlurAddress = UserDefaults.standard.bool(forKey: "isBlurAddress")
        
        // 使用 iOS 15+ 的 UIButton.Configuration API
        var config = UIButton.Configuration.plain()
        
        if isBlurAddress {
            // 隐藏地址状态
            config.image = UIImage(systemName: "eye.slash.fill")
            config.title = "隐藏地址"
        } else {
            // 显示地址状态
            config.image = UIImage(systemName: "eye.fill")
            config.title = "显示地址"
        }
        
        config.imagePadding = 4
        config.imagePlacement = .leading
        config.baseForegroundColor = .label
        
        addressVisibilityButton.configuration = config
    }
    
    // MARK: - 数据分组方法
    private func groupTripRecordsByDate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // 按日期分组
        var groupedDict: [String: [TripRecord]] = [:]
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        
        for trip in tripRecords {
            let dayStart = calendar.startOfDay(for: trip.startTime)
            let dayKey = dayFormatter.string(from: dayStart)
            
            if groupedDict[dayKey] == nil {
                groupedDict[dayKey] = []
            }
            groupedDict[dayKey]?.append(trip)
        }
        
        // 转换为有序数组并生成显示标题
        groupedTripRecords = groupedDict.sorted { first, second in
            return first.key > second.key // 最新日期在前
        }.map { (dateKey, trips) in
            let displayTitle = formatDateTitle(dateKey: dateKey, today: today, yesterday: yesterday)
            return (date: displayTitle, trips: trips)
        }
    }
    
    private func formatDateTitle(dateKey: String, today: Date, yesterday: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateKey) else {
            return dateKey
        }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        // 格式化显示
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = displayFormatter.string(from: date)
        
        // 获取星期几
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        let weekday = weekdayFormatter.string(from: date)
        
        var result = "\(dateString) \(weekday)"
        
        // 添加今天/昨天标识
        if calendar.isDate(dayStart, inSameDayAs: today) {
            result += " 今天"
        } else if calendar.isDate(dayStart, inSameDayAs: yesterday) {
            result += " 昨天"
        }
        
        return result
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
        
        let imageView = UIImageView(image: UIImage(systemName: "car.fill"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = "暂无行程记录"
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .systemGray2
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "开始您的第一次行程吧"
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
}

// MARK: - UITableViewDataSource

extension ShortcutsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return groupedTripRecords.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < groupedTripRecords.count else { return 0 }
        return groupedTripRecords[section].trips.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TripRecordCell", for: indexPath) as! TripRecordCell
        guard indexPath.section < groupedTripRecords.count,
              indexPath.row < groupedTripRecords[indexPath.section].trips.count else {
            return cell
        }
        let tripRecord = groupedTripRecords[indexPath.section].trips[indexPath.row]
        
        // 转换为TripRecordData以配置cell（临时方案）
        let tripData = convertToTripRecordData(tripRecord)
        cell.configure(with: tripData)
        return cell
    }
    
    /// 将TripRecord转换为TripRecordData
    private func convertToTripRecordData(_ record: TripRecord) -> TripRecordData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let departureTime = dateFormatter.string(from: record.startTime)
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let startTime = dateFormatter.string(from: record.startTime)
        let endTime = dateFormatter.string(from: record.endTime ?? Date())
        
        return TripRecordData(
            id: Int(record.id),
            vin: "",
            departureAddress: record.displayStartAddress,
            destinationAddress: record.displayEndAddress,
            departureTime: departureTime,
            duration: record.tripDuration,
            drivingMileage: record.totalDistance,
            consumedMileage: Double(record.consumedRange),
            achievementRate: record.achievementRate,
            powerConsumption: record.powerConsumption,
            averageSpeed: Double(record.avgSpeed),
            energyEfficiency: record.energyEfficiency,
            startTime: startTime,
            endTime: endTime,
            startLocation: "",
            endLocation: "",
            startLatLng: nil,
            endLatLng: nil,
            startMileage: 0,
            endMileage: 0,
            startRange: Double(record.startRangeKm),
            endRange: Double(record.endRangeKm),
            startSoc: Int(record.startSoc),
            endSoc: Int(record.endSoc),
            createdAt: "",
            updatedAt: ""
        )
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < groupedTripRecords.count else { return nil }
        return groupedTripRecords[section].date
    }
}

// MARK: - UITableViewDelegate

extension ShortcutsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section < groupedTripRecords.count,
              indexPath.row < groupedTripRecords[indexPath.section].trips.count else {
            return
        }
        
        let tripRecord = groupedTripRecords[indexPath.section].trips[indexPath.row]
        
        // 跳转到详情页面
        let detailVC = TripDetailViewController(tripRecord: tripRecord)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    // MARK: - 滑动删除
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard indexPath.section < groupedTripRecords.count,
                  indexPath.row < groupedTripRecords[indexPath.section].trips.count else {
                return
            }
            
            let tripRecord = groupedTripRecords[indexPath.section].trips[indexPath.row]
            
            // 二次确认
            let alert = UIAlertController(
                title: "确认删除",
                message: "确定要删除这条行程记录吗？",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
                // 从CoreData删除
                CoreDataManager.shared.deleteTripRecord(tripRecord)
                
                // 更新UI
                self?.loadLocalTripRecords()
                
                QMUITips.showSucceed("删除成功")
            })
            
            present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "删除"
    }
    
    // 旧的didSelectRowAt内容（如果有其他逻辑需要保留）
    func _old_tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section < groupedTripRecords.count,
              indexPath.row < groupedTripRecords[indexPath.section].trips.count,
              let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        // 显示分享选项的sheet弹窗
        let alertController = UIAlertController(title: "行程记录", message: nil, preferredStyle: .actionSheet)
        alertController.view.tintColor = .white
        
        // 分享选项
        let shareAction = UIAlertAction(title: "分享行程", style: .default) { [weak self] _ in
            self?.shareTrip(cell: cell)
        }
        
        // 取消选项
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        alertController.addAction(shareAction)
        alertController.addAction(cancelAction)
        
        // 对于iPad，需要设置popover的源
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - 分享行程方法
    private func shareTrip(cell: UITableViewCell) {
        // 获取cell对应的indexPath
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section < groupedTripRecords.count,
              indexPath.row < groupedTripRecords[indexPath.section].trips.count else {
            return
        }
        
        // 创建带有渐变背景和APP信息的分享图片
        let image = cell.qmui_snapshotImage(afterScreenUpdates: true)
        let shareImage = createShareImage(from: image)
        
        // 分享图片
        let activityViewController = UIActivityViewController(activityItems: [shareImage], applicationActivities: nil)
        
        // 对于iPad，需要设置popover的源
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    // MARK: - 创建分享图片
    private func createShareImage(from cellImage: UIImage) -> UIImage {
        // 设置画布尺寸，增加底部空间用于放置logo和名称
        let padding: CGFloat = 40
        let logoHeight: CGFloat = 60
        let appNameHeight: CGFloat = 38
        let bottomSpace: CGFloat = 40
        
        let canvasWidth = cellImage.size.width + padding * 2
        let canvasHeight = cellImage.size.height + padding * 2 + logoHeight + appNameHeight + bottomSpace
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 创建渐变背景
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
                return
            }
            
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: canvasWidth, y: canvasHeight)
            cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            
            // 绘制cell图片（添加圆角和阴影效果）
            let cellRect = CGRect(x: padding, y: padding, width: cellImage.size.width, height: cellImage.size.height)
            
            // 添加阴影
            cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            
            // 绘制圆角矩形背景
            let roundedRect = UIBezierPath(roundedRect: cellRect, cornerRadius: 12)
            cgContext.addPath(roundedRect.cgPath)
            cgContext.clip()
            
            // 绘制cell图片
            cellImage.draw(in: cellRect)
            
            // 重置裁剪区域
            cgContext.resetClip()
            
            // 绘制APP名称
            let appName = "胖3助手"
            let nameRect = CGRect(x: padding,
                                y: cellRect.maxY + 80,
                                width: canvasWidth - padding * 2,
                                height: appNameHeight)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle,
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
                    shadow.shadowOffset = CGSize(width: 0, height: 1)
                    shadow.shadowBlurRadius = 2
                    return shadow
                }()
            ]
            
            appName.draw(in: nameRect, withAttributes: nameAttributes)
            
            // 添加底部标语
            let slogan = "智能出行，尽在掌握"
            let sloganRect = CGRect(x: padding, 
                                  y: nameRect.maxY,
                                  width: canvasWidth - padding * 2,
                                  height: 20)
            
            let sloganAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]
            
            slogan.draw(in: sloganRect, withAttributes: sloganAttributes)
            
            // 绘制右下角圆形二维码
            if let qrCodeImage = UIImage(named: "qrcode_app") {
                let qrCodeSize: CGFloat = 100
                let qrCodePadding: CGFloat = 20
                let qrCodeRect = CGRect(x: canvasWidth - qrCodeSize - qrCodePadding,
                                      y: canvasHeight - qrCodeSize - qrCodePadding,
                                      width: qrCodeSize,
                                      height: qrCodeSize)
                
                // 绘制圆形二维码图片（使用圆形裁剪）
                let clipPath = UIBezierPath(ovalIn: qrCodeRect)
                clipPath.addClip()
                qrCodeImage.draw(in: qrCodeRect)
            }
        }
    }
}
