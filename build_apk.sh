#!/bin/bash
# 从 .env 文件加载环境变量并构建 APK

# 读取 .env 文件并导出环境变量
export $(cat .env | xargs)

# 使用分割 ABI 构建发行版 APK
flutter build apk --release --split-per-abi

echo "APK build completed!"
