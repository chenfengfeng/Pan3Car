//
//  VehicleStatusView.swift
//  Pan3
//
//  Created by Feng on 2025/8/23.
//

import UIKit

class VehicleStatusView: UIStackView {
    // 车窗状态
    private lazy var leftTopWindowStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左前车窗：关闭"
        return label
    }()
    
    private lazy var rightTopWindowStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右前车窗：关闭"
        return label
    }()
    
    private lazy var leftBottomWindowStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左后车窗：关闭"
        return label
    }()
    
    private lazy var rightBottomWindowStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右后车窗：关闭"
        return label
    }()
    
    // 车门状态
    private lazy var leftTopDoorStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左前车门：关闭"
        return label
    }()
    
    private lazy var rightTopDoorStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右前车门：关闭"
        return label
    }()
    
    private lazy var leftBottomDoorStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左后车门：关闭"
        return label
    }()
    
    private lazy var rightBottomDoorStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右后车门：关闭"
        return label
    }()
    
    private lazy var tailDoorStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "后尾门：关闭"
        return label
    }()
    
    // 胎压数值
    private lazy var leftTopTPStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左前胎压：--"
        return label
    }()
    
    private lazy var rightTopTPStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右前胎压：--"
        return label
    }()
    
    private lazy var leftBottomTPStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "左后胎压：--"
        return label
    }()
    
    private lazy var rightBottomTPStatus: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "右后胎压：--"
        return label
    }()
    
    func setupWindowUI() {
        do {
            let stackView = UIStackView(arrangedSubviews: [leftTopWindowStatus, rightTopWindowStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
        do {
            let stackView = UIStackView(arrangedSubviews: [leftBottomWindowStatus, rightBottomWindowStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
    }
    
    func setupDoorUI() {
        do {
            let stackView = UIStackView(arrangedSubviews: [leftTopDoorStatus, rightTopDoorStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
        do {
            let stackView = UIStackView(arrangedSubviews: [leftBottomDoorStatus, rightBottomDoorStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
        do {
            let stackView = UIStackView(arrangedSubviews: [tailDoorStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
    }
    
    func setupTPUI() {
        do {
            let stackView = UIStackView(arrangedSubviews: [leftTopTPStatus, rightTopTPStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
        do {
            let stackView = UIStackView(arrangedSubviews: [leftBottomTPStatus, rightBottomTPStatus])
            stackView.distribution = .fillProportionally
            stackView.axis = .horizontal
            stackView.spacing = 40
            addArrangedSubview(stackView)
        }
    }
    
    // MARK: - 更新车辆状态信息
    func updateWindowStatusInfo() {
        guard let model = UserManager.shared.carModel else { return }
        // 车窗状态
        setStatusText(for: leftTopWindowStatus, prefix: "左前车窗：", isOpen: model.lfWindowOpen != 0)
        setStatusText(for: rightTopWindowStatus, prefix: "右前车窗：", isOpen: model.rfWindowOpen != 0)
        setStatusText(for: leftBottomWindowStatus, prefix: "左后车窗：", isOpen: model.lrWindowOpen != 0)
        setStatusText(for: rightBottomWindowStatus, prefix: "右后车窗：", isOpen: model.rrWindowOpen != 0)
    }
    
    func updateDoorStatusInfo() {
        guard let model = UserManager.shared.carModel else { return }
        // 车门状态
        setStatusText(for: leftTopDoorStatus, prefix: "左前车门：", isOpen: model.doorStsFrontLeft != 0)
        setStatusText(for: rightTopDoorStatus, prefix: "右前车门：", isOpen: model.doorStsFrontRight != 0)
        setStatusText(for: leftBottomDoorStatus, prefix: "左后车门：", isOpen: model.doorStsRearLeft != 0)
        setStatusText(for: rightBottomDoorStatus, prefix: "右后车门：", isOpen: model.doorStsRearRight != 0)
        
        // 后备箱状态
        setStatusText(for: tailDoorStatus, prefix: "后尾箱：", isOpen: model.trunkLockStatus != 0)
    }
    func updateTPStatusInfo() {
        guard let model = UserManager.shared.carModel else { return }
        // 胎压状态（数据为0时显示--）
        leftTopTPStatus.text = "左前胎压：\(model.lfTirePresure == 0 ? "--" : "\(model.lfTirePresure)")"
        rightTopTPStatus.text = "右前胎压：\(model.rfTirePresure == 0 ? "--" : "\(model.rfTirePresure)")"
        leftBottomTPStatus.text = "左后胎压：\(model.lrTirePresure == 0 ? "--" : "\(model.lrTirePresure)")"
        rightBottomTPStatus.text = "右后胎压：\(model.rrTirePresure == 0 ? "--" : "\(model.rrTirePresure)")"
    }
    
    // MARK: - 设置状态文字颜色
    private func setStatusText(for label: UILabel, prefix: String, isOpen: Bool) {
        let statusText = isOpen ? "开启" : "关闭"
        let statusColor: UIColor = isOpen ? .systemGreen : .white
        
        let attributedString = NSMutableAttributedString(string: prefix + statusText)
        let statusRange = NSRange(location: prefix.count, length: statusText.count)
        attributedString.addAttribute(.foregroundColor, value: statusColor, range: statusRange)
        
        label.attributedText = attributedString
    }
}
