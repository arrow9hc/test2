#!/bin/bash

# ============================================
# Simple Domain Extractor - Direct output
# ============================================

OUTPUT_FILE="./domains.txt"
TEMP_FILE="/tmp/domain_scan_$$.tmp"

# Clear files
> "$OUTPUT_FILE"
> "$TEMP_FILE"

echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Domain Scanner Report" | tee -a "$OUTPUT_FILE"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
echo "Hostname: $(hostname)" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ==========================================
# 1. Extract from Nginx config files
# ==========================================
echo "[1] Extracting from Nginx config files..." | tee -a "$OUTPUT_FILE"
echo "----------------------------------------" | tee -a "$OUTPUT_FILE"

# Search all nginx config files
find /etc/nginx -type f -name "*.conf" -o -name "*.conf.save" 2>/dev/null | while read -r conf; do
    # Extract server_name lines
    grep -h "server_name" "$conf" 2>/dev/null | grep -v "^#" | while read -r line; do
        # Extract domains (skip -- and _)
        echo "$line" | sed 's/.*server_name\s*//' | sed 's/;.*//' | tr -s ' ' | tr '\n' ' ' | while read -r domains; do
            for domain in $domains; do
                # Filter: only keep valid domains (contain at least one dot, not starting with -- or _)
                if [[ "$domain" == *"."* ]] && [ "$domain" != "--" ] && [ "$domain" != "_" ] && [ ${#domain} -gt 3 ]; then
                    # Clean domain (remove trailing .)
                    domain=$(echo "$domain" | sed 's/\.$//')
                    echo "$domain" >> "$TEMP_FILE"
                    echo "  Found: $domain (in: $(basename "$conf"))" | tee -a "$OUTPUT_FILE"
                fi
            done
        done
    done
done

# ==========================================
# 2. Extract from nginx -T (full config)
# ==========================================
echo "" | tee -a "$OUTPUT_FILE"
echo "[2] Extracting from nginx -T..." | tee -a "$OUTPUT_FILE"
echo "----------------------------------------" | tee -a "$OUTPUT_FILE"

if command -v nginx &> /dev/null; then
    nginx -T 2>/dev/null | grep "server_name" | grep -v "^#" | while read -r line; do
        echo "$line" | sed 's/.*server_name\s*//' | sed 's/;.*//' | tr -s ' ' | while read -r domain; do
            if [[ "$domain" == *"."* ]] && [ "$domain" != "--" ] && [ "$domain" != "_" ] && [ ${#domain} -gt 3 ]; then
                domain=$(echo "$domain" | sed 's/\.$//')
                echo "$domain" >> "$TEMP_FILE"
                echo "  Found: $domain" | tee -a "$OUTPUT_FILE"
            fi
        done
    done
fi

# ==========================================
# 3. Extract from Apache config files
# ==========================================
echo "" | tee -a "$OUTPUT_FILE"
echo "[3] Extracting from Apache config files..." | tee -a "$OUTPUT_FILE"
echo "----------------------------------------" | tee -a "$OUTPUT_FILE"

find /etc/apache2 /etc/httpd -type f -name "*.conf" 2>/dev/null | while read -r conf; do
    grep -E "^(ServerName|ServerAlias)" "$conf" 2>/dev/null | grep -v "^#" | while read -r line; do
        domain=$(echo "$line" | awk '{print $2}')
        if [[ "$domain" == *"."* ]] && [ "$domain" != "localhost" ] && [ ${#domain} -gt 3 ]; then
            domain=$(echo "$domain" | sed 's/\.$//')
            echo "$domain" >> "$TEMP_FILE"
            echo "  Found: $domain (in: $(basename "$conf"))" | tee -a "$OUTPUT_FILE"
        fi
    done
done

# ==========================================
# 4. Extract from apachectl -S
# ==========================================
echo "" | tee -a "$OUTPUT_FILE"
echo "[4] Extracting from apachectl -S..." | tee -a "$OUTPUT_FILE"
echo "----------------------------------------" | tee -a "$OUTPUT_FILE"

if command -v apachectl &> /dev/null; then
    apachectl -S 2>/dev/null | grep "namevhost" | while read -r line; do
        domain=$(echo "$line" | sed 's/.*namevhost\s*//' | awk '{print $1}')
        if [[ "$domain" == *"."* ]] && [ ${#domain} -gt 3 ]; then
            domain=$(echo "$domain" | sed 's/\.$//')
            echo "$domain" >> "$TEMP_FILE"
            echo "  Found: $domain" | tee -a "$OUTPUT_FILE"
        fi
    done
fi

# ==========================================
# 5. Summary - Deduplicate and output
# ==========================================
echo "" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "[5] FINAL DOMAIN LIST (Deduplicated)" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"

# Sort and deduplicate, then display and save
if [ -s "$TEMP_FILE" ]; then
    sort -u "$TEMP_FILE" | while read -r domain; do
        # Additional filter: skip common false positives
        if [ "$domain" != "nginx.conf" ] && [ "$domain" != "apache2.conf" ] && [ "$domain" != "localhost" ] && [ "$domain" != "www" ] && [ ${#domain} -gt 4 ]; then
            echo "  $domain" | tee -a "$OUTPUT_FILE"
        fi
    done
else
    echo "  No domains found!" | tee -a "$OUTPUT_FILE"
fi

# ==========================================
# 6. Clean up and finish
# ==========================================
echo "" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "✅ Done! Results saved to: $(pwd)/$OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "Total unique domains found: $(sort -u "$TEMP_FILE" 2>/dev/null | wc -l)" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"

rm -f "$TEMP_FILE"
