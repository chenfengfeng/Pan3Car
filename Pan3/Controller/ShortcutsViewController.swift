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

class ShortcutsViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var siriView: UIScrollView!
    @IBOutlet weak var shortcutsView: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    // MARK: - 点击事件
    @IBAction func changeSegment(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            siriView.isHidden = false
            shortcutsView.isHidden = true
        }else{
            siriView.isHidden = true
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
}
