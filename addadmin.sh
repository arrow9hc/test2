#!/bin/bash

# ============================================
# HARDCODED CREDENTIALS - CHANGE THESE!
# ============================================
USERNAME="adminqqq"
PASSWORD="qqq@ssw0rd123"

# Optional: Force password change on first login
FORCE_PASSWORD_CHANGE="yes"  # Set to "yes" or "no"
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}Creating administrator account...${NC}"

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User '$USERNAME' already exists!${NC}"
    exit 1
fi

# Create user with home directory
useradd -m -s /bin/bash "$USERNAME"

# Set password
echo "$USERNAME:$PASSWORD" | chpasswd

# Add to admin groups
usermod -aG root "$USERNAME"
getent group sudo &>/dev/null && usermod -aG sudo "$USERNAME"
getent group wheel &>/dev/null && usermod -aG wheel "$USERNAME"
getent group admin &>/dev/null && usermod -aG admin "$USERNAME"

# Force password change on first login
if [ "$FORCE_PASSWORD_CHANGE" = "yes" ]; then
    chage -d 0 "$USERNAME"
    echo -e "${YELLOW}User must change password on first login${NC}"
fi

# Create sudoers file for passwordless sudo (optional - uncomment if needed)
# echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME
# chmod 440 /etc/sudoers.d/$USERNAME

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Administrator account created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Username: ${YELLOW}$USERNAME${NC}"
echo -e "Password: ${YELLOW}$PASSWORD${NC}"
echo -e "Home: ${YELLOW}/home/$USERNAME${NC}"
echo -e "Groups: ${YELLOW}$(groups $USERNAME)${NC}"
echo -e "${GREEN}========================================${NC}"

# Security warning
echo -e "${RED}⚠ WARNING: Change these credentials after first login!${NC}"