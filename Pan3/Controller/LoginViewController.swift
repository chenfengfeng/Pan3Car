//
//  LoginViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/28.
//

import UIKit
import SnapKit
import Alamofire
import SafariServices

class LoginViewController: UIViewController, QMUITextFieldDelegate {
    // UI元素
    private lazy var loginImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "login")
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var phoneContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray2.cgColor
        return view
    }()
    
    private lazy var phoneIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "iphone")
        imageView.tintColor = UIColor.label
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var phoneField: QMUITextField = {
        let textField = QMUITextField()
        textField.placeholder = "请输入手机号"
        textField.keyboardType = .phonePad
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.clearButtonMode = .whileEditing
        textField.delegate = self
        textField.returnKeyType = .next
        return textField
    }()
    
    private lazy var passwordContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray2.cgColor
        return view
    }()
    
    private lazy var passwordIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "lock.fill")
        imageView.tintColor = UIColor.label
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var passwdField: QMUITextField = {
        let textField = QMUITextField()
        textField.placeholder = "请输入密码"
        textField.isSecureTextEntry = true
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.clearButtonMode = .whileEditing
        textField.delegate = self
        textField.returnKeyType = .done
        return textField
    }()
    
    private lazy var loginBtn: QMUIButton = {
        let button = QMUIButton()
        button.setTitle("登录胖3", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.addTarget(self, action: #selector(clickLogin), for: .touchUpInside)
        return button
    }()
    
    private lazy var bottomView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var protocolStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var protocolLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var firstLoginLabel: UILabel = {
        let label = UILabel()
        label.text = "用户首次登录将自动创建账号"
        label.textColor = UIColor.label
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        return label
    }()
    
    lazy var checkBox: QMUICheckbox = {
        let box = QMUICheckbox()
        box.tintColor = .label
        box.isSelected = true
        return box
    }()
    
    // 协议URL占位符
    private let privacyPolicyURL = "https://car.dreamforge.top/privacy"
    private let userAgreementURL = "https://car.dreamforge.top/agreement"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupProtocolLabel()
        loadSavedCredentials()
        
        // 激活网络权限检查
        checkNetworkPermission()
    }
    
    func setupUI() {
        // 设置背景色 - 根据storyboard使用系统背景色
        view.backgroundColor = UIColor.systemBackground
        
        // 添加主要容器视图
        view.addSubview(phoneContainerView)
        view.addSubview(passwordContainerView)
        view.addSubview(loginImageView)
        view.addSubview(loginBtn)
        view.addSubview(bottomView)
        view.addSubview(firstLoginLabel)
        
        // 设置手机号容器内的子视图
        phoneContainerView.addSubview(phoneIconImageView)
        phoneContainerView.addSubview(phoneField)
        
        // 设置密码容器内的子视图
        passwordContainerView.addSubview(passwordIconImageView)
        passwordContainerView.addSubview(passwdField)
        
        // 设置底部视图
        protocolStackView.addArrangedSubview(checkBox)
        protocolStackView.addArrangedSubview(protocolLabel)
        bottomView.addArrangedSubview(protocolStackView)
        
        checkBox.qmui_tapBlock = { _ in
            self.checkBox.isSelected = !self.checkBox.isSelected
        }
    }
    
    func setupConstraints() {
        // Login 图片约束 - 位于顶部中央
        loginImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(68)
            make.width.height.equalTo(200)
        }
        
        // 手机号容器视图约束
        phoneContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(loginImageView.snp.bottom).offset(-35)
            make.left.right.equalToSuperview().inset(40)
            make.height.equalTo(54)
        }
        
        // 手机号图标约束
        phoneIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        // 手机号输入框约束
        phoneField.snp.makeConstraints { make in
            make.leading.equalTo(phoneIconImageView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.top.bottom.equalToSuperview()
        }
        
        // 密码容器视图约束
        passwordContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(phoneContainerView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(40)
            make.height.equalTo(54)
        }
        
        // 密码图标约束
        passwordIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        // 密码输入框约束
        passwdField.snp.makeConstraints { make in
            make.leading.equalTo(passwordIconImageView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.top.bottom.equalToSuperview()
        }
        
        // 登录按钮约束
        loginBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(passwordContainerView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(40)
            make.height.equalTo(54)
        }
        
        // 底部协议视图约束
        bottomView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(firstLoginLabel.snp.top).offset(-12)
            make.left.right.equalToSuperview().inset(40)
        }
        
        // 首次登录提示标签约束
        firstLoginLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.left.right.equalToSuperview().inset(40)
        }
        
        // 复选框约束
        checkBox.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
    }
    
    // MARK: - 注意：fetchUserInfo 和 fetchCarInfo 方法已被移除
    // 新的认证接口 auth.php 已经包含了所有必要的信息，无需单独获取
    
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
        
        // 设置整体样式：系统标签颜色，12号字体
        attributedString.addAttributes([
            .foregroundColor: UIColor.label,
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
    
    @objc func clickLogin(_ sender: Any) {
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
                QMUITips.hideAllTips()
                switch result {
                case .success(let authResponse):
                    // 登录成功，保存认证响应信息到单例
                    UserManager.shared.authResponse = authResponse
                    self.saveCredentials()
                    
                    // 登录成功，直接跳转到主界面（新接口已包含所有信息）
                    QMUITips.show(withText: "登录成功", in: self.view, hideAfterDelay: 1.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.navigateToMainViewController()
                    }
                    
                case .failure(let error):
                    QMUITips.show(withText: error.localizedDescription, in: self.view, hideAfterDelay: 2.0)
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == phoneField {
            passwdField.becomeFirstResponder()
        } else if textField == passwdField {
            textField.resignFirstResponder()
            clickLogin(loginBtn)
        }
        return true
    }
    
    // MARK: - 网络权限检查
    /// 检查网络权限并激活网络访问
    private func checkNetworkPermission() {
        // 简单请求 apple.com 来激活网络权限弹窗
        AF.request("https://www.apple.com", method: .get)
            .response { response in
                switch response.result {
                case .success:
                    print("网络权限激活成功")
                case .failure(let error):
                    print("网络请求失败: \(error.localizedDescription)")
                }
            }
    }
}
