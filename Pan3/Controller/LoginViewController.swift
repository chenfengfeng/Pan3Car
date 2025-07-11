//
//  LoginViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import UIKit
import QMUIKit
import SafariServices

class LoginViewController: UIViewController {
    @IBOutlet weak var phoneField: QMUITextField!
    @IBOutlet weak var passwdField: QMUITextField!
    @IBOutlet weak var loginBtn: QMUIButton!
    @IBOutlet weak var bottomView: UIStackView!
    @IBOutlet weak var protocolLabel: UILabel!
    lazy var checkBox: QMUICheckbox = {
        let box = QMUICheckbox()
        box.tintColor = .label
        return box
    }()
    
    // 协议URL占位符
    private let privacyPolicyURL = "https://yiweiauto.cn/privacy"
    private let userAgreementURL = "https://yiweiauto.cn/agreement"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupProtocolLabel()
        loadSavedCredentials()
    }
    
    func setupUI() {
        bottomView.insertArrangedSubview(checkBox, at: 0)
        checkBox.qmui_tapBlock = { _ in
            self.checkBox.isSelected = !self.checkBox.isSelected
        }
    }
    
    // MARK: - 获取用户信息
    func fetchUserInfo() {
        let userManager = UserManager.shared
        guard let phone = userManager.userPhone,
              let userId = userManager.userId,
              let tspUserId = userManager.tspUserId,
              let aaaUserId = userManager.aaaUserId,
              let timaToken = userManager.timaToken,
              let identityParam = userManager.identityParam else {
            QMUITips.hideAllTips()
            QMUITips.show(withText: "登录信息异常", in: view, hideAfterDelay: 2.0)
            return
        }
        
        NetworkManager.shared.getUserInfo(
            phone: phone,
            userId: userId,
            tspUserId: tspUserId,
            aaaUserID: aaaUserId,
            timaToken: timaToken,
            identityParam: identityParam
        ) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let userModels):
                    // 保存用户信息到单例
                    UserManager.shared.userModels = userModels
                    
                    // 获取车辆信息
                    self.fetchCarInfo()
                    
                case .failure(let error):
                    QMUITips.hideAllTips()
                    QMUITips.show(withText: "获取用户信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                }
            }
        }
    }
    
    // MARK: - 获取车辆信息
    func fetchCarInfo() {
        let userManager = UserManager.shared
        guard let timaToken = userManager.timaToken else {
            QMUITips.hideAllTips()
            QMUITips.show(withText: "登录信息异常", in: view, hideAfterDelay: 2.0)
            return
        }
        
        let vins = userManager.allVins
        guard !vins.isEmpty else {
            QMUITips.hideAllTips()
            QMUITips.show(withText: "未找到车辆信息", in: view, hideAfterDelay: 2.0)
            return
        }
        
        NetworkManager.shared.getCarInfo(
            vins: vins,
            timaToken: timaToken
        ) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                QMUITips.hideAllTips()
                switch result {
                case .success(let carModel):
                    // 保存车辆信息到单例
                    UserManager.shared.carModel = carModel
                    
                    // 所有信息获取完成，跳转到主界面
                    QMUITips.show(withText: "登录成功", in: self.view, hideAfterDelay: 1.0)
                    
                    // TODO: 跳转到主界面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.navigateToMainViewController()
                    }
                    
                case .failure(let error):
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                    // 即使车辆信息获取失败，也可以跳转到主界面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.navigateToMainViewController()
                    }
                }
            }
        }
    }
    
    // MARK: - 跳转到主界面
    func navigateToMainViewController() {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainViewController = mainStoryboard.instantiateInitialViewController() {
            // 设置为根视图控制器，替换当前的登录界面
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = mainViewController
                window.makeKeyAndVisible()
            }
        }
    }
    
    func setupProtocolLabel() {
        let fullText = "已阅读并同意《隐私政策》和《用户协议》"
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // 设置整体样式：白色，12号字体
        attributedString.addAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12)
        ], range: NSRange(location: 0, length: fullText.count))
        
        // 设置《隐私政策》链接样式：蓝色，12号字体
        if let privacyRange = fullText.range(of: "《隐私政策》") {
            let nsRange = NSRange(privacyRange, in: fullText)
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 12)
            ], range: nsRange)
        }
        
        // 设置《用户协议》链接样式：蓝色，12号字体
        if let agreementRange = fullText.range(of: "《用户协议》") {
            let nsRange = NSRange(agreementRange, in: fullText)
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 12)
            ], range: nsRange)
        }
        
        protocolLabel.attributedText = attributedString
        protocolLabel.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(protocolLabelTapped(_:)))
        protocolLabel.addGestureRecognizer(tapGesture)
    }
    
    @objc func protocolLabelTapped(_ gesture: UITapGestureRecognizer) {
        let text = protocolLabel.attributedText?.string ?? ""
        let point = gesture.location(in: protocolLabel)
        
        // 创建文本容器和布局管理器
        let textStorage = NSTextStorage(attributedString: protocolLabel.attributedText!)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: protocolLabel.bounds.size)
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = protocolLabel.numberOfLines
        textContainer.lineBreakMode = protocolLabel.lineBreakMode
        
        // 获取点击位置对应的字符索引
        let characterIndex = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        // 检查是否点击了《隐私政策》
        if let privacyRange = text.range(of: "《隐私政策》") {
            let nsRange = NSRange(privacyRange, in: text)
            if NSLocationInRange(characterIndex, nsRange) {
                openURL(privacyPolicyURL)
                return
            }
        }
        
        // 检查是否点击了《用户协议》
        if let agreementRange = text.range(of: "《用户协议》") {
            let nsRange = NSRange(agreementRange, in: text)
            if NSLocationInRange(characterIndex, nsRange) {
                openURL(userAgreementURL)
                return
            }
        }
    }
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }
    
    func loadSavedCredentials() {
        let userDefaults = UserDefaults.standard
        if let savedPhone = userDefaults.string(forKey: "saved_phone"),
           let savedPassword = userDefaults.string(forKey: "saved_password") {
            phoneField.text = savedPhone
            passwdField.text = savedPassword
        }
    }
    
    func saveCredentials() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(phoneField.text, forKey: "saved_phone")
        userDefaults.set(passwdField.text, forKey: "saved_password")
    }
    
    @IBAction func clickLogin(_ sender: Any) {
        // 验证手机号
        guard let phone = phoneField.text, phone.count == 11 else {
            QMUITips.show(withText: "请输入11位手机号", in: view, hideAfterDelay: 2.0)
            return
        }
        
        // 验证密码
        guard let password = passwdField.text, !password.isEmpty else {
            QMUITips.show(withText: "请输入密码", in: view, hideAfterDelay: 2.0)
            return
        }
        
        // 验证协议勾选
        guard checkBox.isSelected else {
            // 震动提示
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.duration = 0.6
            animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
            protocolLabel.layer.add(animation, forKey: "shake")
            if #available(iOS 10.0, *) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
            return
        }
        
        // 执行登录
        performLogin(phone: phone, password: password)
    }
    
    func performLogin(phone: String, password: String) {
        // 使用MD5加密密码
        let encryptedPassword = password.qmui_md5
        
        // 调用网络请求
        QMUITips.showLoading(in: self.view)
        NetworkManager.shared.login(userCode: phone, password: encryptedPassword) { [weak self] result in
            guard let self else {return}
            DispatchQueue.main.async {
                switch result {
                case .success(let loginModel):
                    // 登录成功，保存登录信息到单例
                    UserManager.shared.loginModel = loginModel
                    self.saveCredentials()
                    
                    // 获取用户信息
                    self.fetchUserInfo()
                    
                case .failure(let error):
                    QMUITips.hideAllTips()
                    QMUITips.show(withText: error.localizedDescription, in: self.view, hideAfterDelay: 2.0)
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
