#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本地址
SCRIPT_URL="https://raw.githubusercontent.com/zuoban/alist-uploader/refs/heads/main/alist-uploader.sh"
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="alist-uploader"
INSTALL_PATH="$INSTALL_DIR/$INSTALL_NAME"
TEMP_FILE=$(mktemp)

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  AList-Uploader 一键安装脚本  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 检查是否有sudo权限
if ! command -v sudo &>/dev/null; then
    echo -e "${RED}错误: 安装需要sudo权限，但系统中未找到sudo命令${NC}"
    exit 1
fi

# 下载脚本
echo -e "${BLUE}正在下载 AList-Uploader 脚本...${NC}"
if ! curl -s -o "$TEMP_FILE" "$SCRIPT_URL"; then
    echo -e "${RED}错误: 下载失败，请检查网络连接${NC}"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 检查下载的文件是否有效
if [ ! -s "$TEMP_FILE" ]; then
    echo -e "${RED}错误: 下载的文件为空${NC}"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 提取版本号
VERSION=$(grep -m 1 "VERSION=\".*\"" "$TEMP_FILE" | cut -d'"' -f2)
if [ -z "$VERSION" ]; then
    echo -e "${RED}警告: 无法获取脚本版本号${NC}"
    VERSION="未知"
fi

echo -e "${BLUE}已下载 AList-Uploader 版本 ${VERSION}${NC}"

# 创建安装目录（如果不存在）
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}创建目录: $INSTALL_DIR${NC}"
    sudo mkdir -p "$INSTALL_DIR"
fi

# 安装脚本
echo -e "${BLUE}正在安装 AList-Uploader 到: $INSTALL_PATH${NC}"
sudo cp "$TEMP_FILE" "$INSTALL_PATH"
sudo chmod 755 "$INSTALL_PATH"

# 清理临时文件
rm -f "$TEMP_FILE"

# 验证安装
if [ -f "$INSTALL_PATH" ]; then
    echo -e "${GREEN}✅ 安装成功！${NC}"
    echo -e "${GREEN}现在可以在任何位置使用 '$INSTALL_NAME' 命令${NC}"
    
    # 询问是否立即进行配置
    echo ""
    read -p "是否现在进行配置？[y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        $INSTALL_PATH -i
    else
        echo -e "${BLUE}您可以稍后使用以下命令进行配置:${NC}"
        echo -e "${BLUE}  $INSTALL_NAME -i${NC}"
    fi
else
    echo -e "${RED}安装失败，请检查权限或手动安装${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}感谢使用 AList-Uploader！${NC}"
