#!/bin/bash
# "Things To Do!" script for a fresh Debian installation

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Check if running on Debian
if ! grep -qi "debian" /etc/os-release; then
    echo "Error: This script is designed for Debian-based systems only"
    exit 1
fi

# Check for required packages
for pkg in apt-get dpkg systemctl gpg; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "Error: Required package '$pkg' is not installed"
        exit 1
    fi
done

# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_FILE="/var/log/debian_things_to_do.log"
INITIAL_DIR=$(pwd)

# Function to generate timestamps
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Function to log messages
log_message() {
    local message="$1"
    echo "$(get_timestamp) - $message" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    local exit_code=$?
    local message="$1"
    if [ $exit_code -ne 0 ]; then
        log_message "ERROR: $message"
        exit $exit_code
    fi
}

# Function to prompt for reboot
prompt_reboot() {
    sudo -u $ACTUAL_USER bash -c 'read -p "It is time to reboot the machine. Would you like to do it now? (y/n): " choice; [[ $choice == [yY] ]]'
    if [ $? -eq 0 ]; then
        log_message "Rebooting..."
        reboot
    else
        log_message "Reboot canceled."
    fi
}

# Function to backup configuration files
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        handle_error "Failed to backup $file"
        log_message "Backed up $file"
    fi
}

echo "";
echo "+======================================================+";
echo "|                                                      |";
echo "|    ░░░░░░░░░░░█▀▄░█▀▀░█▀▄░▀█▀░█▀█░█▀█░░░░░░░░░░░░    |";
echo "|    ░░░░░░░░░░░█░█░█▀▀░█▀▄░░█░░█▀█░█░█░░░░░░░░░░░░    |";
echo "|    ░░░░░░░░░░░▀▀░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░░░░░░░░░░░░    |";
echo "|    ░▀█▀░█░█░▀█▀░█▀█░█▀▀░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀█░█    |";
echo "|    ░░█░░█▀█░░█░░█░█░█░█░▀▀█░░░░█░░█░█░░░█░█░█░█░▀    |";
echo "|    ░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀    |";
echo "|                                                      |";
echo "+======================================================+";
echo "";
echo "This script automates \"Things To Do!\" steps after a fresh Debian installation"
echo "ver. 0.1.25.03"
echo ""
echo "Don't run this script if you didn't build it yourself or don't know what it does."
echo ""
read -p "Press Enter to continue or CTRL+C to cancel..."

# System Upgrade
log_message "Performing system upgrade... This may take a while..."
apt-get update
apt-get upgrade -y


# System Configuration
# Optimize APT package manager for faster downloads and efficient updates
log_message "Configuring APT Package Manager..."
backup_file "/etc/apt/apt.conf.d/00aptitude"
echo 'Acquire::http::Pipeline-Depth "10";' | tee -a /etc/apt/apt.conf.d/00aptitude > /dev/null
echo 'Acquire::http::MaxConnections "10";' | tee -a /etc/apt/apt.conf.d/00aptitude > /dev/null
apt-get install -y apt-transport-https ca-certificates software-properties-common

# Enable and configure automatic system updates to enhance security and stability
log_message "Enabling APT autoupdate..."
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
systemctl enable --now unattended-upgrades

# Add Flathub Repo to improve package management and apps stability
log_message "Adding Flathub Repo..."
apt-get install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak repair
flatpak update

# Enable non-free and contrib repositories to access additional software packages and codecs
log_message "Enabling multimedia repositories..."
apt-get install -y software-properties-common
add-apt-repository -y non-free
add-apt-repository -y contrib
apt-get update

# Install multimedia codecs to enhance multimedia capabilities
log_message "Installing multimedia codecs..."
apt-get install -y ffmpeg
apt-get install -y ubuntu-restricted-extras

# Install Hardware Accelerated Codecs for AMD GPUs. This improves video playback and encoding performance on systems with AMD graphics.
log_message "Installing AMD Hardware Accelerated Codecs..."
apt-get install -y mesa-va-drivers
apt-get install -y mesa-vdpau-drivers


# App Installation
# Install essential applications
log_message "Installing essential applications..."
apt-get install -y btop fastfetch unzip unrar git wget curl
log_message "Essential applications installed successfully."

# Install Coding and DevOps applications
log_message "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update
apt-get install -y code
log_message "Visual Studio Code installed successfully."
log_message "Installing Docker..."
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
systemctl enable --now containerd
groupadd docker
usermod -aG docker $ACTUAL_USER
rm -rf $ACTUAL_HOME/.docker
echo "Docker installed successfully. Please log out and back in for the group changes to take effect."
log_message "Docker installed successfully."
# Note: Docker group changes will take effect after logging out and back in


# Customization


# Custom user-defined commands
# Custom user-defined commands
echo "Created with ❤️ for Open Source"


# Before finishing, ensure we're in a safe directory
cd /tmp || cd $ACTUAL_HOME || cd /

# Finish
echo "";
echo "+========================================================================+";
echo "|                                                                        |";
echo "|    ░█░█░█▀▀░█░░░█▀▀░█▀█░█▄█░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀▀░█▀▄░▀█▀░█▀█░█▀█    |";
echo "|    ░█▄█░█▀▀░█░░░█░░░█░█░█░█░█▀▀░░░░█░░█░█░░░█░█░█▀▀░█▀▄░░█░░█▀█░█░█    |";
echo "|    ░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀    |";
echo "|                                                                        |";
echo "+========================================================================+";
echo "";
log_message "All steps completed. Enjoy!"

# Prompt for reboot
prompt_reboot
