//
//  MileageView.swift
//  Pan3
//
//  Created by Feng on 2025/8/23.
//

import UIKit
import SnapKit
import QMUIKit
import SwifterSwift

class MileageView: UIView {
    // 当前续航里程数字标签
    lazy var currentMileageLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.textColor = .white
        label.isUserInteractionEnabled = true
        label.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changeMile)))
        return label
    }()
    // 里程单位标签
    lazy var mileageUnitLabel: UILabel = {
        let label = UILabel()
        label.text = "km"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    // 电池电量进度条
    lazy var batteryProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = .systemGray
        progressView.progress = 0.0
        return progressView
    }()
    // 车辆总里程标签
    lazy var totalMileageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.text = "总里程：0.0km"
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    // 充电状态
    lazy var chargeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemGreen
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    func setupUI() {
        addSubview(currentMileageLabel)
        addSubview(mileageUnitLabel)
        addSubview(batteryProgressView)
        addSubview(totalMileageLabel)
        addSubview(chargeLabel)
        
        currentMileageLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(8)
        }
        mileageUnitLabel.snp.makeConstraints { make in
            make.leading.equalTo(currentMileageLabel.snp.trailing).offset(8)
            make.bottom.equalTo(currentMileageLabel.snp.bottom).offset(-12)
        }
        batteryProgressView.snp.makeConstraints { make in
            make.leading.equalTo(currentMileageLabel.snp.leading)
            make.top.equalTo(currentMileageLabel.snp.bottom)
            make.width.equalTo(126)
            make.height.equalTo(4)
        }
        totalMileageLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(batteryProgressView.snp.bottom)
        }
        chargeLabel.snp.makeConstraints { make in
            make.top.equalTo(batteryProgressView.snp.bottom).offset(3)
            make.leading.equalTo(batteryProgressView.snp.leading)
        }
        
        az_setGradientBackground(with: [.black, .black.withAlphaComponent(0)], start: CGPoint(x: 0, y: 0.7), end: CGPoint(x: 0, y: 1))
    }
    
    // MARK: - 按键事件
    @objc func changeMile() {
        guard let model = UserManager.shared.carModel else { return }
        
        if mileageUnitLabel.text == "km" {
            currentMileageLabel.text = model.soc
            mileageUnitLabel.text = "%"
        }else{
            currentMileageLabel.text = model.acOnMile.string
            mileageUnitLabel.text = "km"
        }
        
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    func setupCarModel(_ isFirstDataLoad: Bool) {
        guard let model = UserManager.shared.carModel else { return }
        
        let targetMileValue = model.acOnMile
        let targetSocValue = BatteryCalculationUtility.getCurrentSoc(from: model) / 100
        
        if isFirstDataLoad {
            // 首次加载 - 执行动画
            animateMileage(to: targetMileValue)
            animateSOC(to: Float(targetSocValue))
        } else {
            // 后续更新 - 根据当前显示状态设置对应数值
            if mileageUnitLabel.text == "km" {
                // 当前显示里程，更新为最新里程数据
                currentMileageLabel.text = "\(targetMileValue)"
            } else {
                // 当前显示电量，更新为最新电量数据
                currentMileageLabel.text = model.soc
            }
            batteryProgressView.progress = Float(targetSocValue)
            
            // 根据SOC值设置进度条颜色
            let percentage = targetSocValue * 100
            if percentage < 10 {
                batteryProgressView.progressTintColor = .systemRed
            } else if percentage < 20 {
                batteryProgressView.progressTintColor = .systemOrange
            } else {
                batteryProgressView.progressTintColor = .systemGreen
            }
        }
        
        // 总里程直接设置
        totalMileageLabel.text = "总里程：\(model.totalMileage)km"
        
        // 充电状态设置
        if model.chgStatus == 2 {
            chargeLabel.isHidden = true
        }else{
            chargeLabel.isHidden = false
            chargeLabel.text = "正在充电 剩余"+formatTime(minutes: model.quickChgLeftTime.float)
        }
    }
    
    // MARK: - 配置信息
    private func formatTime(minutes: Float) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return "\(hours)小时\(mins)分钟\(secs)秒"
    }
    
    // MARK: - 动画的关联密钥
    private struct AssociatedKeys {
        static var mileageStartTime: UInt8 = 0
        static var mileageDuration: UInt8 = 0
        static var mileageTargetValue: UInt8 = 0
        static var mileageDisplayLink: UInt8 = 0
        static var socStartTime: UInt8 = 0
        static var socDuration: UInt8 = 0
        static var socTargetValue: UInt8 = 0
        static var socDisplayLink: UInt8 = 0
    }
    
    // MARK: - 里程动画
    func animateMileage(to targetValue: Int) {
        let duration: TimeInterval = 1.5
        let startTime = CACurrentMediaTime()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(updateMileageAnimation))
        displayLink.add(to: .main, forMode: .common)
        
        // 存储动画参数
        objc_setAssociatedObject(self, &AssociatedKeys.mileageStartTime, startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageDuration, duration, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageTargetValue, targetValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.mileageDisplayLink, displayLink, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc private func updateMileageAnimation() {
        guard let startTime = objc_getAssociatedObject(self, &AssociatedKeys.mileageStartTime) as? TimeInterval,
              let duration = objc_getAssociatedObject(self, &AssociatedKeys.mileageDuration) as? TimeInterval,
              let targetValue = objc_getAssociatedObject(self, &AssociatedKeys.mileageTargetValue) as? Int,
              let displayLink = objc_getAssociatedObject(self, &AssociatedKeys.mileageDisplayLink) as? CADisplayLink else {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - startTime
        let progress = min(elapsed / duration, 1.0)
        
        // 使用缓动函数
        let easedProgress = easeOutQuart(progress)
        let currentValue = Int(Double(targetValue) * easedProgress)
        
        currentMileageLabel.text = "\(currentValue)"
        
        if progress >= 1.0 {
            displayLink.invalidate()
            objc_setAssociatedObject(self, &AssociatedKeys.mileageDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: - SOC动画
    func animateSOC(to targetValue: Float) {
        // 重置进度条
        batteryProgressView.progress = 0.0
        batteryProgressView.progressTintColor = .systemRed // 初始颜色为红色
        
        let duration: TimeInterval = 1.5
        let startTime = CACurrentMediaTime()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(updateSOCAnimation))
        displayLink.add(to: .main, forMode: .common)
        
        // 存储动画参数
        objc_setAssociatedObject(self, &AssociatedKeys.socStartTime, startTime, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socDuration, duration, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socTargetValue, targetValue, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.socDisplayLink, displayLink, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc private func updateSOCAnimation() {
        guard let startTime = objc_getAssociatedObject(self, &AssociatedKeys.socStartTime) as? TimeInterval,
              let duration = objc_getAssociatedObject(self, &AssociatedKeys.socDuration) as? TimeInterval,
              let targetValue = objc_getAssociatedObject(self, &AssociatedKeys.socTargetValue) as? Float,
              let displayLink = objc_getAssociatedObject(self, &AssociatedKeys.socDisplayLink) as? CADisplayLink else {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - startTime
        let progress = min(elapsed / duration, 1.0)
        
        // 使用缓动函数
        let easedProgress = easeOutQuart(progress)
        let currentValue = targetValue * Float(easedProgress)
        let currentPercentage = currentValue * 100
        
        // 更新进度条值
        batteryProgressView.progress = currentValue
        
        // 根据当前进度动态设置颜色
        if currentPercentage < 10 {
            batteryProgressView.progressTintColor = .systemRed
        } else if currentPercentage < 20 {
            batteryProgressView.progressTintColor = .systemOrange
        } else {
            batteryProgressView.progressTintColor = .systemGreen
        }
        
        if progress >= 1.0 {
            displayLink.invalidate()
            objc_setAssociatedObject(self, &AssociatedKeys.socDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: - 缓动函数
    private func easeOutQuart(_ t: Double) -> Double {
        return 1 - pow(1 - t, 4)
    }
}
