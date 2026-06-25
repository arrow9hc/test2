#!/bin/bash

# ============================================
# Linux Web Server Domain Configuration Scanner
# Function: Auto-detect Nginx/Apache and extract all bound domains
# Output: domains.txt in current directory
# ============================================

OUTPUT_FILE="./domains.txt"

# Clear or create output file
> "$OUTPUT_FILE"

# Define separators
SEP="=========================================="
LINE="------------------------------------------"

# Write function: output to both screen and file
write_output() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

write_output "Web Server Domain Configuration Report"
write_output "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
write_output "Hostname: $(hostname)"
write_output "$SEP"

# ==========================================
# 1. Detect server types
# ==========================================
write_output ""
write_output "[1] Detecting Web Server Types"
write_output "$LINE"

HAS_NGINX=false
HAS_APACHE=false

if command -v nginx &> /dev/null || pgrep -x "nginx" &> /dev/null; then
    HAS_NGINX=true
    write_output "✓ Nginx detected"
    NGINX_CONF=$(nginx -t 2>&1 | grep -oP '(?<=configuration file ).*?(?=:)') || NGINX_CONF="/etc/nginx/nginx.conf"
    write_output "  Main config: $NGINX_CONF"
else
    write_output "✗ Nginx not detected"
fi

if command -v httpd &> /dev/null || command -v apache2 &> /dev/null || pgrep -x "httpd" &> /dev/null || pgrep -x "apache2" &> /dev/null; then
    HAS_APACHE=true
    write_output "✓ Apache detected"
    if command -v httpd &> /dev/null; then
        APACHE_CMD="httpd"
    else
        APACHE_CMD="apache2"
    fi
    write_output "  Command: $APACHE_CMD"
else
    write_output "✗ Apache not detected"
fi

if [ "$HAS_NGINX" = false ] && [ "$HAS_APACHE" = false ]; then
    write_output ""
    write_output "⚠ Warning: No Web server detected (Nginx/Apache)"
    write_output "Possible: Service not installed, not running, or using other server (Caddy, Tomcat, etc.)"
fi

write_output "$SEP"

# ==========================================
# 2. Query Nginx domains
# ==========================================
if [ "$HAS_NGINX" = true ]; then
    write_output ""
    write_output "[2] Nginx Bound Domains (server_name)"
    write_output "$LINE"
    
    NGINX_DIRS=("/etc/nginx" "/usr/local/nginx/conf")
    FOUND_NGINX=false
    
    for dir in "${NGINX_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            write_output "▶ Scanning: $dir"
            grep -r "server_name" "$dir" 2>/dev/null | grep -v "#" | grep -v "server_name\s*;" | while read -r line; do
                domains=$(echo "$line" | grep -oE 'server_name\s+[^;]+' | sed 's/server_name\s*//' | tr -s ' ')
                if [ -n "$domains" ] && [ "$domains" != "_" ] && [ "$domains" != " " ]; then
                    echo "  $domains  (file: $(echo "$line" | cut -d: -f1))"
                    FOUND_NGINX=true
                fi
            done
        fi
    done
    
    if [ "$FOUND_NGINX" = false ]; then
        write_output "  No server_name found (possibly using default config)"
    fi
    
    write_output ""
    write_output "▶ Full config server_name (nginx -T):"
    if nginx -T 2>/dev/null | grep -q "server_name"; then
        nginx -T 2>/dev/null | grep "server_name" | grep -v "#" | grep -v "server_name\s*;" | while read -r line; do
            domains=$(echo "$line" | grep -oE 'server_name\s+[^;]+' | sed 's/server_name\s*//' | tr -s ' ')
            if [ -n "$domains" ] && [ "$domains" != "_" ] && [ "$domains" != " " ]; then
                echo "  $domains"
            fi
        done
    else
        write_output "  Cannot execute nginx -T (root permission may be required)"
    fi
fi

# ==========================================
# 3. Query Apache domains
# ==========================================
if [ "$HAS_APACHE" = true ]; then
    write_output ""
    write_output "[3] Apache Bound Domains (ServerName / ServerAlias)"
    write_output "$LINE"
    
    write_output "▶ Virtual Host List (apachectl -S / httpd -S):"
    if command -v apachectl &> /dev/null; then
        apachectl -S 2>/dev/null | grep -E "(ServerRoot|port|namevhost|server name)" | while read -r line; do
            echo "  $line"
        done
    elif command -v httpd &> /dev/null; then
        httpd -S 2>/dev/null | grep -E "(ServerRoot|port|namevhost|server name)" | while read -r line; do
            echo "  $line"
        done
    else
        write_output "  Cannot execute httpd -S (root permission may be required)"
    fi
    
    write_output ""
    write_output "▶ Searching config files for ServerName/ServerAlias:"
    APACHE_DIRS=("/etc/httpd" "/etc/apache2" "/usr/local/apache2/conf")
    FOUND_APACHE=false
    
    for dir in "${APACHE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            write_output "  Scanning: $dir"
            grep -r -E "(ServerName|ServerAlias)" "$dir" 2>/dev/null | grep -v "#" | while read -r line; do
                domain=$(echo "$line" | grep -oE '(ServerName|ServerAlias)\s+[^[:space:]]+' | sed 's/ServerName\s*//;s/ServerAlias\s*//' | tr -s ' ')
                if [ -n "$domain" ] && [ "$domain" != "*" ] && [ "$domain" != "_default_" ]; then
                    echo "    $domain  (file: $(echo "$line" | cut -d: -f1))"
                    FOUND_APACHE=true
                fi
            done
        fi
    done
    
    if [ "$FOUND_APACHE" = false ]; then
        write_output "  No ServerName/ServerAlias found"
    fi
fi

# ==========================================
# 4. Other possible locations
# ==========================================
write_output ""
write_output "[4] Other Possible Domain Config Locations"
write_output "$LINE"

for dir in /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/httpd/sites-enabled /etc/apache2/sites-enabled; do
    if [ -d "$dir" ]; then
        write_output "▶ Directory: $dir"
        ls -la "$dir" 2>/dev/null | grep -E "\.conf$|\.conf\.default$" | while read -r line; do
            echo "  $line"
        done
    fi
done

# ==========================================
# 5. Port listening status
# ==========================================
write_output ""
write_output "[5] Port Listening Status (Auxiliary Info)"
write_output "$LINE"
write_output "▶ Common Web ports (80/443/8080/8443) listening status:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|8080|8443)" | grep -E "nginx|httpd|apache" | while read -r line; do
    echo "  $line"
done

if ! command -v netstat &> /dev/null; then
    ss -tlnp 2>/dev/null | grep -E ":(80|443|8080|8443)" | grep -E "nginx|httpd|apache" | while read -r line; do
        echo "  $line"
    done
fi

# ==========================================
# 6. Summary / Deduplication
# ==========================================
write_output ""
write_output "$SEP"
write_output "[6] Summary: Extracted Domains (Deduplicated)"
write_output "$LINE"

grep -oE '\b([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b' "$OUTPUT_FILE" 2>/dev/null | sort -u | grep -v "^[0-9]" | while read -r domain; do
    if [ ${#domain} -gt 3 ] && [ "$domain" != "localhost" ] && [ "$domain" != "example.com" ]; then
        echo "  $domain"
    fi
done | sort -u

# ==========================================
# 7. Completion message
# ==========================================
write_output ""
write_output "$SEP"
write_output "✅ Done! Full report saved to: $(pwd)/domains.txt"
write_output "Hint: If the list is empty, check if web services are running and virtual hosts are configured"
write_output "$SEP"