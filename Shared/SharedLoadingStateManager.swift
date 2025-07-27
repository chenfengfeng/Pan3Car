//
//  SharedLoadingStateManager.swift
//  Pan3Car
//
//  Created by Feng on 2025/7/6.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - 加载状态管理器
/// 管理Widget按钮的加载状态，不破坏Intent架构
class LoadingStateManager {
    static let shared = LoadingStateManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.feng.pan3")
    
    // 按钮类型枚举
    enum ButtonType: String, CaseIterable {
        case lock = "lock"
        case airConditioner = "airConditioner" 
        case window = "window"
        case findCar = "findCar"
        
        var loadingKey: String {
            return "loading_\(self.rawValue)"
        }
        
        var timestampKey: String {
            return "timestamp_\(self.rawValue)"
        }
    }
    
    private init() {}
    
    /// 设置按钮加载状态
    func setLoading(_ isLoading: Bool, for buttonType: ButtonType) {
        userDefaults?.set(isLoading, forKey: buttonType.loadingKey)
        if isLoading {
            userDefaults?.set(Date().timeIntervalSince1970, forKey: buttonType.timestampKey)
        }
        
        // 刷新Widget显示
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
    }
    
    /// 获取按钮加载状态
    func isLoading(for buttonType: ButtonType) -> Bool {
        let isLoading = userDefaults?.bool(forKey: buttonType.loadingKey) ?? false
        
        // 检查是否超时（30秒后自动清除加载状态）
        if isLoading {
            let timestamp = userDefaults?.double(forKey: buttonType.timestampKey) ?? 0
            let currentTime = Date().timeIntervalSince1970
            if currentTime - timestamp > 30 {
                setLoading(false, for: buttonType)
                return false
            }
        }
        
        return isLoading
    }
    
    /// 清除所有加载状态
    func clearAllLoadingStates() {
        for buttonType in ButtonType.allCases {
            userDefaults?.removeObject(forKey: buttonType.loadingKey)
            userDefaults?.removeObject(forKey: buttonType.timestampKey)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "CarWidget")
        #endif
    }
}
