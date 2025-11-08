//
//  TripRecordCell.swift
//  Pan3
//
//  Created by Assistant on 2024
//

import UIKit
import SnapKit

class TripRecordCell: UITableViewCell {
    
    // MARK: - UI Elements
    
    // 主容器卡片视图
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 达成率圆形进度视图（重点显示）
    private let achievementRateView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        view.layer.cornerRadius = 35
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let achievementRateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = UIColor.systemGreen
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let achievementTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "达成率"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 地址信息容器
    private let addressContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let addressBlurContainer: UIVisualEffectView = {
        let blur = UIBlurEffect.qmui_effect(withBlurRadius: 4)
        let view = UIVisualEffectView(effect: blur)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let departureAddressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.textColor = UIColor.label
        label.numberOfLines = 2
        return label
    }()
    
    private let destinationAddressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.textColor = UIColor.label
        label.numberOfLines = 2
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "arrow.down")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // 时间信息容器
    private let timeContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let departureTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .left
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // 数据信息容器
    private let dataContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let mileageInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.tertiarySystemBackground
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.separator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let mileageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.label
        label.textAlignment = .center
        return label
    }()
    
    private let mileageTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "行驶里程"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private let consumptionInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.tertiarySystemBackground
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.separator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let consumptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.label
        label.textAlignment = .center
        return label
    }()
    
    private let consumptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "消耗里程"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    // 底部数据容器
    private let bottomDataContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let powerConsumptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let averageSpeedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let energyEfficiencyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.clear
        
        // 设置黑暗模式适配
        setupDarkModeSupport()
        
        contentView.addSubview(cardView)
        
        // 添加达成率视图
        cardView.addSubview(achievementRateView)
        achievementRateView.addSubview(achievementRateLabel)
        achievementRateView.addSubview(achievementTitleLabel)
        
        // 添加地址容器
        cardView.addSubview(addressContainer)
        cardView.addSubview(addressBlurContainer)
        addressContainer.addArrangedSubview(departureAddressLabel)
        addressContainer.addArrangedSubview(arrowImageView)
        addressContainer.addArrangedSubview(destinationAddressLabel)
        
        // 添加时间容器
        cardView.addSubview(timeContainer)
        timeContainer.addArrangedSubview(departureTimeLabel)
        timeContainer.addArrangedSubview(durationLabel)
        
        // 添加数据容器
        cardView.addSubview(dataContainer)
        
        // 里程信息
        mileageInfoView.addSubview(mileageLabel)
        mileageInfoView.addSubview(mileageTitleLabel)
        dataContainer.addArrangedSubview(mileageInfoView)
        
        // 消耗信息
        consumptionInfoView.addSubview(consumptionLabel)
        consumptionInfoView.addSubview(consumptionTitleLabel)
        dataContainer.addArrangedSubview(consumptionInfoView)
        
        // 底部数据容器
        cardView.addSubview(bottomDataContainer)
        bottomDataContainer.addArrangedSubview(powerConsumptionLabel)
        bottomDataContainer.addArrangedSubview(averageSpeedLabel)
        bottomDataContainer.addArrangedSubview(energyEfficiencyLabel)
        
        setupConstraints()
    }
    
    // MARK: - Dark Mode Support
    
    private func setupDarkModeSupport() {
        // 监听界面风格变化
        if #available(iOS 13.0, *) {
            // 在 traitCollectionDidChange 中处理
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateAppearanceForCurrentStyle()
            }
        }
    }
    
    private func updateAppearanceForCurrentStyle() {
        // 更新卡片边框颜色
        cardView.layer.borderColor = UIColor.separator.cgColor
        
        // 更新数据信息视图边框颜色
        mileageInfoView.layer.borderColor = UIColor.separator.cgColor
        consumptionInfoView.layer.borderColor = UIColor.separator.cgColor
        
        // 更新阴影效果
        if traitCollection.userInterfaceStyle == .dark {
            cardView.layer.shadowOpacity = 0.25
            cardView.layer.shadowRadius = 10
        } else {
            cardView.layer.shadowOpacity = 0.15
            cardView.layer.shadowRadius = 8
        }
    }
    
    private func setupConstraints() {
        // 卡片视图约束
        cardView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(8)
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.bottom.equalTo(contentView).offset(-8)
        }
        
        // 达成率视图约束（右上角）
        achievementRateView.snp.makeConstraints { make in
            make.top.equalTo(cardView).offset(16)
            make.trailing.equalTo(cardView).offset(-16)
            make.width.height.equalTo(70)
        }
        
        // 达成率标签约束
        achievementRateLabel.snp.makeConstraints { make in
            make.centerX.equalTo(achievementRateView)
            make.centerY.equalTo(achievementRateView).offset(-8)
        }
        
        // 达成率标题约束
        achievementTitleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(achievementRateView)
            make.top.equalTo(achievementRateLabel.snp.bottom).offset(2)
        }
        
        // 地址容器约束
        addressContainer.snp.makeConstraints { make in
            make.top.equalTo(cardView).offset(16)
            make.leading.equalTo(cardView).offset(16)
            make.trailing.equalTo(achievementRateView.snp.leading).offset(-16)
        }
        addressBlurContainer.snp.makeConstraints { make in
            make.edges.equalTo(addressContainer).inset(UIEdgeInsets(inset: -4))
        }
        
        // 箭头图标约束
        arrowImageView.snp.makeConstraints { make in
            make.height.equalTo(16)
        }
        
        // 时间容器约束
        timeContainer.snp.makeConstraints { make in
            make.top.equalTo(addressContainer.snp.bottom).offset(12)
            make.leading.trailing.equalTo(cardView).inset(16)
        }
        
        // 数据容器约束
        dataContainer.snp.makeConstraints { make in
            make.top.equalTo(timeContainer.snp.bottom).offset(16)
            make.leading.trailing.equalTo(cardView).inset(16)
            make.height.equalTo(60)
        }
        
        // 里程信息约束
        mileageLabel.snp.makeConstraints { make in
            make.centerX.equalTo(mileageInfoView)
            make.top.equalTo(mileageInfoView).offset(8)
        }
        
        mileageTitleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(mileageInfoView)
            make.bottom.equalTo(mileageInfoView).offset(-8)
        }
        
        // 消耗信息约束
        consumptionLabel.snp.makeConstraints { make in
            make.centerX.equalTo(consumptionInfoView)
            make.top.equalTo(consumptionInfoView).offset(8)
        }
        
        consumptionTitleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(consumptionInfoView)
            make.bottom.equalTo(consumptionInfoView).offset(-8)
        }
        
        // 底部数据容器约束
        bottomDataContainer.snp.makeConstraints { make in
            make.top.equalTo(dataContainer.snp.bottom).offset(12)
            make.leading.trailing.equalTo(cardView).inset(16)
            make.bottom.equalTo(cardView).offset(-16)
        }
    }
    
    // MARK: - Configuration
    
    func configure(with tripData: TripRecordData) {
        // 确保样式正确应用
        updateAppearanceForCurrentStyle()
        
        // 设置地址
        departureAddressLabel.text = tripData.departureAddress
        destinationAddressLabel.text = tripData.destinationAddress
        
        // 设置时间
        departureTimeLabel.text = "出发: \(tripData.departureTime)"
        durationLabel.text = "历时: \(tripData.duration)"
        
        // 设置里程
        mileageLabel.text = "\(String(format: "%.1f", tripData.drivingMileage)) km"
        consumptionLabel.text = "\(String(format: "%.1f", tripData.consumedMileage)) km"
        
        // 设置达成率（重点显示）
        let achievementRate = tripData.achievementRate
        achievementRateLabel.text = "\(Int(achievementRate))%"
        
        // 根据达成率设置颜色（优化黑暗模式显示）
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let backgroundAlpha: CGFloat = isDarkMode ? 0.2 : 0.15
        let borderAlpha: CGFloat = isDarkMode ? 0.4 : 0.3
        
        if achievementRate >= 90 {
            achievementRateView.backgroundColor = UIColor.systemGreen.withAlphaComponent(backgroundAlpha)
            achievementRateView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(borderAlpha).cgColor
            achievementRateLabel.textColor = UIColor.systemGreen
        } else if achievementRate >= 70 {
            achievementRateView.backgroundColor = UIColor.systemOrange.withAlphaComponent(backgroundAlpha)
            achievementRateView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(borderAlpha).cgColor
            achievementRateLabel.textColor = UIColor.systemOrange
        } else {
            achievementRateView.backgroundColor = UIColor.systemRed.withAlphaComponent(backgroundAlpha)
            achievementRateView.layer.borderColor = UIColor.systemRed.withAlphaComponent(borderAlpha).cgColor
            achievementRateLabel.textColor = UIColor.systemRed
        }
        
        // 设置底部数据（优化格式）
        powerConsumptionLabel.text = "消耗电量\n\(String(format: "%.1f", tripData.powerConsumption))%"
        averageSpeedLabel.text = "平均速度\n\(String(format: "%.1f", tripData.averageSpeed)) km/h"
        energyEfficiencyLabel.text = "平均能耗\n\(String(format: "%.2f", tripData.energyEfficiency)) kWh/100km"
        
        let isBlurAddress = UserDefaults.standard.bool(forKey: "isBlurAddress")
        addressBlurContainer.isHidden = !isBlurAddress
    }
}
