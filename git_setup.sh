#!/bin/bash

# 初始化 Git 仓库并提交 Notification Service Extension 实现

echo "🚀 开始初始化 Git 仓库..."

# 初始化 Git 仓库
git init

echo "📝 添加所有文件到暂存区..."

# 添加所有文件到暂存区
git add .

echo "💾 提交更改..."

# 提交更改
git commit -m "feat: 实现 Notification Service Extension 功能

- 添加 Pan3PushService Notification Service Extension
- 实现推送数据解析和处理逻辑
- 支持 App Groups 数据共享
- 集成小组件刷新功能
- 添加 Apple Watch 数据同步
- 配置必要的权限和依赖
- 更新 Podfile 添加 SwiftyJSON 依赖"

echo "✅ Git 仓库初始化完成！"
echo "📊 查看提交历史："
git log --oneline

echo ""
echo "🔍 当前仓库状态："
git status