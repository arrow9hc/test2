#!/bin/bash

# ============================================
# Linux Web Server Domain Configuration Scanner (FIXED)
# Fixed: Domain extraction and output issues
# ============================================

OUTPUT_FILE="./domains.txt"

# Clear output file
> "$OUTPUT_FILE"

SEP="=========================================="
LINE="------------------------------------------"

# Write function
write_output() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

# ==========================================
# 1. Detect server types
# ==========================================
write_output "Web Server Domain Configuration Report"
write_output "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
write_output "Hostname: $(hostname)"
write_output "$SEP"
write_output ""
write_output "[1] Detecting Web Server Types"
write_output "$LINE"

HAS_NGINX=false
HAS_APACHE=false

if command -v nginx &> /dev/null || pgrep -x "nginx" &> /dev/null; then
    HAS_NGINX=true
    write_output "✓ Nginx detected"
else
    write_output "✗ Nginx not detected"
fi

if command -v httpd &> /dev/null || command -v apache2 &> /dev/null || pgrep -x "httpd" &> /dev/null || pgrep -x "apache2" &> /dev/null; then
    HAS_APACHE=true
    write_output "✓ Apache detected"
else
    write_output "✗ Apache not detected"
fi

write_output "$SEP"

# ==========================================
# 2. Collect all domains in an array
# ==========================================
declare -A DOMAIN_MAP

collect_domain() {
    local domain="$1"
    if [ -n "$domain" ] && [ "$domain" != "--" ] && [ "$domain" != "_" ] && [ "$domain" != "localhost" ] && [ ${#domain} -gt 3 ]; then
        DOMAIN_MAP["$domain"]=1
    fi
}

# ==========================================
# 3. Query Nginx domains
# ==========================================
if [ "$HAS_NGINX" = true ]; then
    write_output ""
    write_output "[2] Nginx Bound Domains (server_name)"
    write_output "$LINE"
    
    # Method 1: Scan config files
    NGINX_DIRS=("/etc/nginx" "/usr/local/nginx/conf")
    
    for dir in "${NGINX_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            write_output "▶ Scanning: $dir"
            grep -r "server_name" "$dir" 2>/dev/null | grep -v "#" | grep -v "server_name\s*;" | while read -r line; do
                # Extract all domains from server_name line
                domains=$(echo "$line" | sed -n 's/.*server_name\s*\([^;]*\).*/\1/p' | tr -s ' ' | tr '\n' ' ')
                for domain in $domains; do
                    if [ -n "$domain" ] && [ "$domain" != "--" ] && [ "$domain" != "_" ]; then
                        echo "  $domain  (file: $(echo "$line" | cut -d: -f1))"
                        collect_domain "$domain"
                    fi
                done
            done
        fi
    done
    
    # Method 2: nginx -T
    write_output ""
    write_output "▶ Full config server_name (nginx -T):"
    if nginx -T 2>/dev/null | grep -q "server_name"; then
        nginx -T 2>/dev/null | grep "server_name" | grep -v "#" | while read -r line; do
            domains=$(echo "$line" | sed -n 's/.*server_name\s*\([^;]*\).*/\1/p' | tr -s ' ')
            for domain in $domains; do
                if [ -n "$domain" ] && [ "$domain" != "--" ] && [ "$domain" != "_" ]; then
                    echo "  $domain"
                    collect_domain "$domain"
                fi
            done
        done
    else
        write_output "  Cannot execute nginx -T (root permission may be required)"
    fi
fi

# ==========================================
# 4. Query Apache domains
# ==========================================
if [ "$HAS_APACHE" = true ]; then
    write_output ""
    write_output "[3] Apache Bound Domains (ServerName / ServerAlias)"
    write_output "$LINE"
    
    write_output "▶ Virtual Host List (apachectl -S / httpd -S):"
    if command -v apachectl &> /dev/null; then
        apachectl -S 2>/dev/null | grep -E "(namevhost|server name)" | while read -r line; do
            echo "  $line"
            # Extract domain from namevhost line
            domain=$(echo "$line" | sed -n 's/.*namevhost\s*\([^[:space:]]*\).*/\1/p')
            collect_domain "$domain"
        done
    elif command -v httpd &> /dev/null; then
        httpd -S 2>/dev/null | grep -E "(namevhost|server name)" | while read -r line; do
            echo "  $line"
            domain=$(echo "$line" | sed -n 's/.*namevhost\s*\([^[:space:]]*\).*/\1/p')
            collect_domain "$domain"
        done
    fi
    
    write_output ""
    write_output "▶ Searching config files for ServerName/ServerAlias:"
    APACHE_DIRS=("/etc/httpd" "/etc/apache2" "/usr/local/apache2/conf")
    
    for dir in "${APACHE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            write_output "  Scanning: $dir"
            grep -r -E "(ServerName|ServerAlias)" "$dir" 2>/dev/null | grep -v "#" | while read -r line; do
                # Extract domains from ServerName or ServerAlias
                domains=$(echo "$line" | grep -oE '(ServerName|ServerAlias)\s+[^[:space:]]+' | sed 's/ServerName\s*//;s/ServerAlias\s*//')
                for domain in $domains; do
                    if [ -n "$domain" ] && [ "$domain" != "*" ] && [ "$domain" != "_default_" ]; then
                        echo "    $domain  (file: $(echo "$line" | cut -d: -f1))"
                        collect_domain "$domain"
                    fi
                done
            done
        fi
    done
fi

# ==========================================
# 5. Port listening status
# ==========================================
write_output ""
write_output "[4] Port Listening Status"
write_output "$LINE"
if command -v netstat &> /dev/null; then
    netstat -tlnp 2>/dev/null | grep -E ":(80|443|8080|8443)" | grep -E "nginx|httpd|apache" | while read -r line; do
        echo "  $line"
    done
elif command -v ss &> /dev/null; then
    ss -tlnp 2>/dev/null | grep -E ":(80|443|8080|8443)" | grep -E "nginx|httpd|apache" | while read -r line; do
        echo "  $line"
    done
fi

# ==========================================
# 6. Summary (FIXED: Direct output from collected domains)
# ==========================================
write_output ""
write_output "$SEP"
write_output "[5] Summary: All Extracted Domains (Deduplicated)"
write_output "$LINE"

# Check if we have any domains
if [ ${#DOMAIN_MAP[@]} -eq 0 ]; then
    write_output "  No domains found. Trying fallback extraction from this file..."
    write_output ""
    write_output "  Extracting domains from config scan results above..."
    
    # Fallback: extract from the output file itself (where domains were listed)
    grep -oE '\b([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b' "$OUTPUT_FILE" 2>/dev/null | \
        grep -v "^[0-9]" | \
        grep -v "nginx.conf" | \
        grep -v "apache2.conf" | \
        grep -v "localhost" | \
        sort -u | \
        while read -r domain; do
            if [ ${#domain} -gt 4 ] && [ "$domain" != "www" ]; then
                echo "  $domain"
            fi
        done
else
    # Output collected domains
    for domain in "${!DOMAIN_MAP[@]}"; do
        echo "  $domain"
    done | sort -u
fi

# ==========================================
# 7. Completion
# ==========================================
write_output ""
write_output "$SEP"
write_output "✅ Done! Full report saved to: $(pwd)/domains.txt"
write_output "$SEP"
