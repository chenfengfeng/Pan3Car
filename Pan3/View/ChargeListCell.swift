//
//  ChargeListCell.swift
//  Pan3
//
//  Created by Feng on 2025/1/2.
//

import UIKit
import SnapKit
import SwifterSwift

class ChargeListCell: UITableViewCell {
    static let identifier = "ChargeListCell"
    
    // MARK: - UI Components
    private let cardView = UIView()
    
    // 顶部容器：时间和状态
    private let topContainerView = UIView()
    private let timeLabel = UILabel()
    private let statusLabel = QMUILabel()
    
    // 主要信息容器：里程和SOC
    private let mainInfoContainerView = UIView()
    private let mileageInfoView = UIView()
    private let mileageIconView = UIImageView()  // 改为UIImageView
    private let initialKmLabel = UILabel()
    private let chargedKmLabel = UILabel()
    
    private let socInfoView = UIView()
    private let socIconView = UIImageView()      // 改为UIImageView
    private let socLabel = UILabel()
    
    // 地址信息区域
    private let addressInfoView = UIView()
    private let addressIconView = UIImageView()
    private let addressLabel = UILabel()
    
    // 底部容器：用时
    private let bottomContainerView = UIView()
    private let durationLabel = UILabel()
    
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
        setupContainerViews()
        setupTopSection()
        setupMainInfoSection()
        setupBottomSection()
        setupConstraints()
    }
    
    private func setupCardView() {
        cardView.backgroundColor = UIColor.tertiarySystemBackground
        cardView.layerCornerRadius = 16
        
        contentView.addSubview(cardView)
    }
    
    private func setupContainerViews() {
        // 添加容器视图来更好地组织布局
        cardView.addSubview(topContainerView)
        cardView.addSubview(mainInfoContainerView)
        cardView.addSubview(bottomContainerView)
        
        // 主要信息区域的子容器
        mainInfoContainerView.addSubview(mileageInfoView)
        mainInfoContainerView.addSubview(socInfoView)
        mainInfoContainerView.addSubview(addressInfoView)
        
        // 图标容器
        mileageInfoView.addSubview(mileageIconView)
        socInfoView.addSubview(socIconView)
        socInfoView.addSubview(socLabel)
        
        // 地址信息区域
        addressIconView.image = UIImage(systemName: "location")
        addressIconView.tintColor = .systemOrange
        addressIconView.contentMode = .scaleAspectFit
        
        addressLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        addressLabel.textColor = .label
        addressLabel.numberOfLines = 2  // 允许两行显示
        addressLabel.lineBreakMode = .byTruncatingTail
        
        addressInfoView.addSubview(addressIconView)
        addressInfoView.addSubview(addressLabel)
        
        mainInfoContainerView.addSubview(mileageInfoView)
        mainInfoContainerView.addSubview(socInfoView)
        mainInfoContainerView.addSubview(addressInfoView)
    }
    
    private func setupTopSection() {
        // 时间标签
        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .left
        timeLabel.numberOfLines = 1
        timeLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        topContainerView.addSubview(timeLabel)

        // 状态徽标
        statusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = .systemGray
        statusLabel.layerCornerRadius = 12
        statusLabel.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        statusLabel.numberOfLines = 1
        statusLabel.textAlignment = .center
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        topContainerView.addSubview(statusLabel)
    }
    
    private func setupMainInfoSection() {
        // 里程信息区域
        mileageIconView.image = UIImage(systemName: "speedometer")
        mileageIconView.tintColor = .systemBlue
        mileageIconView.contentMode = .scaleAspectFit
        
        initialKmLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        initialKmLabel.textColor = .label
        initialKmLabel.numberOfLines = 1
        
        chargedKmLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        chargedKmLabel.textColor = .systemGreen
        chargedKmLabel.numberOfLines = 1
        
        mileageInfoView.addSubview(mileageIconView)
        mileageInfoView.addSubview(initialKmLabel)
        mileageInfoView.addSubview(chargedKmLabel)
        
        // SOC信息区域
        socIconView.image = UIImage(systemName: "battery.100")
        socIconView.tintColor = .systemGreen
        socIconView.contentMode = .scaleAspectFit
        
        socLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        socLabel.textColor = .label
        socLabel.numberOfLines = 1
        
        socInfoView.addSubview(socIconView)
        socInfoView.addSubview(socLabel)
        
        // 地址信息区域
        addressIconView.image = UIImage(systemName: "location")
        addressIconView.tintColor = .systemOrange
        addressIconView.contentMode = .scaleAspectFit
        
        addressLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        addressLabel.textColor = .label
        addressLabel.numberOfLines = 2  // 允许两行显示
        addressLabel.lineBreakMode = .byTruncatingTail
        
        addressInfoView.addSubview(addressIconView)
        addressInfoView.addSubview(addressLabel)
    }
    
    private func setupBottomSection() {
        durationLabel.font = .systemFont(ofSize: 12, weight: .medium)
        durationLabel.textColor = .tertiaryLabel
        durationLabel.textAlignment = .right
        durationLabel.numberOfLines = 1
        bottomContainerView.addSubview(durationLabel)
    }
    
    private func setupConstraints() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            make.height.greaterThanOrEqualTo(215) // 增加高度以适应三行布局
        }
        
        // 顶部容器约束
        topContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(32)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        statusLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(60)
            make.height.equalTo(24)
        }
        
        // 主信息容器
        mainInfoContainerView.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(135) // 增加高度以适应三行布局
        }
        
        // 里程信息视图 - 第一行
        mileageInfoView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(45)
        }
        
        // SOC信息视图 - 第二行
        socInfoView.snp.makeConstraints { make in
            make.top.equalTo(mileageInfoView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(45)
        }
        
        // 地址信息视图 - 第三行
        addressInfoView.snp.makeConstraints { make in
            make.top.equalTo(socInfoView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(45)
        }
        
        // 里程图标约束
        mileageIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // 初始里程标签约束
        initialKmLabel.snp.makeConstraints { make in
            make.leading.equalTo(mileageIconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview().offset(-8)
        }
        
        // 充电里程标签约束
        chargedKmLabel.snp.makeConstraints { make in
            make.leading.equalTo(mileageIconView.snp.trailing).offset(8)
            make.top.equalTo(initialKmLabel.snp.bottom).offset(2)
        }
        
        // SOC图标约束
        socIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // SOC标签约束
        socLabel.snp.makeConstraints { make in
            make.leading.equalTo(socIconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }
        
        // 地址图标约束
        addressIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // 地址标签约束
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(addressIconView.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // 底部容器约束
        bottomContainerView.snp.makeConstraints { make in
            make.top.equalTo(mainInfoContainerView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(20)
        }
        
        durationLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Configuration
    func configure(with task: ChargeTaskModel) {
        var timeText = ""
        if let finishTime = task.finishTime {
            timeText = "\(task.createdAt)~\(finishTime)"
        } else {
            timeText = "\(task.createdAt)~进行中"
        }
        timeLabel.text = timeText

        // 状态文案与颜色
        statusLabel.isHidden = false
        if task.finishTime != nil {
            statusLabel.backgroundColor = .systemOrange
            statusLabel.textColor = .white
            statusLabel.text = "充电完成"
        } else {
            statusLabel.backgroundColor = .systemGreen
            statusLabel.textColor = .white
            statusLabel.text = "正在充电"
        }

        // 用时
        durationLabel.text = "用时：\(task.chargeDuration)"

        // 里程信息：从多少Km到多少Km
        if let endKm = task.endKm {
            initialKmLabel.text = "里程：\(task.startKm) km → \(endKm) km"
        }else {
            initialKmLabel.text = "里程：\(task.startKm) km → --"
        }
        

        // 充了多少Km
        let delta = (task.endKm ?? task.startKm) - task.startKm
        if delta > 0 {
            chargedKmLabel.text = "增加 +\(delta) km"
        } else {
            chargedKmLabel.text = "增加 --"
        }

        // SOC 记录
        if let e = task.endSoc {
            socLabel.text = "SOC：\(task.startSoc)% → \(e)%"
        } else {
            socLabel.text = "SOC：\(task.startSoc)% → --"
        }
        
        // 地址信息
        if let address = task.address, !address.isEmpty {
            addressLabel.text = "地址：\(address)"
        } else {
            addressLabel.text = "地址：未知地址"
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        timeLabel.text = nil
        statusLabel.text = nil
        initialKmLabel.text = nil
        chargedKmLabel.text = nil
        durationLabel.text = nil
        socLabel.text = nil
        addressLabel.text = nil
        statusLabel.backgroundColor = .systemGray
        statusLabel.textColor = .white
    }
}
