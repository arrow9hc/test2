#!/bin/bash

# ============================================
# 创建和管理员权限一样的用户（推荐方式）
# ============================================
USERNAME="adminqqq"
PASSWORD="qqq@ssw0rd123"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root"
    exit 1
fi

# 检查用户是否存在
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists"
    exit 1
fi

# 创建普通用户
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# 添加到 sudo 组（Ubuntu/Debian）
if getent group sudo &>/dev/null; then
    usermod -aG sudo "$USERNAME"
fi

# 添加到 wheel 组（CentOS/RHEL/Fedora）
if getent group wheel &>/dev/null; then
    usermod -aG wheel "$USERNAME"
fi

# 添加到 root 组（可选，增加权限）
usermod -aG root "$USERNAME"

echo "========================================="
echo "✓ Administrator created (NOT full root)"
echo "========================================="
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""
echo "Permissions:"
echo "- Can run admin commands with: sudo <command>"
echo "- Needs to enter password for sudo"
echo "- NOT the same as root (safer)"
echo ""
echo "To test: su - $USERNAME"
echo "Then run: sudo whoami  # should output 'root'"
echo "========================================="
