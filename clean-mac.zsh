#!/bin/zsh

# ------------------------------------------------------------------------------
# Mac Cleanup Script
# Author: Prasit Chanda
# Platform: macOS
# Version: 1.3.6
# Description: Safely cleans unused system/user cache, logs, temp files,
#              empties trash, clears Homebrew leftovers, and reports space freed
# Last Updated: 2025-06-24
# ------------------------------------------------------------------------------

# ───── Colors Variables ─────
# Use standard, high-contrast ANSI codes for best visibility on both dark and light backgrounds
GREEN=$'\033[0;32m'    # Bright Green - Success
YELLOW=$'\033[0;33m'   # Bright Yellow - Warning/Skip
RED=$'\033[0;31m'      # Bright Red - Error/Failure
BLUE=$'\033[0;97m'     # Bright Blue - Info/Action
CYAN=$'\033[0;36m'     # Bright Cyan - General Info
RESET=$'\033[0m'       # Reset all attributes

# ───── Global Variables ─────
# Version info
VER="1.3.6-20250626FSDI"
# Date info
DATE=$(date "+%a, %d %b %Y %H:%M:%S %p")
# Timestamp info
TS=$(date +"%Y%m%d%H%M%S")
# Log file info
LF="clean-mac-${TS}.log"
# Working directory info
WD=$PWD
# Log file info
LOGFILE="${WD}/${LF}"
# Author info (dynamic)
AUTHOR="Prasit Chanda"
# OS Name and Version info
OS_NAME=$(sw_vers -productName)
OS_VERSION=$(sw_vers -productVersion)
OS_BUILD=$(sw_vers -buildVersion)
# Hardware Info
MODEL=$(sysctl -n hw.model)
CPU=$(sysctl -n machdep.cpu.brand_string)
MEM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))" GB"
# Serial Number info
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ { print $4 }')
# Get Uptime info
UPTIME=$(uptime | cut -d ',' -f1 | xargs)
# Get main disk info
MAIN_DISK=$(diskutil info / | awk -F: '/Device Node/ {print $2}' | xargs)
DISK_SIZE=$(diskutil info "$MAIN_DISK" | awk -F: '/Disk Size/ {print $2}' | head -n 1 | xargs)
# Fallback if info not found
[[ -z "$DISK_SIZE" ]] && DISK_SIZE="Unknown"
# Get the first active interface
ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface: / {print $2}')
# Get IP address
IP=$(ipconfig getifaddr "$ACTIVE_IF" 2>/dev/null)
# Get MAC address
MAC=$(ifconfig "$ACTIVE_IF" 2>/dev/null | awk '/ether/ {print $2}')
# Get SSID if it's a Wi-Fi interface
if [[ "$ACTIVE_IF" == en* ]]; then
  SSID_INFO=$(networksetup -getairportnetwork "$ACTIVE_IF" 2>&1)
  if [[ "$SSID_INFO" == *"You cannot"* || "$SSID_INFO" == *"not a Wi-Fi interface"* ]]; then
    SSID="No Wi-Fi on $ACTIVE_IF"
  else
    SSID=$(echo "$SSID_INFO" | cut -d ':' -f2- | xargs)
  fi
else
  SSID="(Not a network interface)"
fi
# Get memory usage before cleanup
MEM_BEFORE=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//')
MEM_BEFORE_MB=$(( MEM_BEFORE * 4096 / 1024 / 1024 ))
# List of protected cache folders
protected_caches=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)
# iOS device backup directory
IOS_BACKUP_DIR="${HOME}/Library/Application Support/MobileSync/Backup"
# Xcode directories
# DerivedData and DeviceSupport directories
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
XCODE_DEVICE_SUPPORT="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"

# ───── Custom Methods ─────
# Custom Text Box
print_box() {
  local content="$1"
  local padding=2
  local IFS=$'\n'
  local lines=($content)
  local max_length=0
  # Find the longest line
  for line in "${lines[@]}"; do
    (( ${#line} > max_length )) && max_length=${#line}
  done
  local box_width=$((max_length + padding * 2))
  local border_top="╔$(printf '═%.0s' $(seq 1 $box_width))╗"
  local border_bottom="╚$(printf '═%.0s' $(seq 1 $box_width))╝"
  echo "$border_top"
  for line in "${lines[@]}"; do
    local total_space=$((box_width - ${#line}))
    local left_space=$((total_space / 2))
    local right_space=$((total_space - left_space))
    printf "%*s%s%*s\n" "$left_space" "" "$line" "$right_space" ""
  done
  echo "$border_bottom"
}

# Custom Divider
fancy_divider() {
  #Total width of the divider
  local width=${1:-50} 
  #Character or emoji to repeat
  local char="${2:-━}"        
  local line=""
  while [[ ${(L)#line} -lt $width ]]; do
    line+="$char"
  done
  print -r -- "$line"
}

# Custom Header
fancy_header() {
  local label="$1"
  local total_width=${80}
  local padding_width=$(( (total_width - ${#label} - 2) / 2 ))
  printf '%*s' "$padding_width" '' | tr ' ' '='
  printf " %s " "$label"
  printf '%*s\n' "$padding_width" '' | tr ' ' '='
}

# Function to print info about execution
print_info() {
  local words=(${(z)1})  # split message into words
  local i=1
  print -Pn "%F{cyan}ⓘ "
  for word in $words; do
    print -n -P "$word "
    (( i++ % 20 == 0 )) && print
  done
  print -P "%f\n"
}

# Function to get free disk space in bytes
get_free_space() {
  df -k / | tail -1 | awk '{print $4 * 1024}'
}

# Function to convert bytes to human-readable format
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

# Function to safely clean temp files
clean_temp_files() {
    local dir="$1"
    local description="$2"
    echo "${BLUE}Cleaning $description${RESET}"
    # Count files before deletion
    local files_count=$(sudo find "$dir" -type f -mtime +3 | wc -l)
    if [[ $files_count -gt 0 ]]; then
        # Use -delete instead of -exec rm for better performance
        sudo find "$dir" -type f -mtime +3 -delete 2>/dev/null
        echo "${GREEN}Cleaned $files_count old files from $description${RESET}"
    else
        echo "${YELLOW}No old files found in $description${RESET}"
    fi
}

# Function to check execution dependencies
check_mac_dependencies() {
  local dependencies_status=0
  fancy_header "Checking Dependencies"
  echo "${YELLOW}"
  # Check Homebrew
  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew is not installed"
    dependencies_status=1
  else
    echo "Homebrew is installed"
  fi
  # Check coreutils via Homebrew
  if ! brew list coreutils >/dev/null 2>&1; then
    echo "❌ coreutils is not installed via Homebrew"
    dependencies_status=1
  else
    echo "coreutils is installed"
  fi
  # Check osascript (should always exist on macOS)
  if ! command -v osascript >/dev/null 2>&1; then
    echo "❌ osascript is not available"
    dependencies_status=1
  else
    echo "osascript is available"
  fi
  # Final decision
  if [[ $dependencies_status -eq 0 ]]; then
    echo "Dependencies are in place, proceeding with cleanup"
  else
    echo "Dependencies did not comply"
    echo "❌ Terminating script execution"
    exit 1
  fi
  echo "${RESET}"
}

# Function to print summary
print_summary() {
    print_box " Summary "
    echo ""
    echo "${CYAN}System${RESET}${GREEN}"
    echo ""
    echo "  Model   $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    echo "  CPU     $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
    echo "  RAM     $(($(sysctl -n hw.memsize 2>/dev/null || echo 0)/1024/1024/1024)) GB"
    echo "  macOS   $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "  Uptime  $(uptime | awk -F'( |,|:)+' '{if ($7=="min") print $6" min"; else if($7=="hrs") print $6" hrs, "$8" min"; else print $6" hrs"}')"
    echo "${RESET}"
    echo "${CYAN}Cleanup Performed${RESET}"
    echo ""
    [[ $user_caches_cleaned -gt 0 ]] && echo "${GREEN}  ✔ User caches cleaned ($user_caches_cleaned folders) ${RESET}" || echo "${YELLOW}  ● No junk found in user cache,nothing to clean up ${RESET}"
    [[ $logs_cleaned -gt 0 ]] && echo "${GREEN}  ✔ Old log files cleaned ($logs_cleaned files) ${RESET}" || echo "${YELLOW}  ● No outdated logs detected, all set ${RESET}"
    [[ $trash_cleaned -gt 0 ]] && echo "${GREEN}  ✔ Trash cleaned ($trash_cleaned files) ${RESET}" || echo "${YELLOW}  ● No files found in Trash, it's squeaky clean ${RESET}"
    [[ $downloads_cleaned -gt 0 ]] && echo "${GREEN}  ✔ Old Downloads cleaned ($downloads_cleaned files) ${RESET}" || echo "${YELLOW}  ● Downloads folder looks tidy, no old files to delete ${RESET}"
    [[ $homebrew_cleaned == 1 ]] && echo "${GREEN}  ✔ Homebrew cleanup complete ${RESET}" || echo "${YELLOW}  ● Homebrew is already clean, no leftover files found ${RESET}"
    [[ $memory_purged == 1 ]] && echo "${GREEN}  ✔ Inactive memory purged ${RESET}" || echo "${YELLOW}  ● Memory usage is already clean and efficient ${RESET}"
    [[ ${ios_backups_cleaned:-0} -gt 0 ]] && echo "${GREEN}  ✔ iOS device backups cleaned ($ios_backups_cleaned) ${RESET}" || echo "${YELLOW}  ● No iOS backups found to clean ${RESET}"
    [[ ${derived_count:-0} -gt 0 ]] && echo "${GREEN}  ✔ Xcode DerivedData cleaned ($derived_count items) ${RESET}" || echo "${YELLOW}  ● No Xcode DerivedData found to clean ${RESET}"
    [[ ${device_support_count:-0} -gt 0 ]] && echo "${GREEN}  ✔ Xcode DeviceSupport cleaned ($device_support_count items) ${RESET}" || echo "${YELLOW}  ● No Xcode DeviceSupport found to clean ${RESET}"
    [[ ${docker_cleaned:-0} -eq 1 ]] && echo "${GREEN}  ✔ Docker system pruned ${RESET}" || echo "${YELLOW}  ● Docker doesn’t seem to be installed on your system ${RESET}"
    # Measure free disk space after cleanup
    space_after=$(get_free_space)
    space_freed=$(( space_after - space_before ))
    # Get memory usage after purge
    MEM_AFTER=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//')
    MEM_AFTER_MB=$(( MEM_AFTER * 4096 / 1024 / 1024 ))
    # Calculate memory freed
    MEM_FREED_MB_RAW=$(echo "$MEM_AFTER_MB - $MEM_BEFORE_MB" | bc -l)
    MEM_FREED_MB=$(echo "$MEM_FREED_MB_RAW" | awk '{printf "%.3f", ($1 == int($1)) ? $1 : int($1)+1 + ($1-int($1))}')
    echo ""
    echo "${CYAN}Results${RESET}"
    echo ""
    # Print memory freed
    if (( MEM_FREED_MB > 0 )); then
       echo "${GREEN}  RAM freed: $MEM_FREED_MB Megabyte(MB)${RESET}"
    else
      echo "${YELLOW}  No additional RAM freed - possibly already optimized${RESET}"
    fi
    if (( space_freed > 0 )); then
        echo "${GREEN}  Disk space freed: $(human_readable_space $space_freed)${RESET}"
    elif (( space_freed < 0 )); then
        echo "${YELLOW}  No noticeable disk space - possibly already optimized${RESET}"
    else
        echo "${YELLOW}  Disk space unchanged - possibly already optimized${RESET}"
    fi
    echo "${GREEN}  Log file: $LOGFILE"
    echo "  Script version: $VER"
    echo "${RESET}"
    fancy_header "${AUTHOR} © $(date +%Y)"
    echo ""
}

# ───── Script Starts ─────
clear

# Ensure the script is run with zsh
if [[ -z "$ZSH_VERSION" ]]; then
    echo "❌ This script requires zsh to run. Please run it with zsh." >&2
    exit 1
fi

# Ensure the OS is macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Unsupported OS: This script only works on macOS" >&2
    exit 1
fi

# Optimize globbing and file matching for safety and flexibility
setopt nullglob extended_glob

# Strip ANSI color codes and save clean output to log, while keeping colored output in terminal
# Need to install brew install coreutils
exec > >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' > "${LF}")) \
     2> >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "${LF}") >&2)

# Print the initial box with script info
echo ""
print_box "macOS Cleanup"
echo ""
echo "clean-mac is a free, all-in-one script for macOS that quickly cleans caches, logs,"
echo "temp files, old downloads, and Homebrew leftovers—helping you reclaim space and keep"
echo "your Mac running fast with just one command"
echo ""
echo "$DATE"
echo "Version $VER"
echo "Author  $AUTHOR"
echo ""
echo "${CYAN}Starting Mac cleanup${RESET}"
echo "${CYAN}You might be asked for your password to perform certain tasks${RESET}"
echo "${CYAN}For the smoothest experience, we recommend running this script directly in the macOS Terminall${RESET}"
echo "${RED}To exit the script at any time, press Control + C${RESET}"
echo ""

# Print system details
fancy_header " System Details "
echo "${GREEN}"
echo "Mac Model   : $MODEL"
echo "CPU         : $CPU"
echo "RAM         : $MEM"
echo "Capacity    : $DISK_SIZE"
echo "Serial      : $SERIAL"
echo "OS Name     : $OS_NAME"
echo "OS Version  : $OS_VERSION"
echo "Build       : $OS_BUILD"
echo "Uptime      : $UPTIME"
echo "Interface   : $ACTIVE_IF"
echo "IP          : $IP"
echo "MAC         : $MAC"
echo "SSID        : $SSID"
echo "${RESET}"

# Check for required dependencies
check_mac_dependencies

# Ask for sudo once at the start
sudo -v

# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Measure free disk space before
space_before=$(get_free_space)

# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Step 1: Clear user caches
fancy_header " Cleaning Caches "
print_info "Clearing user caches frees space, removes junk, and improves performance and stability"
# Use find for more efficient file operations
counter=0
find ~/Library/Caches -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  dirname=$(basename "$dir")
  if [[ ${protected_caches[(ie)$dirname]} -le ${#protected_caches} ]]; then
    echo "${YELLOW}Skipping Protected Cache Folder: $dir${RESET}"
  else
    echo "${BLUE}Cleaning User Cache: $dir${RESET}"
    sudo rm -rf "${dir:?}"/* 2>/dev/null || echo "${YELLOW}Warning: Failed to Clean $dir${RESET}"
    ((counter++))
  fi
done
if (( counter > 0 )); then
  echo "${GREEN}User Cache cleanup completed${RESET}"
  user_caches_cleaned=$counter
else
  echo "${YELLOW}User Cache Directories are clean — no files to clean${RESET}"
fi
echo ""

# Step 2: Clean iOS device backups
fancy_header " Cleaning iOS Device Backups "
print_info "Removing old iOS device backups from MobileSync and Backup"
if [[ -d "$IOS_BACKUP_DIR" ]]; then
  backup_count=$(find "$IOS_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
  if (( backup_count > 0 )); then
    echo "${BLUE}Found $backup_count iOS device backup(s)${RESET}"
    sudo rm -rf "$IOS_BACKUP_DIR"/*
    echo "${GREEN}All iOS device backups removed${RESET}"
    ios_backups_cleaned=$backup_count
  else
    echo "${YELLOW}No iOS device backups found.{RESET}"
    ios_backups_cleaned=0
  fi
else
  echo "${YELLOW}No iOS device backup directory found${RESET}"
  ios_backups_cleaned=0
fi
echo ""

# Step 3: Clean Xcode DerivedData and device support
fancy_header " Cleaning Xcode Data "
print_info "Removing Xcode DerivedData and DeviceSupport to free up space"
if [[ -d "$XCODE_DERIVED_DATA" ]]; then
    derived_count=$(find "$XCODE_DERIVED_DATA" -mindepth 1 -maxdepth 1 | wc -l | xargs)
    if [[ -n "$(ls -A "$XCODE_DERIVED_DATA")" ]]; then
        sudo rm -rf "$XCODE_DERIVED_DATA"/*
        echo "${GREEN}Xcode DerivedData cleaned ($derived_count items).${RESET}"
    else
        echo "${YELLOW}No Xcode DerivedData found${RESET}"
    fi
else
    echo "${YELLOW}No Xcode DerivedData found${RESET}"
fi
if [[ -d "$XCODE_DEVICE_SUPPORT" ]]; then
    device_support_count=$(find "$XCODE_DEVICE_SUPPORT" -mindepth 1 -maxdepth 1 | wc -l | xargs)
    sudo rm -rf "$XCODE_DEVICE_SUPPORT"/*
    echo "${GREEN}Xcode DeviceSupport cleaned ($device_support_count items)${RESET}"
else
    echo "${YELLOW}No Xcode DeviceSupport found${RESET}"
fi
echo ""

# Step 4: Clean Docker system (if installed)
fancy_header " Cleaning Docker System "
print_info "Removing unused Docker images, containers, and volumes"
if command -v docker >/dev/null 2>&1; then
    docker system prune -af --volumes
    echo "${GREEN}Docker system pruned${RESET}"
    docker_cleaned=1
else
    echo "${YELLOW}Docker not installed, skipping Docker cleanup${RESET}"
    docker_cleaned=0
fi
echo ""

# Step 5: Clean old system logs older than 7 days
fancy_header " Cleaning Logs "
print_info "Cleaning logs older than 7 days to save disk space and improve performance"
# Find old files and store in array
old_logs=("${(@f)$(sudo find "/private/var/log" -type f -mtime +7 2>/dev/null)}")
# Clean empty entries
old_logs=(${old_logs:#""})  
if (( ${#old_logs[@]} == 0 )); then
    echo "${YELLOW}LOG is clean — no files to clean${RESET}"
    logs_cleaned=0
else
    for file in "${old_logs[@]}"; do
        echo "${BLUE}Cleaning LOG File: $file${RESET}"
        sudo rm -f "$file"
    done
    echo "${GREEN}${#old_logs[@]} old LOG files cleaned${RESET}"
    logs_cleaned=${#old_logs[@]}
fi
echo ""

# Step 6: Empty Trash/Bin
fancy_header " Cleaning Trash "
print_info "Clearing Trash frees disk space and prevents clutter, vital for active users"
# Empty User Trash
trash_files=("${(@f)$(sudo ls -1 "${HOME}/.Trash" 2>/dev/null)}")
trash_files=(${trash_files:#""}) 
if (( ${#trash_files[@]} == 0 )); then
    echo "${YELLOW}User Trash is clean — no files to clean${RESET}"
else
    for file in "${trash_files[@]}"; do
        echo "${BLUE}Cleaning File: $file${RESET}"
    done
    osascript -e 'tell application "Finder" to empty trash' 2>/dev/null
    echo "${GREEN}${#trash_files[@]} files cleaned${RESET}"  
    echo "${GREEN}Trash for current user has been cleaned${RESET}"
    trash_cleaned=${#trash_files[@]}
fi
# Empty System Trash
system_trash="/private/var/root/.Trash"
if [[ -d "$system_trash" ]]; then
    if [[ -z "$(sudo ls -A "$system_trash" 2>/dev/null)" ]]; then
        echo "${YELLOW}System Trash is already clean${RESET}"
    else
        sudo rm -rf "$system_trash"/* 2>/dev/null
        echo "${GREEN}Trash for system has been cleaned${RESET}"
        trash_cleaned=1
    fi
else
    echo "${YELLOW}System Trash folder not accessible${RESET}"
fi
# Trash on all mounted volumes
found_volume=0
for volume in /Volumes/*; do
    trashes_dir="$volume/.Trashes"
    if [[ -d "$trashes_dir" ]]; then
        found_volume=1
        if [[ -z "$(sudo ls -A "$trashes_dir" 2>/dev/null)" ]]; then
            echo "${YELLOW}Trash already clean on volume: $volume${RESET}"
        else
            sudo rm -rf "$trashes_dir"/* 2>/dev/null
            echo "${GREEN}Cleaned trash on volume: $volume${RESET}"
            trash_cleaned=1
        fi
    fi
done
if [[ $found_volume -eq 0 ]]; then
    echo "${YELLOW}No Mounted Volume found${RESET}"
fi
echo ""

# Step 7: Clean temporary files older than 3 days
fancy_header " Cleaning Files "
print_info "Temporary files slow systems, cleaning unused files (3+ days) improves performance"
# Clean various temp directories
clean_temp_files "/tmp" "system temporary directory"
clean_temp_files "/var/tmp" "variable temporary directory"
clean_temp_files "$HOME/Library/Caches/TemporaryItems" "user temporary items"
echo ""

# Step 8: Clean old Downloads
fancy_header " Cleaning Downloads "
print_info "The Downloads folder fills with old files, regularly deleting files frees space"
old_files=("${(@f)$(sudo find "${HOME}/Downloads" -type f -mtime +7 2>/dev/null)}")
# Clean empty entries
old_files=(${old_files:#""}) 
if (( ${#old_files[@]} == 0 )); then
    echo "${YELLOW}Downloads is clean — no files to clean${RESET}"  
    downloads_cleaned=0
else
    for file in "${old_files[@]}"; do
        echo "${BLUE}Cleaning File: $file${RESET}"
        rm -f "$file"
    done
    echo "${GREEN}${#old_files[@]} files cleaned${RESET}"
    downloads_cleaned=${#old_files[@]}
fi
echo ""

# Step 9: Homebrew cleanup
fancy_header " Cleaning Homebrew "
print_info "Homebrew is a popular macOS package manager for installing and managing software"
if command -v brew >/dev/null 2>&1; then
    echo "${BLUE}Running: brew config${RESET}"
    brew config
    echo "${BLUE}Running: brew info${RESET}"
    brew info
    echo "${BLUE}Running: brew cleanup -s${RESET}"
    brew cleanup -s
    echo "${RESET}${GREEN}Homebrew cleanup complete${RESET}"
    homebrew_cleaned=1
else
    echo "${YELLOW}Homebrew not installed, skipping process${RESET}"
    homebrew_cleaned=0
fi
echo ""

# Step 10: Purge inactive memory (if possible)
fancy_header " Cleaning Memory "
print_info "Freeing inactive memory to boost performance without closing any running applications"
if command -v purge >/dev/null 2>&1; then
    sudo purge
    sleep 1
    echo "${GREEN}Inactive memory purged${RESET}"
    memory_purged=1
else
    echo "${RED}'purge' command not available, skipping process${RESET}"
    memory_purged=0
fi
echo ""

# Print the cleanup summary
print_summary

# Flush filesystem buffers to ensure all changes are written to disk
sync

# Close file descriptors (for tee subshells)
exec 1>&- 2>&-

# Open the log file in Console (if available)
if command -v open >/dev/null 2>&1; then
    open -a "Console" "${LOGFILE}" 2>/dev/null || echo "${YELLOW}Could not open log in Console.${RESET}"
fi

exit 0