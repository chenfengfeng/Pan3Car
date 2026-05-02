//
//  ScanViewController.swift
//  Pan3
//
//  Created by Kiro on 2025/12/30.
//

import UIKit
import AVFoundation
import Alamofire
import SafariServices

class ScanViewController: UIViewController {
    
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessing = false
    
    // 扫描框
    private let scanFrameView = UIView()
    private let scanLineView = UIView()
    private var scanLineAnimation: CABasicAnimation?
    
    // 提示标签
    private let tipLabel = UILabel()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCameraPermission()
        // 提前触发本地网络权限请求
        requestLocalNetworkPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    deinit {
        captureSession?.stopRunning()
        captureSession = nil
        print("ScanViewController deinit")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateScanFramePosition()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "扫一扫"
        view.backgroundColor = .black
        
        // 关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        
        // 手电筒按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "flashlight.off.fill"),
            style: .plain,
            target: self,
            action: #selector(toggleFlashlight)
        )
        
        setupScanFrame()
        setupTipLabel()
    }
    
    private func setupScanFrame() {
        // 扫描框
        scanFrameView.layer.borderColor = UIColor.white.cgColor
        scanFrameView.layer.borderWidth = 2
        scanFrameView.backgroundColor = .clear
        view.addSubview(scanFrameView)
        
        // 扫描线
        scanLineView.backgroundColor = UIColor.systemGreen
        scanFrameView.addSubview(scanLineView)
    }
    
    private func setupTipLabel() {
        tipLabel.text = "将二维码放入框内，即可自动扫描"
        tipLabel.textColor = .white
        tipLabel.font = .systemFont(ofSize: 14)
        tipLabel.textAlignment = .center
        view.addSubview(tipLabel)
    }
    
    private func updateScanFramePosition() {
        let scanSize: CGFloat = 250
        let centerX = view.bounds.width / 2
        let centerY = view.bounds.height / 2 - 50
        
        scanFrameView.frame = CGRect(
            x: centerX - scanSize / 2,
            y: centerY - scanSize / 2,
            width: scanSize,
            height: scanSize
        )
        
        scanLineView.frame = CGRect(x: 0, y: 0, width: scanSize, height: 2)
        
        tipLabel.frame = CGRect(
            x: 20,
            y: scanFrameView.frame.maxY + 20,
            width: view.bounds.width - 40,
            height: 20
        )
        
        // 添加四角装饰
        addCornerDecorations()
    }
    
    private func addCornerDecorations() {
        // 移除旧的装饰
        scanFrameView.layer.sublayers?.filter { $0.name == "corner" }.forEach { $0.removeFromSuperlayer() }
        
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 4
        let color = UIColor.systemGreen.cgColor
        
        let corners: [(CGPoint, Bool, Bool)] = [
            (CGPoint(x: 0, y: 0), true, true),           // 左上
            (CGPoint(x: scanFrameView.bounds.width, y: 0), false, true),  // 右上
            (CGPoint(x: 0, y: scanFrameView.bounds.height), true, false), // 左下
            (CGPoint(x: scanFrameView.bounds.width, y: scanFrameView.bounds.height), false, false) // 右下
        ]
        
        for (point, isLeft, isTop) in corners {
            // 水平线
            let hLayer = CALayer()
            hLayer.name = "corner"
            hLayer.backgroundColor = color
            hLayer.frame = CGRect(
                x: isLeft ? point.x : point.x - cornerLength,
                y: isTop ? point.y : point.y - cornerWidth,
                width: cornerLength,
                height: cornerWidth
            )
            scanFrameView.layer.addSublayer(hLayer)
            
            // 垂直线
            let vLayer = CALayer()
            vLayer.name = "corner"
            vLayer.backgroundColor = color
            vLayer.frame = CGRect(
                x: isLeft ? point.x : point.x - cornerWidth,
                y: isTop ? point.y : point.y - cornerLength,
                width: cornerWidth,
                height: cornerLength
            )
            scanFrameView.layer.addSublayer(vLayer)
        }
    }
    
    // MARK: - Local Network Permission
    /// 提前触发本地网络权限请求，避免在扫描时卡住
    private func requestLocalNetworkPermission() {
        // 通过尝试连接本地地址来触发本地网络权限弹窗
        // 使用一个常见的本地网络地址，即使连接失败也会触发权限请求
        guard let url = URL(string: "http://192.168.1.1") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.1 // 设置很短的超时时间，快速失败
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            // 忽略错误，我们只是为了触发权限请求
            // 连接失败是预期的，因为我们只是用来触发权限弹窗
            if let error = error {
                print("本地网络权限请求触发: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Camera
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                        self?.startScanning()  // 权限通过后立即启动扫描
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        default:
            showPermissionDeniedAlert()
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession,
              captureSession.canAddInput(videoInput) else {
            showCameraError()
            return
        }
        
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            showCameraError()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.insertSublayer(previewLayer, at: 0)
        }
        
        // 添加遮罩
        addMaskLayer()
    }
    
    private func addMaskLayer() {
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: view.bounds)
        
        let scanSize: CGFloat = 250
        let centerX = view.bounds.width / 2
        let centerY = view.bounds.height / 2 - 50
        let scanRect = CGRect(
            x: centerX - scanSize / 2,
            y: centerY - scanSize / 2,
            width: scanSize,
            height: scanSize
        )
        
        path.append(UIBezierPath(rect: scanRect).reversing())
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        
        view.layer.insertSublayer(maskLayer, above: previewLayer)
    }
    
    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
        startScanLineAnimation()
        isProcessing = false
    }
    
    private func stopScanning() {
        captureSession?.stopRunning()
        stopScanLineAnimation()
    }
    
    private func startScanLineAnimation() {
        scanLineView.isHidden = false
        scanLineView.layer.removeAllAnimations()
        
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = 0
        animation.toValue = scanFrameView.bounds.height
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        scanLineView.layer.add(animation, forKey: "scanLine")
    }
    
    private func stopScanLineAnimation() {
        scanLineView.layer.removeAllAnimations()
        scanLineView.isHidden = true
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                navigationItem.rightBarButtonItem?.image = UIImage(systemName: "flashlight.off.fill")
            } else {
                try device.setTorchModeOn(level: 1.0)
                navigationItem.rightBarButtonItem?.image = UIImage(systemName: "flashlight.on.fill")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Flashlight error: \(error)")
        }
    }
    
    // MARK: - Handle Scan Result
    private func handleScanResult(_ code: String) {
        guard !isProcessing else { return }
        isProcessing = true
        
        // 停止扫描
        stopScanning()
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 检查是否是局域网地址（带 sn 参数）
        if isLocalNetworkURL(code) {
            handleLocalNetworkBinding(code)
        } else if let url = URL(string: code), UIApplication.shared.canOpenURL(url) {
            // 其他URL，打开WebView
            openWebPage(url: url)
        } else {
            // 非URL内容，显示结果
            showScanResult(code)
        }
    }
    
    private func isLocalNetworkURL(_ urlString: String) -> Bool {
        // 匹配局域网地址格式: http://x.x.x.x/?sn=xxx 或 http://x.x.x.x:port/?sn=xxx
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let _ = components.queryItems?.first(where: { $0.name == "sn" })?.value else {
            return false
        }
        return true
    }
    
    private func handleLocalNetworkBinding(_ urlString: String) {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let _ = components.queryItems?.first(where: { $0.name == "sn" })?.value else {
            QMUITips.showError("无效的设备链接", in: view)
            isProcessing = false
            return
        }
        
        // 获取用户 token
        guard let token = UserManager.shared.timaToken else {
            QMUITips.showError("未登录，请先登录", in: view)
            isProcessing = false
            return
        }
        
        // 获取车架号
        guard let vin = UserManager.shared.defaultVin else {
            QMUITips.showError("未找到车架号", in: view)
            isProcessing = false
            return
        }
        
        // 构建绑定 URL
        let scheme = url.scheme ?? "http"
        let host = url.host ?? ""
        let port = url.port.map { ":\($0)" } ?? ""
        let bindURL = "\(scheme)://\(host)\(port)/bindUser"
        
        // 显示加载提示
        QMUITips.showLoading("正在绑定设备...", in: view)
        
        // 发送绑定请求
        let parameters: [String: String] = [
            "token": token,
            "vin": vin
        ]
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        AF.request(bindURL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseJSON { [weak self] response in
                guard let self = self else { return }
                
                QMUITips.hideAllTips(in: self.view)
                
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any],
                       let code = json["code"] as? Int {
                        if code == 200 {
                            let message = json["message"] as? String ?? "绑定成功"
                            QMUITips.showSucceed(message, in: self.view)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.dismiss(animated: true)
                            }
                        } else {
                            let message = json["message"] as? String ?? "绑定失败"
                            QMUITips.showError(message, in: self.view)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.isProcessing = false
                                self.startScanning()
                            }
                        }
                    } else {
                        QMUITips.showError("响应格式错误", in: self.view)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.isProcessing = false
                            self.startScanning()
                        }
                    }
                case .failure(let error):
                    let errorMessage = "绑定失败: \(error.localizedDescription)"
                    QMUITips.showError(errorMessage, in: self.view)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isProcessing = false
                        self.startScanning()
                    }
                }
            }
    }
    
    private func openWebPage(url: URL) {
        stopScanning()
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        present(safariVC, animated: true)
    }
    
    private func showScanResult(_ result: String) {
        let alert = UIAlertController(title: "扫描结果", message: result, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "复制", style: .default) { [weak self] _ in
            UIPasteboard.general.string = result
            if let view = self?.view {
                QMUITips.showSucceed("已复制", in: view)
            }
            self?.isProcessing = false
        })
        alert.addAction(UIAlertAction(title: "确定", style: .cancel) { [weak self] _ in
            self?.isProcessing = false
        })
        present(alert, animated: true)
    }
    
    // MARK: - Alerts
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相机权限",
            message: "请在设置中允许访问相机以使用扫一扫功能",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func showCameraError() {
        let alert = UIAlertController(
            title: "相机错误",
            message: "无法启动相机，请检查设备",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        handleScanResult(stringValue)
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ScanViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        isProcessing = false
        startScanning()
    }
}
