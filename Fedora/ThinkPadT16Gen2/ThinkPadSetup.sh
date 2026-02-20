#!/bin/bash
# "Things To Do!" script for a fresh Fedora Workstation installation



# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Funtion to echo colored text
color_echo() {
    local color="$1"
    local text="$2"
    case "$color" in
        "red")     echo -e "\033[0;31m$text\033[0m" ;;
        "green")   echo -e "\033[0;32m$text\033[0m" ;;
        "yellow")  echo -e "\033[1;33m$text\033[0m" ;;
        "blue")    echo -e "\033[0;34m$text\033[0m" ;;
        *)         echo "$text" ;;
    esac
}

# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_FILE="/var/log/fedora_things_to_do.log"
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
        color_echo "red" "ERROR: $message"
        exit $exit_code
    fi
}

# Function to prompt for reboot
prompt_reboot() {
    sudo -u $ACTUAL_USER bash -c 'read -p "It is time to reboot the machine. Would you like to do it now? (y/n): " choice; [[ $choice == [yY] ]]'
    if [ $? -eq 0 ]; then
        color_echo "green" "Rebooting..."
        reboot
    else
        color_echo "red" "Reboot canceled."
    fi
}

# Function to backup configuration files
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        handle_error "Failed to backup $file"
        color_echo "green" "Backed up $file"
    fi
}

echo "";
echo "╔═════════════════════════════════════════════════════════════════════════════╗";
echo "║                                                                             ║";
echo "║   ░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░▀█▀░█▀█░▀█▀░▀█▀░█▀█░█▀█░   ║";
echo "║   ░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░░█░░█▀█░░█░░░█░░█░█░█░█░   ║";
echo "║   ░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀░   ║";
echo "║   ░░░░░░░░░░░░▀█▀░█░█░▀█▀░█▀█░█▀▀░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀█░█░░░░░░░░░░░░░░   ║";
echo "║   ░░░░░░░░░░░░░█░░█▀█░░█░░█░█░█░█░▀▀█░░░░█░░█░█░░░█░█░█░█░▀░░░░░░░░░░░░░░   ║";
echo "║   ░░░░░░░░░░░░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀░░░░░░░░░░░░░░   ║";
echo "║                                                                             ║";
echo "╚═════════════════════════════════════════════════════════════════════════════╝";
echo "";
echo "This script automates \"Things To Do!\" steps after a fresh Fedora Workstation installation"
echo "ver. 25.08 / 100 Stars Edition"
echo ""
echo "Don't run this script if you didn't build it yourself or don't know what it does."
echo ""
read -p "Press Enter to continue or CTRL+C to cancel..."

# System Upgrade
color_echo "blue" "Performing system upgrade... This may take a while..."
dnf upgrade -y


# System Configuration
# Set the system hostname to uniquely identify the machine on the network
color_echo "yellow" "Setting hostname..."
hostnamectl set-hostname ThinkPadEma

# Optimize DNF package manager for faster downloads and efficient updates
color_echo "yellow" "Configuring DNF Package Manager..."
backup_file "/etc/dnf/dnf.conf"
dnf -y install dnf-plugins-core

# Enable and configure automatic system updates to enhance security and stability
color_echo "yellow" "Enabling DNF autoupdate..."
dnf install dnf-automatic -y
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

# Replace Fedora Flatpak Repo with Flathub for better package management and apps stability
color_echo "yellow" "Replacing Fedora Flatpak Repo with Flathub..."
dnf install -y flatpak
flatpak remote-delete fedora --force || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak repair
flatpak update

# Check and apply firmware updates to improve hardware compatibility and performance
color_echo "yellow" "Checking for firmware updates..."
fwupdmgr refresh --force
fwupdmgr get-updates
fwupdmgr update -y

# Enable RPM Fusion repositories to access additional software packages and codecs
color_echo "yellow" "Enabling RPM Fusion repositories..."
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf update @core -y

# Install multimedia codecs to enhance multimedia capabilities
color_echo "yellow" "Installing multimedia codecs..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y
dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
dnf update @sound-and-video -y

# Install Hardware Accelerated Codecs for AMD GPUs. This improves video playback and encoding performance on systems with AMD graphics.
color_echo "yellow" "Installing AMD Hardware Accelerated Codecs..."
dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y
dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y

# Install virtualization tools to enable virtual machines and containerization
color_echo "yellow" "Installing virtualization tools..."
dnf install -y @virtualization


# App Installation
# Install essential applications
color_echo "yellow" "Installing essential applications..."
dnf install -y btop inxi fastfetch unzip unrar git wget curl
color_echo "green" "Essential applications installed successfully."

# Install Internet & Communication applications
color_echo "yellow" "Installing Brave..."
dnf install -y dnf-plugins-core
if command -v dnf4 &>/dev/null; then
  dnf4 config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
else
  dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
fi
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf install -y brave-browser
color_echo "green" "Brave installed successfully."
color_echo "yellow" "Installing LibreWolf..."
curl -fsSL https://repo.librewolf.net/librewolf.repo | pkexec tee /etc/yum.repos.d/librewolf.repo
dnf install -y librewolf
color_echo "green" "LibreWolf installed successfully."
color_echo "yellow" "Installing Betterbird..."
flatpak install -y flathub eu.betterbird.Betterbird
color_echo "green" "Betterbird installed successfully."
color_echo "yellow" "Installing Telegram Desktop..."
dnf install -y telegram-desktop
color_echo "green" "Telegram Desktop installed successfully."

# Install Coding and DevOps applications
color_echo "yellow" "Installing Visual Studio Code..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf check-update
dnf install -y code
color_echo "green" "Visual Studio Code installed successfully."

# Install Media & Graphics applications
color_echo "yellow" "Installing VLC..."
dnf install -y vlc
color_echo "green" "VLC installed successfully."
color_echo "yellow" "Installing OBS Studio..."
dnf install -y obs-studio
color_echo "green" "OBS Studio installed successfully."

# Install Remote Networking applications
color_echo "yellow" "Installing RustDesk..."
flatpak install -y flathub com.rustdesk.RustDesk
color_echo "green" "RustDesk installed successfully."

# Install File Sharing & Download applications
color_echo "yellow" "Installing qBittorrent..."
dnf install -y qbittorrent
color_echo "green" "qBittorrent installed successfully."

# Install System Tools applications
color_echo "yellow" "Installing Gear Lever..."
flatpak install -y flathub it.mijorus.gearlever
color_echo "green" "Gear Lever installed successfully."


# Customization


# Custom user-defined commands
# Custom user-defined commands
color_echo "yellow" "Disabling NetworkManager-wait-online"
systemctl disable NetworkManager-wait-online.service

color_echo "yellow" "Remove Brave Bloat"
bash <(curl -s https://raw.githubusercontent.com/MulesGaming/brave-debloatinator/main/brave-bullshitinator-linux-install.sh)

color_echo "yellow" "Removing KDE-PIM group"
dnf group remove kde-pim -y

color_echo "yellow" "Removing KDE apps"
dnf remove kamoso mediawriter elisa-player kcharselect kcolorchooser dragon kmines kmahjongg kpat kmouth kolourpaint neochat firefox qrca khelpcenter plasma-welcome -y --no-autoremove

color_echo "yellow" "Installing necessary apps"

# Install Termius
flatpak install -y flathub com.termius.Termius

# Install EasyEffect
dnf install easyeffects -y

# Install ZapZap
flatpak install -y flathub com.rtosta.zapzap

# Install Moonlight
flatpak install -y flathub com.moonlight_stream.Moonlight

# Install Distrobox and DistroShelf
dnf install distrobox -y
flatpak install -y com.ranfdev.DistroShelf

# Install LocalSend
flatpak install -y flathub org.localsend.localsend_app

# Install GetEduroam
flatpak install -y flathub app.eduroam.geteduroam

# Install Planify
flatpak install -y flathub io.github.alainm23.planify

# Install WareHouse
flatpak install -y flathub io.github.flattool.Warehouse

# Install Calibre
dnf install calibre -y

# Install Ente Auth
flatpak install -y flathub io.ente.auth

# Install Pomodorolm
flatpak install -y flathub org.jousse.vincent.Pomodorolm




# Before finishing, ensure we're in a safe directory
cd /tmp || cd $ACTUAL_HOME || cd /

# Finish
echo "";
echo "╔═════════════════════════════════════════════════════════════════════════╗";
echo "║                                                                         ║";
echo "║   ░█░█░█▀▀░█░░░█▀▀░█▀█░█▄█░█▀▀░░░▀█▀░█▀█░░░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░█░   ║";
echo "║   ░█▄█░█▀▀░█░░░█░░░█░█░█░█░█▀▀░░░░█░░█░█░░░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░▀░   ║";
echo "║   ░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░▀░░▀▀▀░░░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░▀░   ║";
echo "║                                                                         ║";
echo "╚═════════════════════════════════════════════════════════════════════════╝";
echo "";
color_echo "green" "All steps completed. Enjoy!"
echo -e "\e[31m======================================================================
ATTENZIONE: INSTALLAZIONI MANUALI RICHIESTE
======================================================================
DA FARE PRE REBOOT!!!!
Per completare la configurazione del sistema, è necessario installare 
le seguenti applicazioni tramite GearLever. 

Per favore, recati sui rispettivi repository GitHub ufficiali, scarica
l'ultima release in formato AppImage e importala in GearLever:

  1. Vesktop 
     (dal GitHub ufficiale di Vencord/Vesktop)

  2. Pear Desktop / YouTube Music 
     (dal GitHub ufficiale del progetto)

  3. Obsidian 
     (dal GitHub ufficiale di Obsidian)

Una volta scaricati i file, apri GearLever e trascinali all'interno 
per integrarli comodamente nel menu delle applicazioni.
        
QUESTO POST REBOOT!!!!
- Aggiustare tutte le impostazioni Plasma
- Aggiustare gli speaker con il profilo EasyEffect del T14G4 (preso da ArchWiki)
======================================================================\e[0m"

# Prompt for reboot
prompt_reboot
