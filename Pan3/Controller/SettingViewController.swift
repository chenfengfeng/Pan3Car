//
//  SettingViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import Alamofire
import Kingfisher

class SettingViewController: UIViewController {
    
    @IBOutlet weak var avatarView: UIImageView!
    @IBOutlet weak var nickName: UILabel!
    @IBOutlet weak var carNumber: UILabel!
    @IBOutlet weak var tableView: UITableView!
    var versionClickCount = 0
    var isDeveloperModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "shouldEnableDebug")
    }
    
    private var settingSections: [[(String, String, String)]] {
        var sections = [
            // 第一组：基本设置
            [
                ("车架号", "vin", "car.fill"),
                ("手机号", "phone", "phone.fill"),
                ("切换首页欢迎词", "greeting", "message.fill"),
                //增加二次确认switch
                ("二次确认", "confirm", "checkmark.square.fill"),
//                ("切换服务器", "server", "server.rack"),
                ("用户反馈", "feedback", "envelope.fill"),
                ("常见问题", "help", "questionmark.circle.fill"),
                ("APP使用教程", "tutorial", "book.fill"),
                ("导入行程数据", "importTrips", "arrow.down.doc.fill")
            ],
            // 第二组：账户操作
            [
                ("注销用户", "logout", "person.badge.minus"),
                ("退出登录", "exit", "arrow.right.square")
            ]
        ]
        
        // 如果开发者模式开启，在退出登录下方添加开发者模式组
        if isDeveloperModeEnabled {
            sections.append([
                ("开发者模式", "developer", "hammer.fill")
            ])
        }
        
        return sections
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupData()
        setupCarNumberTapGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupData()
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // 注册带有subtitle样式的cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
        
        // 设置tableView样式
        if #available(iOS 13.0, *) {
            // 对于iOS 13+，我们需要在Storyboard中设置为Inset Grouped样式
            // 这里只是确保其他属性正确设置
            tableView.backgroundColor = UIColor.systemGroupedBackground
        }
        
        
    }
    
    func setupData() {
        if let user = UserManager.shared.userInfo {
            nickName.text = user.userName
            
            // 设置头像
            if !user.headUrl.isEmpty {
                avatarView.kf.setImage(with: URL(string: user.headUrl))
            } else {
                // 使用默认头像
                avatarView.image = UIImage(systemName: "person.circle.fill")
            }
        }
        
        if let user = UserManager.shared.userInfo {
            // 检查是否有自定义的车牌号显示
            let phoneKey = user.realPhone
            let customCarNumber = UserDefaults.standard.string(forKey: "custom_car_number_\(phoneKey)")
            carNumber.text = customCarNumber ?? user.plateLicenseNo
        }
    }
    
    func setupCarNumberTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(carNumberTapped))
        carNumber.addGestureRecognizer(tapGesture)
        carNumber.isUserInteractionEnabled = true
    }
    
    @objc func carNumberTapped() {
        guard let user = UserManager.shared.userInfo else { return }
        
        let alert = UIAlertController(title: "自定义车牌号显示", message: "此功能仅为本地显示，不会影响实际数据", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "请输入自定义显示内容"
            let phoneKey = user.realPhone
            textField.text = UserDefaults.standard.string(forKey: "custom_car_number_\(phoneKey)") ?? user.plateLicenseNo
        }
        
        let confirmAction = UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let textField = alert.textFields?.first,
                  let customText = textField.text,
                  !customText.isEmpty else { return }
            
            let phoneKey = user.realPhone
            UserDefaults.standard.set(customText, forKey: "custom_car_number_\(phoneKey)")
            self?.carNumber.text = customText
        }
        
        let resetAction = UIAlertAction(title: "恢复原始", style: .destructive) { [weak self] _ in
            let phoneKey = user.realPhone
            UserDefaults.standard.removeObject(forKey: "custom_car_number_\(phoneKey)")
            self?.carNumber.text = user.plateLicenseNo
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        alert.addAction(confirmAction)
        alert.addAction(resetAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    @objc func versionLabelTapped() {
        // 如果已经是开发者模式，提示用户
        if isDeveloperModeEnabled {
            QMUITips.show(withText: "已经是开发者模式")
            return
        }
        
        versionClickCount += 1
        
        if versionClickCount == 10 {
            UserDefaults.standard.set(true, forKey: "shouldEnableDebug")
            if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
                sharedDefaults.set(true, forKey: "shouldEnableDebug")
            }
            QMUITips.show(withText: "🎉开启开发者模式")
            tableView.reloadData()
        } else {
            let remainingClicks = 10 - versionClickCount
            let tip = QMUITips.show(withText: "再点击\(remainingClicks)下开启开发者模式")
            tip.isUserInteractionEnabled = false
        }
    }
}

// MARK: - UITableViewDataSource
extension SettingViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return settingSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingSections[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingCell")
        let item = settingSections[indexPath.section][indexPath.row]
        
        cell.textLabel?.text = item.0
        cell.accessoryType = .disclosureIndicator
        
        // 设置图标
        cell.imageView?.image = UIImage(systemName: item.2)
        cell.imageView?.tintColor = .label
        
        // 设置注销用户字体为红色
        if item.1 == "logout" {
            cell.textLabel?.textColor = .systemRed
            cell.imageView?.tintColor = .systemRed
        } else {
            cell.textLabel?.textColor = .label
        }
        
        // 设置详细信息
        switch item.1 {
        case "vin":
            cell.detailTextLabel?.text = UserManager.shared.defaultVin
        case "phone":
            cell.detailTextLabel?.text = UserManager.shared.userInfo?.realPhone
        case "greeting":
            cell.detailTextLabel?.text = getCurrentGreetingType()
        case "server":
            cell.detailTextLabel?.text = getCurrentServerType()
        case "confirm":
            // 为二次确认添加开关控件
            let confirmSwitch = UISwitch()
            confirmSwitch.isOn = getConfirmationEnabled()
            confirmSwitch.addTarget(self, action: #selector(confirmSwitchChanged(_:)), for: .valueChanged)
            cell.accessoryView = confirmSwitch
            cell.accessoryType = .none
            cell.detailTextLabel?.text = nil
        case "developer":
            cell.detailTextLabel?.text = "开启"
        default:
            cell.detailTextLabel?.text = nil
        }
        
        cell.selectionStyle = .default
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = settingSections[indexPath.section][indexPath.row]
        
        switch item.1 {
        case "vin":
            copyVinToClipboard()
        case "phone":
            break // 手机号不需要特殊处理
        case "greeting":
            showGreetingOptions()
        case "server":
            showServerOptions()
        case "confirm":
            // 二次确认由开关控件处理，这里不需要额外操作
            break
        case "feedback":
            showFeedbackAlert()
        case "help":
            showHelpViewController()
        case "tutorial":
            showAppTutorial()
        case "importTrips":
            showImportTripsConfirmation()
        case "logout":
            showLogoutConfirmation()
        case "exit":
            showExitConfirmation()
        case "developer":
            showDeveloperModeConfirmation()
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // 只在最后一个section显示版本信息
        if section == settingSections.count - 1 {
            let footerView = UIView()
            footerView.backgroundColor = UIColor.clear
            
            let versionLabel = UILabel()
            versionLabel.textAlignment = .center
            versionLabel.font = UIFont.systemFont(ofSize: 12)
            versionLabel.textColor = UIColor.secondaryLabel
            versionLabel.numberOfLines = 0
            
            // 获取版本号和build号
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
            
            versionLabel.text = "版本 \(version) (Build \(build))"
            
            // 为版本号标签添加点击手势
            let versionTapGesture = UITapGestureRecognizer(target: self, action: #selector(versionLabelTapped))
            versionLabel.addGestureRecognizer(versionTapGesture)
            versionLabel.isUserInteractionEnabled = true
            
            footerView.addSubview(versionLabel)
            versionLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(20)
                make.bottom.equalToSuperview().offset(-20)
                make.leading.greaterThanOrEqualToSuperview().offset(20)
                make.trailing.lessThanOrEqualToSuperview().offset(-20)
            }
            
            return footerView
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // 只在最后一个section显示footer
        if section == settingSections.count - 1 {
            return 100
        }
        return 0
    }
}

// MARK: - Private Methods
private extension SettingViewController {
    
    // MARK: - 二次确认相关方法
    func getConfirmationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "confirmation_enabled")
    }
    
    @objc func confirmSwitchChanged(_ sender: UISwitch) {
        setConfirmationEnabled(sender.isOn)
    }
    
    func setConfirmationEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "confirmation_enabled")
        UserDefaults.standard.synchronize()
    }
    
    func copyVinToClipboard() {
        guard let vin = UserManager.shared.defaultVin else {
            QMUITips.show(withText: "车架号不可用")
            return
        }
        
        UIPasteboard.general.string = vin
        QMUITips.show(withText: "车架号已复制到剪贴板")
    }
    
    func getCurrentGreetingType() -> String {
        let greetingType = UserDefaults.standard.string(forKey: "GreetingType") ?? "nickname"
        switch greetingType {
        case "nickname":
            return "昵称"
        case "carNumber":
            return "车牌号"
        case "custom":
            return "自定义"
        case "none":
            return "不显示"
        default:
            return "昵称"
        }
    }
    
    func getCurrentServerType() -> String {
        let serverType = UserDefaults.standard.string(forKey: "ServerType") ?? "main"
        switch serverType {
        case "main":
            return "主服务器"
        case "spare":
            return "备用服务器"
        default:
            return "主服务器"
        }
    }
    
    func showGreetingOptions() {
        let alert = UIAlertController(title: "选择首页欢迎词", message: "请选择首页显示的欢迎词类型", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "昵称", style: .default) { _ in
            self.setGreetingType("nickname")
        })
        
        alert.addAction(UIAlertAction(title: "车牌号", style: .default) { _ in
            self.setGreetingType("carNumber")
        })
        
        alert.addAction(UIAlertAction(title: "自定义", style: .default) { _ in
            self.showCustomGreetingInput()
        })
        
        alert.addAction(UIAlertAction(title: "不显示", style: .default) { _ in
            self.setGreetingType("none")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 适配iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 2, section: 0))
        }
        
        present(alert, animated: true)
    }
    
    func showCustomGreetingInput() {
        let alert = UIAlertController(title: "自定义欢迎词", message: "请输入自定义的欢迎词", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "请输入欢迎词"
            textField.text = UserDefaults.standard.string(forKey: "CustomGreeting")
        }
        
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                UserDefaults.standard.set(text, forKey: "CustomGreeting")
                self.setGreetingType("custom")
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func setGreetingType(_ type: String) {
        UserDefaults.standard.set(type, forKey: "GreetingType")
        tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .none)
        
        // 通知首页更新欢迎词
        NotificationCenter.default.post(name: NSNotification.Name("UpdateGreeting"), object: nil)
    }
    
    func showServerOptions() {
        let alert = UIAlertController(title: "选择服务器", message: "请选择要使用的服务器", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "主服务器", style: .default) { _ in
            self.setServerType("main")
        })
        
        alert.addAction(UIAlertAction(title: "备用服务器", style: .default) { _ in
            self.setServerType("spare")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 适配iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 4, section: 0))
        }
        
        present(alert, animated: true)
    }
    
    func setServerType(_ type: String) {
        UserDefaults.standard.set(type, forKey: "ServerType")
        if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
            sharedDefaults.set(type, forKey: "ServerType")
        }
        tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
        
        let serverName = type == "main" ? "主服务器" : "备用服务器"
        QMUITips.show(withText: "已切换到\(serverName)")
    }
    
    func showFeedbackAlert() {
        let alert = UIAlertController(title: "用户反馈", message: "请选择反馈方式", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "邮件反馈", style: .default) { _ in
            self.openEmailFeedback()
        })
        
        alert.addAction(UIAlertAction(title: "微信联系我", style: .default) { _ in
            self.showInAppFeedback()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 适配iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 3, section: 0))
        }
        
        present(alert, animated: true)
    }
    
    func openEmailFeedback() {
        let email = "dd031068@gmail.com"
        let subject = "Pan3应用反馈"
        let body = "请在此处描述您的问题或建议：\n\n"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                QMUITips.show(withText: "无法打开邮件应用")
            }
        }
    }
    
    func showInAppFeedback() {
        let alert = UIAlertController(title: "微信联系我", message: "有啥问题加我微信联系", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "点击复制微信号", style: .default) { _ in
            let wxid = "chenfengfeng-1989"
            UIPasteboard.general.string = wxid
            QMUITips.show(withText: "复制成功")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func showHelpViewController() {
        let helpVC = HelpViewController()
        helpVC.hidesBottomBarWhenPushed = true
        navigationController?.show(helpVC, sender: self)
    }
    
    func showAppTutorial() {
        WechatShowView.show(from: self)
    }
    
    func showLogoutConfirmation() {
        let alert = UIAlertController(title: "注销用户", message: "注销后将清除所有登录数据，确定要注销吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "确定注销", style: .destructive) { _ in
            self.performLogout()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func showExitConfirmation() {
        let alert = UIAlertController(title: "退出登录", message: "确定要退出登录吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "确定退出", style: .default) { _ in
            self.performLogout()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func showDeveloperModeConfirmation() {
        let alert = UIAlertController(title: "开发者模式", message: "是否要关闭开发者模式？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "关闭", style: .destructive) { _ in
            self.closeDeveloperMode()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func closeDeveloperMode() {
        UserDefaults.standard.set(false, forKey: "shouldEnableDebug")
        if let sharedDefaults = UserDefaults(suiteName: "group.com.feng.pan3") {
            sharedDefaults.set(false, forKey: "shouldEnableDebug")
        }
        versionClickCount = 0 // 重置点击计数
        QMUITips.show(withText: "已关闭开发者模式")
        tableView.reloadData()
    }
    
    // MARK: - 导入行程数据相关方法
    
    func showImportTripsConfirmation() {
        // 显示导入确认对话框
        let alert = UIAlertController(
            title: "导入行程数据",
            message: "此功能将从旧服务器导入历史行程数据。\n\n✅ 系统会自动过滤已存在的记录，不会产生重复数据。\n\n⏱ 导入过程可能需要一些时间，请耐心等待。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self] _ in
            self?.importLegacyTrips()
        })
        
        present(alert, animated: true)
    }
    
    func importLegacyTrips() {
        // 显示加载提示
        QMUITips.showLoading("正在导入数据...", in: self.view)
        
        // 开始导入
        importAllTripsFromLegacyServer { [weak self] result in
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                
                switch result {
                case .success(let count):
                    if count > 0 {
                        QMUITips.showSucceed("成功导入 \(count) 条新的行程记录")
                    } else {
                        QMUITips.showInfo("所有行程记录已存在，无需重复导入")
                    }
                    
                    // 发送数据导入完成通知（即使count为0也发送，以便刷新UI）
                    NotificationCenter.default.post(name: NSNotification.Name("TripDataImported"), object: nil)
                    
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "导入失败",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    func importAllTripsFromLegacyServer(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let vin = UserManager.shared.defaultVin else {
            completion(.failure(NSError(domain: "ImportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到车架号"])))
            return
        }
        
        var allTrips: [[String: Any]] = []
        
        // 递归获取所有分页数据
        func fetchPage(_ page: Int) {
            let urlString = "https://car.dreamforge.top/get_trip_records"
            let parameters: [String: Any] = [
                "vin": vin,
                "page": page
            ]
            
            AF.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate()
                .responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        guard let json = value as? [String: Any],
                              let success = json["success"] as? Bool,
                              success,
                              let dataDict = json["data"] as? [String: Any],
                              let trips = dataDict["trips"] as? [[String: Any]],
                              let pagination = dataDict["pagination"] as? [String: Any] else {
                            completion(.failure(NSError(domain: "ImportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据格式错误"])))
                            return
                        }
                        
                        // 添加当前页的数据
                        allTrips.append(contentsOf: trips)
                        
                        print("[导入] 第\(page)页: 获取了\(trips.count)条记录，总计\(allTrips.count)条")
                        
                        // 检查是否还有下一页
//                        if let hasNext = pagination["has_next"] as? Bool, hasNext {
//                            // 继续获取下一页
//                            fetchPage(page + 1)
//                        } else {
                            // 所有数据获取完成，开始转换并保存
                            print("[导入] 数据获取完成，共\(allTrips.count)条记录，开始转换格式...")
                            
                            let convertedTrips = self.convertLegacyTripsToNewFormat(allTrips)
                            
                            // 保存到CoreData
                            let savedRecords = CoreDataManager.shared.syncTripRecordsFromServer(convertedTrips)
                            
                            print("[导入] 成功保存\(savedRecords.count)条记录到CoreData")
                            
                            completion(.success(savedRecords.count))
//                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        }
        
        // 从第1页开始
        fetchPage(1)
    }
    
    func convertLegacyTripsToNewFormat(_ legacyTrips: [[String: Any]]) -> [[String: Any]] {
        var convertedTrips: [[String: Any]] = []
        
        for trip in legacyTrips {
            var newTrip: [String: Any] = [:]
            
            // 基本字段映射
            newTrip["id"] = trip["id"] as? Int ?? 0
            newTrip["start_time"] = trip["startTime"] as? String ?? ""
            newTrip["end_time"] = trip["endTime"] as? String ?? ""
            newTrip["start_soc"] = trip["startSoc"] as? Int ?? 0
            newTrip["end_soc"] = trip["endSoc"] as? Int ?? 0
            newTrip["start_range_km"] = Int((trip["startRange"] as? Double ?? 0))
            newTrip["end_range_km"] = Int((trip["endRange"] as? Double ?? 0))
            newTrip["total_distance"] = trip["drivingMileage"] as? Double ?? 0.0
            newTrip["consumed_range"] = Int((trip["consumedMileage"] as? Double ?? 0))
            newTrip["avg_speed"] = Int((trip["averageSpeed"] as? Double ?? 0))
            newTrip["max_speed"] = 0  // 旧数据没有最大速度，设为0
            
            // 解析经纬度 (旧服务器格式: "经度,纬度" 即 "lng,lat")
            if let startLatLng = trip["startLatLng"] as? String {
                let components = startLatLng.split(separator: ",")
                if components.count == 2 {
                    newTrip["start_lon"] = Double(components[0]) ?? 0.0  // 第一个是经度
                    newTrip["start_lat"] = Double(components[1]) ?? 0.0  // 第二个是纬度
                }
            }
            
            if let endLatLng = trip["endLatLng"] as? String {
                let components = endLatLng.split(separator: ",")
                if components.count == 2 {
                    newTrip["end_lon"] = Double(components[0]) ?? 0.0  // 第一个是经度
                    newTrip["end_lat"] = Double(components[1]) ?? 0.0  // 第二个是纬度
                }
            }
            
            // 如果没有经纬度，设置默认值
            if newTrip["start_lat"] == nil {
                newTrip["start_lat"] = 0.0
                newTrip["start_lon"] = 0.0
            }
            if newTrip["end_lat"] == nil {
                newTrip["end_lat"] = 0.0
                newTrip["end_lon"] = 0.0
            }
            
            convertedTrips.append(newTrip)
        }
        
        return convertedTrips
    }
    
    func performLogout() {
        // 显示加载提示
        QMUITips.showLoading(in: self.view)
        
        // 调用退出登录接口
        NetworkManager.shared.logout { result in
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                
                switch result {
                case .success(_):
                    // 退出登录成功，清除本地数据
                    UserManager.shared.clearUserData()
                    
                    // 返回登录界面
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        let loginViewController = LoginViewController()
                        let navigationController = UINavigationController(rootViewController: loginViewController)
                        appDelegate.window?.rootViewController = navigationController
                        appDelegate.window?.makeKeyAndVisible()
                    }
                case .failure(let error):
                    // 退出登录失败，但仍然清除本地数据
                    QMUITips.show(withText: "退出登录失败：\(error.localizedDescription)，但已清除本地数据")
                    UserManager.shared.clearUserData()
                    
                    // 返回登录界面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                            let loginViewController = LoginViewController()
                            let navigationController = UINavigationController(rootViewController: loginViewController)
                            appDelegate.window?.rootViewController = navigationController
                            appDelegate.window?.makeKeyAndVisible()
                        }
                    }
                }
            }
        }
    }
}
