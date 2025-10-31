#!/bin/bash

# 编译测试脚本
# 用于验证项目是否能够成功编译

echo "开始编译测试..."
echo "项目路径: $(pwd)"

# 检查是否存在 .xcworkspace 文件
if [ -f "Pan3.xcworkspace/contents.xcworkspacedata" ]; then
    echo "使用 workspace 进行编译..."
    WORKSPACE_FILE="Pan3.xcworkspace"
else
    echo "使用 project 进行编译..."
    WORKSPACE_FILE="Pan3.xcodeproj"
fi

# 列出可用的 schemes
echo "可用的 schemes:"
xcodebuild -list -workspace "$WORKSPACE_FILE" 2>/dev/null || xcodebuild -list -project "Pan3.xcodeproj"

echo ""
echo "开始编译主应用..."

# 编译主应用 (iOS)
if [ -f "Pan3.xcworkspace/contents.xcworkspacedata" ]; then
    xcodebuild -workspace "$WORKSPACE_FILE" \
               -scheme "Pan3" \
               -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" \
               -configuration Debug \
               build-for-testing \
               CODE_SIGNING_ALLOWED=NO \
               CODE_SIGN_IDENTITY="" \
               PROVISIONING_PROFILE=""
else
    xcodebuild -project "Pan3.xcodeproj" \
               -scheme "Pan3" \
               -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" \
               -configuration Debug \
               build-for-testing \
               CODE_SIGNING_ALLOWED=NO \
               CODE_SIGN_IDENTITY="" \
               PROVISIONING_PROFILE=""
fi

COMPILE_RESULT=$?

if [ $COMPILE_RESULT -eq 0 ]; then
    echo ""
    echo "✅ 编译成功！"
    echo "所有类型引用和语法问题已修复。"
else
    echo ""
    echo "❌ 编译失败，退出码: $COMPILE_RESULT"
    echo "请检查上述错误信息。"
fi

exit $COMPILE_RESULT