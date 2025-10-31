//
//  WechatShowView.swift
//  Pan3
//
//  Created by Feng on 2025/1/27.
//

import UIKit
import SnapKit
import SwifterSwift

class WechatShowView: QMUIModalPresentationViewController {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let qrcodeImageView = UIImageView()
    private let copyButton = QMUIButton()
    private let saveButton = QMUIButton()
    
    // MARK: - Properties
    private let imageAspectRatio: CGFloat = 1710.0 / 624.0 // 宽高比
    private let wechatPublicAccountName = "探索AI工坊" // 公众号名称
    
    // 回调闭包
    var onCopyName: (() -> Void)?
    var onSaveQRCode: (() -> Void)?
    
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
        
        // 计算容器高度：标题(25) + 间距(20) + 图片高度 + 间距(30) + 按钮(54) + 间距(40)
        let screenWidth = UIScreen.main.bounds.width
        let imageWidth = screenWidth - 40 // 左右各20的边距
        let imageHeight = imageWidth / imageAspectRatio
        let containerHeight = 25 + 20 + imageHeight + 30 + 54 + 40
        
        // 容器视图
        containerView.layer.cornerRadius = 16
        containerView.backgroundColor = .systemBackground
        containerView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: containerHeight)
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        // 标题
        titleLabel.text = "微信公众号"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // 二维码图片
        qrcodeImageView.image = UIImage(named: "qrcode_wx") // 使用项目中的微信二维码图片
        qrcodeImageView.contentMode = .scaleAspectFit
        qrcodeImageView.layer.cornerRadius = 8
        qrcodeImageView.clipsToBounds = true
        containerView.addSubview(qrcodeImageView)
        
        // 复制公众号名称按钮
        copyButton.setTitle("复制公众号名称", for: .normal)
        copyButton.backgroundColor = .systemGray5
        copyButton.setTitleColor(.label, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        containerView.addSubview(copyButton)
        
        // 保存二维码按钮
        saveButton.setTitle("保存二维码", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        containerView.addSubview(saveButton)
    }
    
    // MARK: - Setup Constraints
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(25)
        }
        
        qrcodeImageView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
            // 根据宽高比设置高度
            make.height.equalTo(qrcodeImageView.snp.width).dividedBy(imageAspectRatio)
        }
        
        copyButton.snp.makeConstraints { make in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(54)
            make.width.equalTo(saveButton.snp.width)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(30)
            make.right.equalToSuperview().offset(-20)
            make.left.equalTo(copyButton.snp.right).offset(10)
            make.height.equalTo(54)
        }
    }
    
    // MARK: - Setup Actions
    private func setupActions() {
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    @objc private func copyButtonTapped() {
        // 复制公众号名称到剪贴板
        UIPasteboard.general.string = wechatPublicAccountName
        
        // 显示提示
        QMUITips.showSucceed("已复制公众号名称", in: self.view)
        
        onCopyName?()
    }
    
    @objc private func saveButtonTapped() {
        guard let image = qrcodeImageView.image else {
            QMUITips.showError("图片加载失败", in: self.view)
            return
        }
        
        // 保存图片到相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        onSaveQRCode?()
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            QMUITips.showError("保存失败：\(error.localizedDescription)", in: self.view)
        } else {
            QMUITips.showSucceed("已保存到相册", in: self.view)
        }
    }
    
    // MARK: - Show Method
    static func show(from viewController: UIViewController, onCopyName: (() -> Void)? = nil, onSaveQRCode: (() -> Void)? = nil) {
        let wechatShowView = WechatShowView()
        wechatShowView.onCopyName = onCopyName
        wechatShowView.onSaveQRCode = onSaveQRCode
        viewController.present(wechatShowView, animated: true)
    }
}
