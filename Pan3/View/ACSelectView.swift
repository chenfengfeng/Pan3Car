//
//  ACSelectView.swift
//  Pan3
//
//  Created by Feng on 2025/7/1.
//

import UIKit
import QMUIKit
import SnapKit
import SwifterSwift

class ACSelectView: QMUIModalPresentationViewController {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let temperatureLabel = UILabel()
    private let temperatureSegment = UISegmentedControl()
    private let timeLabel = UILabel()
    private let timeSegment = UISegmentedControl()
    private let startACButton = QMUIButton()
    
    // MARK: - Properties
    private let temperatures = [16, 20, 26, 28, 30]
    private let times = [10, 15, 20, 25, 30]
    
    var selectedTemperature: Int {
        return temperatures[temperatureSegment.selectedSegmentIndex]
    }
    
    var selectedTime: Int {
        return times[timeSegment.selectedSegmentIndex]
    }
    
    // 回调闭包
    var onStartAC: ((Int, Int) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        
        let blur = UIBlurEffect.qmui_effect(withBlurRadius: 10)
        let blurView = UIVisualEffectView(effect: blur)
        dimmingView = blurView
        animationStyle = .slide
        
        contentView = containerView
        contentViewMargins = UIEdgeInsets.zero
        layoutBlock = { containerBounds, keyboardHeight, contentViewDefaultFrame in
            guard let contentView = self.contentView else {return}
            let rect = CGRectSetXY(contentView.frame, CGFloatGetCenter(CGRectGetWidth(containerBounds), CGRectGetWidth(contentView.frame)), CGRectGetHeight(containerBounds) - CGRectGetHeight(contentView.frame))
            contentView.qmui_frameApplyTransform = rect
        }
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        // 设置模态样式
        animationStyle = .slide
        
        // 容器视图
        containerView.layer.cornerRadius = 16
        containerView.backgroundColor = .systemBackground
        containerView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 400)
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        // 标题
        titleLabel.text = "空调设置"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // 温度标签
        temperatureLabel.text = "温度设置"
        temperatureLabel.font = UIFont.systemFont(ofSize: 16)
        containerView.addSubview(temperatureLabel)
        
        // 温度选择器
        for (index, temp) in temperatures.enumerated() {
            temperatureSegment.insertSegment(withTitle: "\(temp)°C", at: index, animated: false)
        }
        temperatureSegment.selectedSegmentTintColor = .systemBlue
        
        // 从UserDefaults读取上次选择的温度，默认26度
        let savedTemperature = UserDefaults.standard.integer(forKey: "PresetTemperature")
        let defaultTemperature = savedTemperature == 0 ? 26 : savedTemperature
        
        // 找到对应的索引并设置为选中状态
        if let index = temperatures.firstIndex(of: defaultTemperature) {
            temperatureSegment.selectedSegmentIndex = index
        } else {
            // 如果保存的温度不在选项中，默认选择26度
            temperatureSegment.selectedSegmentIndex = temperatures.firstIndex(of: 26) ?? 2
        }
        
        containerView.addSubview(temperatureSegment)
        
        // 时间标签
        timeLabel.text = "持续时间"
        timeLabel.font = UIFont.systemFont(ofSize: 16)
        containerView.addSubview(timeLabel)
        
        // 时间选择器
        for (index, time) in times.enumerated() {
            timeSegment.insertSegment(withTitle: "\(time)分钟", at: index, animated: false)
        }
        timeSegment.selectedSegmentTintColor = .systemBlue
        timeSegment.selectedSegmentIndex = 4
        containerView.addSubview(timeSegment)
        
        // 开启空调按钮
        startACButton.setTitle("开启空调", for: .normal)
        startACButton.backgroundColor = .systemBlue
        startACButton.setTitleColor(.white, for: .normal)
        startACButton.layer.cornerRadius = 8
        startACButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        containerView.addSubview(startACButton)
    }
    
    // MARK: - Setup Constraints
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(25)
        }
        
        temperatureLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(20)
        }
        
        temperatureSegment.snp.makeConstraints { make in
            make.top.equalTo(temperatureLabel.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(temperatureSegment.snp.bottom).offset(25)
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(20)
        }
        
        timeSegment.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
        
        startACButton.snp.makeConstraints { make in
            make.top.equalTo(timeSegment.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(54)
        }
    }
    
    // MARK: - Setup Actions
    private func setupActions() {
        startACButton.addTarget(self, action: #selector(startACButtonTapped), for: .touchUpInside)
    }
    
    @objc private func startACButtonTapped() {
        onStartAC?(selectedTemperature, selectedTime)
        dismiss(animated: true)
    }
    
    // MARK: - Show Method
    static func show(from viewController: UIViewController, completion: @escaping (Int, Int) -> Void) {
        let acSelectView = ACSelectView()
        acSelectView.onStartAC = completion
        viewController.present(acSelectView, animated: true)
    }
}
