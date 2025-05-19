# AList-Uploader

[![Version](https://img.shields.io/badge/version-1.3.4-blue.svg)](https://github.com/zuoban/alist-uploader)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

AList-Uploader 是一个命令行工具，用于便捷地将文件上传到 [AList](https://github.com/alist-org/alist) 服务器。支持单文件上传、批量上传和递归上传整个目录。同时支持 Linux 和 macOS 系统。

## 功能特点

- 🚀 支持单文件、批量和递归目录上传
- 🔐 安全存储 AList 凭据（密码加密存储）
- 📊 高级上传进度条显示（百分比、速度、剩余时间）
- ⏱️ 上传速度和剩余时间实时估计
- 🌐 支持自定义远程路径
- 🔧 交互式配置
- 📝 批量上传支持文件列表
- 🔄 可全局安装使用
- 🔄 自动更新功能
- 🧹 卸载功能
- 💻 跨平台支持 (Linux 和 macOS)

## 安装

### 方法 1：直接下载

```bash
# 克隆仓库
git clone https://github.com/zuoban/alist-uploader.git
cd alist-uploader

# 添加执行权限
chmod +x alist-uploader.sh
```

### 方法 2：全局安装

```bash
# 下载后执行安装命令
./alist-uploader.sh --install
```

安装后，您可以在系统的任何位置使用 `alist-uploader` 命令。

### 卸载

如果您想卸载全局安装的脚本：

```bash
alist-uploader --uninstall
```

卸载过程中，您可以选择是否同时删除配置文件。

## 快速开始

### 更新脚本

保持脚本为最新版本：

```bash
./alist-uploader.sh --update
```

或者如果全局安装：

```bash
alist-uploader --update
```

### 首次使用

首次使用时，脚本会引导您完成交互式配置：

```bash
./alist-uploader.sh -i
```

您需要提供以下信息：
- AList 服务器地址
- 用户名和密码
- 默认上传目录
- 首选文本编辑器

### 基本用法

**上传单个文件：**

```bash
alist-uploader file.txt
```

**上传到指定路径：**

```bash
alist-uploader file.txt /remote/path/
```

**递归上传整个目录：**

```bash
alist-uploader -r photos/ /albums/vacation/
```

**批量上传文件列表：**

```bash
alist-uploader -b filelist.txt
```

## 命令行选项

```
用法: alist-uploader [选项] [本地文件/目录] [远程路径]
选项:
  -c, --config <配置文件路径>  指定配置文件路径
  -i, --init                  初始化/重置默认配置文件(交互式)
  -e, --edit                  编辑配置文件
  -r, --recursive             递归上传目录内的所有文件
  -b, --batch <文件列表>      批量上传文件列表中的文件
  --install                   安装脚本到系统路径使其可全局使用
  --uninstall                 卸载全局安装的脚本
  --update                    检查并更新到最新版本
  -h, --help                  显示此帮助信息
  -v, --version               显示版本信息
```

## 批量上传文件列表格式

批量上传文件列表是一个简单的文本文件，每行包含一个文件路径：

```
/path/to/file1.txt
/path/to/file2.jpg
# 这是注释行，将被忽略
/path/to/file3.pdf
```

## 配置文件

配置文件默认保存在 `~/.config/alist/config.ini`，包含以下内容：

```ini
# Alist 登录凭据
USERNAME=your_username
# 密码已加密存储
ENCRYPTED_PASSWORD=encrypted_string

# Alist服务器地址
ALIST_BASE_URL=https://your-alist-server.com

# 默认上传目标目录
DEFAULT_REMOTE_DIR=/upload

# 使用的编辑器
EDITOR=vim
```

## 安全性

- 密码使用 AES-256-CBC 加密存储
- 配置文件权限设置为 600（仅所有者可读写）
- 密钥文件单独存储

## 系统要求

- Bash 4.0+
- curl
- openssl（用于密码加密）
- bc（用于计算）
- 支持的操作系统：Linux 和 macOS

## 贡献

欢迎提交 Pull Requests 和 Issues！

## 许可证

[MIT](LICENSE)
