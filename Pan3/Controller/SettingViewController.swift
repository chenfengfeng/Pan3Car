//
//  SettingViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import Kingfisher
import QMUIKit

class SettingViewController: UIViewController {
    
    @IBOutlet weak var avatarView: UIImageView!
    @IBOutlet weak var nickName: UILabel!
    @IBOutlet weak var carNumber: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    private let settingSections = [
        // 第一组：基本设置
        [
            ("车架号", "vin", "car.fill"),
            ("手机号", "phone", "phone.fill"),
            ("切换首页欢迎词", "greeting", "message.fill"),
            ("用户反馈", "feedback", "envelope.fill"),
            ("常见问题", "help", "questionmark.circle.fill")
        ],
        // 第二组：账户操作
        [
            ("注销用户", "logout", "person.badge.minus"),
            ("退出登录", "exit", "arrow.right.square")
        ]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupData()
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
        if let loginModel = UserManager.shared.loginModel {
            nickName.text = loginModel.userName
            
            // 设置头像
            if !loginModel.headUrl.isEmpty {
                avatarView.kf.setImage(with: URL(string: loginModel.headUrl))
            } else {
                // 使用默认头像
                avatarView.image = UIImage(systemName: "person.circle.fill")
            }
        }
        
        if let car = UserManager.shared.userModels?.first {
            carNumber.text = car.plateLicenseNo
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
            cell.detailTextLabel?.text = UserManager.shared.loginModel?.realPhone
        case "greeting":
            cell.detailTextLabel?.text = getCurrentGreetingType()
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
        case "feedback":
            showFeedbackAlert()
        case "help":
            showHelpViewController()
        case "logout":
            showLogoutConfirmation()
        case "exit":
            showExitConfirmation()
        default:
            break
        }
    }
}

// MARK: - Private Methods
private extension SettingViewController {
    
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
    
    func showLogoutConfirmation() {
        let alert = UIAlertController(title: "注销用户", message: "注销后将清除所有登录数据，确定要注销吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "确定注销", style: .destructive) { _ in
            self.performLogout(clearData: true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func showExitConfirmation() {
        let alert = UIAlertController(title: "退出登录", message: "确定要退出登录吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "确定退出", style: .default) { _ in
            self.performLogout(clearData: false)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func performLogout(clearData: Bool) {
        if clearData {
            // 注销用户，清除所有数据
            UserManager.shared.clearUserData()
        }
        
        // 返回登录界面
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                let loginStoryboard = UIStoryboard(name: "Login", bundle: nil)
                let loginViewController = loginStoryboard.instantiateInitialViewController()
                appDelegate.window?.rootViewController = loginViewController
                appDelegate.window?.makeKeyAndVisible()
            }
        }
    }
}
