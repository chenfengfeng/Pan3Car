//
//  ControllButtonView.swift
//  Pan3
//
//  Created by Feng on 2025/8/23.
//

import UIKit
import SnapKit
import QMUIKit
import SwifterSwift

class ControllButtonView: UIStackView {
    private lazy var lockBtn: QMUIButton = {
        let button = QMUIButton()
        button.cornerRadius = -1
        button.tintColor = .white
        button.backgroundColor = .white.withAlphaComponent(0.1)
        let config = UIImage.SymbolConfiguration(scale: .large)
        button.addTarget(self, action: #selector(lockButtonTapped), for: .touchUpInside)
        button.setImage(UIImage(systemName: "lock.fill", withConfiguration: config), for: .normal)
        return button
    }()
    
    private lazy var lockLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "已锁车"
        return label
    }()
    
    private lazy var acBtn: QMUIButton = {
        let button = QMUIButton()
        button.cornerRadius = -1
        button.tintColor = .white
        button.backgroundColor = .white.withAlphaComponent(0.1)
        let config = UIImage.SymbolConfiguration(scale: .large)
        button.addTarget(self, action: #selector(acButtonTapped), for: .touchUpInside)
        button.setImage(UIImage(systemName: "fanblades.slash.fill", withConfiguration: config), for: .normal)
        return button
    }()
    
    private lazy var acLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "空调关"
        return label
    }()
    
    private lazy var windowBtn: QMUIButton = {
        let button = QMUIButton()
        button.cornerRadius = -1
        button.tintColor = .white
        button.backgroundColor = .white.withAlphaComponent(0.1)
        let config = UIImage.SymbolConfiguration(scale: .large)
        button.addTarget(self, action: #selector(windowButtonTapped), for: .touchUpInside)
        button.setImage(UIImage(systemName: "window.shade.closed", withConfiguration: config), for: .normal)
        return button
    }()
    
    private lazy var windowLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "窗已关"
        return label
    }()
    
    private lazy var honkBtn: QMUIButton = {
        let button = QMUIButton()
        button.cornerRadius = -1
        button.tintColor = .white
        button.backgroundColor = .white.withAlphaComponent(0.1)
        let config = UIImage.SymbolConfiguration(scale: .large)
        button.addTarget(self, action: #selector(callButtonTapped), for: .touchUpInside)
        button.setImage(UIImage(systemName: "car.front.waves.up", withConfiguration: config), for: .normal)
        return button
    }()
    
    private lazy var honkLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "鸣笛"
        return label
    }()
    
    var blockTemperatureChange: ((Int) -> ())?

    func setupUI() {
        // 创建按钮容器视图
        let lockContainer = UIView()
        lockContainer.addSubview(lockBtn)
        lockContainer.addSubview(lockLabel)
        
        let acContainer = UIView()
        acContainer.addSubview(acBtn)
        acContainer.addSubview(acLabel)
        
        let windowContainer = UIView()
        windowContainer.addSubview(windowBtn)
        windowContainer.addSubview(windowLabel)
        
        let callContainer = UIView()
        callContainer.addSubview(honkBtn)
        callContainer.addSubview(honkLabel)
        
        addArrangedSubview(lockContainer)
        addArrangedSubview(acContainer)
        addArrangedSubview(windowContainer)
        addArrangedSubview(callContainer)
        
        setupControlButtonConstraints()
    }
    
    private func setupControlButtonConstraints() {
        // 开锁按钮容器内约束
        if let _ = self.arrangedSubviews.first {
            lockBtn.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.centerX.equalToSuperview()
                make.size.equalTo(40)
            }
            
            lockLabel.snp.makeConstraints { make in
                make.top.equalTo(lockBtn.snp.bottom).offset(4)
                make.centerX.equalTo(lockBtn)
            }
        }
        
        // 空调按钮容器内约束
        if self.arrangedSubviews.count > 1 {
            let _ = self.arrangedSubviews[1]
            acBtn.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.centerX.equalToSuperview()
                make.size.equalTo(40)
            }
            
            acLabel.snp.makeConstraints { make in
                make.top.equalTo(acBtn.snp.bottom).offset(4)
                make.centerX.equalTo(acBtn)
            }
        }
        
        // 开窗按钮容器内约束
        if self.arrangedSubviews.count > 2 {
            let _ = self.arrangedSubviews[2]
            windowBtn.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.centerX.equalToSuperview()
                make.size.equalTo(40)
            }
            
            windowLabel.snp.makeConstraints { make in
                make.top.equalTo(windowBtn.snp.bottom).offset(4)
                make.centerX.equalTo(windowBtn)
            }
        }
        
        // 寻车按钮容器内约束
        if self.arrangedSubviews.count > 3 {
            let _ = self.arrangedSubviews[3]
            honkBtn.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.centerX.equalToSuperview()
                make.size.equalTo(40)
            }
            
            honkLabel.snp.makeConstraints { make in
                make.top.equalTo(honkBtn.snp.bottom).offset(4)
                make.centerX.equalTo(honkBtn)
            }
        }
    }
    
    func setupCarModel() {
        guard let model = UserManager.shared.carModel else { return }
        
        let config = UIImage.SymbolConfiguration(scale: .large)
        // 设置车锁按钮图标和文字
        let lockImageName = model.mainLockStatus == 0 ? "lock.fill" : "lock.open.fill"
        let lockImage = UIImage(systemName: lockImageName, withConfiguration: config)
        lockBtn.setImage(lockImage, for: .normal)
        // 根据锁车状态调整背景色
        lockBtn.backgroundColor = model.mainLockStatus == 0 ? UIColor.white.withAlphaComponent(0.1) : UIColor.systemGreen
        lockLabel.text = model.mainLockStatus == 0 ? "已锁车" : "已解锁"
        
        // 设置风扇按钮图标和文字
        let fanImageName = model.acStatus == 1 ? "fanblades.fill" : "fanblades.slash.fill"
        let fanImage = UIImage(systemName: fanImageName, withConfiguration: config)
        acBtn.setImage(fanImage, for: .normal)
        // 根据空调状态调整背景色
        acBtn.backgroundColor = model.acStatus == 1 ? UIColor.systemBlue : UIColor.white.withAlphaComponent(0.1)
        
        if model.acStatus == 1 {
            // 开启空调 - 添加360度旋转动画
            startFanRotationAnimation()
            acLabel.text = "空调开"
        }else{
            // 关闭空调 - 停止旋转动画
            stopFanRotationAnimation()
            acLabel.text = "空调关"
        }
        
        // 设置车窗按钮图标和文字（根据所有车窗状态判断）
        let allWindowsClosed = model.lfWindowOpen == 0 && model.rfWindowOpen == 0 &&
        model.lrWindowOpen == 0 && model.rrWindowOpen == 0
        let windowImageName = allWindowsClosed ? "window.shade.closed" : "window.shade.open"
        let windowImage = UIImage(systemName: windowImageName, withConfiguration: config)
        windowBtn.setImage(windowImage, for: .normal)
        // 根据车窗状态调整背景色
        windowBtn.backgroundColor = allWindowsClosed ? UIColor.white.withAlphaComponent(0.1) : UIColor.systemTeal
        windowLabel.text = allWindowsClosed ? "窗已关" : "窗已开"
        
        // 鸣笛按钮文字（固定）
        honkLabel.text = "鸣笛"
    }
    
    @objc private func lockButtonTapped() {
        // 检查是否启用调试模式
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        guard shouldEnableDebug else {
            return
        }
        
        actionLock()
    }
    
    @objc private func acButtonTapped() {
        // 检查是否启用调试模式
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        guard shouldEnableDebug else {
            return
        }
        
        actionAC()
    }
    
    @objc private func windowButtonTapped() {
        // 检查是否启用调试模式
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        guard shouldEnableDebug else {
            return
        }
        
        actionWindow()
    }
    
    @objc private func callButtonTapped() {
        // 检查是否启用调试模式
        let shouldEnableDebug = UserDefaults.standard.bool(forKey: "shouldEnableDebug")
        guard shouldEnableDebug else {
            return
        }
        
        actionCall()
    }
    
    // MARK: - 小组件专用方法（无调试模式检查）
    /// 小组件专用车锁控制方法
    func widgetLockButtonTapped() {
        actionLock()
    }
    
    /// 小组件专用空调控制方法
    func widgetAcButtonTapped() {
        actionAC()
    }
    
    /// 小组件专用车窗控制方法
    func widgetWindowButtonTapped() {
        actionWindow()
    }
    
    /// 小组件专用寻车控制方法
    func widgetCallButtonTapped() {
        actionCall()
    }
    
    // MARK: - 二次确认相关方法
    private func isConfirmationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "confirmation_enabled")
    }
    
    private func showConfirmationAlert(title: String, message: String, confirmAction: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        let confirmActionButton = UIAlertAction(title: "确认", style: .default) { _ in
            confirmAction()
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmActionButton)
        
        qmui_viewController?.present(alert, animated: true, completion: nil)
    }
    
    func actionLock() {
        guard let model = UserManager.shared.carModel else { return }
        
        let isLocked = model.mainLockStatus == 0
        let operation = isLocked ? 2 : 1  // 2=开锁, 1=关锁
        let actionText = isLocked ? "开锁" : "关锁"
        
        // 检查是否需要二次确认
        if isConfirmationEnabled() {
            showConfirmationAlert(title: "确认\(actionText)", message: "确定要\(actionText)吗？") {
                self.performLockAction(operation: operation, actionText: actionText)
            }
        } else {
            performLockAction(operation: operation, actionText: actionText)
        }
    }
    
    private func performLockAction(operation: Int, actionText: String) {
        executeCarControl(
            loadingText: "\(actionText)中...",
            successText: "\(actionText)指令发送成功",
            failureText: "\(actionText)失败",
            controlAction: { completion in
                let pushToken = UserDefaults.standard.string(forKey: "pushToken") ?? ""
                NetworkManager.shared.syncVehicle(operationType: "LOCK", operation: operation, pushToken: pushToken, completion: completion)
            }
        )
    }
    
    func actionAC() {
        guard let model = UserManager.shared.carModel else { return }
        guard let vc = qmui_viewController else { return }
        
        let isACOn = model.acStatus == 1
        let actionText = isACOn ? "关闭空调" : "开启空调"
        
        if isACOn {
            // 如果空调是开启的，则执行关闭逻辑
            let action = { self.performAirConditionerAction(operation: 1, actionText: actionText) } // 1 代表关闭
            
            if isConfirmationEnabled() {
                showConfirmationAlert(title: "确认\(actionText)", message: "确定要\(actionText)吗?", confirmAction: action)
            } else {
                action()
            }
        } else {
            // 如果空调是关闭的，则弹出选择框，执行开启逻辑
            ACSelectView.show(from: vc) { [weak self] temperature, time in
                guard let self = self else { return }
                
                UserDefaults.standard.set(temperature, forKey: "PresetTemperature")
                // 同时保存到App Groups，供小组件和Watch应用使用
                UserDefaults(suiteName: "group.com.feng.pan3")?.set(temperature, forKey: "PresetTemperature")
                self.blockTemperatureChange?(temperature)
                
                let action = { self.performAirConditionerAction(operation: 2, temperature: temperature, time: time, actionText: actionText) } // 2 代表开启
                
                if self.isConfirmationEnabled() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.showConfirmationAlert(title: "确认\(actionText)", message: "确定要\(actionText)吗?", confirmAction: action)
                    }
                } else {
                    action()
                }
            }
        }
    }
    
    /// 执行空调控制的私有通用函数
    private func performAirConditionerAction(operation: Int, temperature: Int = 26, time: Int = 30, actionText: String) {
        executeCarControl(
            loadingText: "\(actionText)中...",
            successText: "\(actionText)指令发送成功",
            failureText: "\(actionText)失败",
            controlAction: { completion in
                let pushToken = UserDefaults.standard.string(forKey: "pushToken") ?? ""
                
                NetworkManager.shared.syncVehicle(
                    operationType: "INTELLIGENT_AIRCONDITIONER",
                    operation: operation,
                    temperature: temperature,
                    duringTime: time,
                    pushToken: pushToken,
                    completion: completion
                )
            }
        )
    }
    
    // MARK: - 控制车窗
    func actionWindow() {
        guard let model = UserManager.shared.carModel else {
            // 尝试获取视图控制器，如果获取不到（如小组件触发），使用全局提示方法
            if let vc = qmui_viewController {
                QMUITips.show(withText: "车辆信息不可用", in: vc.view, hideAfterDelay: 2.0)
            } else {
                QMUITips.showError("车辆信息不可用")
            }
            return
        }
        
        // 判断当前车窗状态
        let allWindowsClosed = model.lfWindowOpen == 0 && model.rfWindowOpen == 0 &&
        model.lrWindowOpen == 0 && model.rrWindowOpen == 0
        
        let operation = allWindowsClosed ? 2 : 1  // 2开启，1关闭
        let openLevel = allWindowsClosed ? 2 : 0  // 2完全打开，0关闭
        let actionText = allWindowsClosed ? "开窗" : "关窗"
        
        // 检查是否需要二次确认
        if isConfirmationEnabled() {
            showConfirmationAlert(title: "确认\(actionText)", message: "确定要\(actionText)吗？") {
                self.performWindowAction(operation: operation, openLevel: openLevel, actionText: actionText)
            }
        } else {
            performWindowAction(operation: operation, openLevel: openLevel, actionText: actionText)
        }
    }
    
    private func performWindowAction(operation: Int, openLevel: Int, actionText: String) {
        executeCarControl(
            loadingText: "\(actionText)中...",
            successText: "\(actionText)指令发送成功",
            failureText: "\(actionText)失败",
            controlAction: { completion in
                let pushToken = UserDefaults.standard.string(forKey: "pushToken") ?? ""
                NetworkManager.shared.syncVehicle(
                    operationType: "WINDOW",
                    operation: operation,
                    openLevel: openLevel,
                    pushToken: pushToken,
                    completion: completion
                )
            }
        )
    }
    
    func actionCall() {
        let pushToken = UserDefaults.standard.string(forKey: "pushToken") ?? ""
        
        // 尝试获取视图控制器，如果获取不到（如小组件触发），使用全局提示方法
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            QMUITips.showLoading("鸣笛寻车指令发送中...", in: keyWindow)
        }
        
        NetworkManager.shared.syncVehicle(
            operationType: "FIND_VEHICLE",
            pushToken: pushToken) { result in
                QMUITips.hideAllTips()
                switch result {
                case .success(_):
                    QMUITips.showSucceed("鸣笛指令发送成功")
                default:
                    break
                }
            }
    }
    
    // MARK: - 通用车辆控制方法
    private func executeCarControl(
        loadingText: String,
        successText: String,
        failureText: String,
        controlAction: @escaping (@escaping (Result<Bool, Error>) -> Void) -> Void
    ) {
        // 尝试获取视图控制器，如果获取不到（如小组件触发），使用全局提示方法
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            // 正常情况：在指定视图上显示提示
            QMUITips.showLoading(loadingText, in: keyWindow)
            
            controlAction { result in
                DispatchQueue.main.async {
                    QMUITips.hideAllTips()
                    
                    switch result {
                    case .success(_):
                        QMUITips.show(withText: successText)
                        // 直接请求模式：操作成功后等待推送更新数据
                        
                    case .failure(let error):
                        QMUITips.show(withText: "\(failureText): \(error.localizedDescription)", in: keyWindow, hideAfterDelay: 2.0)
                    }
                }
            }
        }
    }
}

// MARK: - 动画相关
extension ControllButtonView {
    // MARK: - 风扇旋转动画
    private func startFanRotationAnimation() {
        // 停止之前的动画
        stopFanRotationAnimation()
        
        // 创建360度旋转动画
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2 // 360度
        rotationAnimation.duration = 1.0 // 1秒完成一次旋转
        rotationAnimation.repeatCount = Float.infinity // 无限循环
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .linear) // 线性动画
        
        // 添加动画到风扇按钮的图层
        acBtn.layer.add(rotationAnimation, forKey: "fanRotation")
    }
    
    private func stopFanRotationAnimation() {
        // 移除旋转动画
        acBtn.layer.removeAnimation(forKey: "fanRotation")
    }
}
