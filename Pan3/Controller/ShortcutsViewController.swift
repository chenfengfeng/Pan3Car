//
//  ShortcutsViewController.swift
//  Pan3
//
//  Created by Feng on 2025/6/29.
//

import UIKit
import SnapKit
import QMUIKit
import CoreNFC
import MJRefresh

class ShortcutsViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var siriView: UIScrollView!
    @IBOutlet weak var shortcutsView: UIScrollView!
    
    // MARK: - 行程记录相关属性
    private var tripRecords: [TripRecordData] = []
    private var currentPage = 1
    private var totalPages = 1
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupTableView()
        loadTripRecords()
    }
    
    // MARK: - 点击事件
    @IBAction func changeSegment(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            siriView.isHidden = true
            tableView.isHidden = false
            shortcutsView.isHidden = true
        }else if sender.selectedSegmentIndex == 1 {
            siriView.isHidden = false
            tableView.isHidden = true
            shortcutsView.isHidden = true
        }else if sender.selectedSegmentIndex == 2 {
            siriView.isHidden = true
            tableView.isHidden = true
            shortcutsView.isHidden = false
        }
    }
    
    @IBAction func writeNFC(_ sender: Any) {
        // 检查设备是否支持NFC
        guard NFCNDEFReaderSession.readingAvailable else {
            let alert = UIAlertController(title: "不支持NFC", message: "此设备不支持NFC功能或NFC功能未启用", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "请将iPhone靠近NFC标签进行写入"
        session.begin()
    }
    
    @IBAction func openShortcuts(_ sender: Any) {
        if let url = URL(string: "shortcuts://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let alert = UIAlertController(title: "无法打开", message: "无法打开快捷指令App", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // 用户取消，不显示错误
                    break
                default:
                    let alert = UIAlertController(title: "NFC错误", message: nfcError.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // 检测到NDEF消息，但我们需要写入功能
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "未检测到有效的NFC标签")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "连接NFC标签失败: \(error.localizedDescription)")
                return
            }
            
            // 创建NDEF消息
            let payload = "Pan3_Car_Lock".data(using: .utf8)!
            let record = NFCNDEFPayload(format: .nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data(), payload: payload)
            let message = NFCNDEFMessage(records: [record])
            
            // 写入NDEF消息
            tag.writeNDEF(message) { error in
                if let error = error {
                    session.invalidate(errorMessage: "写入失败: \(error.localizedDescription)")
                } else {
                    session.alertMessage = "写入成功！"
                    session.invalidate()
                    
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "成功", message: "已成功写入到NFC标签", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - 行程记录相关方法
    private func setupHeader() {
        let isBlurAddress = UserDefaults.standard.bool(forKey: "isBlurAddress")
        
        let title = UILabel(text: "隐藏地址")
        title.font = .systemFont(ofSize: 14)
        title.textColor = .white
        view.addSubview(title)
        let sw = UISwitch()
        sw.isOn = isBlurAddress
        sw.addTarget(self, action: #selector(changeSwitch), for: .valueChanged)
        view.addSubview(sw)
        let view = UIStackView(arrangedSubviews: [title, sw], axis: .horizontal)
        view.spacing = 4
        let item = UIBarButtonItem(customView: view)
        navigationItem.rightBarButtonItem = item
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TripRecordCell.self, forCellReuseIdentifier: "TripRecordCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemGroupedBackground
        
        // 使用 MJRefresh 添加下拉刷新
        let header = MJRefreshNormalHeader { [weak self] in
            self?.refreshTripRecords()
        }
        header.lastUpdatedTimeLabel?.isHidden = true
        tableView.mj_header = header
        
        // 使用 MJRefresh 添加上拉加载更多
        let footer = MJRefreshAutoNormalFooter { [weak self] in
            self?.loadMoreTripRecords()
        }
        tableView.mj_footer = footer
    }
    
    private func loadTripRecords(page: Int = 1) {
        guard !isLoading else { return }
        
        isLoading = true
        
        NetworkManager.shared.getTripRecords(page: page) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                // 结束刷新状态
                if page == 1 {
                    self?.tableView.mj_header?.endRefreshing()
                } else {
                    if case .success(let response) = result, response.trips.isEmpty {
                        self?.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    } else {
                        self?.tableView.mj_footer?.endRefreshing()
                    }
                }
                
                switch result {
                case .success(let response):
                    if page == 1 {
                        self?.tripRecords = response.trips
                    } else {
                        self?.tripRecords.append(contentsOf: response.trips)
                    }
                    
                    self?.currentPage = response.pagination.currentPage
                    self?.totalPages = response.pagination.totalPages
                    self?.tableView.reloadData()
                    
                    // 检查是否还有更多数据
                    if self?.currentPage ?? 0 >= self?.totalPages ?? 0 {
                        self?.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    }
                    
                case .failure(let error):
                    self?.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func refreshTripRecords() {
        currentPage = 1
        // 重置 footer 状态
        tableView.mj_footer?.resetNoMoreData()
        loadTripRecords(page: 1)
    }
    
    private func loadMoreTripRecords() {
        guard currentPage < totalPages && !isLoading else { return }
        loadTripRecords(page: currentPage + 1)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func changeSwitch(_ sender: UISwitch) {
        let ud = UserDefaults.standard
        ud.set(sender.isOn, forKey: "isBlurAddress")
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension ShortcutsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tripRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TripRecordCell", for: indexPath) as! TripRecordCell
        let tripData = tripRecords[indexPath.row]
        cell.configure(with: tripData)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ShortcutsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        // 创建带有渐变背景和APP信息的分享图片
        let image = cell.qmui_snapshotImage(afterScreenUpdates: true)
        let shareImage = createShareImage(from: image)
        
        // 分享图片
        let activityViewController = UIActivityViewController(activityItems: [shareImage], applicationActivities: nil)
        
        // 对于iPad，需要设置popover的源
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    // MARK: - 创建分享图片
    private func createShareImage(from cellImage: UIImage) -> UIImage {
        // 设置画布尺寸，增加底部空间用于放置logo和名称
        let padding: CGFloat = 40
        let logoHeight: CGFloat = 60
        let appNameHeight: CGFloat = 38
        let bottomSpace: CGFloat = 40
        
        let canvasWidth = cellImage.size.width + padding * 2
        let canvasHeight = cellImage.size.height + padding * 2 + logoHeight + appNameHeight + bottomSpace
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 创建渐变背景
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
                return
            }
            
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: canvasWidth, y: canvasHeight)
            cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            
            // 绘制cell图片（添加圆角和阴影效果）
            let cellRect = CGRect(x: padding, y: padding, width: cellImage.size.width, height: cellImage.size.height)
            
            // 添加阴影
            cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            
            // 绘制圆角矩形背景
            let roundedRect = UIBezierPath(roundedRect: cellRect, cornerRadius: 12)
            cgContext.addPath(roundedRect.cgPath)
            cgContext.clip()
            
            // 绘制cell图片
            cellImage.draw(in: cellRect)
            
            // 重置裁剪区域
            cgContext.resetClip()
            
            // 绘制APP logo
//            let logoRect = CGRect(x: (canvasWidth - logoHeight) / 2, 
//                                y: cellRect.maxY + 20, 
//                                width: logoHeight, 
//                                height: logoHeight)
            
            // 创建圆形背景
//            let logoBackground = UIBezierPath(ovalIn: logoRect)
//            UIColor.white.withAlphaComponent(0.9).setFill()
//            logoBackground.fill()
//            
//            // 绘制APP图标
//            if let appIcon = UIImage(named: "login") {
//                let iconSize: CGFloat = logoHeight * 0.8
//                let iconRect = CGRect(x: logoRect.midX - iconSize/2, 
//                                    y: logoRect.midY - iconSize/2, 
//                                    width: iconSize, 
//                                    height: iconSize)
//                
//                // 以原始颜色绘制图片，不使用template模式
//                appIcon.draw(in: iconRect)
//            }
            
            // 绘制APP名称
            let appName = "胖3助手"
            let nameRect = CGRect(x: padding,
                                y: cellRect.maxY + 80,
                                width: canvasWidth - padding * 2,
                                height: appNameHeight)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle,
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
                    shadow.shadowOffset = CGSize(width: 0, height: 1)
                    shadow.shadowBlurRadius = 2
                    return shadow
                }()
            ]
            
            appName.draw(in: nameRect, withAttributes: nameAttributes)
            
            // 添加底部标语
            let slogan = "智能出行，尽在掌握"
            let sloganRect = CGRect(x: padding, 
                                  y: nameRect.maxY,
                                  width: canvasWidth - padding * 2,
                                  height: 20)
            
            let sloganAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]
            
            slogan.draw(in: sloganRect, withAttributes: sloganAttributes)
            
            // 绘制右下角圆形二维码
            if let qrCodeImage = UIImage(named: "qrcode_app") {
                let qrCodeSize: CGFloat = 100
                let qrCodePadding: CGFloat = 20
                let qrCodeRect = CGRect(x: canvasWidth - qrCodeSize - qrCodePadding,
                                      y: canvasHeight - qrCodeSize - qrCodePadding,
                                      width: qrCodeSize,
                                      height: qrCodeSize)
                
                // 绘制圆形二维码图片（使用圆形裁剪）
                let clipPath = UIBezierPath(ovalIn: qrCodeRect)
                clipPath.addClip()
                qrCodeImage.draw(in: qrCodeRect)
            }
        }
    }
}
