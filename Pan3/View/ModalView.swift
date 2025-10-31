//
//  ModalView.swift
//  ResonanceAPP
//
//  Created by Feng on 2024/6/9.
//

import UIKit
import SnapKit
import SwifterSwift

class ModalView: QMUIModalPresentationViewController {
    var text = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        var height = heightForString(text)+50
        if height > 500 {
            height = 500
        }
        
        
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width*0.8, height: height))
        contentView.backgroundColor = .systemGray5
        contentView.layerCornerRadius = 10
        
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.textColor = .label
        textView.text = text
        
        contentView.addSubview(textView)
        self.contentView = contentView
        
        textView.snp.makeConstraints({
            $0.edges.equalToSuperview().inset(10)
        })
        
        let blur = UIBlurEffect.qmui_effect(withBlurRadius: 10)
        let blurView = UIVisualEffectView(effect: blur)
        dimmingView = blurView
        
        animationStyle = .slide
    }

    func show() {
        showWith(animated: true)
    }
    
    func hide() {
        hideWith(animated: true)
    }
    
    private func heightForString(_ string: String, width: CGFloat = UIScreen.main.bounds.width*0.8-20, font: UIFont = .systemFont(ofSize: 14)) -> CGFloat {
        let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        let attributes = [NSAttributedString.Key.font: font]
        
        let boundingRect = NSString(string: string).boundingRect(with: size, options: options, attributes: attributes, context: nil)
        
        return ceil(boundingRect.height)
    }
}
