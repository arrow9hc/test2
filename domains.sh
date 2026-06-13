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

# Report variables
REPORT=""
WEBSITES_FOUND=0

# Initialize report
init_report() {
    REPORT="========================================\n"
    REPORT+="       Linux Server Website Deployment Report\n"
    REPORT+="========================================\n"
    REPORT+="Detection Time: $(date '+%Y-%m-%d %H:%M:%S')\n"
    REPORT+="Hostname: $(hostname)\n"
    REPORT+="IP Address: $(hostname -I | awk '{print $1}')\n"
    REPORT+="========================================\n\n"
}

# Print and append to report
add_to_report() {
    echo -e "$1"
    REPORT+="$1\n"
}

# Detect web server type
detect_web_server() {
    add_to_report "${BLUE}[1/6] Detecting web server type...${NC}"
    
    local web_servers=()
    
    if command -v nginx &> /dev/null || pgrep nginx &> /dev/null; then
        web_servers+=("nginx")
    fi
    
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null || pgrep apache2 &> /dev/null || pgrep httpd &> /dev/null; then
        web_servers+=("apache")
    fi
    
    if [ ${#web_servers[@]} -eq 0 ]; then
        add_to_report "${RED}❌ No Nginx or Apache service detected${NC}"
        add_to_report "Note: May be using other web servers (Tomcat, Node.js, etc.) or no website deployed\n"
        return 1
    fi
    
    add_to_report "${GREEN}✅ Detected web servers: ${web_servers[*]}${NC}\n"
    return 0
}

# Check listening ports
check_ports() {
    add_to_report "${BLUE}[2/6] Checking web port listening status...${NC}"
    
    if command -v netstat &> /dev/null; then
        local ports=$(sudo netstat -tlnp 2>/dev/null | grep -E ':80|:443' | awk '{print $4}' | sed 's/.*://' | sort -u)
    elif command -v ss &> /dev/null; then
        local ports=$(sudo ss -tlnp 2>/dev/null | grep -E ':80|:443' | awk '{print $4}' | sed 's/.*://' | sort -u)
    else
        add_to_report "${YELLOW}⚠️  Unable to check port status (netstat/ss not available)${NC}\n"
        return
    fi
    
    if [ -n "$ports" ]; then
        for port in $ports; do
            if [ "$port" = "80" ]; then
                add_to_report "${GREEN}✅ HTTP (port 80) is listening${NC}"
            elif [ "$port" = "443" ]; then
                add_to_report "${GREEN}✅ HTTPS (port 443) is listening${NC}"
            fi
        done
    else
        add_to_report "${YELLOW}⚠️  No listening services detected on ports 80/443${NC}"
    fi
    add_to_report ""
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
            add_to_report "${BLUE}[3/6] Analyzing Nginx configuration (${config_path})...${NC}"
            
            # Find server_name and root
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
                            add_to_report "${GREEN}📍 Website #${WEBSITES_FOUND}${NC}"
                            add_to_report "  Type: Nginx"
                            [ -n "$current_server" ] && [ "$current_server" != "_" ] && add_to_report "  Domain: $current_server"
                            add_to_report "  Path: $current_root"
                            
                            # Check directory contents
                            local file_count=$(find "$current_root" -maxdepth 1 -type f 2>/dev/null | wc -l)
                            add_to_report "  File count: $file_count (excluding subdirectories)"
                            
                            # Check entry files
                            if [ -f "$current_root/index.html" ]; then
                                add_to_report "  Entry file: index.html ✓"
                            elif [ -f "$current_root/index.php" ]; then
                                add_to_report "  Entry file: index.php ✓"
                            elif [ -f "$current_root/index.htm" ]; then
                                add_to_report "  Entry file: index.htm ✓"
                            fi
                            add_to_report ""
                            
                            current_server=""
                            current_root=""
                        fi
                    fi
                done < "$temp_file"
                rm "$temp_file"
            else
                add_to_report "${YELLOW}⚠️  No valid site configurations found${NC}\n"
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
            add_to_report "${BLUE}[4/6] Analyzing Apache configuration (${config_path})...${NC}"
            
            # Find DocumentRoot and ServerName
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
                            add_to_report "${GREEN}📍 Website #${WEBSITES_FOUND}${NC}"
                            add_to_report "  Type: Apache"
                            [ -n "$current_server" ] && add_to_report "  Domain: $current_server"
                            add_to_report "  Path: $current_root"
                            
                            # Check directory contents
                            local file_count=$(find "$current_root" -maxdepth 1 -type f 2>/dev/null | wc -l)
                            add_to_report "  File count: $file_count (excluding subdirectories)"
                            
                            # Check entry files
                            if [ -f "$current_root/index.html" ]; then
                                add_to_report "  Entry file: index.html ✓"
                            elif [ -f "$current_root/index.php" ]; then
                                add_to_report "  Entry file: index.php ✓"
                            elif [ -f "$current_root/index.htm" ]; then
                                add_to_report "  Entry file: index.htm ✓"
                            fi
                            add_to_report ""
                            
                            current_server=""
                            current_root=""
                        fi
                    fi
                done < "$temp_file"
                rm "$temp_file"
            else
                add_to_report "${YELLOW}⚠️  No valid site configurations found${NC}\n"
            fi
            break
        fi
    done
}

# Check common default directories
check_default_directories() {
    add_to_report "${BLUE}[5/6] Checking common default website directories...${NC}"
    
    local default_dirs=(
        "/var/www/html"
        "/var/www"
        "/usr/share/nginx/html"
        "/home/*/public_html"
    )
    
    for dir in "${default_dirs[@]}"; do
        # Handle wildcards
        if [[ "$dir" == *"*"* ]]; then
            for expanded_dir in $dir; do
                if [ -d "$expanded_dir" ] && [ "$(ls -A "$expanded_dir" 2>/dev/null)" ]; then
                    add_to_report "${GREEN}📁 Found website directory: $expanded_dir${NC}"
                    add_to_report "  File preview: $(ls -la "$expanded_dir" 2>/dev/null | head -5 | tail -3 | awk '{print "    " $NF}')"
                fi
            done
        else
            if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
                add_to_report "${GREEN}📁 Found website directory: $dir${NC}"
                add_to_report "  File preview: $(ls -la "$dir" 2>/dev/null | head -5 | tail -3 | awk '{print "    " $NF}')"
            fi
        fi
    done
    add_to_report ""
}

# Check service status
check_service_status() {
    add_to_report "${BLUE}[6/6] Checking web service running status...${NC}"
    
    # Check Nginx
    if systemctl list-units --type=service 2>/dev/null | grep -q "nginx.service"; then
        local nginx_status=$(systemctl is-active nginx 2>/dev/null)
        if [ "$nginx_status" = "active" ]; then
            add_to_report "${GREEN}✅ Nginx service: Running${NC}"
        else
            add_to_report "${RED}❌ Nginx service: $nginx_status${NC}"
        fi
    fi
    
    # Check Apache
    if systemctl list-units --type=service 2>/dev/null | grep -q "apache2.service\|httpd.service"; then
        local apache_service="apache2"
        [ -f "/usr/lib/systemd/system/httpd.service" ] && apache_service="httpd"
        local apache_status=$(systemctl is-active $apache_service 2>/dev/null)
        if [ "$apache_status" = "active" ]; then
            add_to_report "${GREEN}✅ Apache service: Running${NC}"
        else
            add_to_report "${RED}❌ Apache service: $apache_status${NC}"
        fi
    fi
    
    add_to_report ""
}

# Generate final summary
generate_summary() {
    add_to_report "${BLUE}════════════════════════════════════════${NC}"
    add_to_report "${BLUE}             Detection Summary${NC}"
    add_to_report "${BLUE}════════════════════════════════════════${NC}"
    
    if [ $WEBSITES_FOUND -eq 0 ]; then
        add_to_report "${YELLOW}⚠️  No clear website deployment detected${NC}"
        add_to_report ""
        add_to_report "Possible reasons:"
        add_to_report "  1. Website deployed in non-standard directory"
        add_to_report "  2. Using containerized deployment (Docker/K8s)"
        add_to_report "  3. Using other web servers (Tomcat/Node.js/Python, etc.)"
        add_to_report "  4. Permission restrictions prevent reading config files"
        add_to_report ""
        add_to_report "Suggested commands for further investigation:"
        add_to_report "  • ps aux | grep -E 'nginx|apache|httpd|java|node|python'"
        add_to_report "  • docker ps (if Docker is installed)"
        add_to_report "  • find / -name '*.conf' -path '*/nginx/*' 2>/dev/null"
    else
        add_to_report "${GREEN}✅ Total $WEBSITES_FOUND website(s) deployed${NC}"
        add_to_report ""
        add_to_report "All website configuration file locations:"
        [ -d "/etc/nginx" ] && add_to_report "  • Nginx: /etc/nginx/"
        [ -d "/etc/apache2" ] && add_to_report "  • Apache: /etc/apache2/"
        [ -d "/etc/httpd" ] && add_to_report "  • Apache: /etc/httpd/"
    fi
    
    add_to_report ""
    add_to_report "========================================"
    add_to_report "           Report Complete"
    add_to_report "========================================"
}

# Main function
main() {
    # Check for sudo privileges
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}⚠️  Note: Some features require root privileges. It's recommended to run this script with sudo${NC}"
        echo -e "${YELLOW}Hint: Please run 'sudo bash $0' for complete detection results\n${NC}"
    fi
    
    init_report
    
    # Run detection
    if detect_web_server; then
        check_ports
        detect_nginx_sites
        detect_apache_sites
    fi
    
    check_default_directories
    check_service_status
    generate_summary
    
    # Save report to file
    local report_file="/tmp/web_detect_report_$(date +%Y%m%d_%H%M%S).txt"
    echo -e "$REPORT" > "$report_file"
    echo -e "\n${GREEN}📄 Complete report saved to: $report_file${NC}"
    
    # Ask to save to home directory
    echo -e "\n${YELLOW}Save report to home directory? [y/N]${NC}"
    read -r save_to_home
    if [[ "$save_to_home" =~ ^[Yy]$ ]]; then
        cp "$report_file" ~/web_detect_report.txt
        echo -e "${GREEN}✅ Report saved to: ~/web_detect_report.txt${NC}"
    fi
}

# Run main function
main