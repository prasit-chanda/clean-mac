#!/bin/zsh

# Stricter error handling: exit on error, unset variable, or failed pipeline
# set -euo pipefail

# Optimize globbing and file matching for safety and flexibility
setopt nullglob extended_glob localoptions no_nomatch

# ------------------------------------------------------------------------------
# clean-mac.zsh — macOS cleanup utility
# Author   : Prasit Chanda
# Version  : 2.3.8-20250712-PW8XU
# License  : Apache-2.0
# github   : https://github.com/prasit-chanda/clean-mac.git
# Description: Cleans caches, logs, temp files, old downloads, Homebrew leftovers
# Usage: Run in Terminal with zsh. Requires: Homebrew, coreutils, osascript
# ------------------------------------------------------------------------------

# ───── Static Colors Variables ─────

# Reset
RESET=$'\e[0m'
# REGULAR Colors
BLACK=$'\e[30m'
RED=$'\e[31m' #Good
GREEN=$'\e[32m' #Good
GREY=$'\e[90m' #Good
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
MAGENTA=$'\e[35m' #Good
CYAN=$'\e[36m'
WHITE=$'\e[37m'
# BOLD Colors
BBLACK=$'\e[1;30m'
BRED=$'\e[1;31m' #Good
BGREEN=$'\e[1;32m' #Good
BGREY=$'\e[1;90m' #Good
BYELLOW=$'\e[1;33m'
BBLUE=$'\e[1;34m'
BMAGENTA=$'\e[1;35m' #Good
BCYAN=$'\e[1;36m'
BWHITE=$'\e[1;37m'

# ───── Global Variables ─────

ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface: / {print $2}')
: ${ACTIVE_IF:="No active interface"}
AUTHOR="Prasit Chanda"
CPU="$(sysctl -n machdep.cpu.brand_string), $(sysctl -n hw.physicalcpu) CPU Core"
DNS_SERVER="1.1.1.1"
DATE=$(date "+%a, %d %b %Y %I:%M:%S %p")
MAIN_DISK=$(diskutil info / | awk -F: '/Device Node/ {print $2}' | xargs)
DISK_SIZE=$(diskutil info "$MAIN_DISK" | awk -F: '/Disk Size/ {print $2}' | cut -d'(' -f1 | xargs)
TS=$(date +"%s")
LOG_FILE="clean-mac-${TS}.log"
WD=$(pwd)
LOG_PATH="${WD}/${LOG_FILE}"
if [[ "$ACTIVE_IF" != "No active interface" ]]; then
  MAC=$(ifconfig "$ACTIVE_IF" 2>/dev/null | awk '/ether/ {print $2}')
  : ${MAC:="MAC not found"}
else
  MAC="MAC not found"
fi
MEM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))" GB"
MEM_BEFORE=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//')
MEM_BEFORE_MB=$(( MEM_BEFORE * 4096 / 1024 / 1024 ))
MODEL=$(sysctl -n hw.model)
HOST=$(sysctl -n kern.hostname)
OS_BUILD=$(sw_vers -buildVersion)
OS_VERSION=$(sw_vers -productVersion)
SCRIPT_START_TIME=$(date +%s)
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ { print $4 }')
CACHES_CLEANED=0
LOG_CLEANED=0
DOWNLOADS_CLEANED=0
BREW_CLEANED=0
RAM_PURGED=0
IOS_BCK_CLEANED=0
DERIVED_COUNT=0
DEVICE_SUPPORT_COUNT=0
DOCKER_CLEANED=0
TRASH_CLEANED=0
UC_FILE_COUNT=0
UPTIME=$(uptime | cut -d ',' -f1 | xargs)
USER_EXITED=0
IOS_BACKUP_DIR="${HOME}/Library/Application Support/MobileSync/Backup"
IP=$(ipconfig getifaddr "$ACTIVE_IF" 2>/dev/null)
if [[ -z "$IP" ]]; then
  IP="IP not found"
fi
VERSION="2.3.8-20250712-PW8XU"
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
XCODE_DEVICE_SUPPORT="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"
PROTECTED_CACHES=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)

# ───── Static Text Variables ─────

AUTHOR_COPYRIGHT=" ${AUTHOR} © $(date +%Y) "
CLEANING_CACHES_HEADER="Caches"
CLEANING_CACHES_HINT="Removing temporary cache files to optimize system performance"
CLEANING_DOCKER_HEADER="Docker"
CLEANING_DOCKER_HINT="Cleaning up unused containers, images, and volumes"
CLEANING_DOWNLOADS_HEADER="Downloads"
CLEANING_DOWNLOADS_HINT="Removing outdated files from your Downloads folder"
CLEANING_FILES_HEADER="Files"
CLEANING_FILES_HINT="Clearing temporary files to free up storage space"
CLEANING_HOMEBREW_HEADER="Homebrew"
CLEANING_HOMEBREW_HINT="Tidying up Homebrew installations and leftover files"
CLEANING_IOS_HEADER="Backups"
CLEANING_IOS_HINT="Removing outdated iOS backups to save disk space"
CLEANING_LOGS_HEADER="Logs"
CLEANING_LOGS_HINT="Cleaning system and application logs"
CLEANING_MEMORY_HEADER="Memory"
CLEANING_MEMORY_HINT="Freeing up memory to help improve system responsiveness"
CLEANING_TRASH_HEADER="Trash"
CLEANING_TRASH_HINT="Emptying your Trash to permanently remove deleted files"
CLEANING_XCODE_HEADER="Xcode"
CLEANING_XCODE_HINT="Removing Xcode build artifacts and unnecessary data"
CLEANUP_MSG="Cleanup Summary"
DD_NONE="  ● No DerivedData folder found for Xcode"
DEPENDENCIES_HEADER="Dependencies"
DEPENDENCIES_NOT_MSG="Some required tools are missing. Please check your setup"
DEPENDENCIES_OK_MSG="All necessary dependencies are present and functional"
DISK_SPACE_UNCHANGED_MSG="  No change in disk usage detected"
DL_NONE="  ● Downloads folder is already clean"
DOCKER_CLEANING="Cleaning Docker containers, images, and volumes"
DOCKER_NONE="  ✖ Docker not detected. Skipped cleanup"
DOCKER_NOT_INSTALLED_MSG="Docker is not installed on this system"
DOCKER_OK="  ✓ Docker resources cleaned successfully"
DOCKER_PRUNED_MSG="Docker cleanup completed"
DOCKER_SCAN="Scanning Docker for unused containers, images, and volumes"
DOWNLOADS_CLEAN_MSG="Downloads folder is already clean"
DOWNLOADS_FILE_CLEANED_MSG="Outdated downloads removed successfully"
DS_NONE="  ● Xcode DeviceSupport folder is already clean"
FOOTER_LOG_DIR_MSG="Folder   $WD"
FOOTER_LOG_FILE_MSG="Log      $LOG_FILE"
FOOTER_SCRIPT_VERSION_MSG="Version  $VERSION"
HOMEBREW_CLEANED_MSG="Homebrew cleanup completed"
HOMEBREW_CLEAN_HEADER_MSG="Performing Homebrew cleanup"
HOMEBREW_CLEANUP_SKIPPED_MSG="Skipped Homebrew cleanup (Homebrew not found or offline)"
HOMEBREW_INFO_HEADER_MSG="Homebrew Status"
HOMEBREW_INSTALL_ATTEMPT_MSG="Attempting to install Homebrew"
HOMEBREW_INSTALL_COREUTIL_ASK_MSG="Would you like to install coreutils via Homebrew? (y/n) "
HOMEBREW_INSTALL_COREUTIL_FAIL_MSG="coreutils installation failed. Please try manually."
HOMEBREW_INSTALL_FAILED_MSG="Homebrew installation failed. Visit https://brew.sh/ for manual setup"
HOMEBREW_INSTALL_SUCCESS_MSG="Homebrew installed successfully"
HOMEBREW_INSTALLED_COREUTIL_DENIAL_MSG="coreutils not found. Manual installation may be required"
HOMEBREW_INSTALLED_COREUTIL_MSG="coreutils is already installed"
HOMEBREW_INSTALLED_MSG="Homebrew is already installed on your system"
HOMEBREW_NONE="  ✖ Unable to clean Homebrew. It may be missing or offline"
HOMEBREW_NOT_INSTALLED_COREUTIL_MSG="coreutils not installed. Please check your Homebrew setup"
HOMEBREW_NOT_INSTALLED_MSG="Homebrew is not installed"
HOMEBREW_OK="  ✓ Homebrew cleanup completed successfully"
HOMEBREW_INTERNET_CHECK="Checking internet connectivity. DNS: $DNS_SERVER\n"
HOMEBREW_INTERNET_DOWN="Internet not available. Please check your connection"
HOMEBREW_INTERNET_UP="Internet connection is active"
HOMEBREW_CLEAN_AR="Removing unnecessary packages not directly installed"
HOMEBREW_CLEAN_OV="Cleaning up old versions of Homebrew packages"
HOMEBREW_CLEAN_CACHE="Clearing contents of the Homebrew cache directory"
INTERNET_AVAILABLE="✓ Connected"
INTERNET_AVAILABLE_MSG="  ✓ Internet connection is active"
INTERNET_UNAVAILABLE="✖ Disconnected"
INTERNET_UNAVAILABLE_MSG="  ✖ No internet connection detected"
IOS_BACKUP_DIR_NONE_MSG="No iOS backup folder found"
IOS_BACKUP_FOUND_MSG="Old iOS backups located"
IOS_BACKUP_NONE_MSG="No outdated iOS backups found"
IOS_BACKUP_REMOVED_MSG="Outdated iOS backups removed"
IOS_NONE="  ● No iOS backups found"
IOS_BACKUP_NOT_DETECTED="No connected iOS devices detected"
LOG_CLEAN_MSG="Log files already clean"
LOG_FILE_CLEANED_MSG="Old log files successfully removed"
LOG_NONE="  ● No old log files to delete"
MEM_NONE="  ● No memory to free at this time"
MEM_OK="  ✓ Memory cleared successfully"
MEMORY_SPACE_UNCHANGED_MSG="No changes in memory usage detected"
NO_DOCKER_ON_SYS="Docker isn’t installed or can’t be found"
NO_FILES_TO_CLEAN_MSG="No files detected for cleanup"
NO_HOMEBREW="Homebrew is not available in the system path"
NO_IOS_DEVICE="No iOS devices are connected to the system"
NO_LOG_CLEAN="Log files are already clean"
NO_MOUNTED_VOLUME_MSG="No external volumes mounted"
NOT_ZSH_MSG="This script is optimized for Zsh. Please switch your shell."
OSASCRIPT_AVAILABLE_MSG="osascript is available"
OSASCRIPT_INSTALL_ASK_MSG="Would you like to install osascript via Homebrew? (y/n) "
OSASCRIPT_INSTALL_CANT_MSG="osascript cannot be installed automatically. Please install manually."
OSASCRIPT_INSTALL_FAILED_MSG="osascript installation failed. Manual installation is required."
OSASCRIPT_INSTALL_SKIPPED_MSG="osascript installation was skipped"
OSASCRIPT_INSTALL_SUCCESS_MSG="osascript installed successfully"
OSASCRIPT_NOT_INSTALLED_MSG="osascript is not installed on this system"
PROMPT_USER_CONSENT_APPROVAL="✓ $(whoami) confirmed. Proceeding with script execution"
PROMPT_USER_CONSENT_DENIAL="✖ $(whoami) declined. Exiting script"
PROMPT_USER_CONSENT_MSG="${BYELLOW}Would you like to proceed with the script? (y/n) "
PROMPT_VALIDATE_MSG="Please respond with 'y' or 'n'"
PURGE_CLEANED_MSG="RAM purge completed"
PURGE_NOT_AVAILABLE_MSG="The 'purge' command is not available on this system"
RAM_CLEAN="Clearing RAM to improve system performance"
RAM_PURGE_MISS="Please ensure the 'purge' command is installed and accessible"
OLD_FILE_CLEAN="Scanning Downloads folder for files older than 7 days"
OLD_LOG_CLEAN="Scanning system logs older than 7 days"
ROOT_WARNING_MSG="Running as root is not recommended. Exiting for safety"
SCRIPT_BOX_TITLE="clean-mac.zsh"
SCRIPT_DESCRIPTION="A script to clean caches, logs, downloads, and other temporary files"
SCRIPT_EXIT_MSG=" ● Press ⌃ + Z anytime to pause or exit"
SCRIPT_INTERNET_MSG=" ● Internet connectivity is required"
SCRIPT_START_MSG="Starting clean-mac: optimizing your system now"
SCRIPT_SUDO_FAIL_MSG="✖ Sudo access not granted. Exiting for safety"
SCRIPT_SUDO_MSG=" ● This script may request your administrator password"
SCRIPT_TERMINAL_MSG=" ● Please run this in the macOS Terminal"
SUM_TEXT_CACHE="  ✓ User caches cleaned "
SUM_TEXT_LOG="  ✓ Old log files cleaned "
SUM_TEXT_TRASH="  ✓ Trash cleaned "
SUM_TEXT_DWL="  ✓ Old Downloads cleaned "
SUM_TEXT_IOS_BCK="  ✓ iOS device backups cleaned "
SUM_TEXT_ISO_DD="  ✓ Xcode DerivedData cleaned "
SUM_TEXT_ISO_DS="  ✓ Xcode DeviceSupport cleaned "
SUMMARY_SUB_TITLE_1_MSG="System Overview"
SUMMARY_SUB_TITLE_2_MSG="Cleanup Actions"
SUMMARY_SUB_TITLE_3_MSG="Post-Cleanup Report"
SYSTEM_DETAILS_HEADER="System Information"
SYSTEM_TRASH_CLEAN_MSG="System Trash is already empty"
SYSTEM_TRASH_CLEANED_MSG="System Trash emptied successfully"
SYSTEM_TRASH_NOT_ACCESSIBLE_MSG="Unable to access System Trash"
TRASH_CLEAN_MSG="User Trash has been emptied"
TRASH_FILE_CLEANED_MSG="Deleted files from Trash"
TRASH_NONE="  ● Trash is already empty"
TRASH_USER_CLEANED_MSG="Trash has been cleared"
TRASH_VOLUME_CLEAN_MSG="Volume Trash is already empty"
TRASH_VOLUME_CLEANED_MSG="Volume Trash has been cleaned"
UNSUPPORTED_OS_MSG="✖ This script is only compatible with macOS"
USER_CACHE_CLEAN_MSG="User cache is already clean"
USER_CACHE_CLEANED_MSG="User cache cleared successfully"
USER_CACHE_NONE="  ● No user cache files found"
XCODE_DEVICE_CLEANED_MSG="Xcode device data removed"
XCODE_DEVICE_NONE_MSG="No Xcode device data found"
XCODE_DERIVED_CLEANED_MSG="Xcode DerivedData folder cleaned"
XCODE_DERIVED_NONE_MSG="Xcode DerivedData folder already clean"

# ───── Custom Methods ─────

# This function asks the user for consent to continue
ask_user_consent() {
  while true; do
    print -nP "$PROMPT_USER_CONSENT_MSG"
    read answer
    echo ""
    case "$answer" in
      [yY][eE][sS]|[yY])
        echo "${BGREEN}$PROMPT_USER_CONSENT_APPROVAL${RESET}"
        echo ""
        break
        ;;
      [nN][oO]|[nN])
        echo "${BRED}$PROMPT_USER_CONSENT_DENIAL${RESET}"
        echo ""
        USER_EXITED=1   
        print_summary
        exit 1
        ;;
      *)
        echo "${BYELLOW}$PROMPT_VALIDATE_MSG${RESET}"
        ;;
    esac
  done
}

# This function checks execution dependencies (Homebrew, coreutils, osascript)
check_dependencies() {
  local dependencies_status=0
  fancy_text_header "$DEPENDENCIES_HEADER"
  echo ""
  # --- Homebrew Check ---
  if ! command -v brew >/dev/null 2>&1; then
    echo "${RED}$HOMEBREW_NOT_INSTALLED_MSG${RESET}"
    echo "${YELLOW}$HOMEBREW_INSTALL_ATTEMPT_MSG${RESET}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
    if command -v brew >/dev/null 2>&1; then
      echo "${GREEN}$HOMEBREW_INSTALL_SUCCESS_MSG${RESET}"
    else
      echo "${RED}$HOMEBREW_INSTALL_FAILED_MSG${RESET}"
      dependencies_status=1
    fi
  else
    echo "${GREY}$HOMEBREW_INSTALLED_MSG${RESET}"
  fi
  # --- Coreutils Check ---
  if ! brew ls --versions coreutils >/dev/null 2>&1; then
    echo "${RED}$HOMEBREW_NOT_INSTALLED_COREUTIL_MSG${RESET}"
    print -nP "${YELLOW}$HOMEBREW_INSTALL_COREUTIL_ASK_MSG${RESET}"
    read coreutil_answer
    case "$coreutil_answer" in
      [yY][eE][sS]|[yY])
        brew install coreutils >/dev/null 2>&1 && \
        echo "${GREEN}$HOMEBREW_INSTALLED_COREUTIL_MSG${RESET}" || {
          echo "${RED}$HOMEBREW_INSTALL_COREUTIL_FAIL_MSG${RESET}"
          dependencies_status=1
        }
        ;;
      [nN][oO]|[nN])
        echo "${YELLOW}$HOMEBREW_INSTALLED_COREUTIL_DENIAL_MSG${RESET}"
        dependencies_status=1
        ;;
      *)
        echo "${YELLOW}$PROMPT_VALIDATE_MSG${RESET}"
        ;;
    esac
  else
    echo "${GREY}$HOMEBREW_INSTALLED_COREUTIL_MSG${RESET}"
  fi
  # --- osascript Check (macOS-only) ---
  if ! command -v osascript >/dev/null 2>&1; then
    echo "${RED}$OSASCRIPT_NOT_INSTALLED_MSG${RESET}"
    if brew info osascript >/dev/null 2>&1; then
      print -nP "${YELLOW}$OSASCRIPT_INSTALL_ASK_MSG${RESET}"
      read osascript_answer
      case "$osascript_answer" in
        [yY][eE][sS]|[yY])
          brew install osascript >/dev/null 2>&1 && \
          echo "${GREEN}$OSASCRIPT_INSTALL_SUCCESS_MSG${RESET}" || {
            echo "${RED}$OSASCRIPT_INSTALL_FAILED_MSG${RESET}"
            dependencies_status=1
          }
          ;;
        [nN][oO]|[nN])
          echo "${YELLOW}$OSASCRIPT_INSTALL_SKIPPED_MSG${RESET}"
          dependencies_status=1
          ;;
        *)
          echo "${YELLOW}$PROMPT_VALIDATE_MSG${RESET}"
          ;;
      esac
    else
      echo "${YELLOW}$OSASCRIPT_INSTALL_CANT_MSG${RESET}"
      dependencies_status=1
    fi
  else
    echo "${GREY}$OSASCRIPT_AVAILABLE_MSG${RESET}"
  fi
  sleep 10
  # --- Final Result ---
  echo ""
  if [[ $dependencies_status -eq 0 ]]; then
    echo "${BGREEN}$DEPENDENCIES_OK_MSG${RESET}"
  else
    echo "${BRED}$DEPENDENCIES_NOT_MSG${RESET}"
  fi
  echo ""
}

# This function checks if the user has an internet connection
# This uses ping to a reliable DNS server
check_internet() {
  local timeout=2
  if ping -c 1 -W $timeout "$DNS_SERVER" >/dev/null 2>&1; then
    echo "${GREEN}$INTERNET_AVAILABLE_MSG${RESET}"
    return 0
  else
    echo "${RED}$INTERNET_UNAVAILABLE_MSG${RESET}"
    return 1
  fi
}

# This functions checks Runtime Environment
check_runtime_environment(){
  # Check if running in zsh console
  if [[ -z "$ZSH_VERSION" ]]; then
    echo ""
    echo "${RED}$NOT_ZSH_MSG${RESET}" >&2
    echo ""
    exit 1
  fi
  # Check if running in macOS
  if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "${RED}$UNSUPPORTED_OS_MSG${RESET}" >&2
    echo ""
    exit 1
  fi
  # Warn if running as root (not recommended)
  if [[ "$EUID" -eq 0 ]]; then
    echo ""
    echo "${RED}$ROOT_WARNING_MSG${RESET}"  >&2
    echo ""
    exit 1
  fi
}

# This function clean temporary files older than 3 days 
clean_all_temp_dirs() {
  fancy_text_header "$CLEANING_FILES_HEADER"
  print_hints "$CLEANING_FILES_HINT"
  clean_temp_files "/tmp" "system temporary directory"
  clean_temp_files "/var/tmp" "variable temporary directory"
  clean_temp_files "$HOME/Library/Caches/TemporaryItems" "user temporary items"
  echo ""
}

# This function cleans Docker stuffs
clean_docker() {
  fancy_text_header "$CLEANING_DOCKER_HEADER"
  print_hints "$CLEANING_DOCKER_HINT"
  echo "${MAGENTA}$DOCKER_SCAN${RESET}"
  if command -v docker >/dev/null 2>&1; then
    echo "${GREY}$DOCKER_CLEANING${RESET}"
    docker system prune -af --volumes >/dev/null 2>&1
    echo "${BGREEN}${DOCKER_PRUNED_MSG}${RESET}"
    DOCKER_CLEANED=1
  else
    echo "${GREY}$NO_DOCKER_ON_SYS${RESET}"
    echo "${BRED}${DOCKER_NOT_INSTALLED_MSG}${RESET}"
    DOCKER_CLEANED=0
  fi
  echo ""
}

# This function cleans iOS backup
clean_ios_backups() {
  fancy_text_header "$CLEANING_IOS_HEADER"
  print_hints "$CLEANING_IOS_HINT"
  local backup_count
  echo "${MAGENTA}Scanning: $IOS_BACKUP_DIR${RESET}"
  if [[ -d "$IOS_BACKUP_DIR" ]]; then
    backup_count=$(find "$IOS_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
    if (( backup_count > 0 )); then
      echo "${GREY}${IOS_BACKUP_FOUND_MSG} $backup_count iOS device backup(s)${RESET}"
      sudo rm -rf "$IOS_BACKUP_DIR"/*
      echo "${BGREEN}${IOS_BACKUP_REMOVED_MSG}${RESET}"
      IOS_BCK_CLEANED=$backup_count
    else
      echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
      echo "${BYELLOW}${IOS_BACKUP_NONE_MSG}${RESET}"
      IOS_BCK_CLEANED=0
    fi
  else
    echo "${GREY}$IOS_BACKUP_NOT_DETECTED${RESET}"
    echo "${BRED}${IOS_BACKUP_DIR_NONE_MSG}${RESET}"
    IOS_BCK_CLEANED=0
  fi
  echo ""
}

# This function cleans Hombrew 
clean_homebrew() {
  fancy_text_header "$CLEANING_HOMEBREW_HEADER"
  print_hints "$CLEANING_HOMEBREW_HINT"
  if command -v brew >/dev/null 2>&1; then
    print_brew_info
    # Check internet connectivity via DNS ping
    echo "${MAGENTA}$HOMEBREW_INTERNET_CHECK${RESET}"
    if ping -c1 -W2 "$DNS_SERVER" >/dev/null 2>&1; then 
      echo "${BCYAN}${HOMEBREW_CLEAN_HEADER_MSG}${RESET}"
      echo "" 
      echo "${GREY}$HOMEBREW_INTERNET_UP${RESET}"     
      brew autoremove
      echo "${GREY}$HOMEBREW_CLEAN_AR${RESET}"
      brew cleanup -s
      echo "${GREY}$HOMEBREW_CLEAN_OV${RESET}"
      rm -rf "$(brew --cache)"/*
      echo "${GREY}$HOMEBREW_CLEAN_CACHE${RESET}"
      echo "${BGREEN}${HOMEBREW_CLEANED_MSG}${RESET}"
      BREW_CLEANED=1       
    else
      echo "${GREY}$HOMEBREW_INTERNET_DOWN${RESET}"   
      echo "${BYELLOW}${HOMEBREW_CLEANUP_SKIPPED_MSG}${RESET}"
      BREW_CLEANED=0
    fi
  else
    echo "${GREY}$NO_HOMEBREW${RESET}" 
    echo "${BRED}${HOMEBREW_NOT_INSTALLED_MSG}${RESET}"
    BREW_CLEANED=0
  fi  
  echo ""
}

# This function cleans RAM
clean_memory_ram() {
  echo "${MAGENTA}$RAM_CLEAN${RESET}"
  if command -v purge >/dev/null 2>&1; then
    sudo purge >/dev/null 2>&1 && sleep 1
    echo "${GREY}$RAM_CLEAN${RESET}"
    echo "${BGREEN}${PURGE_CLEANED_MSG}${RESET}"
    RAM_PURGED=1
  else
    echo "${GREY}$RAM_PURGE_MISS${RESET}"
    echo "${BRED}${PURGE_NOT_AVAILABLE_MSG}${RESET}"
    RAM_PURGED=0
  fi
}

# This fuction clean old downloads older than 7 days
clean_old_downloads() {
  local old_files
  fancy_text_header "$CLEANING_DOWNLOADS_HEADER"
  print_hints "$CLEANING_DOWNLOADS_HINT"
  # Use find to collect files older than 7 days
  echo "${MAGENTA}$OLD_FILE_CLEAN${RESET}"
  old_files=("${(@f)$(command find "$HOME/Downloads" -type f -mtime +7 2>/dev/null)}")
  # Remove empty entries
  old_files=(${old_files:#""})
  if (( ${#old_files[@]} == 0 )); then
    echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    echo "${BYELLOW}${DOWNLOADS_CLEAN_MSG}${RESET}"
    DOWNLOADS_CLEANED=0
  else
    for file in "${old_files[@]}"; do
      echo "${GREY}Cleaning File: $file${RESET}"
      command rm -f -- "$file"
    done
    DOWNLOADS_CLEANED=${#old_files[@]}
    echo "${BGREEN}${DOWNLOADS_CLEANED} ${DOWNLOADS_FILE_CLEANED_MSG}${RESET}"
  fi
  echo ""
}

# This function cleans old System Logs older than 7 days
clean_old_logs() {
  local old_logs
  fancy_text_header "$CLEANING_LOGS_HEADER"
  print_hints "$CLEANING_LOGS_HINT"
  echo "${MAGENTA}$OLD_LOG_CLEAN${RESET}"
  old_logs=("${(@f)$(sudo find /private/var/log -type f -mtime +7 2>/dev/null)}")
  # Remove void entries (if any)
  old_logs=(${old_logs:#""})
  if (( ${#old_logs[@]} == 0 )); then
    echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    echo "${BYELLOW}$NO_LOG_CLEAN${RESET}"
    LOG_CLEANED=0
  else
    for file in "${old_logs[@]}"; do
      echo "${GREY}Cleaning LOG File: $file${RESET}"
      sudo rm -f -- "$file"
    done
    echo "${BGREEN}${#old_logs[@]} $LOG_FILE_CLEANED_MSG${RESET}"
    LOG_CLEANED=${#old_logs[@]}
  fi
  echo ""
}

# Function to safely clean temp files in a directory older than 3 days
clean_temp_files() {
  local dir="$1"
  local description="$2"
  echo "${MAGENTA}Scanning: $description for files older than 3 days${RESET}"
  # Count files before deletion
  local files_count=$(sudo find "$dir" -type f -mtime +3 | wc -l)
  if [[ $files_count -gt 0 ]]; then
    # Use -delete for efficiency
    echo "${GREY}Cleaning: 3 days old files from $description${RESET}"
    sudo find "$dir" -type f -mtime +3 -delete 2>/dev/null
    echo "${BGREEN}Cleaned $files_count old files from $description${RESET}"
  else
    echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    echo "${BYELLOW}No old files in $description${RESET}"
  fi
}

# This function cleans Trash for user, root, and all mounted volumes
clean_trash() {
  local trash_files system_trash="/private/var/root/.Trash"
  local trashes_dir found_volume=0
  fancy_text_header "$CLEANING_TRASH_HEADER"
  print_hints "$CLEANING_TRASH_HINT"
  # Clean User Trash
  echo "${MAGENTA}Scanning: User Trash${RESET}"
  trash_files=("${(@f)$(ls -1 "$HOME/.Trash" 2>/dev/null)}")
  trash_files=(${trash_files:#""})
  if (( ${#trash_files[@]} == 0 )); then
    echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    echo "${BYELLOW}$TRASH_CLEAN_MSG${RESET}"
  else
    for file in "${trash_files[@]}"; do
      echo "${GREY}Cleaning File: $file${RESET}"
    done
    osascript -e 'tell application "Finder" to empty trash' &>/dev/null
    echo "${BGREEN}${#trash_files[@]} $TRASH_FILE_CLEANED_MSG${RESET}"
    echo "${BGREEN}$TRASH_USER_CLEANED_MSG${RESET}"
    TRASH_CLEANED=${#trash_files[@]}
  fi
  # Clean System Trash (Root)
  echo "${MAGENTA}Scanning: System Trash (Root)${RESET}"
  if [[ -d "$system_trash" ]]; then
    if [[ -z "$(sudo ls -A "$system_trash" 2>/dev/null)" ]]; then
      echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
      echo "${BYELLOW}$SYSTEM_TRASH_CLEAN_MSG${RESET}"
    else
      sudo rm -rf "$system_trash"/* &>/dev/null
      echo "${BGREEN}$SYSTEM_TRASH_CLEANED_MSG${RESET}"
      TRASH_CLEANED=1
    fi
  else
    echo "${GREY}Nice try, but the system says no${RESET}"
    echo "${BYELLOW}$SYSTEM_TRASH_NOT_ACCESSIBLE_MSG${RESET}"
  fi
  # Clean Volume Trashes
  echo "${MAGENTA}Scanning: Volume Trashes${RESET}"
  for volume in /Volumes/*; do
    trashes_dir="$volume/.Trashes"
    if [[ -d "$trashes_dir" ]]; then
      found_volume=1
      if [[ -z "$(sudo ls -A "$trashes_dir" 2>/dev/null)" ]]; then
        echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
        echo "${BYELLOW}$TRASH_VOLUME_CLEAN_MSG $volume${RESET}"
      else
        sudo rm -rf "$trashes_dir"/* &>/dev/null
        echo "${BGREEN}$TRASH_VOLUME_CLEANED_MSG $volume${RESET}"
        TRASH_CLEANED=1
      fi
    fi
  done
  # No Mounted Volume Found
  if (( found_volume == 0 )); then
    echo "${GREY}$NO_MOUNTED_VOLUME_MSG${RESET}"
    echo "${BRED}$NO_MOUNTED_VOLUME_MSG${RESET}"
  fi
  echo ""
}

# This function cleans user caches
clean_user_caches() { 
  local cache_dir=~/Library/Caches
  local dir dirname
  local custom_caches=(
    "$HOME/Library/Application Support/Code/Cache"
    "$HOME/Library/Application Support/Slack/Service Worker/CacheStorage"
    "$HOME/Library/Application Support/Google/Chrome/Default/Cache"
    "$HOME/Library/Safari/Favicon Cache"
    "$HOME/Library/WebKit"
  )
  fancy_text_header "$CLEANING_CACHES_HEADER"
  print_hints "$CLEANING_CACHES_HINT"
  # Main User Cache: ~/Library/Caches
  echo "${MAGENTA}Scanning: $cache_dir${RESET}"
  find "$cache_dir" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    dirname=$(basename "$dir")
    # Skip protected cache folders
    if [[ " ${PROTECTED_CACHES[*]} " == *" $dirname "* ]]; then
      echo "${YELLOW}Skipping Protected Cache Folder: $dir${RESET}"
    else
      echo "${GREY}Cleaning User Cache: $dir${RESET}"
      rm -rf "${dir:?}/"* 2>/dev/null || echo "${RED}Warning: Failed to clean $dir${RESET}"
      ((UC_FILE_COUNT++))
    fi
  done
  # Sandboxed App Cachees: ~/Library/Containers
  containers_cache_root="$HOME/Library/Containers"
  echo "${MAGENTA}Scanning: $containers_cache_root${RESET}"
  if [[ -d "$containers_cache_root" ]]; then
    find "$containers_cache_root" -type d -path "*/Data/Library/Caches" | while read -r sandbox_cache; do
      echo "${GREY}Cleaning Sandboxed Cache: $sandbox_cache${RESET}"
      rm -rf "${sandbox_cache:?}/"* 2>/dev/null || echo "${RED}Warning: Failed to clean $sandbox_cache${RESET}"
      ((UC_FILE_COUNT++))
    done
  fi
  # Custom Caches: Specific paths
  for dir in "${custom_caches[@]}"; do
    echo "${MAGENTA}Scanning: $dir${RESET}"
    if [[ -d $dir ]]; then
      echo "${GREY}Cleaning Custom Cache: $dir${RESET}"
      rm -rf "${dir:?}/"* 2>/dev/null || echo "${RED}Warning: Failed to clean $dir${RESET}"
      ((UC_FILE_COUNT++))
    else
      echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    fi
  done
  # Print summary of cleaned user caches
  if (( UC_FILE_COUNT > 0 )); then
    echo "${BGREEN}$USER_CACHE_CLEANED_MSG ($UC_FILE_COUNT files cleaned)${RESET}"
    CACHES_CLEANED=$UC_FILE_COUNT
  else
    echo "${BYELLOW}$USER_CACHE_CLEAN_MSG${RESET}"
  fi
  echo ""
}

# This function cleans Xcode DerivedData and device support
clean_xcode_cruft() {
  fancy_text_header "$CLEANING_XCODE_HEADER"
  print_hints "$CLEANING_XCODE_HINT"
  # Clean Xcode DerivedData
  echo "${MAGENTA}Scanning: $XCODE_DERIVED_DATA${RESET}"
  if [[ -d "$XCODE_DERIVED_DATA" ]]; then
    DERIVED_COUNT=$(find "$XCODE_DERIVED_DATA" -mindepth 1 -maxdepth 1 | wc -l | xargs)
    if [[ $DERIVED_COUNT -gt 0 ]]; then
      sudo rm -rf "$XCODE_DERIVED_DATA"/*
      echo "${BGREEN}${XCODE_DERIVED_CLEANED_MSG} ($DERIVED_COUNT items).${RESET}"
    else
      DERIVED_COUNT=0
      echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
      echo "${BYELLOW}${XCODE_DERIVED_NONE_MSG}${RESET}"
    fi
  else
    DERIVED_COUNT=0
    echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
    echo "${BYELLOW}${XCODE_DERIVED_NONE_MSG}${RESET}"
  fi
  # Clean Xcode DeviceSupport
  echo "${MAGENTA}Scanning: $XCODE_DEVICE_SUPPORT${RESET}"
  if [[ -d "$XCODE_DEVICE_SUPPORT" ]]; then
    DEVICE_SUPPORT_COUNT=$(find "$XCODE_DEVICE_SUPPORT" -mindepth 1 -maxdepth 1 | wc -l | xargs)
    if [[ $DEVICE_SUPPORT_COUNT -gt 0 ]]; then
      sudo rm -rf "$XCODE_DEVICE_SUPPORT"/*
      echo "${BGREEN}${XCODE_DEVICE_CLEANED_MSG} ($DEVICE_SUPPORT_COUNT items).${RESET}"
    else
      DEVICE_SUPPORT_COUNT=0
      echo "${GREY}$NO_FILES_TO_CLEAN_MSG${RESET}"
      echo "${BYELLOW}${XCODE_DEVICE_NONE_MSG}${RESET}"
    fi
  else
    DEVICE_SUPPORT_COUNT=0
    echo "${GREY}$NO_IOS_DEVICE${RESET}"
    echo "${BRED}${XCODE_DEVICE_NONE_MSG}${RESET}"
  fi
  echo ""
}

# This function prints a fancy line divider
fancy_line_divider() {
  # Total width of the divider
  local width=${1:-50}
  # Character or emoji to repeat
  local char="${2:-━}"
  local line=""
  while [[ ${(L)#line} -lt $width ]]; do
    line+="$char"
  done
  #print -Pn "%F{GREY}"
  print -r -- "$line"
}

# This function creates a fancy text box with centered content
fancy_title_box() {
  local content="$1"
  local padding=1
  local IFS=$'\n'
  local lines=($content)
  local max_length=0
  # Find the longest line for box width calculation
  for line in "${lines[@]}"; do
    (( ${#line} > max_length )) && max_length=${#line}
  done
  printf "${BGREY}"
  local box_width=$((max_length + padding * 2))
  local border_top="╔$(printf '═%.0s' $(seq 1 $box_width))╗"
  local border_bottom="╚$(printf '═%.0s' $(seq 1 $box_width))╝"
  echo "$border_top"
  for line in "${lines[@]}"; do
    local total_space=$((box_width - ${#line}))
    local left_space=$((total_space / 1))
    local right_space=$((total_space - left_space))
    # Print each line centered in the box
    printf "%*s%s%*s\n" "$left_space" "" "$line" "$right_space" ""
  done
  echo "$border_bottom"
  printf "${RESET}"
}

# This function prints a centered header with grey padding
fancy_text_header() {
  local label="$1"
  local total_width=25
  local padding_width=$(( (total_width - ${#label} - 2) / 2 ))
  printf "${BGREY}"
  printf '%*s' "$padding_width" '' | tr ' ' '='
  printf " %s " "$label"
  printf '%*s\n' "$padding_width" '' | tr ' ' '='
  printf "${RESET}"
}

# Generates a random alphanumeric string like "A1B2C-3D4E-F5G6-H7I8-J9K0"
generate_random_string() {
  local chars=( {A..Z} {1..9} 0 )  # 0 placed after 1-9 for correct digit range
  local num_chars=${#chars[@]}
  local str=""
  if (( num_chars == 0 )); then
    echo "✖ Error: character array is empty!" >&2
    return 1
  fi
  for ((i = 1; i <= 25; i++)); do
    str+="${chars[RANDOM % num_chars]}"
    if (( i % 5 == 0 && i != 25 )); then
      str+="-"
    fi
  done
  echo "$str"
}

# This function shows macOS version name
get_macos_name() {
  local darwin_version macos_name
  darwin_version=$(sysctl -n kern.osrelease | cut -d. -f1)
  case $darwin_version in
    16) macos_name="Sierra" ;;
    17) macos_name="High Sierra" ;;
    18) macos_name="Mojave" ;;
    19) macos_name="Catalina" ;;
    20) macos_name="Big Sur" ;;
    21) macos_name="Monterey" ;;
    22) macos_name="Ventura" ;;
    23) macos_name="Sonoma" ;;
    24) macos_name="Sequoia" ;;
    25) macos_name="Sequoia (Update)" ;;
    26) macos_name="Tahoe" ;;
    *)  macos_name="Unknown macOS version" ;;
  esac
  echo "macOS $macos_name"
}

# This function gets free disk space in bytes (for root volume)
get_free_space() {
  df -k / | tail -1 | awk '{print $4 * 1024}'
}

# This function gets simple uptime (returns "X days", "Y hours", etc.)
get_uptime() {
  local uptime_part
  uptime_part=$(uptime | awk -F'up ' '{split($2,a,","); print a[1]}' | sed -E '
    s/^ *([0-9]+) days?.*/\1 days/;
    s/^ *([0-9]+):[0-9]+.*/\1 hours/;
    s/^ *([0-9]+) mins?.*/\1 minutes/;
    s/^\s*$/Just booted/
  ')
  echo "$uptime_part"
}

# This function converts bytes to human-readable format
human_readable_space() {
  local bytes=$1
  if (( bytes < 1024 )); then
    echo "${bytes} Bytes"
  elif (( bytes < 1024 * 1024 )); then
    echo "$(( bytes / 1024 )) Kilobyte(KB)"
  elif (( bytes < 1024 * 1024 * 1024 )); then
    echo "$(( bytes / 1024 / 1024 )) Megabyte(MB)"
  else
    echo "$(( bytes / 1024 / 1024 / 1024 )) Gigabyte(GB)"
  fi
}

# This function prints Homebrew information
print_brew_info() {
  echo "${BCYAN}$HOMEBREW_INFO_HEADER_MSG${RESET}"
  local b=$(brew --version | head -n1)
  local p=${commands[brew]}
  local r=$(brew --repository)
  local c=$(brew --cellar)
  local u=$(git -C "$r" log -1 --format="%cd" --date=short 2>/dev/null); [[ -z "$u" ]] && u="no clue"
  local j1=$(HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 --installed); local f=$(jq '.formulae | length' <<<"$j1"); local ck=$(jq '.casks | length' <<<"$j1")
  local j2=$(brew outdated --json=v2); local of=$(jq '.formulae | length' <<<"$j2"); local oc=$(jq '.casks | length' <<<"$j2")
  local duo=$(du -sh "$c" 2>/dev/null | awk '{print $1}'); [[ -z "$duo" ]] && duo="??"
  local d=; brew doctor --quiet &>/dev/null && d="OK" || d="Doctor says brew is sick"
  local srv=$(brew services list 2>/dev/null | grep started | wc -l | tr -d ' '); [[ -z "$srv" ]] && srv=0
  echo "${GREY}"
  echo "Path                  : $p"
  echo "Version               : $b"
  echo "Installed Formulae    : $f"
  echo "Installed Casks       : $ck"
  echo "Outdated Formulae     : $of"
  echo "Outdated Casks        : $oc"
  echo "Last Update           : $u"
  echo "Disk Usage            : $duo"
  echo "Doctor Status         : $d"
  echo "Services Running      : $srv"
  echo "${RESET}"
}

# This function prints hints about execution
print_hints() {
  # split message into words
  local words=(${(z)1})  
  local i=1
  echo -ne "\n${BLUE}ⓘ "
  for word in $words; do
    print -n -P "$word "
    (( i++ % 20 == 0 )) && print
  done
  print -P "%f\n"
}

# This function prints script info as header
print_script_info(){
  fancy_title_box "$SCRIPT_BOX_TITLE"
  echo "\n${BCYAN}$SCRIPT_DESCRIPTION${RESET}\n"
  echo "${GREY}$DATE${RESET}"
  echo "${GREY}SCAN ID $(generate_random_string)${RESET}"
  echo "${GREY}Version $VERSION${RESET}"
  echo "${GREY}Author  $AUTHOR${RESET}"
  echo "\n${BCYAN}$SCRIPT_START_MSG${RESET}\n"
  echo "${GREY}$SCRIPT_SUDO_MSG${RESET}"
  echo "${GREY}$SCRIPT_TERMINAL_MSG${RESET}"
  echo "${GREY}$SCRIPT_INTERNET_MSG${RESET}"
  echo "${RED}$SCRIPT_EXIT_MSG${RESET}\n"
}

# This function prints clean-up summary at the end of the script
print_summary() {
  # Only show Results section if not exited by user
  if [[ "$USER_EXITED" -ne 1 ]]; then
    echo ""
    fancy_title_box "$CLEANUP_MSG"
    echo -e "\n${BCYAN}$SUMMARY_SUB_TITLE_1_MSG${RESET}${GREY}\n"
    echo "  Model   $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    echo "  CPU     $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
    echo "  RAM     $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 )) GB"
    echo "  macOS   $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "  Uptime  $(get_uptime)"
    echo -e "${RESET}\n${BCYAN}$SUMMARY_SUB_TITLE_2_MSG${RESET}\n"
    check_internet
    # Status checks
    [[ $CACHES_CLEANED -gt 0 ]] && echo "${GREEN}$SUM_TEXT_CACHE($CACHES_CLEANED folders)${RESET}" || echo "${GREY}$USER_CACHE_NONE${RESET}"
    [[ $LOG_CLEANED -gt 0 ]] && echo "${GREEN}$SUM_TEXT_LOG($LOG_CLEANED files)${RESET}" || echo "${GREY}$LOG_NONE${RESET}"
    [[ $TRASH_CLEANED -gt 0 ]] && echo "${GREEN}$SUM_TEXT_TRASH($TRASH_CLEANED files)${RESET}" || echo "${GREY}$TRASH_NONE${RESET}"
    [[ $DOWNLOADS_CLEANED -gt 0 ]] && echo "${GREEN}$SUM_TEXT_DWL($DOWNLOADS_CLEANED files)${RESET}" || echo "${GREY}$DL_NONE${RESET}"
    [[ $BREW_CLEANED -eq 1 ]] && echo "${GREEN}$HOMEBREW_OK${RESET}" || echo "${RED}$HOMEBREW_NONE${RESET}"
    [[ $RAM_PURGED -eq 1 ]] && echo "${GREEN}$MEM_OK${RESET}" || echo "${GREY}$MEM_NONE${RESET}"
    [[ ${IOS_BCK_CLEANED:-0} -gt 0 ]] && echo "${GREEN}$SUM_TEXT_IOS_BCK($IOS_BCK_CLEANED)${RESET}" || echo "${GREY}$IOS_NONE${RESET}"
    [[ ${DERIVED_COUNT:-0} -gt 0 ]] && echo "${GREEN}$SUM_TEXT_ISO_DD($DERIVED_COUNT items)${RESET}" || echo "${GREY}$DD_NONE${RESET}"
    [[ ${DEVICE_SUPPORT_COUNT:-0} -gt 0 ]] && echo "${GREEN}$SUM_TEXT_ISO_DS($DEVICE_SUPPORT_COUNT items)${RESET}" || echo "${GREY}$DS_NONE${RESET}"
    [[ ${DOCKER_CLEANED:-0} -eq 1 ]] && echo "${GREEN}$DOCKER_OK${RESET}" || echo "${RED}$DOCKER_NONE${RESET}"
    # Disk and Memory Calculations
    space_after=$(get_free_space)
    space_freed=$(( space_after - space_before ))
    MEM_AFTER_MB=$(( $(vm_stat | awk '/Pages free/ {print $3}' | sed 's/\\.//') * 4096 / 1024 / 1024 ))
    MEM_FREED_MB_RAW=$(echo "$MEM_AFTER_MB - $MEM_BEFORE_MB" | bc -l)
    MEM_FREED_MB=$(echo "$MEM_FREED_MB_RAW" | awk '{printf "%.3f", ($1 == int($1)) ? $1 : int($1)+1 + ($1-int($1))}')
    echo -e "\n${BCYAN}$SUMMARY_SUB_TITLE_3_MSG${RESET}\n"
    (( MEM_FREED_MB > 0 )) && echo "${GREEN}  RAM Cleaned $MEM_FREED_MB Megabyte(MB)${RESET}" || echo "${GREY}$MEMORY_SPACE_UNCHANGED_MSG${RESET}"
    (( space_freed > 0 )) && echo "${GREEN}  Disk Cleaned $(human_readable_space $space_freed)${RESET}" || echo "${GREY}$DISK_SPACE_UNCHANGED_MSG${RESET}"
    # Script execution time
    SCRIPT_END_TIME=$(date +%s)
    if [[ -n "$SCRIPT_START_TIME" ]]; then
      local elapsed=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
      printf "${GREEN}  Execution Time %02d:%02d:%02d${RESET}\n" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
    fi
    echo ""
  fi
  # Footer info
  echo "${GREY}$FOOTER_LOG_DIR_MSG"
  echo "$FOOTER_LOG_FILE_MSG"
  echo "$FOOTER_SCRIPT_VERSION_MSG${RESET}"
  echo ""
  fancy_text_header "$AUTHOR_COPYRIGHT"
  echo ""
  # Finalize and closing writing to log file
  sync
  exec 1>&- 2>&-
  command -v open >/dev/null 2>&1 && open -a "Console" "${LOG_PATH}" 2>/dev/null || echo "${RED}Could not open log in Console.${RESET}"
}

# This function prints System Details
print_system_details(){
  fancy_text_header "$SYSTEM_DETAILS_HEADER"
  echo "${GREY}"
  echo "Model     $MODEL"
  echo "Host      $HOST"
  echo "CPU       $CPU"
  echo "RAM       $MEM"
  echo "Storage   $DISK_SIZE"
  echo "Serial    $SERIAL"
  echo "OS        $(get_macos_name)"
  echo "Version   $OS_VERSION"
  echo "Build     $OS_BUILD"
  echo "Uptime    $UPTIME"
  if [[ "$ACTIVE_IF" == "No active interface" ]]; then
    echo "Internet  ${RED}$INTERNET_UNAVAILABLE${RESET}${GREEN}"
  else
    echo "Internet  $INTERNET_AVAILABLE"
  fi
  echo "NetIface  $ACTIVE_IF"
  echo "IP        $IP"
  echo "MAC       $MAC"
  echo "${RESET}"
}

# This function shows RAM summary
print_ram_info() {
  fancy_text_header "$CLEANING_MEMORY_HEADER"
  print_hints "$CLEANING_MEMORY_HINT"
  # macOS page size in bytes
  local pagesize=4096
  local to_mb=' / 1024 / 1024'
  # Total physical RAM
  local total_bytes=$(sysctl -n hw.memsize)
  local total_gb=$((total_bytes / 1024 / 1024 / 1024))
  # Extract page counts from vm_stat
  local vm_output=$(vm_stat)
  local pages_free=$(echo "$vm_output" | awk '/Pages free/ {gsub("\\.",""); print $3}')
  local pages_active=$(echo "$vm_output" | awk '/Pages active/ {gsub("\\.",""); print $3}')
  local pages_inactive=$(echo "$vm_output" | awk '/Pages inactive/ {gsub("\\.",""); print $3}')
  local pages_wired=$(echo "$vm_output" | awk '/Pages wired down/ {gsub("\\.",""); print $4}')
  local pages_compressed=$(echo "$vm_output" | awk '/Pages occupied by compressor/ {gsub("\\.",""); print $5}')
  # Convert to MB
  local free_mb=$((pages_free * pagesize / 1024 / 1024))
  local active_mb=$((pages_active * pagesize / 1024 / 1024))
  local inactive_mb=$((pages_inactive * pagesize / 1024 / 1024))
  local wired_mb=$((pages_wired * pagesize / 1024 / 1024))
  local compressed_mb=$((pages_compressed * pagesize / 1024 / 1024))
  # Memory Pressure
  local pressure=$(memory_pressure | awk '/System-wide memory free/ {getline; print $NF}')
  # Print the summary
  echo "${GREY}"
  echo "Total RAM  : ${total_gb} GB"
  echo "Free RAM   : ${free_mb} MB"
  echo "Active     : ${active_mb} MB"
  echo "Inactive   : ${inactive_mb} MB"
  echo "Wired      : ${wired_mb} MB"
  echo "Compressed : ${compressed_mb} MB"
  echo "Memory     : ${pressure} FREE"
  echo "${RESET}"
  clean_memory_ram
}

# This function prompts for sudo and handle interruption
prompt_sudo(){
  sudo -v
  if ! sudo -v; then
    echo ""
    echo "${RED}$SCRIPT_SUDO_FAIL_MSG${RESET}"
    echo ""
    USER_EXITED=1
    print_summary
    exit 1
  else
    # Keep sudo alive in the background to avoid password prompts
    while true; do sudo -n true; sleep 1200; kill -0 "$$" || exit; done 2>/dev/null &
  fi
}

# This functions ensures all background jobs are killed on exit
terminate_script(){
  trap 'kill $(jobs -p) 2>/dev/null' EXIT
  exit 0
}

# This functions creates log file and redirect output
write_log(){
  exec > >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' > "${LOG_FILE}")) \
    2> >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "${LOG_FILE}") >&2)
}

# ───── Execution STARTS ─────

# Check Runtime Environment
check_runtime_environment 

# Script Starts
clear

# Measure free disk space before cleanup
space_before=$(get_free_space)

# Create log file and redirect output
write_log

# Ensure the script is run with sudo privileges
trap cleanup EXIT INT TERM

# Print the script Title in a fancy box with Details
print_script_info

# Print System Details
print_system_details

# Check for required dependencies before proceeding
check_dependencies

# Ask user for consent to continue (can exit here)
ask_user_consent

# Prompt for sudo and handle interruption
prompt_sudo

# Step 1: Clear User Caches
clean_user_caches

# Step 2: Clean iOS device Backups
clean_ios_backups

# Step 3: Clean Xcode DerivedData and device support
clean_xcode_cruft

# Step 4: Clean Docker system (if installed)
clean_docker

# Step 5: Clean old System Logs older than 7 days
clean_old_logs

# Step 6: Empty Trash/Bin for user, root, and all mounted volumes
clean_trash

# Step 7: Clean Temporary Files older than 3 days
clean_all_temp_dirs

# Step 8: Clean old Downloads
clean_old_downloads

# Step 9: Homebrew Cleanup
clean_homebrew

# Step 10: Purge inactive memory (if possible)
print_ram_info

# Print the cleanup summary at the end
print_summary

# Ensure all background jobs are killed on exit
terminate_script

# ───── Execution ENDS ─────