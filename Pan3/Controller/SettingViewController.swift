//
//  SettingViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import QMUIKit
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
                ("APP使用教程", "tutorial", "book.fill")
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
