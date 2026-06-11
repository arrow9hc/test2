#!/bin/bash

# ============================================
# Comprehensive Linux Website Directory Scanner
# Based on index.php, sitemap.xml, robots.txt files
# ============================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 常见网站目录位置（用于快速搜索）
COMMON_BASE_DIRS=(
    "/var/www"
    "/var/www/html"
    "/var/www/htdocs"
    "/var/www/public_html"
    "/home"
    "/srv/www"
    "/srv/http"
    "/usr/share/nginx/html"
    "/opt/lampp/htdocs"
    "/opt/bitnami/apache2/htdocs"
    "/opt/bitnami/nginx/html"
    "/opt/xampp/htdocs"
    "/data/www"
    "/data/wwwroot"
    "/www/wwwroot"
    "/www/html"
    "/app/www"
    "/usr/local/www"
    "/usr/local/apache2/htdocs"
    "/usr/local/nginx/html"
)

# 常见的网站目录名称
COMMON_DIR_NAMES=(
    "html"
    "htdocs"
    "public_html"
    "www"
    "web"
    "public"
    "wwwroot"
    "site"
    "website"
    "httpdocs"
    "app"
    "application"
    "cms"
    "content"
)

# 显示横幅
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     Comprehensive Linux Website Directory Scanner        ║"
    echo "║     Based on index.php, sitemap.xml, robots.txt          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}[INFO]${NC} Scan started at: $(date)"
    echo ""
}

# 方法1：通过 find 命令查找 index.php
scan_by_indexphp() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 1] Finding directories with index.php${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local found=0
    local search_paths=""
    
    # 构建搜索路径
    for dir in "${COMMON_BASE_DIRS[@]}"; do
        search_paths="$search_paths $dir"
    done
    
    echo -e "${YELLOW}Searching in:${NC} ${COMMON_BASE_DIRS[*]}"
    echo ""
    
    # 查找 index.php 文件
    for base in "${COMMON_BASE_DIRS[@]}"; do
        if [ -d "$base" ] 2>/dev/null; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local dir_path=$(dirname "$file")
                    echo -e "${GREEN}[FOUND]${NC} $dir_path"
                    echo "$dir_path" >> /tmp/websites_found_temp
                    ((found++))
                fi
            done < <(find "$base" -maxdepth 5 -name "index.php" -type f 2>/dev/null | head -100)
        fi
    done
    
    # 全系统搜索（较慢，作为备选）
    echo -e "\n${YELLOW}[Extended] Searching entire system (may take a while)...${NC}"
    local sys_found=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local dir_path=$(dirname "$file")
            echo -e "${GREEN}[FOUND]${NC} $dir_path"
            echo "$dir_path" >> /tmp/websites_found_temp
            ((sys_found++))
            [ $sys_found -ge 50 ] && break  # 限制结果数量
        fi
    done < <(find / -maxdepth 6 -name "index.php" -type f 2>/dev/null | head -100)
    
    echo -e "\n${BLUE}[RESULT]${NC} Total directories with index.php found: $((found + sys_found))"
    echo ""
}

# 方法2：通过 robots.txt 查找
scan_by_robots() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 2] Finding directories with robots.txt${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local found=0
    
    # 在常见目录中查找
    for base in "${COMMON_BASE_DIRS[@]}"; do
        if [ -d "$base" ] 2>/dev/null; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local dir_path=$(dirname "$file")
                    echo -e "${GREEN}[FOUND]${NC} $dir_path"
                    echo "$dir_path" >> /tmp/websites_found_temp
                    # 显示 robots.txt 内容摘要
                    echo -e "${CYAN}  robots.txt content:${NC}"
                    head -3 "$file" | sed 's/^/    /'
                    ((found++))
                fi
            done < <(find "$base" -maxdepth 4 -name "robots.txt" -type f 2>/dev/null)
        fi
    done
    
    # 全系统搜索
    echo -e "\n${YELLOW}[Extended] Searching entire system...${NC}"
    local sys_found=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local dir_path=$(dirname "$file")
            echo -e "${GREEN}[FOUND]${NC} $dir_path"
            echo "$dir_path" >> /tmp/websites_found_temp
            ((sys_found++))
            [ $sys_found -ge 30 ] && break
        fi
    done < <(find / -maxdepth 6 -name "robots.txt" -type f 2>/dev/null | head -50)
    
    echo -e "\n${BLUE}[RESULT]${NC} Total directories with robots.txt found: $((found + sys_found))"
    echo ""
}

# 方法3：通过 sitemap.xml 查找
scan_by_sitemap() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 3] Finding directories with sitemap.xml${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local found=0
    
    for base in "${COMMON_BASE_DIRS[@]}"; do
        if [ -d "$base" ] 2>/dev/null; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local dir_path=$(dirname "$file")
                    echo -e "${GREEN}[FOUND]${NC} $dir_path"
                    echo "$dir_path" >> /tmp/websites_found_temp
                    # 显示 sitemap 中的 URL 数量
                    local url_count=$(grep -c "<loc>" "$file" 2>/dev/null)
                    [ -n "$url_count" ] && [ $url_count -gt 0 ] && echo -e "${CYAN}  Contains $url_count URLs${NC}"
                    ((found++))
                fi
            done < <(find "$base" -maxdepth 4 -name "sitemap*.xml" -type f 2>/dev/null | head -20)
        fi
    done
    
    echo -e "\n${BLUE}[RESULT]${NC} Total directories with sitemap.xml found: $found"
    echo ""
}

# 方法4：通过常见目录名称模式查找
scan_by_common_names() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 4] Finding directories by common names${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local found=0
    
    for base in / /home /var /opt /srv /usr/share; do
        for name in "${COMMON_DIR_NAMES[@]}"; do
            if [ -d "$base/$name" ] 2>/dev/null; then
                # 检查是否包含网站文件
                for web_file in index.php index.html robots.txt; do
                    if [ -f "$base/$name/$web_file" ]; then
                        echo -e "${GREEN}[FOUND]${NC} $base/$name (contains $web_file)"
                        echo "$base/$name" >> /tmp/websites_found_temp
                        ((found++))
                        break
                    fi
                done
            fi
        done
    done
    
    # 递归查找常见模式
    echo -e "\n${YELLOW}[Extended] Searching for common patterns recursively...${NC}"
    for base in "${COMMON_BASE_DIRS[@]}"; do
        if [ -d "$base" ] 2>/dev/null; then
            for name in "${COMMON_DIR_NAMES[@]}"; do
                while IFS= read -r dir; do
                    for web_file in index.php index.html; do
                        if [ -f "$dir/$web_file" ]; then
                            echo -e "${GREEN}[FOUND]${NC} $dir"
                            echo "$dir" >> /tmp/websites_found_temp
                            ((found++))
                            break
                        fi
                    done
                done < <(find "$base" -maxdepth 3 -type d -name "$name" 2>/dev/null | head -30)
            done
        fi
    done
    
    echo -e "\n${BLUE}[RESULT]${NC} Total directories found by common names: $found"
    echo ""
}

# 方法5：通过 Web 服务器配置查找
scan_by_web_configs() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 5] Extracting document roots from web server configs${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # Apache configurations
    if [ -d "/etc/apache2" ] || [ -d "/etc/httpd" ]; then
        echo -e "${YELLOW}Apache configurations:${NC}"
        grep -rh "DocumentRoot" /etc/apache2 /etc/httpd 2>/dev/null | grep -v "^#" | while read line; do
            root=$(echo "$line" | awk '{print $2}' | sed 's/[";]//g')
            if [ -n "$root" ] && [ -d "$root" ]; then
                echo -e "${GREEN}[FOUND]${NC} $root (from Apache config)"
                echo "$root" >> /tmp/websites_found_temp
            fi
        done
    fi
    
    # Nginx configurations
    if [ -d "/etc/nginx" ]; then
        echo -e "\n${YELLOW}Nginx configurations:${NC}"
        grep -rh "root" /etc/nginx 2>/dev/null | grep -v "^#" | grep -v "^\s*#" | while read line; do
            root=$(echo "$line" | awk '{print $2}' | sed 's/[";]//g')
            if [ -n "$root" ] && [ -d "$root" ]; then
                echo -e "${GREEN}[FOUND]${NC} $root (from Nginx config)"
                echo "$root" >> /tmp/websites_found_temp
            fi
        done
    fi
    
    echo ""
}

# 方法6：通过分析符号链接和进程
scan_by_processes() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 6] Finding web server processes and their roots${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # Find running web servers
    echo -e "${YELLOW}Running web servers:${NC}"
    ps aux | grep -E "apache|nginx|httpd|php-fpm" | grep -v grep | while read line; do
        echo -e "${CYAN}  $line${NC}"
    done
    
    # Check common web server working directories
    for proc in apache2 nginx httpd; do
        pidof "$proc" &>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "\n${YELLOW}Process $proc is running, checking paths...${NC}"
            for pid in $(pidof "$proc" 2>/dev/null | head -3); do
                if [ -d "/proc/$pid" ]; then
                    cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)
                    if [ -n "$cwd" ] && [ -d "$cwd" ]; then
                        echo -e "${GREEN}[FOUND]${NC} $cwd (working directory of $proc)"
                        echo "$cwd" >> /tmp/websites_found_temp
                    fi
                    # Check open files
                    ls -l "/proc/$pid/fd" 2>/dev/null | grep -E "\.(php|html|conf)" | awk '{print $NF}' | while read file; do
                        if [ -f "$file" ]; then
                            dir_path=$(dirname "$file")
                            echo -e "${GREEN}[FOUND]${NC} $dir_path (open by $proc)"
                            echo "$dir_path" >> /tmp/websites_found_temp
                        fi
                    done 2>/dev/null
                fi
            done
        fi
    done
    
    echo ""
}

# 方法7：通过 PHP 配置和扩展
scan_by_php_configs() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 7] Finding PHP include paths and configurations${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # PHP configuration files
    if [ -f "/etc/php.ini" ]; then
        echo -e "${YELLOW}PHP configurations:${NC}"
        grep -E "include_path|open_basedir|doc_root" /etc/php.ini 2>/dev/null | grep -v "^;" | while read line; do
            echo -e "${CYAN}  $line${NC}"
            path=$(echo "$line" | sed 's/.*=[ ]*//' | sed 's/[";]//g' | tr ':' '\n' | head -1)
            if [ -n "$path" ] && [ -d "$path" ]; then
                echo -e "${GREEN}[FOUND]${NC} $path (from PHP config)"
                echo "$path" >> /tmp/websites_found_temp
            fi
        done
    fi
    
    # PHP-FPM pool configurations
    if [ -d "/etc/php" ]; then
        find /etc/php -name "*.conf" -o -name "*.ini" 2>/dev/null | while read conf; do
            grep -E "chdir|prefix|doc_root" "$conf" 2>/dev/null | grep -v "^;" | while read line; do
                path=$(echo "$line" | awk '{print $NF}' | sed 's/[";]//g')
                if [ -n "$path" ] && [ -d "$path" ]; then
                    echo -e "${GREEN}[FOUND]${NC} $path (from $conf)"
                    echo "$path" >> /tmp/websites_found_temp
                fi
            done
        done
    fi
    
    echo ""
}

# 方法8：通过网站备份和版本控制文件
scan_by_backups() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}[Method 8] Finding directories via backup/config files${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local patterns=(
        ".git/config"
        ".svn/entries"
        "wp-config.php"
        "config.php"
        "settings.php"
        ".env"
        "composer.json"
        "package.json"
    )
    
    for pattern in "${patterns[@]}"; do
        echo -e "${YELLOW}Searching for $pattern...${NC}"
        for base in "${COMMON_BASE_DIRS[@]}"; do
            if [ -d "$base" ] 2>/dev/null; then
                find "$base" -maxdepth 5 -name "$(basename "$pattern")" -type f 2>/dev/null | head -10 | while read file; do
                    dir_path=$(dirname "$file")
                    echo -e "${GREEN}[FOUND]${NC} $dir_path (contains $pattern)"
                    echo "$dir_path" >> /tmp/websites_found_temp
                done
            fi
        done
    done
    
    echo ""
}

# 去重并显示最终结果
show_final_results() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════╗"
    echo -e "║                    FINAL RESULTS                               ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    if [ -f /tmp/websites_found_temp ] && [ -s /tmp/websites_found_temp ]; then
        local total=$(sort -u /tmp/websites_found_temp | wc -l)
        echo -e "${GREEN}Total unique website directories found: $total${NC}\n"
        echo -e "${WHITE}List of discovered website directories:${NC}\n"
        
        sort -u /tmp/websites_found_temp | nl | while read line; do
            echo -e "${CYAN}$line${NC}"
        done
        
        # Verify each directory
        echo -e "\n${YELLOW}Verifying directories with index.php presence:${NC}\n"
        sort -u /tmp/websites_found_temp | while read dir; do
            if [ -f "$dir/index.php" ]; then
                echo -e "${GREEN}[VALID]${NC} $dir/index.php exists"
            elif [ -f "$dir/index.html" ]; then
                echo -e "${GREEN}[VALID]${NC} $dir/index.html exists"
            elif [ -f "$dir/robots.txt" ]; then
                echo -e "${YELLOW}[PARTIAL]${NC} $dir/robots.txt exists (no index file)"
            else
                echo -e "${RED}[WARNING]${NC} $dir - no index file found"
            fi
        done
    else
        echo -e "${RED}No website directories found.${NC}"
        echo -e "${YELLOW}Try running with sudo for deeper search:${NC} sudo $0"
    fi
    
    # 清理临时文件
    rm -f /tmp/websites_found_temp
}

# 主函数
main() {
    show_banner
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_info "Running with root privileges - full system scan enabled"
    else
        print_warning "Running without root privileges - some directories may be inaccessible"
        print_warning "Consider running with: sudo $0"
    fi
    
    echo ""
    
    # Run all scanning methods
    scan_by_indexphp
    scan_by_robots
    scan_by_sitemap
    scan_by_common_names
    scan_by_web_configs
    scan_by_processes
    scan_by_php_configs
    scan_by_backups
    
    # Show consolidated results
    show_final_results
    
    echo -e "\n${BLUE}[INFO]${NC} Scan completed at: $(date)"
}

# 运行主函数
main