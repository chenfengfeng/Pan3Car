//
//  ChargeViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import QMUIKit
import SwifterSwift

class ChargeViewController: UIViewController, CarDataRefreshable {
    @IBOutlet weak var mile: UILabel!
    @IBOutlet weak var soc: UIProgressView!
    @IBOutlet weak var chargeStatus: UILabel!

    @IBOutlet weak var segmentView: UISegmentedControl!
    // 服务费view
    @IBOutlet weak var tipPriceView: UIStackView!
    @IBOutlet weak var tipUnitPrice: UITextField!
    @IBOutlet weak var tipPrice: UITextField!
    // 电量view
    @IBOutlet weak var kWhView: UIStackView!
    @IBOutlet weak var kWhField: UITextField!
    // 价格view
    @IBOutlet weak var priceView: UIStackView!
    @IBOutlet weak var unitPrice: UITextField!
    @IBOutlet weak var price: UITextField!
    
    @IBOutlet weak var autoChargeBtn: QMUIButton!
    @IBOutlet weak var stopChargeBtn: QMUIButton!
    @IBOutlet weak var chargeTimeLeft: UILabel!
    
    // 标记是否是首次数据加载
    var isFirstDataLoad = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 注册应用进入前台通知
        registerAppDidBecomeActiveNotification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !isFirstDataLoad {
            setupCarData()
            fetchCarInfo()
            getTaskStatus()
        } else {
            // 首次加载
            setupCarData()
            fetchCarInfo()
            getTaskStatus()
            isFirstDataLoad = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - CarDataRefreshable Protocol Implementation
    func refreshCarData() {
        fetchCarInfo()
        getTaskStatus()
    }
    
    @objc func handleAppDidBecomeActive() {
        print("APP重新进入前台了 - ChargeViewController")
        if !isFirstDataLoad {
            refreshCarData()
        }
    }
    
    // MARK: - 初始化界面
    func setupUI() {
        navigationItem.title = "便捷充电"
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
                switch result {
                case .success(let carModel):
                    // 保存车辆信息
                    UserManager.shared.carModel = carModel
                    self.setupCarData()
                case .failure(let error):
                    QMUITips.show(withText: "获取车辆信息失败: \(error.localizedDescription)", in: self.view, hideAfterDelay: 2.0)
                }
            }
        }
    }
    
    // MARK: - 配置信息
    func formatTime(minutes: Float) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return "\(hours)小时\(mins)分钟\(secs)秒"
    }
    
    func setupCarData() {
        guard let model = UserManager.shared.carModel else { return }
        
        let targetMileValue = model.acOnMile
        let targetSocValue = model.soc.nsString.floatValue / 100
        
        mile.text = "\(targetMileValue)"
        soc.progress = targetSocValue
        
        // 根据SOC值设置进度条颜色
        let percentage = targetSocValue * 100
        if percentage <= 20 {
            soc.progressTintColor = .systemRed
        } else if percentage <= 50 {
            soc.progressTintColor = .systemOrange
        } else {
            soc.progressTintColor = .systemGreen
        }
        
        // 充电状态
        if model.chgStatus == 2 {
            stopChargeBtn.isHidden = true
            chargeTimeLeft.isHidden = true
            chargeStatus.text = "当前没有在充电"
        }else{
            stopChargeBtn.isHidden = false
            chargeTimeLeft.isHidden = false
            chargeStatus.text = "⚡️当前正在充电"
            chargeTimeLeft.text = "预计充满时间："+formatTime(minutes: model.quickChgLeftTime.float)
        }
    }
    
    // MARK: - 点击事件
    @IBAction func clickDianfen(_ sender: Any) {
        if let image = UIImage(named: "qrcode") {
            QMUIImageWriteToSavedPhotosAlbumWithAlbumAssetsGroup(image, QMUIAssetsGroup()) { _, error in
                if error == nil {
                    let alert = UIAlertController(title: "点击确定跳转到微信扫一扫识别二维码即可领取充电金", message: nil, preferredStyle: .alert)
                    alert.addAction(title: "确定") { _ in
                        if let url = URL(string: "weixin://scanqrcode") {
                            UIApplication.shared.open(url)
                        }
                    }
                    alert.addAction(title: "算了我自己打开微信", style: .cancel)
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    @IBAction func clickChargeList(_ sender: Any) {
        let vc = ChargeListController()
        vc.hidesBottomBarWhenPushed = true
        show(vc, sender: nil)
    }
    
    @IBAction func clickBatteryInfo(_ sender: Any) {
        guard let model = UserManager.shared.carModel else { return }
        // 电池信息
        let estimated = model.estimatedModelAndCapacity
        let socValue = model.soc.nsString.floatValue
        let capacity = estimated.batteryCapacity.float
        let remainingKWh = capacity * (socValue / 100)
        let remainingTo90KWh = max(0, capacity * 0.9 - remainingKWh)

        var fastChargeTimeToFull: Float = 0
        var slowChargeTimeToFull: Float = 0
        var fastChargePower: Float = 0
        var slowChargePower: Float = 0

        switch estimated.model {
        case "330":
            fastChargeTimeToFull = 0.58
            slowChargeTimeToFull = 12
            fastChargePower = 34.5 * 0.5 / fastChargeTimeToFull // ≈29.7
            slowChargePower = 34.5 / slowChargeTimeToFull
        case "405":
            fastChargeTimeToFull = 0.5
            slowChargeTimeToFull = 7.5
            fastChargePower = 41 * 0.5 / fastChargeTimeToFull // ≈41
            slowChargePower = 41 / slowChargeTimeToFull
        case "505":
            fastChargeTimeToFull = 0.5
            slowChargeTimeToFull = 9
            fastChargePower = 51.5 * 0.5 / fastChargeTimeToFull // ≈51.5
            slowChargePower = 51.5 / slowChargeTimeToFull
        default:
            break
        }

        let fastMinutesTo90 = fastChargePower > 0 ? remainingTo90KWh / fastChargePower * 60 : 0
        let slowMinutesTo90 = slowChargePower > 0 ? remainingTo90KWh / slowChargePower * 60 : 0

        let text = """
        当前车型：\(estimated.model) km
        电池总容量：\(capacity) kWh

        当前电量：\(String(format: "%.1f", remainingKWh)) kWh
        距离100%可再充：\(String(format: "%.1f", capacity-remainingKWh)) kWh

        预计充到90%时间：
        快充约需：\(formatTime(minutes: fastMinutesTo90))
        慢充约需：\(formatTime(minutes: slowMinutesTo90))
        
        \(model.chgStatus != 2 ? "当前正在充电\n充满需要：\(formatTime(minutes: model.quickChgLeftTime.float))" : "")
        """
        let modal = ModalView()
        modal.text = text
        modal.show()
    }
    
    @IBAction func changeSegmentView(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            tipPriceView.isHidden = false
            priceView.isHidden = true
            kWhView.isHidden = true
        case 1:
            tipPriceView.isHidden = true
            priceView.isHidden = true
            kWhView.isHidden = false
        case 2:
            tipPriceView.isHidden = true
            priceView.isHidden = false
            kWhView.isHidden = true
        default:
            break
        }
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func clickAutoCharge(_ sender: QMUIButton) {
        view.endEditing(true)
        NetworkManager.shared.getChargeStatus { result in
            switch result {
            case .success(let response):
                if response.hasRunningTask {
                    // 当前有正在充电的任务
                    self.cancelCharge()
                }else{
                    // 当前没有充电的任务
                    self.startCharge()
                }
            default:
                break
            }
        }
    }
    
    @IBAction func clickStopCharge(_ sender: QMUIButton) {
        // 显示确认对话框
        let alert = UIAlertController(title: "确认停止", message: "确定要停止当前的充电吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { _ in
            // 调用停止充电接口
            NetworkManager.shared.stopCharge { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        self.fetchCarInfo()
                        self.getTaskStatus()
                        LiveActivityManager.shared.cleanupAllActivities()
                        self.showAlert(title: "停止成功", message: "充电已成功停止")
                    case .failure(let error):
                        self.showAlert(title: "停止失败", message: error.localizedDescription)
                    }
                }
            }
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - 充电功能
    // 获取充电任务状态
    private func getTaskStatus() {
        NetworkManager.shared.getChargeStatus { result in
            switch result {
            case .success(let response):
                if response.hasRunningTask {
                    // 当前有正在充电的任务
                    self.autoChargeBtn.setTitle("取消充电任务", for: .normal)
                }else{
                    // 当前没有充电的任务
                    self.autoChargeBtn.setTitle("启动自动停止充电任务", for: .normal)
                }
            default:
                break
            }
        }
    }
    
    // 取消充电任务
    private func cancelCharge() {
        // 显示确认对话框
        let alert = UIAlertController(title: "确认取消", message: "确定要取消当前的充电任务吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { _ in
            // 调用取消充电接口
            NetworkManager.shared.cancelChargeTask { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        self.getTaskStatus()
                        LiveActivityManager.shared.cleanupAllActivities()
                        self.showAlert(title: "取消成功", message: "充电任务已成功取消")
                    case .failure(let error):
                        self.showAlert(title: "取消失败", message: error.localizedDescription)
                    }
                }
            }
        }))
        
        present(alert, animated: true)
    }
    
    // 按电量充电
    private func startCharge() {
        // 检查是否首次使用充电功能
        if !UserManager.shared.hasAcceptedChargeAgreement {
            showChargeAgreementAlert()
            return
        }
        
        executeChargeTask()
    }
    
    // 显示充电协议提示
    private func showChargeAgreementAlert() {
        let alert = UIAlertController(
            title: "充电服务协议",
            message: "为了向您推送充电状态通知，我们需要使用和记录您的登录凭证与服务器进行通信。点击\"确定\"即表示您同意此服务条款。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            // 用户同意协议，标记已接受并执行充电任务
            UserManager.shared.markChargeAgreementAccepted()
            self.executeChargeTask()
        }))
        
        present(alert, animated: true)
    }
    
    // 执行充电任务
    private func executeChargeTask() {
        var kWh: Float = 0
        switch segmentView.selectedSegmentIndex {
        case 0:
            guard
                let unitText = tipUnitPrice.text?.trimmingCharacters(in: .whitespaces),
                let priceText = tipPrice.text?.trimmingCharacters(in: .whitespaces),
                !unitText.isEmpty,
                !priceText.isEmpty
            else {
                QMUITips.showError("请输入完整的服务费单价和总服务费")
                return
            }
            let unit = unitText.nsString.floatValue
            if unit == 0 {
                QMUITips.showError("单价不能为0")
                return
            }
            kWh = priceText.nsString.floatValue / unit
        case 1:
            guard
                let text = kWhField.text?.trimmingCharacters(in: .whitespaces),
                !text.isEmpty
            else {
                QMUITips.showError("请输入充电电量")
                return
            }
            kWh = text.nsString.floatValue
        case 2:
            guard
                let unitText = unitPrice.text?.trimmingCharacters(in: .whitespaces),
                let priceText = price.text?.trimmingCharacters(in: .whitespaces),
                !unitText.isEmpty,
                !priceText.isEmpty
            else {
                QMUITips.showError("请输入完整的电价和总电费")
                return
            }
            let unit = unitText.nsString.floatValue
            if unit == 0 {
                QMUITips.showError("单价不能为0")
                return
            }
            kWh = priceText.nsString.floatValue / unit
        default:
            break
        }
        NetworkManager.shared.startChargeTask(charge_kwh: kWh) { result in
            switch result {
            case .success(let response):
                self.getTaskStatus()
                if let model = response.task {
                    LiveActivityManager.shared.startChargeActivity(with: model)
                }
                self.showAlert(title: "充电任务创建成功", message: "已成功启动自动充电停止任务，充电量：\(kWh) kWh，已开启实时活动，你可以实时观看任务进度")
            case .failure(let error):
                self.showAlert(title: "充电任务创建失败", message: error.localizedDescription)
            }
        }
    }
    
    // 显示提示框
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            self.getTaskStatus()
        }))
        present(alert, animated: true)
    }
}
