//
//  ChargeListCell.swift
//  Pan3
//
//  Created by Feng on 2025/1/2.
//

import UIKit
import QMUIKit
import SnapKit
import SwifterSwift

// MARK: - ChargeTaskModel Extension
extension ChargeTaskModel {
    // 状态颜色
    var statusColor: UIColor {
        switch status {
        case "ready":
            return .systemYellow
        case "pending":
            return .systemBlue
        case "done":
            return .systemGreen
        case "timeout", "error":
            return .systemRed
        case "cancelled":
            return .systemOrange
        default:
            return .systemGray
        }
    }
}

class ChargeListCell: UITableViewCell {
    static let identifier = "ChargeListCell"
    
    // MARK: - UI Components
    private let cardView = UIView()
    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let initialKmLabel = UILabel()
    private let targetKmLabel = UILabel()
    private let initialKwhLabel = UILabel()
    private let chargeKwhLabel = UILabel()
    private let percentageLabel = UILabel()
    private let durationLabel = UILabel()
    private let messageLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let batteryIconView = UIImageView()
    
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
        backgroundColor = .clear
        selectionStyle = .none
        
        setupCardView()
        setupStatusLabel()
        setupTimeLabel()
        setupBatteryIcon()
        setupProgressView()
        setupLabels()
        setupDurationLabel()
        setupMessageLabel()
        setupConstraints()
    }
    
    private func setupCardView() {
        cardView.backgroundColor = .systemGray6
        cardView.layerCornerRadius = 12
        cardView.layerShadowColor = UIColor.black
        cardView.layerShadowOpacity = 0.1
        cardView.layerShadowOffset = CGSize(width: 0, height: 2)
        cardView.layerShadowRadius = 4
        contentView.addSubview(cardView)
    }
    
    private func setupStatusLabel() {
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.layerCornerRadius = 8
        statusLabel.backgroundColor = .systemBlue
        statusLabel.textColor = .white
        cardView.addSubview(statusLabel)
    }
    
    private func setupTimeLabel() {
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .systemGray
        timeLabel.textAlignment = .right
        cardView.addSubview(timeLabel)
    }
    
    private func setupBatteryIcon() {
        batteryIconView.image = UIImage(systemName: "battery.100")
        batteryIconView.tintColor = .systemGreen
        batteryIconView.contentMode = .scaleAspectFit
        cardView.addSubview(batteryIconView)
    }
    
    private func setupProgressView() {
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = .systemGray4
        progressView.layerCornerRadius = 2
        cardView.addSubview(progressView)
    }
    
    private func setupLabels() {
        // 里程标签 - 强化显示
        initialKmLabel.font = .systemFont(ofSize: 16, weight: .medium)
        initialKmLabel.textColor = .label
        
        targetKmLabel.font = .systemFont(ofSize: 16, weight: .medium)
        targetKmLabel.textColor = .label
        
        // 电量标签 - 弱化显示
        initialKwhLabel.font = .systemFont(ofSize: 12)
        initialKwhLabel.textColor = .systemGray2
        
        chargeKwhLabel.font = .systemFont(ofSize: 12)
        chargeKwhLabel.textColor = .systemGray2
        
        percentageLabel.font = .systemFont(ofSize: 18, weight: .bold)
        percentageLabel.textColor = .systemGreen
        percentageLabel.textAlignment = .right
        
        cardView.addSubview(initialKmLabel)
        cardView.addSubview(targetKmLabel)
        cardView.addSubview(initialKwhLabel)
        cardView.addSubview(chargeKwhLabel)
        cardView.addSubview(percentageLabel)
    }
    
    private func setupDurationLabel() {
        durationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = .systemBlue
        durationLabel.textAlignment = .right
        cardView.addSubview(durationLabel)
    }
    
    private func setupMessageLabel() {
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .systemGray2
        messageLabel.numberOfLines = 2
        cardView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.width.equalTo(60)
            make.height.equalTo(24)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.leading.greaterThanOrEqualTo(statusLabel.snp.trailing).offset(8)
        }
        
        batteryIconView.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(24)
        }
        
        progressView.snp.makeConstraints { make in
            make.centerY.equalTo(batteryIconView)
            make.leading.equalTo(batteryIconView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(4)
        }
        
        initialKmLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(16)
        }
        
        percentageLabel.snp.makeConstraints { make in
            make.centerY.equalTo(initialKmLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        targetKmLabel.snp.makeConstraints { make in
            make.top.equalTo(initialKmLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(16)
        }
        
        initialKwhLabel.snp.makeConstraints { make in
            make.top.equalTo(targetKmLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
        }
        
        chargeKwhLabel.snp.makeConstraints { make in
            make.top.equalTo(initialKwhLabel.snp.bottom).offset(2)
            make.leading.equalToSuperview().offset(16)
        }
        
        durationLabel.snp.makeConstraints { make in
            make.centerY.equalTo(chargeKwhLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(chargeKwhLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
    // MARK: - Configuration
    func configure(with task: ChargeTaskModel) {
        statusLabel.text = task.statusText
        statusLabel.backgroundColor = task.statusColor
        statusLabel.textColor = .white
        
        initialKmLabel.text = "初始里程: \(String(format: "%.1f", task.initialKm)) km"
        targetKmLabel.text = "目标里程: \(String(format: "%.1f", task.targetKm)) km"
        initialKwhLabel.text = "初始电量: \(String(format: "%.1f", task.initialKwh)) kWh"
        chargeKwhLabel.text = "目标电量: \(String(format: "%.1f", task.targetKwh)) kWh"
        
        // 计算进度和百分比 - 基于已充电量
        let targetChargeAmount = task.targetKwh - task.initialKwh
        let progress: Float = targetChargeAmount > 0 ? task.chargedKwh / targetChargeAmount : 0
        let percentage = Int(min(progress * 100, 100))
        percentageLabel.text = "\(percentage)%"
        
        progressView.progress = min(max(progress, 0), 1)
        
        // 格式化创建时间显示
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: task.createdAt) {
            formatter.dateFormat = "MM-dd HH:mm"
            timeLabel.text = "创建时间："+formatter.string(from: date)
        } else {
            timeLabel.text = "创建时间："+task.createdAt
        }
        
        // 设置持续时间
        durationLabel.text = task.chargeDuration
        
        // 设置消息
        if let message = task.message, !message.isEmpty {
            messageLabel.text = message
            messageLabel.isHidden = false
        } else {
            messageLabel.isHidden = true
        }
        
        // 设置电池图标和进度条颜色
        updateBatteryIcon(progress: progress)
    }
    
    private func updateBatteryIcon(progress: Float) {
        let percentage = progress * 100
        if percentage <= 20 {
            batteryIconView.image = UIImage(systemName: "battery.25")
            batteryIconView.tintColor = .systemRed
            progressView.progressTintColor = .systemRed
        } else if percentage <= 50 {
            batteryIconView.image = UIImage(systemName: "battery.50")
            batteryIconView.tintColor = .systemOrange
            progressView.progressTintColor = .systemOrange
        } else if percentage <= 75 {
            batteryIconView.image = UIImage(systemName: "battery.75")
            batteryIconView.tintColor = .systemYellow
            progressView.progressTintColor = .systemYellow
        } else {
            batteryIconView.image = UIImage(systemName: "battery.100")
            batteryIconView.tintColor = .systemGreen
            progressView.progressTintColor = .systemGreen
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        statusLabel.text = nil
        timeLabel.text = nil
        initialKmLabel.text = nil
        targetKmLabel.text = nil
        initialKwhLabel.text = nil
        chargeKwhLabel.text = nil
        durationLabel.text = nil
        messageLabel.text = nil
        messageLabel.isHidden = false
        progressView.progress = 0
    }
}
