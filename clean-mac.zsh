#!/bin/zsh

# ------------------------------------------------------------------------------
# Mac Cleanup Script
# Author: Prasit Chanda
# Platform: macOS
# Version: 1.3.3
# Description: Safely cleans unused system/user cache, logs, temp files,
#              empties trash, clears Homebrew leftovers, and reports space freed
# Last Updated: 2025-06-23
# ------------------------------------------------------------------------------

# ───── Colors Variables ─────
GREEN=$'\e[92m'    # Green
YELLOW=$'\e[93m'   # Yellow
RED=$'\e[91m'      # Red
BLUE=$'\e[94m'     # Blue
CYAN=$'\e[96m'     # Cyan
RESET=$'\e[0m'     # Reset all attributes

# ───── Global Variables ─────
# Version info
VER="1.3.3-2025062339"
# Date info
DATE=$(date "+%a, %d %b %Y %H:%M:%S %p")
# Timestamp info
TS=$(date +"%Y%m%d%H%M%S")
# Log file info
LF="mac-clean-${TS}.log"
# Working directory info
WD=$PWD
# Log file info
LOGFILE="${WD}/${LF}"
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
# List of protected cache folders
protected_caches=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)

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
    echo "Dependency check complete. Ready to execute script."
  else
    echo "Dependencies did not comply"
    echo "❌ Terminating script execution"
    exit 1
  fi
  echo "${RESET}"
}
# Function to print info about execution
print_info() {
  local words=(${(z)1})  # split message into words
  local i=1
  print -P "%F{cyan}"
  for word in $words; do
    print -n -P "$word "
    (( i++ % 20 == 0 )) && print
  done
  print -P "%f\n"
}

# ───── Script Starts ─────

# Ensure the OS is macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Unsupported OS: This script only works on macOS." >&2
    exit 1
fi

setopt local_options nullglob extended_glob
clear

# Strip ANSI color codes and save clean output to log, while keeping colored output in terminal
# Need to install brew install coreutils
exec > >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' > "${LF}")) \
     2> >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "${LF}") >&2)

# System Details
echo ""
print_box "macOS Cleanup Script"
echo ""
echo "${CYAN}$DATE${RESET}"
echo ""
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
echo "${CYAN}Starting cleanup for your Mac System${RESET}"
echo "${CYAN}You may be prompted for password to authorize system operations${RESET}"
echo "${CYAN}For best results, run the script directly in the macOS Terminal${RESET}"
echo ""

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
else
  echo "${YELLOW}User Cache Directories are clean — no files to clean${RESET}"
fi
echo ""

# Step 2: Clean old system logs older than 7 days
fancy_header " Cleaning Logs "
print_info "Cleaning logs older than 7 days to save disk space and improve performance"
# Find old files and store in array
old_logs=("${(@f)$(sudo find "/private/var/log" -type f -mtime +7 2>/dev/null)}")
# Clean empty entries
old_logs=(${old_logs:#""})  
if (( ${#old_logs[@]} == 0 )); then
  echo "${YELLOW}LOG is clean — no files to clean${RESET}"
else
  for file in "${old_logs[@]}"; do
    echo "${BLUE}Cleaning LOG File: $file${RESET}"
    sudo rm -f "$file"
  done
  echo "${GREEN}${#old_logs[@]} old LOG files cleaned${RESET}"
fi
echo ""

# Step 3: Empty Trash/Bin
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
fi

# Empty System Trash
system_trash="/private/var/root/.Trash"
if [[ -d "$system_trash" ]]; then
  if [[ -z "$(sudo ls -A "$system_trash" 2>/dev/null)" ]]; then
    echo "${YELLOW}System Trash is already clean${RESET}"
  else
    sudo rm -rf "$system_trash"/* 2>/dev/null
    echo "${GREEN}Trash for system has been cleaned${RESET}"
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
    fi
  fi
done
if [[ $found_volume -eq 0 ]]; then
  echo "${YELLOW}No Mounted Volume found${RESET}"
fi
echo ""

# Step 4: Clean temporary files older than 3 days
fancy_header " Cleaning Files "
print_info "Temporary files slow systems, cleaning unused files (3+ days) improves performance"
# Clean various temp directories
clean_temp_files "/tmp" "system temporary directory"
clean_temp_files "/var/tmp" "variable temporary directory"
clean_temp_files "$HOME/Library/Caches/TemporaryItems" "user temporary items"
echo ""

# Step 5: Clean old Downloads
fancy_header " Cleaning Downloads "
print_info "The Downloads folder fills with old files, regularly deleting files frees space"
old_files=("${(@f)$(sudo find "${HOME}/Downloads" -type f -mtime +7 2>/dev/null)}")
# Clean empty entries
old_files=(${old_files:#""}) 
if (( ${#old_files[@]} == 0 )); then
  echo "${YELLOW}Downloads is clean — no files to clean${RESET}"  
else
  for file in "${old_files[@]}"; do
    echo "${BLUE}Cleaning File: $file${RESET}"
    rm -f "$file"
  done
    echo "${GREEN}${#old_files[@]} files cleaned${RESET}"
fi
echo ""

# Step 6: Homebrew cleanup
fancy_header " Cleaning Homebrew "
print_info "Homebrew is a popular macOS package manager for installing and managing software${BLUE}"
if command -v brew >/dev/null 2>&1; then
  echo "${BLUE}Running: brew config${RESET}"
  brew config
  echo "${BLUE}Running: brew info${RESET}"
  brew info
  echo "${BLUE}Running: brew cleanup -s${RESET}"
  brew cleanup -s
  echo "${RESET}${GREEN}Homebrew cleanup complete${RESET}"
else
  echo "${YELLOW}Homebrew not installed, skipping process${RESET}"
fi
echo ""

# Step 7: Purge inactive memory (if possible)
fancy_header " Cleaning Memory "
print_info "Freeing inactive memory to boost performance without closing any running applications"
if command -v purge >/dev/null 2>&1; then
  sudo purge
  echo "${GREEN}Inactive memory purged${RESET}"
else
  echo "${RED}'purge' command not available, skipping process${RESET}"
fi
echo ""

# Measure free disk space after cleanup
space_after=$(get_free_space)
space_freed=$(( space_after - space_before ))

# Display results
echo "${GREEN}Disk cleanup successfully completed${RESET}"
if (( space_freed > 0 )); then
  echo "${GREEN}Disk Freed $(human_readable_space $space_freed)${RESET}"
elif (( space_freed < 0 )); then
  echo "${YELLOW}No noticeable disk space change due to background processes${RESET}"
else
  echo "${YELLOW}Disk space unchanged${RESET}"
fi
echo "${GREEN}Log PATH ${LOGFILE}${RESET}"
echo ""

# Footer
fancy_divider 25 "="
echo "Version ${VER}"
echo "Prasit Chanda © $(date +%Y)"
fancy_divider 25 "="
echo ""

# Flush filesystem buffers to ensure all changes are written to disk
sync

# Close file descriptors (for tee subshells)
exec 1>&- 2>&-

# Open the log file in Console (if available)
if command -v open >/dev/null 2>&1; then
    open -a "Console" "${LOGFILE}" 2>/dev/null || echo "${YELLOW}Could not open log in Console${RESET}"
fi

exit 0