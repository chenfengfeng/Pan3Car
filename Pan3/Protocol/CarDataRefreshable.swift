//
//  CarDataRefreshable.swift
//  Pan3
//
//  Created by Feng on 2025/1/20.
//

import UIKit
import Foundation

// MARK: - 通知名称定义
extension Notification.Name {
    /// 车辆数据更新通知
    static let carDataDidUpdate = Notification.Name("carDataDidUpdate")
}

// MARK: - 车辆数据刷新协议
@objc protocol CarDataRefreshable: AnyObject {
    /// 刷新车辆数据的方法
    func refreshCarData()
    
    /// 是否是首次数据加载
    var isFirstDataLoad: Bool { get set }
    
    /// 处理应用进入前台事件
    @objc func handleAppDidBecomeActive()
}

// MARK: - 协议默认实现
extension CarDataRefreshable where Self: UIViewController {
    
    /// 注册应用进入前台通知
    func registerAppDidBecomeActiveNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    /// 移除应用进入前台通知
    func unregisterAppDidBecomeActiveNotification() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    /// 注册车辆数据更新通知
    func registerCarDataUpdateNotification() {
        NotificationCenter.default.addObserver(
            forName: .carDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCarDataUpdate(notification)
        }
    }
    
    /// 移除车辆数据更新通知
    func unregisterCarDataUpdateNotification() {
        NotificationCenter.default.removeObserver(
            self,
            name: .carDataDidUpdate,
            object: nil
        )
    }
    
    /// 处理车辆数据更新通知的默认实现
    func handleCarDataUpdate(_ notification: Notification) {
        print("\(String(describing: type(of: self))): 收到车辆数据更新通知")
        // 在主线程中刷新车辆数据
        DispatchQueue.main.async { [weak self] in
            self?.refreshCarData()
        }
    }

}

// MARK: - UIViewController 扩展
extension UIViewController {
    
    /// 在 deinit 中自动移除通知观察者
    func setupAutoRemoveNotificationObserver() {
        // 这个方法可以在需要时调用，确保在控制器销毁时移除观察者
        // 通常在 deinit 中调用 NotificationCenter.default.removeObserver(self)
    }
}
