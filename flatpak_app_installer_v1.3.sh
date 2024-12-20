#!/bin/bash

# Flatpak App Installer v1.3
#
# Description:
# This script automates the replacement of applications installed via `apt` or `snap` with their Flatpak versions.
# It is designed for systems like Kubuntu, where managing application installations and avoiding conflicts 
# between different package sources (apt, snap, and flatpak) is crucial.
#
# Features:
# - Checks for and removes applications installed via `apt` or `snap` if they exist.
# - Replaces these applications with their corresponding Flatpak versions from the Flathub repository.
# - Ensures Flatpak is installed and Flathub is added as a repository if not already present.
# - Handles retries for failed Flatpak installations.
# - Optional flag (`--install-only-missing`) to skip installing Flatpaks for applications already installed.
# - Provides a detailed summary of actions taken (successes, failures, and skipped installations).
#
# Applications Replaced:
# - Yakuake
# - qBittorrent
# - RetroArch
# - PCSX2
# - Firefox
# - Steam
# - Kate
# - Gwenview
# - Spectacle
# - Okular
# - VLC
# - Krita
# - Grsync (Installed via apt since no Flatpak version exists)
#
# Flags:
# --install-only-missing   Skips already-installed Flatpak applications.
#
# Behavior:
# 1. Checks for Flatpak installation. Installs Flatpak if not found.
# 2. Adds Flathub repository if not already present.
# 3. Removes existing `apt` or `snap` versions of listed applications.
# 4. Installs Flatpak versions of listed applications from Flathub.
# 5. Skips Flatpak installation for already-installed apps when `--install-only-missing` is used.
# 6. Summarizes successes, failures, and skipped steps.

# Begin script logic
version="1.3"
lockfile="/tmp/flatpak_app_installer.lock"
declare -a actions_taken
declare -a failures
removed_packages=false
install_only_missing=false

# Color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
NC="\033[0m"

if [[ "$1" == "--install-only-missing" ]]; then
    install_only_missing=true
fi

if [ -f "$lockfile" ]; then
    echo -e "${RED}Script is already running. Exiting.${NC}"
    exit 1
fi

touch "$lockfile"

cleanup() {
    rm -f "$lockfile"
    echo -e "${CYAN}Cleaned up resources.${NC}"
}

trap 'cleanup; exit 1' INT TERM
trap cleanup EXIT

log_success() {
    local message="$1"
    echo -e "${GREEN}$message${NC}"
    actions_taken+=("$message")
}

log_failure() {
    local message="$1"
    echo -e "${RED}$message${NC}"
    failures+=("$message")
}

launch_in_terminal() {
    if [[ -z "$DISPLAY" ]]; then
        terminals=("konsole" "gnome-terminal" "xterm")
        for term in "${terminals[@]}"; do
            if command -v "$term" &> /dev/null; then
                echo -e "${YELLOW}Relaunching script in $term...${NC}"
                case $term in
                    "konsole")
                        "$term" --noclose -e /bin/bash -c "$0 $*"
                        ;;
                    "gnome-terminal")
                        "$term" -- bash -c "$0 $*; exec bash"
                        ;;
                    "xterm")
                        "$term" -hold -e /bin/bash -c "$0 $*"
                        ;;
                esac
                exit
            fi
        done
        echo -e "${RED}No supported terminal found. Please run this script in a terminal.${NC}"
        exit 1
    fi
}

launch_in_terminal "$@"

if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This script requires elevated privileges. Please enter your password.${NC}"
    sudo -v || { echo -e "${RED}Failed to obtain sudo privileges. Exiting.${NC}"; exit 1; }
fi

echo -e "${CYAN}Updating package list...${NC}"
sudo apt update || { echo -e "${RED}Failed to update package list. Exiting.${NC}"; exit 1; }

check_flatpak_app_installed() {
    flatpak list --app | grep -q "$1"
    return $?
}

check_apt_app_installed() {
    dpkg -s "$1" &> /dev/null
    return $?
}

remove_apt_app_if_installed() {
    local app_name="$1"
    if check_apt_app_installed "$app_name"; then
        echo -e "${YELLOW}$app_name is installed via apt. Removing it...${NC}"
        sudo apt remove --purge -y "$app_name" || {
            log_failure "Failed to remove apt version of $app_name"
            exit 1
        }
        log_success "Removed apt version of $app_name"
        removed_packages=true
    fi
}

remove_snap_app_if_installed() {
    local app_name="$1"
    if snap list | grep -q "$app_name"; then
        echo -e "${YELLOW}$app_name is installed via Snap. Removing it...${NC}"
        sudo snap remove "$app_name" || {
            log_failure "Failed to remove Snap version of $app_name"
            exit 1
        }
        log_success "Removed Snap version of $app_name"
        removed_packages=true
    fi
}

install_flatpak() {
    echo -e "${CYAN}Checking if Flatpak is installed...${NC}"
    if ! check_apt_app_installed flatpak; then
        echo -e "${YELLOW}Flatpak is not installed. Installing Flatpak...${NC}"
        sudo apt install -y flatpak || { echo -e "${RED}Failed to install Flatpak. Exiting.${NC}"; exit 1; }
        log_success "Installed Flatpak"
    else
        log_success "Flatpak was already installed"
    fi
}

add_flathub_repo() {
    echo -e "${CYAN}Adding Flathub repository if not already added...${NC}"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || {
        log_failure "Failed to add Flathub repository"
        exit 1
    }
    log_success "Added Flathub repository (if not already present)"
}

install_flatpak_with_retry() {
    local flatpak_id="$1"
    local app_display_name="$2"
    local attempts=3

    until [ $attempts -le 0 ]; do
        flatpak install -y flathub "$flatpak_id" && {
            log_success "Installed $app_display_name via Flatpak"
            return 0
        }
        echo -e "${YELLOW}Installation failed for $app_display_name. Retrying...${NC}"
        ((attempts--))
        sleep 2
    done

    log_failure "Failed to install $app_display_name after multiple attempts"
}

install_flatpak_app_if_not_installed() {
    local flatpak_id="$1"
    local apt_name="$2"
    local app_display_name="$3"

    if $install_only_missing && check_flatpak_app_installed "$flatpak_id"; then
        echo -e "${CYAN}$app_display_name is already installed. Skipping.${NC}"
        return
    fi

    echo -e "${CYAN}Checking if $app_display_name is installed...${NC}"
    
    # Remove apt and Snap versions if they exist
    remove_apt_app_if_installed "$apt_name"
    remove_snap_app_if_installed "$app_display_name"

    # Install the Flatpak version
    if ! check_flatpak_app_installed "$flatpak_id"; then
        echo -e "${YELLOW}$app_display_name is not installed via Flatpak. Installing...${NC}"
        install_flatpak_with_retry "$flatpak_id" "$app_display_name"
    else
        log_success "$app_display_name was already installed via Flatpak"
    fi
}

install_grsync_if_not_installed() {
    echo -e "${CYAN}Checking if Grsync is installed...${NC}"
    if ! check_apt_app_installed grsync; then
        echo -e "${YELLOW}Grsync is not installed. Installing via apt...${NC}"
        sudo apt install -y grsync || { log_failure "Failed to install Grsync via apt"; exit 1; }
        log_success "Installed Grsync via apt"
    else
        log_success "Grsync was already installed via apt"
    fi
}

summarize_actions() {
    echo -e "\n${CYAN}Summary of actions taken:${NC}"
    echo -e "${GREEN}Installed via Flatpak:${NC}"
    for action in "${actions_taken[@]}"; do
        if [[ "$action" == *"Installed"* ]]; then
            echo " - $action"
        fi
    done
    echo -e "${GREEN}Removed apt/Snap packages:${NC}"
    for action in "${actions_taken[@]}"; do
        if [[ "$action" == *"Removed"* ]]; then
            echo " - $action"
        fi
    done
    echo -e "${CYAN}Other actions:${NC}"
    for action in "${actions_taken[@]}"; do
        if [[ "$action" != *"Installed"* && "$action" != *"Removed"* ]]; then
            echo " - $action"
        fi
    done

    if [ ${#failures[@]} -ne 0 ]; then
        echo -e "\n${RED}Summary of failed actions:${NC}"
        for failure in "${failures[@]}"; do
            echo " - $failure"
        done
    fi
}

main() {
    install_flatpak
    add_flathub_repo

    total_steps=13
    current_step=1

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Yakuake...${NC}"
    install_flatpak_app_if_not_installed "org.kde.yakuake" "yakuake" "Yakuake"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing qBittorrent...${NC}"
    install_flatpak_app_if_not_installed "org.qbittorrent.qBittorrent" "qbittorrent" "qBittorrent"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing RetroArch...${NC}"
    install_flatpak_app_if_not_installed "org.libretro.RetroArch" "retroarch" "RetroArch"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing PCSX2...${NC}"
    install_flatpak_app_if_not_installed "net.pcsx2.PCSX2" "pcsx2" "PCSX2"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Firefox...${NC}"
    install_flatpak_app_if_not_installed "org.mozilla.firefox" "firefox" "Firefox"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Steam...${NC}"
    install_flatpak_app_if_not_installed "com.valvesoftware.Steam" "steam" "Steam"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Kate...${NC}"
    install_flatpak_app_if_not_installed "org.kde.kate" "kate" "Kate"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Gwenview...${NC}"
    install_flatpak_app_if_not_installed "org.kde.gwenview" "gwenview" "Gwenview"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Spectacle...${NC}"
    install_flatpak_app_if_not_installed "org.kde.spectacle" "spectacle" "Spectacle"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Okular...${NC}"
    install_flatpak_app_if_not_installed "org.kde.okular" "okular" "Okular"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing VLC...${NC}"
    install_flatpak_app_if_not_installed "org.videolan.VLC" "vlc" "VLC"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Krita...${NC}"
    install_flatpak_app_if_not_installed "org.kde.krita" "krita" "Krita"
    ((current_step++))

    echo -e "${CYAN}Step $current_step/$total_steps: Installing Grsync...${NC}"
    install_grsync_if_not_installed
    ((current_step++))

    if [ "$removed_packages" = true ]; then
        sudo apt autoremove -y || { log_failure "Failed to auto-remove dependencies"; exit 1; }
    fi

    summarize_actions
}

main
