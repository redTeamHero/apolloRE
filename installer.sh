#!/bin/bash

# -----------------------------------------
#  Pentesting Tools Auto Installer (Kali)
#  Author: ducky
# -----------------------------------------

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${GREEN}[*] Updating system...${RESET}"
sudo apt update -y && sudo apt upgrade -y

install_apt_pkg() {
    PKG=$1
    echo -e "${GREEN}[*] Installing ${PKG}...${RESET}"
    sudo apt install -y "$PKG"
    if dpkg -l | grep -q "$PKG"; then
        echo -e "${GREEN}[+] ${PKG} installed successfully.${RESET}"
    else
        echo -e "${RED}[-] Failed to install ${PKG}.${RESET}"
    fi
}

install_gem_pkg() {
    PKG=$1
    echo -e "${GREEN}[*] Installing Ruby gem: ${PKG}...${RESET}"
    sudo gem install "$PKG"
}

install_pip_pkg() {
    PKG=$1
    echo -e "${GREEN}[*] Installing Python pip package: ${PKG}...${RESET}"
    pip3 install "$PKG"
}

echo -e "${YELLOW}==============================="
echo -e " Installing Required Tools"
echo -e "===============================${RESET}"

# APT tools
install_apt_pkg "aquatone"
install_apt_pkg "sqlmap"
install_apt_pkg "nuclei"
install_apt_pkg "curl"
install_apt_pkg "perl"
install_apt_pkg "python3"
install_apt_pkg "python3-pip"
install_apt_pkg "ruby-full"

# WPScan (Ruby Gem)
install_gem_pkg "wpscan"

# Shodan (pip)
install_pip_pkg "shodan"

# JFscan (pip)
install_pip_pkg "jfscan"

echo -e "${GREEN}"
echo "=================================="
echo "[+] Installation Complete!"
echo "=================================="
echo " Tools Installed:"
echo "  • aquatone"
echo "  • shodan"
echo "  • sqlmap"
echo "  • nuclei"
echo "  • wpscan"
echo "  • jfscan"
echo "  • curl"
echo "  • perl"
echo "  • python3 + pip"
echo "=================================="
echo -e "${RESET}"

exit 0
