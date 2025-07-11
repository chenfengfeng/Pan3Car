//
//  ChargeListController.swift
//  Pan3
//
//  Created by Feng on 2025/1/2.
//

import UIKit
import QMUIKit
import SnapKit
import MJRefresh
import SwifterSwift

class ChargeListController: UIViewController {
    
    // MARK: - Properties
    private var tableView: UITableView!
    private var chargeTasks: [ChargeTaskModel] = []
    private var currentPage = 1
    private var totalPages = 1
    private var isLoading = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadChargeList()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "充电任务列表"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        setupRefreshControl()
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ChargeListCell.self, forCellReuseIdentifier: ChargeListCell.identifier)
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = UITableView.automaticDimension
        
        // 设置contentInsetAdjustmentBehavior以避免与导航栏遮挡
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .automatic
        } else {
            automaticallyAdjustsScrollViewInsets = true
        }
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    private func setupRefreshControl() {
        // 下拉刷新
        let header = MJRefreshNormalHeader { [weak self] in
            self?.refreshData()
        }
        
        // 设置刷新控件的偏移量，避免与大标题导航栏遮挡
        header.ignoredScrollViewContentInsetTop = 50
        
        tableView.mj_header = header
        
        // 上拉加载更多
        tableView.mj_footer = MJRefreshAutoNormalFooter { [weak self] in
            self?.loadMoreData()
        }
    }
    
    // MARK: - Data Loading
    private func loadChargeList(page: Int = 1) {
        guard !isLoading else { return }
        isLoading = true
        
        NetworkManager.shared.getChargeTaskList(page: page) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.tableView.mj_header?.endRefreshing()
                self?.tableView.mj_footer?.endRefreshing()
                
                switch result {
                case .success(let response):
                    self?.handleChargeListResponse(response, page: page)
                case .failure(let error):
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func handleChargeListResponse(_ response: ChargeListResponse, page: Int) {
        currentPage = response.pagination.currentPage
        totalPages = response.pagination.totalPages
        
        if page == 1 {
            // 刷新数据
            chargeTasks = response.tasks
        } else {
            // 加载更多
            chargeTasks.append(contentsOf: response.tasks)
        }
        
        tableView.reloadData()
        
        // 更新footer状态
        if currentPage >= totalPages {
            tableView.mj_footer?.endRefreshingWithNoMoreData()
        } else {
            tableView.mj_footer?.resetNoMoreData()
        }
        
        // 如果没有数据，显示空状态
        if chargeTasks.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private func handleError(_ error: Error) {
        QMUITips.showError("加载失败: \(error.localizedDescription)")
    }
    
    private func refreshData() {
        currentPage = 1
        loadChargeList(page: 1)
    }
    
    private func loadMoreData() {
        guard currentPage < totalPages else {
            tableView.mj_footer?.endRefreshingWithNoMoreData()
            return
        }
        loadChargeList(page: currentPage + 1)
    }
    
    // MARK: - Empty State
    private func showEmptyState() {
        let emptyView = createEmptyStateView()
        tableView.backgroundView = emptyView
    }
    
    private func hideEmptyState() {
        tableView.backgroundView = nil
    }
    
    private func createEmptyStateView() -> UIView {
        let containerView = UIView()
        
        let imageView = UIImageView(image: UIImage(systemName: "battery.0"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = "暂无充电记录"
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .systemGray2
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "开始您的第一次充电任务吧"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray3
        subtitleLabel.textAlignment = .center
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(80)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        return containerView
    }
}

// MARK: - UITableViewDataSource
extension ChargeListController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chargeTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChargeListCell.identifier, for: indexPath) as! ChargeListCell
        let task = chargeTasks[indexPath.row]
        cell.configure(with: task)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChargeListController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let task = chargeTasks[indexPath.row]
        showTaskDetail(task)
    }
    
    private func showTaskDetail(_ task: ChargeTaskModel) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var detailText = ""
        detailText += "任务ID: \(task.id)\n"
        detailText += "车辆VIN: \(task.vin)\n"
        detailText += "目标里程: \(String(format: "%.1f", task.targetKm)) km\n"
        detailText += "初始里程: \(String(format: "%.1f", task.initialKm)) km\n"
        detailText += "起始电量: \(String(format: "%.1f", task.initialKwh)) kWh\n"
        detailText += "目标电量: \(String(format: "%.1f", task.targetKwh)) kWh\n"
        detailText += "已充电量: \(String(format: "%.1f", task.chargedKwh)) kWh\n"
        detailText += "任务状态: \(task.statusText)\n"
        detailText += "创建时间: \(task.createdAt)\n"
        
        if let finishTime = task.finishTime, !finishTime.isEmpty {
            detailText += "完成时间: \(finishTime)\n"
        }
        
        detailText += "充电时长: \(task.chargeDuration)\n"
        
        if let message = task.message, !message.isEmpty {
            detailText += "\n备注信息:\n\(message)"
        }
        
        let modal = ModalView()
        modal.text = detailText
        modal.show()
    }
}
