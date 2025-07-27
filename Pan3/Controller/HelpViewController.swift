//
//  HelpViewController.swift
//  Pan3
//
//  Created by Feng on 2025/7/6.
//

import UIKit
import QMUIKit

class HelpViewController: UIViewController {
    
    private var tableView: UITableView!
    
    private let faqData = [
        (
            question: "为什么不显示胎压数据？",
            answer: "胎压数据需要从车辆获取，请确保您的车辆已成功连接且数据传输正常。所有数据依赖官方接口返回，如果没有显示意味着官方接口没有提供有效的数据。"
        ),
        (
            question: "为什么车内温度显示异常？",
            answer: "车内温度依赖系统传感器，当车辆静止一段时间会断开传感器导致无法获取到温度数据\n如何远程获取到温度数据：\n打开空调，运行1分钟左右就可以获取到车内温度。"
        ),
        (
            question: "为什么小组件不定时会掉线需要重新登陆？",
            answer: "可能是您的账号在其他小程序或APP中被自动登录，导致当前设备被下线，小组件无法正常访问数据。\n\n解决方案：\n1. 使用官方APP创建授权号，实现独立登录\n2. 在官方APP中修改密码，防止其他平台自动登录您的账号"
        ),
        (
            question: "这个应用需要付费使用吗？",
            answer: "本应用是完全免费的开源项目，永久免费使用，不收取任何费用。我们致力于为广大车主提供便捷、实用的车辆管理服务。\n\n作为开源项目，我们的目标是：\n\n1. 为用户提供完全免费的车辆管理工具\n2. 保持应用的纯净性，无任何收费功能\n3. 通过开源社区的力量持续改进应用\n4. 让更多开发者参与到项目建设中来\n\n您可以放心使用所有功能，我们承诺永远不会对核心功能收费。"
        ),
        (
            question: "应用内会显示广告吗？",
            answer: "本应用承诺永久无广告，为用户提供纯净、专注的使用体验。我们坚持以下原则：\n\n1. 不植入任何形式的广告内容\n2. 不推送商业营销信息\n3. 不收集用户数据用于广告投放\n4. 专注于功能本身，提供最佳用户体验\n\n我们相信，优秀的应用应该通过功能和体验来获得用户认可，而不是通过广告获利。这也是我们选择开源免费模式的重要原因。"
        ),
        (
            question: "个人数据安全如何保障？",
            answer: "我们非常重视用户的数据安全和隐私保护，采取了多重保障措施：\n\n技术保障：\n1. 全部接口均使用官方定义的API\n2. 数据传输采用HTTPS加密协议\n3. 不在本地存储敏感的用户信息\n4. 严格遵循数据最小化原则\n\n隐私承诺：\n1. 不收集任何用户个人隐私数据\n2. 不追踪用户行为和使用习惯\n3. 不与第三方分享用户信息\n4. 开源代码接受社区监督\n\n您的车辆数据仅用于应用功能实现，我们承诺永远不会将其用于其他目的。"
        ),
        (
            question: "为什么没有行程记录功能？",
            answer: "我们经过深思熟虑后决定不提供行程记录功能，主要基于以下考虑：\n\n隐私保护：\n1. 行程记录需要持续收集用户位置信息\n2. 涉及用户出行轨迹等高度敏感数据\n3. 需要服务器后台持续监听和存储\n4. 可能被恶意利用造成隐私泄露\n\n技术考量：\n1. 需要大量服务器资源和维护成本\n2. 数据存储和备份的复杂性\n3. 不同地区法律法规的合规要求\n\n我们坚持隐私优先的原则，宁可牺牲部分功能也要确保用户隐私安全。"
        ),
        (
            question: "为什么把行程记录功能加上？",
            answer: "经过重新考虑和技术架构调整，我们现在提供了行程记录功能，但采用了更加隐私友好的实现方式：\n\n功能特点：\n1. 以车辆解锁和关锁为起始点记录行程\n2. 不会持续追踪用户位置信息\n3. 只在有明确驾驶行为时才开始记录\n4. 避免了全天候位置监控的隐私风险\n\n技术实现：\n1. 所有接口通过服务器进行统一封装\n2. 满足各平台审核要求和合规标准\n3. 数据处理逻辑完全透明化\n\n开源透明：\n1. 所有相关代码完全开源\n2. 后台API接口文档公开\n3. 数据库表结构完全透明\n4. 欢迎社区监督和改进建议\n\n我们始终坚持在功能实用性和隐私保护之间找到最佳平衡点，如果您对实现方式有任何建议或担忧，欢迎随时反馈。"
        ),
        (
            question: "充电任务功能会收集哪些数据？",
            answer: "充电任务是一个可选功能，我们严格控制数据收集范围：\n\n必要数据（仅在您主动创建充电任务时收集）：\n1. 车辆VIN码 - 用于识别特定车辆\n2. 访问令牌 - 用于API调用授权\n3. 充电设置参数 - 用于执行充电任务\n\n数据处理原则：\n1. 完全可选 - 不创建任务则不收集任何数据\n2. 本地优先 - 尽可能在本地处理数据\n3. 最小化收集 - 只收集功能必需的数据\n4. 透明处理 - 所有数据用途都会明确告知。"
        ),
        (
            question: "应用会持续更新维护吗？",
            answer: "我们承诺在合理范围内持续维护和更新应用，具体包括：\n\n定期维护：\n1. 修复已知的bug和问题\n2. 适配新版本iOS系统\n3. 优化应用性能和稳定性\n4. 更新第三方依赖库\n\n功能更新：\n1. 根据用户反馈添加实用功能\n2. 改进用户界面和交互体验\n3. 支持新的车型和API\n4. 增强安全性和隐私保护\n\n社区驱动：\n1. 欢迎开发者贡献代码\n2. 接受用户建议和功能请求\n3. 开源透明的开发过程\n\n更新频率会根据实际需求和开发资源来确定，我们会尽力保持应用的活跃度。"
        ),
        (
            question: "在哪里可以查看源代码？",
            answer: "本应用源代码完全开源，您可以通过以下方式获取和参与：\n\nGitHub仓库：\n1. 完整的源代码托管在GitHub平台\n2. 包含详细的项目文档和使用说明\n3. 提供问题反馈和功能建议渠道\n4. 欢迎开发者提交Pull Request\n\n开源优势：\n1. 代码透明，接受社区监督\n2. 安全性可以被独立验证\n3. 支持二次开发和定制\n4. 学习交流iOS开发技术\n\n参与方式：\n1. Star项目表示支持\n2. 提交Issue报告问题\n3. 贡献代码改进功能\n4. 分享使用经验和建议\n\n我们相信开源的力量，期待更多开发者加入项目建设。"
        ),
        (
            question: "遇到其他问题如何联系？",
            answer: "如果您遇到上述FAQ未涵盖的问题，可以通过以下方式联系我们：\n\n主要联系方式：\n1. 微信联系开发者（推荐）\n2. GitHub Issues提交问题\n3. 应用内反馈功能\n\n联系时请提供：\n1. 问题的详细描述\n2. 复现问题的具体步骤\n3. 设备型号和iOS版本\n4. 应用版本号\n5. 相关截图或错误信息\n\n响应时间：\n1. 一般问题：1-3个工作日内回复\n2. 紧急问题：24小时内回复\n3. 功能建议：会在下个版本中考虑\n\n我们重视每一位用户的反馈，您的建议是我们改进应用的重要动力。感谢您的支持和理解！"
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "常见问题"
        view.backgroundColor = UIColor.systemGroupedBackground
        
        // 创建TableView
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.systemGroupedBackground
        
        // 注册cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FAQCell")
        
        view.addSubview(tableView)
        
        // 设置约束
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource
extension HelpViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return faqData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FAQCell", for: indexPath)
        let faqItem = faqData[indexPath.section]
        
        // 创建自定义内容
        let questionLabel = UILabel()
        let answerLabel = UILabel()
        
        // 检查是否是"为什么没有行程记录功能？"这个cell（索引为5）
        if indexPath.section == 6 {
            // 为问题添加删除线
            let questionAttributedString = NSMutableAttributedString(string: faqItem.question)
            questionAttributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: faqItem.question.count))
            questionAttributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: NSRange(location: 0, length: faqItem.question.count))
            questionAttributedString.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: faqItem.question.count))
            questionLabel.attributedText = questionAttributedString
            
            // 为答案添加删除线
            let answerAttributedString = NSMutableAttributedString(string: faqItem.answer)
            answerAttributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: faqItem.answer.count))
            answerAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: faqItem.answer.count))
            answerAttributedString.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: faqItem.answer.count))
            answerLabel.attributedText = answerAttributedString
        } else {
            // 普通显示
            questionLabel.text = faqItem.question
            questionLabel.font = UIFont.boldSystemFont(ofSize: 16)
            questionLabel.textColor = UIColor.label
            
            answerLabel.text = faqItem.answer
            answerLabel.font = UIFont.systemFont(ofSize: 14)
            answerLabel.textColor = UIColor.secondaryLabel
        }
        
        questionLabel.numberOfLines = 0
        answerLabel.numberOfLines = 0
        
        let stackView = UIStackView(arrangedSubviews: [questionLabel, answerLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 清除cell的默认内容
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
        
        cell.selectionStyle = .none
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension HelpViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
