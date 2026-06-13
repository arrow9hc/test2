#!/bin/bash

# Define your path patterns here (feel free to add more)
# Format: number|description|relative_path
PATTERNS=(
    "1|Copy directly to folder root|"
    "2|Copy to public_html directory|public_html"
    "3|Copy to public_html/good directory|public_html/good"
    "4|Copy to public_html/good/backup|public_html/good/backup"
    "5|Copy to www directory|www"
    "6|Copy to html directory|html"
)

# Check if ty.php exists
if [ ! -f "ty.php" ]; then
    echo "Error: ty.php not found in current directory!"
    exit 1
fi

# Get all folder names in current directory (excluding hidden folders)
folders=$(find . -maxdepth 1 -type d ! -name "." ! -name ".*" -printf "%f\n")

if [ -z "$folders" ]; then
    echo "No subfolders found in current directory."
    exit 0
fi

# Display menu
echo "Please select copy mode:"
echo "----------------------------------------"
for pattern in "${PATTERNS[@]}"; do
    IFS='|' read -r num desc path <<< "$pattern"
    echo "$num) $desc"
done
echo "----------------------------------------"
echo "0) Enter custom path manually"
read -p "Enter your choice: " mode

# Handle selection
if [ "$mode" = "0" ]; then
    read -p "Enter relative path (e.g., public_html/newfolder): " target_suffix
elif [[ "$mode" =~ ^[0-9]+$ ]]; then
    for pattern in "${PATTERNS[@]}"; do
        IFS='|' read -r num desc path <<< "$pattern"
        if [ "$num" = "$mode" ]; then
            target_suffix="$path"
            break
        fi
    done
else
    echo "Invalid option"
    exit 1
fi

# Execute copy operation
for folder in $folders; do
    if [ -n "$target_suffix" ]; then
        target_path="$folder/$target_suffix"
        mkdir -p "$target_path"
    else
        target_path="$folder"
    fi

    if cp "ty.php" "$target_path/"; then
        echo "✓ Copied to: $target_path/"
    else
        echo "✗ Failed to copy to: $target_path/"
    fi
done

echo "Operation completed."