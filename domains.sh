#!/bin/bash

# ============================================
# Linux Server Website Deployment Detection Script
# Function: Automatically detect web servers, website directories, domains and status
# Author: DevOps Assistant
# ============================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WEBSITES_FOUND=0

# Print section header
print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}$1${NC}"
}

# Detect web server type
detect_web_server() {
    print_header "[1/6] Detecting web server type..."
    
    local web_servers=()
    
    if command -v nginx &> /dev/null || pgrep nginx &> /dev/null; then
        web_servers+=("nginx")
    fi
    
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null || pgrep apache2 &> /dev/null || pgrep httpd &> /dev/null; then
        web_servers+=("apache")
    fi
    
    if [ ${#web_servers[@]} -eq 0 ]; then
        print_error "❌ No Nginx or Apache service detected"
        echo -e "Note: May be using other web servers (Tomcat, Node.js, etc.) or no website deployed\n"
        return 1
    fi
    
    print_success "✅ Detected web servers: ${web_servers[*]}"
    echo ""
    return 0
}

# Check listening ports
check_ports() {
    print_header "[2/6] Checking web port listening status..."
    
    if command -v netstat &> /dev/null; then
        local ports=$(sudo netstat -tlnp 2>/dev/null | grep -E ':80|:443' | awk '{print $4}' | sed 's/.*://' | sort -u)
    elif command -v ss &> /dev/null; then
        local ports=$(sudo ss -tlnp 2>/dev/null | grep -E ':80|:443' | awk '{print $4}' | sed 's/.*://' | sort -u)
    else
        print_warning "⚠️  Unable to check port status (netstat/ss not available)"
        echo ""
        return
    fi
    
    if [ -n "$ports" ]; then
        for port in $ports; do
            if [ "$port" = "80" ]; then
                print_success "✅ HTTP (port 80) is listening"
            elif [ "$port" = "443" ]; then
                print_success "✅ HTTPS (port 443) is listening"
            fi
        done
    else
        print_warning "⚠️  No listening services detected on ports 80/443"
    fi
    echo ""
}

# Detect Nginx sites
detect_nginx_sites() {
    local config_paths=(
        "/etc/nginx/sites-enabled/"
        "/etc/nginx/conf.d/"
        "/etc/nginx/nginx.conf"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [ -e "$config_path" ]; then
            print_header "[3/6] Analyzing Nginx configuration (${config_path})..."
            
            local temp_file=$(mktemp)
            sudo grep -r -E "server_name|root" "$config_path" 2>/dev/null | grep -v "^#" > "$temp_file"
            
            if [ -s "$temp_file" ]; then
                local current_server=""
                local current_root=""
                
                while IFS= read -r line; do
                    if echo "$line" | grep -q "server_name"; then
                        current_server=$(echo "$line" | sed 's/.*server_name\s*//' | sed 's/;.*//' | sed 's/\s*$//')
                    fi
                    if echo "$line" | grep -q "root"; then
                        current_root=$(echo "$line" | sed 's/.*root\s*//' | sed 's/;.*//' | sed 's/\s*$//')
                        
                        if [ -n "$current_root" ] && [ -d "$current_root" ]; then
                            WEBSITES_FOUND=$((WEBSITES_FOUND + 1))
                            echo ""
                            print_success "📍 Website #${WEBSITES_FOUND}"
                            echo "  Type: Nginx"
                            [ -n "$current_server" ] && [ "$current_server" != "_" ] && echo "  Domain: $current_server"
                            echo "  Path: $current_root"
                            
                            local file_count=$(find "$current_root" -maxdepth 1 -type f 2>/dev/null | wc -l)
                            echo "  File count: $file_count (excluding subdirectories)"
                            
                            if [ -f "$current_root/index.html" ]; then
                                echo "  Entry file: index.html ✓"
                            elif [ -f "$current_root/index.php" ]; then
                                echo "  Entry file: index.php ✓"
                            elif [ -f "$current_root/index.htm" ]; then
                                echo "  Entry file: index.htm ✓"
                            fi
                            
                            current_server=""
                            current_root=""
                        fi
                    fi
                done < "$temp_file"
                rm "$temp_file"
                echo ""
            else
                print_warning "⚠️  No valid site configurations found"
                echo ""
            fi
            break
        fi
    done
}

# Detect Apache sites
detect_apache_sites() {
    local config_paths=(
        "/etc/apache2/sites-enabled/"
        "/etc/httpd/conf.d/"
        "/etc/httpd/conf/httpd.conf"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [ -e "$config_path" ]; then
            print_header "[4/6] Analyzing Apache configuration (${config_path})..."
            
            local temp_file=$(mktemp)
            sudo grep -r -E "DocumentRoot|ServerName" "$config_path" 2>/dev/null | grep -v "^#" > "$temp_file"
            
            if [ -s "$temp_file" ]; then
                local current_server=""
                local current_root=""
                
                while IFS= read -r line; do
                    if echo "$line" | grep -q "ServerName"; then
                        current_server=$(echo "$line" | sed 's/.*ServerName\s*//' | sed 's/\s*$//')
                    fi
                    if echo "$line" | grep -q "DocumentRoot"; then
                        current_root=$(echo "$line" | sed 's/.*DocumentRoot\s*//' | sed 's/\s*$//' | tr -d '"')
                        
                        if [ -n "$current_root" ] && [ -d "$current_root" ]; then
                            WEBSITES_FOUND=$((WEBSITES_FOUND + 1))
                            echo ""
                            print_success "📍 Website #${WEBSITES_FOUND}"
                            echo "  Type: Apache"
                            [ -n "$current_server" ] && echo "  Domain: $current_server"
                            echo "  Path: $current_root"
                            
                            local file_count=$(find "$current_root" -maxdepth 1 -type f 2>/dev/null | wc -l)
                            echo "  File count: $file_count (excluding subdirectories)"
                            
                            if [ -f "$current_root/index.html" ]; then
                                echo "  Entry file: index.html ✓"
                            elif [ -f "$current_root/index.php" ]; then
                                echo "  Entry file: index.php ✓"
                            elif [ -f "$current_root/index.htm" ]; then
                                echo "  Entry file: index.htm ✓"
                            fi
                            
                            current_server=""
                            current_root=""
                        fi
                    fi
                done < "$temp_file"
                rm "$temp_file"
                echo ""
            else
                print_warning "⚠️  No valid site configurations found"
                echo ""
            fi
            break
        fi
    done
}

# Check common default directories
check_default_directories() {
    print_header "[5/6] Checking common default website directories..."
    
    local default_dirs=(
        "/var/www/html"
        "/var/www"
        "/usr/share/nginx/html"
        "/home/*/public_html"
    )
    
    local found=0
    for dir in "${default_dirs[@]}"; do
        if [[ "$dir" == *"*"* ]]; then
            for expanded_dir in $dir; do
                if [ -d "$expanded_dir" ] && [ "$(ls -A "$expanded_dir" 2>/dev/null)" ]; then
                    print_success "📁 Found website directory: $expanded_dir"
                    echo "  File preview: $(ls -la "$expanded_dir" 2>/dev/null | head -5 | tail -3 | awk '{print "    " $NF}')"
                    found=1
                fi
            done
        else
            if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
                print_success "📁 Found website directory: $dir"
                echo "  File preview: $(ls -la "$dir" 2>/dev/null | head -5 | tail -3 | awk '{print "    " $NF}')"
                found=1
            fi
        fi
    done
    
    if [ $found -eq 0 ]; then
        print_warning "⚠️  No common default directories found"
    fi
    echo ""
}

# Check service status
check_service_status() {
    print_header "[6/6] Checking web service running status..."
    
    # Check Nginx
    if systemctl list-units --type=service 2>/dev/null | grep -q "nginx.service"; then
        local nginx_status=$(systemctl is-active nginx 2>/dev/null)
        if [ "$nginx_status" = "active" ]; then
            print_success "✅ Nginx service: Running"
        else
            print_error "❌ Nginx service: $nginx_status"
        fi
    fi
    
    # Check Apache
    if systemctl list-units --type=service 2>/dev/null | grep -q "apache2.service\|httpd.service"; then
        local apache_service="apache2"
        [ -f "/usr/lib/systemd/system/httpd.service" ] && apache_service="httpd"
        local apache_status=$(systemctl is-active $apache_service 2>/dev/null)
        if [ "$apache_status" = "active" ]; then
            print_success "✅ Apache service: Running"
        else
            print_error "❌ Apache service: $apache_status"
        fi
    fi
    
    echo ""
}

# Generate final summary
generate_summary() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}             Detection Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    if [ $WEBSITES_FOUND -eq 0 ]; then
        print_warning "⚠️  No clear website deployment detected"
        echo ""
        echo "Possible reasons:"
        echo "  1. Website deployed in non-standard directory"
        echo "  2. Using containerized deployment (Docker/K8s)"
        echo "  3. Using other web servers (Tomcat/Node.js/Python, etc.)"
        echo "  4. Permission restrictions prevent reading config files"
        echo ""
        echo "Suggested commands for further investigation:"
        echo "  • ps aux | grep -E 'nginx|apache|httpd|java|node|python'"
        echo "  • docker ps (if Docker is installed)"
        echo "  • find / -name '*.conf' -path '*/nginx/*' 2>/dev/null"
    else
        print_success "✅ Total $WEBSITES_FOUND website(s) deployed"
        echo ""
        echo "All website configuration file locations:"
        [ -d "/etc/nginx" ] && echo "  • Nginx: /etc/nginx/"
        [ -d "/etc/apache2" ] && echo "  • Apache: /etc/apache2/"
        [ -d "/etc/httpd" ] && echo "  • Apache: /etc/httpd/"
    fi
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           Detection Complete${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Main function
main() {
    # Check for sudo privileges
    if [ "$EUID" -ne 0 ]; then 
        print_warning "⚠️  Note: Some features require root privileges. It's recommended to run this script with sudo"
        echo -e "Hint: Please run 'sudo bash $0' for complete detection results\n"
    fi
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Linux Server Website Detection Tool${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Detection Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Hostname: $(hostname)"
    echo -e "IP Address: $(hostname -I | awk '{print $1}')"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Run detection
    if detect_web_server; then
        check_ports
        detect_nginx_sites
        detect_apache_sites
    fi
    
    check_default_directories
    check_service_status
    generate_summary
}

# Run main function
main
