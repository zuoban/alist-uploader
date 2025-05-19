#!/bin/bash

# 版本信息
VERSION="1.3.3"

# GitHub仓库脚本地址
UPDATE_URL="https://raw.githubusercontent.com/zuoban/alist-uploader/refs/heads/main/alist-uploader.sh"

# 检测操作系统类型
detect_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

OS_TYPE=$(detect_os)

# 默认配置文件路径
CONFIG_DIR="$HOME/.config/alist"
CONFIG_FILE="$CONFIG_DIR/config.ini"

# 显示使用说明
usage() {
    echo "AList-Uploader $VERSION - AList 文件上传工具"
    echo "用法: $0 [选项] [本地文件/目录] [远程路径]"
    echo "选项:"
    echo "  -c, --config <配置文件路径>  指定配置文件路径"
    echo "  -i, --init                  初始化/重置默认配置文件(交互式)"
    echo "  -e, --edit                  编辑配置文件"
    echo "  -r, --recursive         递归上传目录内的所有文件"
    echo "  -b, --batch <文件列表>  批量上传文件列表中的文件"
    echo "  --install                安装脚本到系统路径使其可全局使用"
    echo "  --uninstall              卸载全局安装的脚本"
    echo "  --update                 检查并更新到最新版本"
    echo "  -h, --help                  显示此帮助信息"
    echo "  -v, --version               显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0 file.txt                    # 上传单个文件到默认位置"
    echo "  $0 file.txt /remote/path/      # 上传单个文件到指定位置"
    echo "  $0 -r photos/ /albums/vacation/ # 递归上传整个目录"
    echo "  $0 -b filelist.txt             # 批量上传文件列表中的文件"
    echo "  $0 -i                          # 交互式配置"
    echo "  $0 -e                          # 编辑配置文件"
    echo "  $0 --install                   # 安装到系统路径"
    echo "  $0 --update                    # 更新脚本到最新版本"
    exit 1
}

# 显示版本信息
show_version() {
    echo "AList-Uploader 版本 $VERSION"
    exit 0
}

# 函数：显示错误信息并退出
error_exit() {
    echo -e "\033[31m✗ 错误: $1\033[0m" >&2
    exit 1
}

# 函数：显示成功信息
success_msg() {
    echo -e "\033[32m$1\033[0m"
}

# 函数：显示信息
info_msg() {
    echo -e "\033[36m$1\033[0m"
}

# 加密密码
encrypt_password() {
    local password="$1"
    local encrypted
    
    # 生成加密密钥 (使用配置目录路径作为盐值的一部分)
    local key_file="$CONFIG_DIR/.key"
    
    # 如果密钥文件不存在，则生成它
    if [ ! -f "$key_file" ]; then
        openssl rand -hex 16 > "$key_file"
        chmod 600 "$key_file"
    fi
    
    # 读取密钥
    local key=$(cat "$key_file")
    
    # 使用 openssl 加密密码
    encrypted=$(echo -n "$password" | openssl enc -aes-256-cbc -a -salt -pass pass:"$key" 2>/dev/null)
    
    echo "$encrypted"
}

# 解密密码
decrypt_password() {
    local encrypted="$1"
    local decrypted
    
    # 读取密钥
    local key_file="$CONFIG_DIR/.key"
    
    if [ ! -f "$key_file" ]; then
        error_exit "密钥文件丢失，无法解密密码"
    fi
    
    local key=$(cat "$key_file")
    
    # 使用 openssl 解密密码
    decrypted=$(echo "$encrypted" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$key" 2>/dev/null)
    
    echo "$decrypted"
}

# 格式化文件大小为易读形式
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo $(echo "scale=2; $size / 1073741824" | bc)" GB"
    elif [ $size -ge 1048576 ]; then
        echo $(echo "scale=2; $size / 1048576" | bc)" MB"
    elif [ $size -ge 1024 ]; then
        echo $(echo "scale=2; $size / 1024" | bc)" KB"
    else
        echo "$size 字节"
    fi
}

# 格式化时间
format_time() {
    local seconds=$1
    if [ $seconds -ge 3600 ]; then
        printf "%d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
    else
        printf "%d:%02d" $((seconds/60)) $((seconds%60))
    fi
}

# 上传单个文件
upload_file() {
    local local_file="$1"
    local remote_path="$2"
    local token="$3"
    local base_url="$4"
    
    # 检查文件是否存在
    if [ ! -f "$local_file" ]; then
        echo -e "\033[31m跳过: 文件不存在: $local_file\033[0m"
        return 1
    fi

    # 格式化远程路径
    local remote_file_path
    if [[ "$remote_path" == http* ]]; then
        # 用户提供了完整URL作为远程路径
        local temp_base_url=$(echo "$remote_path" | sed 's|\(https\?://[^/]*\)/.*|\1|')
        remote_file_path=$(echo "$remote_path" | sed "s|$temp_base_url||")
    else
        # 用户只提供了路径部分
        # 确保路径以斜杠开头
        if [[ "$remote_path" != /* ]]; then
            remote_file_path="/$remote_path"
        else
            remote_file_path="$remote_path"
        fi
    fi
    
    # 获取文件大小（字节和易读形式）
    local file_size_bytes
    local file_size
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        file_size_bytes=$(stat -f%z "$local_file")
        file_size=$(du -h "$local_file" | awk '{print $1}')
    else
        file_size_bytes=$(stat -c%s "$local_file")
        file_size=$(du -h "$local_file" | cut -f1)
    fi
    local file_name=$(basename "$local_file")
    
    # 显示上传信息
    echo -e "\033[36m开始上传: $file_name ($file_size)\033[0m"
    
    # 执行上传
    local upload_url="$base_url/api/fs/put"
    local remote_url="$base_url$remote_file_path"
    
    # 计算开始时间
    local start_time=$(date +%s)
    local last_updated=$start_time
    local uploaded_bytes=0
    local last_bytes=0
    local current_time
    local elapsed
    local percent
    local speed
    local eta
    local temp_file=$(mktemp)
    
    # 使用curl的写出函数来跟踪进度
    # -# 选项显示进度条，-o /dev/null 不保存输出
    curl -# -T "$local_file" "$upload_url" \
      -H "Authorization: $token" \
      -H "File-Path: $remote_file_path" \
      -o /dev/null \
      -w "%{size_upload}\n" \
      2> "$temp_file" > "${temp_file}.complete"
    
    # 检查上传结果
    local upload_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 清除临时文件
    rm -f "$temp_file" "${temp_file}.complete"
    
    # 清除进度条行
    echo -ne "\r\033[K"
    
    if [ $upload_status -eq 0 ]; then
        if [ $duration -gt 0 ]; then
            local speed=$(echo "scale=2; $file_size_bytes / $duration" | bc)
            local speed_human
            
            if [ $(echo "$speed > 1048576" | bc) -eq 1 ]; then
                speed_human=$(echo "scale=2; $speed / 1048576" | bc)" MB/s"
            elif [ $(echo "$speed > 1024" | bc) -eq 1 ]; then
                speed_human=$(echo "scale=2; $speed / 1024" | bc)" KB/s"
            else
                speed_human="$speed 字节/秒"
            fi
            
            # 成功信息包含速度和耗时
            local time_taken=$(format_time $duration)
            echo -e "\033[32m✓ 上传成功: $file_name | 平均速度: $speed_human | 耗时: $time_taken\033[0m"
        else
            echo -e "\033[32m✓ 上传成功: $file_name\033[0m"
        fi
        # 存储远程 URL 以供后续使用
        echo "$remote_url" > /tmp/alist_last_upload_url_$file_name
        return 0
    else
        echo -e "\033[31m✗ 上传失败: $file_name\033[0m"
        return 1
    fi
}

# 递归上传目录
upload_directory() {
    local src_dir="$1"
    local dst_dir="$2"
    local token="$3"
    local base_url="$4"
    
    # 确保目录路径以斜杠结尾
    src_dir=$(echo "$src_dir" | sed 's|/*$|/|')
    
    # 移除目标路径末尾的斜杠
    dst_dir=$(echo "$dst_dir" | sed 's|/*$||')
    
    # 获取目录中的所有文件和子目录
    local items=($(find "$src_dir" -type f | sort))
    local total_files=${#items[@]}
    
    if [ $total_files -eq 0 ]; then
        info_msg "目录为空，无文件可上传"
        return 0
    fi
    
    # 计算总大小
    local total_size=0
    local total_size_human
    
    info_msg "正在计算总文件大小..."
    for ((i=0; i<$total_files; i++)); do
        local file_size
        if [[ "$OS_TYPE" == "macos" ]]; then
            file_size=$(stat -f%z "${items[$i]}")
        else
            file_size=$(stat -c%s "${items[$i]}")
        fi
        ((total_size+=file_size))
    done
    
    # 将总大小转换为易读的形式
    if [ $total_size -ge 1073741824 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1073741824" | bc)" GB"
    elif [ $total_size -ge 1048576 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1048576" | bc)" MB"
    elif [ $total_size -ge 1024 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1024" | bc)" KB"
    else
        total_size_human="$total_size 字节"
    fi
    
    info_msg "共找到 $total_files 个文件需要上传，总大小: $total_size_human"
    
    # 绘制简洁的进度条头部
    echo -e "\033[36m┌─ 上传目录: $dst_dir ─┐\033[0m"
    echo -e "\033[36m└─ 共 $total_files 个文件, 总计: $total_size_human ─┘\033[0m"
    
    local success_count=0
    local fail_count=0
    local start_time=$(date +%s)
    local current_time
    local elapsed_time
    local average_speed
    local estimated_time
    local uploaded_size=0
    
    for ((i=0; i<$total_files; i++)); do
        local file="${items[$i]}"
        local rel_path="${file#$src_dir}"
        local remote_file_path="$dst_dir/$rel_path"
        local file_size=$(stat -c%s "$file")
        local percent_complete=$((($i * 100) / $total_files))
        
        # 显示更简洁的整体进度
        echo -ne "\r\033[K\033[33m[$((i+1))/$total_files] ${percent_complete}% [$(printf '%*s' $((percent_complete/2)) | tr ' ' '=')]\033[0m $(basename "$file")"
        
        # 上传文件
        upload_file "$file" "$remote_file_path" "$token" "$base_url"
        
        if [ $? -eq 0 ]; then
            ((success_count++))
            ((uploaded_size+=file_size))
        else
            ((fail_count++))
        fi
        
        # 计算速度和预计时间
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -gt 0 ] && [ $uploaded_size -gt 0 ]; then
            average_speed=$(echo "scale=2; $uploaded_size / $elapsed_time" | bc)
            
            if [ $average_speed -ge 1048576 ]; then
                average_speed_human=$(echo "scale=2; $average_speed / 1048576" | bc)" MB/s"
            elif [ $average_speed -ge 1024 ]; then
                average_speed_human=$(echo "scale=2; $average_speed / 1024" | bc)" KB/s"
            else
                average_speed_human="$average_speed 字节/秒"
            fi
            
            # 计算剩余时间
            remaining_size=$((total_size - uploaded_size))
            if [ $average_speed -gt 0 ]; then
                estimated_time=$((remaining_size / average_speed))
                # 格式化预计时间
                if [ $estimated_time -ge 3600 ]; then
                    estimated_time_human=$(printf "%d:%02d:%02d" $((estimated_time/3600)) $((estimated_time%3600/60)) $((estimated_time%60)))
                else
                    estimated_time_human=$(printf "%d:%02d" $((estimated_time/60)) $((estimated_time%60)))
                fi
                
                echo -ne " • $average_speed_human • 剩余: $estimated_time_human"
            fi
        fi
        
        echo -e ""
    done
    
    # 汇总信息
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    # 格式化总耗时
    if [ $elapsed_time -ge 3600 ]; then
        elapsed_time_human=$(printf "%d:%02d:%02d" $((elapsed_time/3600)) $((elapsed_time%3600/60)) $((elapsed_time%60)))
    else
        elapsed_time_human=$(printf "%d:%02d" $((elapsed_time/60)) $((elapsed_time%60)))
    fi
    
    echo -e "\033[36m―――――――――――――――――――――――――――――――\033[0m"
    
    # 计算平均速度
    local average_speed_human="N/A"
    if [ $uploaded_size -gt 0 ] && [ $elapsed_time -gt 0 ]; then
        average_speed=$(echo "scale=2; $uploaded_size / $elapsed_time" | bc)
        if [ $average_speed -ge 1048576 ]; then
            average_speed_human=$(echo "scale=2; $average_speed / 1048576" | bc)" MB/s"
        elif [ $average_speed -ge 1024 ]; then
            average_speed_human=$(echo "scale=2; $average_speed / 1024" | bc)" KB/s"
        else
            average_speed_human="$average_speed 字节/秒"
        fi
    fi
    
    # 更简洁的摘要信息
    echo -e "\033[36m📊 文件: $success_count/$total_files | 大小: $total_size_human | 用时: $elapsed_time_human | 速度: $average_speed_human\033[0m"
    echo -e "\033[36m🌐 远程目录: $base_url$dst_dir\033[0m"
    
    if [ $fail_count -eq 0 ]; then
        success_msg "✅ 目录上传完成: 全部 $success_count 个文件上传成功"
    else
        echo -e "\033[33m⚠️ 目录上传完成: $success_count 个文件成功, $fail_count 个文件失败\033[0m"
    fi
}

# 批量上传文件列表
upload_file_list() {
    local list_file="$1"
    local remote_dir="$2"
    local token="$3"
    local base_url="$4"
    
    if [ ! -f "$list_file" ]; then
        error_exit "文件列表不存在: $list_file"
    fi
    
    # 移除远程目录末尾的斜杠
    remote_dir=$(echo "$remote_dir" | sed 's|/*$||')
    
    # 读取文件列表
    local files=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 忽略空行和注释行
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            files+=("$line")
        fi
    done < "$list_file"
    
    local total_files=${#files[@]}
    
    if [ $total_files -eq 0 ]; then
        info_msg "文件列表为空，无文件可上传"
        return 0
    fi
    
    # 计算总大小
    local total_size=0
    local total_size_human
    
    info_msg "正在计算总文件大小..."
    for ((i=0; i<$total_files; i++)); do
        if [ -f "${files[$i]}" ]; then
            local file_size
            if [[ "$OS_TYPE" == "macos" ]]; then
                file_size=$(stat -f%z "${files[$i]}" 2>/dev/null || echo 0)
            else
                file_size=$(stat -c%s "${files[$i]}" 2>/dev/null || echo 0)
            fi
            ((total_size+=file_size))
        fi
    done
    
    # 将总大小转换为易读的形式
    if [ $total_size -ge 1073741824 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1073741824" | bc)" GB"
    elif [ $total_size -ge 1048576 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1048576" | bc)" MB"
    elif [ $total_size -ge 1024 ]; then
        total_size_human=$(echo "scale=2; $total_size / 1024" | bc)" KB"
    else
        total_size_human="$total_size 字节"
    fi
    
    info_msg "共找到 $total_files 个文件需要上传，总大小: $total_size_human"
    
    # 绘制简洁的进度条头部
    echo -e "\033[36m┌─ 批量上传: $remote_dir ─┐\033[0m"
    echo -e "\033[36m└─ 共 $total_files 个文件, 总计: $total_size_human ─┘\033[0m"
    
    local success_count=0
    local fail_count=0
    local start_time=$(date +%s)
    local current_time
    local elapsed_time
    local average_speed
    local estimated_time
    local uploaded_size=0
    
    for ((i=0; i<$total_files; i++)); do
        local file="${files[$i]}"
        local file_name=$(basename "$file")
        local remote_path="$remote_dir/$file_name"
        local file_size=0
        
        if [ -f "$file" ]; then
            if [[ "$OS_TYPE" == "macos" ]]; then
                file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
            else
                file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            fi
        fi
        
        local percent_complete=$((($i * 100) / $total_files))
        
        # 显示更简洁的整体进度
        echo -ne "\r\033[K\033[33m[$((i+1))/$total_files] ${percent_complete}% [$(printf '%*s' $((percent_complete/2)) | tr ' ' '=')]\033[0m $file_name"
        
        # 上传文件
        upload_file "$file" "$remote_path" "$token" "$base_url"
        
        if [ $? -eq 0 ]; then
            ((success_count++))
            ((uploaded_size+=file_size))
        else
            ((fail_count++))
        fi
        
        # 计算速度和预计时间
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -gt 0 ] && [ $uploaded_size -gt 0 ]; then
            average_speed=$(echo "scale=2; $uploaded_size / $elapsed_time" | bc)
            
            if [ $average_speed -ge 1048576 ]; then
                average_speed_human=$(echo "scale=2; $average_speed / 1048576" | bc)" MB/s"
            elif [ $average_speed -ge 1024 ]; then
                average_speed_human=$(echo "scale=2; $average_speed / 1024" | bc)" KB/s"
            else
                average_speed_human="$average_speed 字节/秒"
            fi
            
            # 计算剩余时间
            remaining_size=$((total_size - uploaded_size))
            if [ $average_speed -gt 0 ]; then
                estimated_time=$((remaining_size / average_speed))
                # 格式化预计时间
                if [ $estimated_time -ge 3600 ]; then
                    estimated_time_human=$(printf "%d:%02d:%02d" $((estimated_time/3600)) $((estimated_time%3600/60)) $((estimated_time%60)))
                else
                    estimated_time_human=$(printf "%d:%02d" $((estimated_time/60)) $((estimated_time%60)))
                fi
                
                echo -ne " • $average_speed_human • 剩余: $estimated_time_human"
            fi
        fi
        
        echo -e ""
    done
    
    # 汇总信息
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    # 格式化总耗时
    if [ $elapsed_time -ge 3600 ]; then
        elapsed_time_human=$(printf "%d:%02d:%02d" $((elapsed_time/3600)) $((elapsed_time%3600/60)) $((elapsed_time%60)))
    else
        elapsed_time_human=$(printf "%d:%02d" $((elapsed_time/60)) $((elapsed_time%60)))
    fi
    
    # 计算平均速度
    local average_speed_human="N/A"
    if [ $uploaded_size -gt 0 ] && [ $elapsed_time -gt 0 ]; then
        average_speed=$(echo "scale=2; $uploaded_size / $elapsed_time" | bc)
        if [ $average_speed -ge 1048576 ]; then
            average_speed_human=$(echo "scale=2; $average_speed / 1048576" | bc)" MB/s"
        elif [ $average_speed -ge 1024 ]; then
            average_speed_human=$(echo "scale=2; $average_speed / 1024" | bc)" KB/s"
        else
            average_speed_human="$average_speed 字节/秒"
        fi
    fi
    
    # 简化的上传摘要
    echo -e "\033[36m―――――――――――――――――――――――――――――――\033[0m"
    echo -e "\033[36m📊 上传摘要:\033[0m"
    echo -e "\033[36m • 文件: $success_count/$total_files 成功 ($fail_count 失败)\033[0m"
    echo -e "\033[36m • 大小: $total_size_human\033[0m"
    echo -e "\033[36m • 用时: $elapsed_time_human\033[0m"
    echo -e "\033[36m • 速度: $average_speed_human\033[0m"
    echo -e "\033[36m • 远程目录: $base_url$remote_dir\033[0m"
    echo -e "\033[36m―――――――――――――――――――――――――――――――\033[0m"
    
    if [ $fail_count -eq 0 ]; then
        success_msg "批量上传完成: 全部 $total_files 个文件上传成功"
    else
        info_msg "批量上传完成: $success_count 成功, $fail_count 失败, 共 $total_files 个文件"
    fi
}

# 交互式配置
interactive_config() {
    mkdir -p "$CONFIG_DIR"
    
    echo "========================================="
    info_msg "  AList-Uploader 交互式配置向导  "
    echo "========================================="
    echo ""
    
    # 如果配置文件已存在，询问是否重新配置
    if [ -f "$1" ]; then
        read -p "配置文件已存在，是否重新配置？[y/N] " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "保留现有配置."
            return 0
        fi
    fi
    
    echo "请输入以下信息 (按 Ctrl+C 可随时取消):"
    echo ""
    
    # 收集服务器信息
    read -p "AList 服务器地址(含 http:// 或 https://): " server_url
    
    # 验证 URL 格式
    if [[ ! "$server_url" =~ ^https?:// ]]; then
        error_exit "服务器地址必须包含 http:// 或 https://"
    fi
    
    # 去除结尾的斜杠
    server_url=$(echo "$server_url" | sed 's|/*$||')
    
    # 收集登录凭据
    read -p "AList 用户名: " username
    read -s -p "AList 密码: " password
    echo ""
    
    # 收集上传目录
    read -p "默认上传目录 (例如 /upload): " remote_dir
    
    # 确保路径以斜杠开头
    if [[ ! "$remote_dir" =~ ^/ ]]; then
        remote_dir="/$remote_dir"
    fi
    
    # 确保路径不以斜杠结尾
    remote_dir=$(echo "$remote_dir" | sed 's|/*$||')
    
    # 选择默认编辑器
    default_editor=""
    if command -v vim &>/dev/null; then
        default_editor="vim"
    elif command -v nano &>/dev/null; then
        default_editor="nano"
    elif command -v vi &>/dev/null; then
        default_editor="vi"
    fi
    
    read -p "默认编辑器 (默认: $default_editor): " editor
    if [ -z "$editor" ]; then
        editor="$default_editor"
    fi
    
    # 加密密码
    local encrypted_password=$(encrypt_password "$password")
    
    # 创建配置文件
    cat > "$1" << EOF
# Alist 上传配置文件
# 创建于: $(date)
# 注意: 此文件包含敏感信息，请确保适当的文件权限

# Alist 登录凭据
USERNAME=$username
# 密码已加密存储
ENCRYPTED_PASSWORD=$encrypted_password

# Alist服务器地址
ALIST_BASE_URL=$server_url

# 默认上传目标目录
DEFAULT_REMOTE_DIR=$remote_dir

# 使用的编辑器
EDITOR=$editor
EOF

    # 设置配置文件权限
    chmod 600 "$1"
    
    success_msg "配置完成! 配置文件已保存到: $1"
}

# 定义安装路径变量
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="alist-uploader"
INSTALL_PATH="$INSTALL_DIR/$INSTALL_NAME"

# 安装脚本到系统路径
install_script() {
    local script_path="$(realpath "$0")"
    
    echo "========================================="
    info_msg "  AList-Uploader 安装向导  "
    echo "========================================="
    echo ""
    
    # 检查是否有sudo权限
    if ! command -v sudo &>/dev/null; then
        error_exit "安装需要sudo权限，但系统中未找到sudo命令"
    fi
    
    echo "将安装 AList-Uploader 到系统路径: $INSTALL_PATH"
    echo "这将使脚本可以全局使用，通过命令: $INSTALL_NAME"
    echo ""
    read -p "是否继续安装？[y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "安装已取消."
        exit 0
    fi
    
    # 创建目录（如果不存在）
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "创建目录: $INSTALL_DIR"
        sudo mkdir -p "$INSTALL_DIR"
    fi
    
    # 复制脚本并设置权限
    echo "正在复制脚本到: $INSTALL_PATH"
    sudo cp "$script_path" "$INSTALL_PATH"
    sudo chmod 755 "$INSTALL_PATH"
    
    # 验证安装
    if [ -f "$INSTALL_PATH" ]; then
        success_msg "✅ 安装成功！现在可以在任何位置使用 '$INSTALL_NAME' 命令"
    else
        error_exit "安装失败，请检查权限或手动复制脚本"
    fi
    
    exit 0
}

# 更新脚本
update_script() {
    echo "========================================="
    info_msg "  AList-Uploader 更新向导  "
    echo "========================================="
    echo ""
    
    local script_path="$(realpath "$0")"
    local temp_file=$(mktemp)
    local current_version="$VERSION"
    
    info_msg "当前版本: $current_version"
    info_msg "正在检查更新..."
    
    # 下载最新脚本到临时文件
    if ! curl -s -o "$temp_file" "$UPDATE_URL"; then
        rm -f "$temp_file"
        error_exit "无法下载最新版本，请检查网络连接"
    fi
    
    # 检查下载的文件是否有效
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        error_exit "下载的文件为空，更新失败"
    fi
    
    # 提取远程脚本的版本号
    local remote_version=$(grep -m 1 "VERSION=\".*\"" "$temp_file" | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        rm -f "$temp_file"
        error_exit "无法获取远程脚本的版本号"
    fi
    
    info_msg "发现版本: $remote_version"
    
    # 比较版本
    if [ "$current_version" = "$remote_version" ]; then
        rm -f "$temp_file"
        success_msg "已经是最新版本 ($current_version)"
        exit 0
    fi
    
    echo "发现新版本: $remote_version (当前版本: $current_version)"
    read -p "是否更新到最新版本? [y/N] " answer
    
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        rm -f "$temp_file"
        echo "更新已取消."
        exit 0
    fi
    
    # 备份当前脚本
    local backup_file="${script_path}.bak"
    cp "$script_path" "$backup_file"
    
    # 更新脚本
    if [ -f "$INSTALL_PATH" ]; then
        # 如果是全局安装的脚本，需要sudo权限
        if ! command -v sudo &>/dev/null; then
            rm -f "$temp_file"
            error_exit "更新全局安装的脚本需要sudo权限，但系统中未找到sudo命令"
        fi
        
        echo "正在更新全局安装的脚本..."
        sudo cp "$temp_file" "$INSTALL_PATH"
        sudo chmod 755 "$INSTALL_PATH"
        
        # 同时更新当前脚本
        cp "$temp_file" "$script_path"
        chmod +x "$script_path"
    else
        # 只更新当前脚本
        cp "$temp_file" "$script_path"
        chmod +x "$script_path"
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    success_msg "✅ 更新成功! 已从 $current_version 更新到 $remote_version"
    success_msg "原脚本已备份到: $backup_file"
    
    exit 0
}

# 卸载脚本
uninstall_script() {
    echo "========================================="
    info_msg "  AList-Uploader 卸载向导  "
    echo "========================================="
    echo ""
    
    # 检查是否有sudo权限
    if ! command -v sudo &>/dev/null; then
        error_exit "卸载需要sudo权限，但系统中未找到sudo命令"
    fi
    
    # 检查脚本是否已安装
    if [ ! -f "$INSTALL_PATH" ]; then
        error_exit "未找到全局安装的脚本: $INSTALL_PATH"
    fi
    
    echo "将卸载 AList-Uploader 从系统路径: $INSTALL_PATH"
    echo ""
    read -p "是否继续卸载？[y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "卸载已取消."
        exit 0
    fi
    
    # 删除脚本
    echo "正在删除脚本: $INSTALL_PATH"
    sudo rm -f "$INSTALL_PATH"
    
    # 验证卸载
    if [ ! -f "$INSTALL_PATH" ]; then
        success_msg "✅ 卸载成功！全局命令 '$INSTALL_NAME' 已移除"
        
        # 询问是否删除配置文件
        echo ""
        read -p "是否同时删除配置文件？($CONFIG_DIR) [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "正在删除配置目录: $CONFIG_DIR"
            rm -rf "$CONFIG_DIR"
            if [ ! -d "$CONFIG_DIR" ]; then
                success_msg "✅ 配置文件已删除"
            else
                echo "配置文件删除失败，请手动删除: $CONFIG_DIR"
            fi
        else
            echo "保留配置文件，您可以手动删除: $CONFIG_DIR"
        fi
    else
        error_exit "卸载失败，请检查权限或手动删除脚本"
    fi
    
    exit 0
}

# 编辑配置文件
edit_config() {
    if [ ! -f "$1" ]; then
        echo "配置文件不存在，将创建..."
        interactive_config "$1"
        return
    fi
    
    # 确定要使用的编辑器
    if [ -f "$1" ]; then
        # 如果配置文件中指定了编辑器，则使用它
        CONFIG_EDITOR=$(grep -E "^EDITOR=" "$1" | cut -d= -f2)
    fi
    
    # 如果配置中没有指定编辑器或为空，则选择系统编辑器，优先使用vim或vi
    if [ -z "$CONFIG_EDITOR" ]; then
        if command -v vim &>/dev/null; then
            CONFIG_EDITOR="vim"
        elif command -v vi &>/dev/null; then
            CONFIG_EDITOR="vi"
        elif [ -n "$EDITOR" ]; then
            CONFIG_EDITOR="$EDITOR"
        elif [ -n "$VISUAL" ]; then
            CONFIG_EDITOR="$VISUAL"
        elif command -v nano &>/dev/null; then
            CONFIG_EDITOR="nano"
        else
            echo "错误: 找不到可用的文本编辑器"
            echo "请手动编辑配置文件: $1"
            exit 1
        fi
    fi
    
    echo "正在使用 $CONFIG_EDITOR 编辑 $1..."
    $CONFIG_EDITOR "$1"
}

# 解析命令行参数
RECURSIVE_MODE=false
BATCH_MODE=false
BATCH_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            if [ -n "$2" ]; then
                CONFIG_FILE="$2"
                shift 2
            else
                error_exit "-c/--config 需要指定一个文件路径"
            fi
            ;;
        -i|--init)
            interactive_config "$CONFIG_FILE"
            exit 0
            ;;
        -e|--edit)
            edit_config "$CONFIG_FILE"
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        -v|--version)
            show_version
            ;;
        --install)
            install_script
            exit 0
            ;;
        --uninstall)
            uninstall_script
            exit 0
            ;;
        --update)
            update_script
            exit 0
            ;;
        -r|--recursive)
            RECURSIVE_MODE=true
            shift
            ;;
        -b|--batch)
            BATCH_MODE=true
            if [ -n "$2" ]; then
                BATCH_FILE="$2"
                shift 2
            else
                error_exit "-b/--batch 需要指定一个文件列表"
            fi
            ;;
        -*)
            error_exit "未知选项: $1"
            ;;
        *)
            break
            ;;
    esac
done

# 检查配置文件是否存在，不存在则创建
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件不存在，将开始交互式配置..."
    interactive_config "$CONFIG_FILE"
    echo "请设置好配置后重新运行脚本上传文件"
    exit 0
fi

# 加载配置
source "$CONFIG_FILE"

# 处理批量上传模式
if [ "$BATCH_MODE" = true ]; then
    if [ -z "$BATCH_FILE" ]; then
        error_exit "批量上传模式需要指定文件列表"
    fi
    
    # 检查文件是否存在
    if [ ! -f "$BATCH_FILE" ]; then
        error_exit "批量文件列表不存在: $BATCH_FILE"
    fi
    
    # 如果提供了远程路径，则使用它，否则使用默认路径
    REMOTE_DIR=""
    if [ -n "$1" ]; then
        REMOTE_DIR="$1"
    else
        REMOTE_DIR="$DEFAULT_REMOTE_DIR"
    fi
    
    # 检查必需的配置项
    if [ -z "$USERNAME" ] || [ -z "$ENCRYPTED_PASSWORD" ] || [ -z "$ALIST_BASE_URL" ]; then
        error_exit "配置文件中缺少必要参数(USERNAME, ENCRYPTED_PASSWORD, ALIST_BASE_URL)\n请使用 --init 选项重新配置"
    fi
    
    # 解密密码
    PASSWORD=$(decrypt_password "$ENCRYPTED_PASSWORD")
    if [ -z "$PASSWORD" ]; then
        error_exit "密码解密失败，请重新配置"
    fi
    
    # 获取 token
    RESPONSE=$(curl --silent --header "Content-Type: application/json" \
      --request POST --data "{\"username\":\"$USERNAME\", \"password\":\"$PASSWORD\"}" \
      "$ALIST_BASE_URL/api/auth/login")
    
    # 提取 token
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
    
    if [ -z "$TOKEN" ]; then
        error_exit "获取令牌失败，请检查用户名和密码"
    fi
    
    # 执行批量上传
    upload_file_list "$BATCH_FILE" "$REMOTE_DIR" "$TOKEN" "$ALIST_BASE_URL"
    exit 0
fi

# 检查必要参数
if [ -z "$1" ]; then
    error_exit "请指定要上传的文件或目录"
fi

LOCAL_PATH="$1"

# 递归上传目录
if [ "$RECURSIVE_MODE" = true ]; then
    # 检查路径是否存在
    if [ ! -d "$LOCAL_PATH" ]; then
        error_exit "目录不存在: $LOCAL_PATH"
    fi
    
    # 如果提供了远程路径，则使用它，否则使用默认路径
    REMOTE_DIR=""
    if [ -n "$2" ]; then
        REMOTE_DIR="$2"
    else
        # 获取目录名
        DIR_NAME=$(basename "$LOCAL_PATH")
        # 使用默认远程目录加目录名
        REMOTE_DIR="${DEFAULT_REMOTE_DIR}/${DIR_NAME}"
    fi
    
    # 检查必需的配置项
    if [ -z "$USERNAME" ] || [ -z "$ENCRYPTED_PASSWORD" ] || [ -z "$ALIST_BASE_URL" ]; then
        error_exit "配置文件中缺少必要参数(USERNAME, ENCRYPTED_PASSWORD, ALIST_BASE_URL)\n请使用 --init 选项重新配置"
    fi
    
    # 解密密码
    PASSWORD=$(decrypt_password "$ENCRYPTED_PASSWORD")
    if [ -z "$PASSWORD" ]; then
        error_exit "密码解密失败，请重新配置"
    fi
    
    # 获取 token
    RESPONSE=$(curl --silent --header "Content-Type: application/json" \
      --request POST --data "{\"username\":\"$USERNAME\", \"password\":\"$PASSWORD\"}" \
      "$ALIST_BASE_URL/api/auth/login")
    
    # 提取 token
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
    
    if [ -z "$TOKEN" ]; then
        error_exit "获取令牌失败，请检查用户名和密码"
    fi
    
    # 执行目录上传
    upload_directory "$LOCAL_PATH" "$REMOTE_DIR" "$TOKEN" "$ALIST_BASE_URL"
    exit 0
fi

# 单文件上传模式
# 检查本地文件是否存在
if [ ! -f "$LOCAL_PATH" ]; then
    error_exit "本地文件不存在: $LOCAL_PATH"
fi

# 如果提供了远程路径，则使用它，否则使用默认路径
if [ -n "$2" ]; then
    REMOTE_PATH="$2"
else
    # 获取文件名
    FILE_NAME=$(basename "$LOCAL_PATH")
    # 使用默认远程目录加文件名
    REMOTE_PATH="${DEFAULT_REMOTE_DIR}/${FILE_NAME}"
fi

# 检查必需的配置项
if [ -z "$USERNAME" ] || [ -z "$ENCRYPTED_PASSWORD" ] || [ -z "$ALIST_BASE_URL" ]; then
    error_exit "配置文件中缺少必要参数(USERNAME, ENCRYPTED_PASSWORD, ALIST_BASE_URL)\n请使用 --init 选项重新配置"
fi

# 解密密码
PASSWORD=$(decrypt_password "$ENCRYPTED_PASSWORD")
if [ -z "$PASSWORD" ]; then
    error_exit "密码解密失败，请重新配置"
fi

# 格式化远程路径
if [[ "$REMOTE_PATH" == http* ]]; then
    # 用户提供了完整URL作为远程路径
    BASE_URL=$(echo "$REMOTE_PATH" | sed 's|\(https\?://[^/]*\)/.*|\1|')
    REMOTE_FILE_PATH=$(echo "$REMOTE_PATH" | sed "s|$BASE_URL||")
else
    # 用户只提供了路径部分
    BASE_URL="$ALIST_BASE_URL"
    # 确保路径以斜杠开头
    if [[ "$REMOTE_PATH" != /* ]]; then
        REMOTE_FILE_PATH="/$REMOTE_PATH"
    else
        REMOTE_FILE_PATH="$REMOTE_PATH"
    fi
fi

# 获取 token
RESPONSE=$(curl --silent --header "Content-Type: application/json" \
  --request POST --data "{\"username\":\"$USERNAME\", \"password\":\"$PASSWORD\"}" \
  "$BASE_URL/api/auth/login")

# 提取 token
TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

if [ -z "$TOKEN" ]; then
    error_exit "获取令牌失败，请检查用户名和密码"
fi

# 上传单个文件
upload_file "$LOCAL_PATH" "$REMOTE_PATH" "$TOKEN" "$BASE_URL"

# 检查上传结果
UPLOAD_STATUS=$?

# 提示用户上传完成
if [ $UPLOAD_STATUS -eq 0 ]; then
    # 获取文件大小（易读形式）
    file_size=$(du -h "$LOCAL_PATH" | cut -f1)
    remote_url="$BASE_URL$REMOTE_FILE_PATH"
    success_msg "✅ 上传完成: $FILE_NAME ($file_size)"
    echo -e "\033[36m🌐 远程地址: $remote_url\033[0m"
    
    # 静默验证上传 (不显示详细结果)
    curl --silent -H "Authorization: $TOKEN" \
      -H "Content-Type: application/json" \
      --request POST --data "{\"path\":\"$REMOTE_FILE_PATH\"}" \
      "$BASE_URL/api/fs/get" > /dev/null
else
    error_exit "✗ 上传失败！请检查网络连接和权限设置"
fi
