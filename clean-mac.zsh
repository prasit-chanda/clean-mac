#!/bin/zsh

# ------------------------------------------------------------------------------
# Mac Cleanup Script
# Author: Prasit Chanda
# Platform: macOS
# Version: 1.4.0-20250627CVOP
# Description: Safely cleans unused system/user cache, logs, temp files,
#              empties trash, clears Homebrew leftovers, and reports space freed
# Last Updated: 2025-06-27
# ------------------------------------------------------------------------------

# ───── Colors Variables ─────
# Use standard, high-contrast ANSI codes for best visibility on both dark and light backgrounds
WHITE='\e[97m'     # Bright White - General Info
GREEN=$'\e[32m'    # Bright Green - Success
YELLOW=$'\e[33m'   # Bright Yellow - Warning/Skip
RED=$'\e[31m'      # Bright Red - Error/Failure
BLUE=$'\e[94m'     # Bright Blue - Info/Action
CYAN=$'\e[36m'     # Bright Cyan - General Info
RESET=$'\e[0m'     # Reset all attributes

# ───── Global Variables ─────
VER="1.4.0-20250627CVOP" # Version info
DATE=$(date "+%a, %d %b %Y %H:%M:%S %p") # Date info
TS=$(date +"%Y%m%d%H%M%S") # Timestamp info
LF="clean-mac-${TS}.log" # Log file info
WD=$PWD # Working directory info
LOGFILE="${WD}/${LF}" # Log file path
AUTHOR="Prasit Chanda" # Author info (dynamic)
OS_NAME=$(sw_vers -productName) # OS Name
OS_VERSION=$(sw_vers -productVersion) # OS Version
OS_BUILD=$(sw_vers -buildVersion) # OS Build
MODEL=$(sysctl -n hw.model) # Hardware Model
CPU=$(sysctl -n machdep.cpu.brand_string) # CPU Info
MEM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))" GB" # RAM Info
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ { print $4 }') # Serial Number
UPTIME=$(uptime | cut -d ',' -f1 | xargs) # Uptime
MAIN_DISK=$(diskutil info / | awk -F: '/Device Node/ {print $2}' | xargs) # Main disk
DISK_SIZE=$(diskutil info "$MAIN_DISK" | awk -F: '/Disk Size/ {print $2}' | head -n 1 | xargs) # Disk size
[[ -z "$DISK_SIZE" ]] && DISK_SIZE="Unknown" # Fallback if info not found
ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface: / {print $2}') # First active interface
IP=$(ipconfig getifaddr "$ACTIVE_IF" 2>/dev/null) # IP address
MAC=$(ifconfig "$ACTIVE_IF" 2>/dev/null | awk '/ether/ {print $2}') # MAC address

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

MEM_BEFORE=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//') # Memory usage before cleanup
MEM_BEFORE_MB=$(( MEM_BEFORE * 4096 / 1024 / 1024 )) # Memory before in MB

# List of protected cache folders
protected_caches=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)

IOS_BACKUP_DIR="${HOME}/Library/Application Support/MobileSync/Backup" # iOS device backup directory
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData" # Xcode DerivedData directory
XCODE_DEVICE_SUPPORT="${HOME}/Library/Developer/Xcode/iOS DeviceSupport" # Xcode DeviceSupport directory
SCRIPT_START_TIME=$(date +%s) # Initialize cleanup counters

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
  print -Pn "%F{blue}"
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
  # Total width of the divider
  local width=${1:-50}
  # Character or emoji to repeat
  local char="${2:-━}"
  local line=""
  while [[ ${(L)#line} -lt $width ]]; do
    line+="$char"
  done
  print -Pn "%F{blue}"
  print -r -- "$line"
}

# Custom Header
fancy_header() {
  local label="$1"
  local total_width=80
  local padding_width=$(( (total_width - ${#label} - 2) / 2 ))
  print -Pn "%F{blue}"
  printf '%*s' "$padding_width" '' | tr ' ' '='
  printf " %s " "$label"
  printf '%*s\n' "$padding_width" '' | tr ' ' '='
}

# Function to print info about execution
print_info() {
  local words=(${(z)1})  # split message into words
  local i=1
  print -Pn "\n%F{cyan} ⓘ "
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

# Function to show RAM summary
show_ram_summary() {
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
  echo "${GREEN}Total RAM  : ${total_gb} GB"
  echo "Free RAM   : ${free_mb} MB"
  echo "Active     : ${active_mb} MB"
  echo "Inactive   : ${inactive_mb} MB"
  echo "Wired      : ${wired_mb} MB"
  echo "Compressed : ${compressed_mb} MB"
  echo "Pressure   : ${pressure}${RESET}"
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
  echo "  Uptime  $(get_simple_uptime)"
  echo "${RESET}"
  echo "${CYAN}Cleanup Performed${RESET}"
  echo ""
  [[ $user_caches_cleaned -gt 0 ]] && \
    echo "${GREEN}  ✔ User caches cleaned ($user_caches_cleaned folders) ${RESET}" || \
    echo "${YELLOW}  ● No junk found in user cache, nothing to clean up ${RESET}"
  [[ $logs_cleaned -gt 0 ]] && \
    echo "${GREEN}  ✔ Old log files cleaned ($logs_cleaned files) ${RESET}" || \
    echo "${YELLOW}  ● No outdated logs detected, all set ${RESET}"
  [[ $trash_cleaned -gt 0 ]] && \
    echo "${GREEN}  ✔ Trash cleaned ($trash_cleaned files) ${RESET}" || \
    echo "${YELLOW}  ● No files found in Trash, it's squeaky clean ${RESET}"
  [[ $downloads_cleaned -gt 0 ]] && \
    echo "${GREEN}  ✔ Old Downloads cleaned ($downloads_cleaned files) ${RESET}" || \
    echo "${YELLOW}  ● Downloads folder looks tidy, no old files to delete ${RESET}"
  [[ $homebrew_cleaned == 1 ]] && \
    echo "${GREEN}  ✔ Homebrew cleanup complete ${RESET}" || \
    echo "${YELLOW}  ● Homebrew is already clean, no leftover files found ${RESET}"
  [[ $memory_purged == 1 ]] && \
    echo "${GREEN}  ✔ Cleared unused memory ${RESET}" || \
    echo "${YELLOW}  ● Memory usage is already clean and efficient ${RESET}"
  [[ ${ios_backups_cleaned:-0} -gt 0 ]] && \
    echo "${GREEN}  ✔ iOS device backups cleaned ($ios_backups_cleaned) ${RESET}" || \
    echo "${YELLOW}  ● No iOS backups found to clean ${RESET}"
  [[ ${derived_count:-0} -gt 0 ]] && \
    echo "${GREEN}  ✔ Xcode DerivedData cleaned ($derived_count items) ${RESET}" || \
    echo "${YELLOW}  ● No Xcode DerivedData found to clean ${RESET}"
  [[ ${device_support_count:-0} -gt 0 ]] && \
    echo "${GREEN}  ✔ Xcode DeviceSupport cleaned ($device_support_count items) ${RESET}" || \
    echo "${YELLOW}  ● No Xcode DeviceSupport found to clean ${RESET}"
  [[ ${docker_cleaned:-0} -eq 1 ]] && \
    echo "${GREEN}  ✔ Docker system pruned ${RESET}" || \
    echo "${YELLOW}  ● Docker doesn’t seem to be installed on your system ${RESET}"

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
    echo "${GREEN}  RAM Cleaned  $MEM_FREED_MB Megabyte(MB)${RESET}"
  else
    echo "${YELLOW}  No additional RAM freed - possibly already optimized${RESET}"
  fi

  if (( space_freed > 0 )); then
    echo "${GREEN}  Disk Cleaned $(human_readable_space $space_freed)${RESET}"
  elif (( space_freed < 0 )); then
    echo "${YELLOW}  No noticeable change, possibly already optimized${RESET}"
  else
    echo "${YELLOW}  Disk space unchanged, possibly already optimized${RESET}"
  fi

  # Add execution time
  SCRIPT_END_TIME=$(date +%s)
  if [[ -n "$SCRIPT_START_TIME" && -n "$SCRIPT_END_TIME" ]]; then
    local elapsed=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    echo "${GREEN}  Execution Time: ${mins}m ${secs}s${RESET}"
  fi

  echo "${GREEN}  Log File $LOGFILE"
  echo "  Script Version $VER"
  echo "${RESET}"
  fancy_header "${AUTHOR} © $(date +%Y)"
  echo ""
}

# Function to get simple uptime
get_simple_uptime() {
  local uptime_part
  uptime_part=$(uptime | awk -F'up ' '{split($2,a,","); print a[1]}' | sed -E '
    s/^ *([0-9]+) days?.*/\1 days/;
    s/^ *([0-9]+):[0-9]+.*/\1 hours/;
    s/^ *([0-9]+) mins?.*/\1 minutes/;
    s/^\s*$/Just booted/
  ')
  echo "$uptime_part"
}

# Function to show Homebrew information
show_brew_info() {
  # Collect Homebrew information
  echo "${BLUE}Fetching Homebrew information${RESET}${GREEN}"
  local brew_path=$(command -v brew)
  local brew_version=$(brew --version | head -n 1)
  local installed_formulae=$(brew list --formulae 2>/dev/null | wc -l | tr -d ' ')
  local installed_casks=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
  local outdated_formulae=$(brew outdated --formulae --quiet | wc -l | tr -d ' ')
  local outdated_casks=$(brew outdated --cask --quiet | wc -l | tr -d ' ')
  # Last update (checking Homebrew Git repo timestamp)
  local last_update=$(git -C "$(brew --repo)" log -1 --format="%cd" --date=short 2>/dev/null || echo "Unavailable")
  # Disk usage of Homebrew Cellar
  local cellar_path=$(brew --cellar)
  local disk_usage=$(du -sh "$cellar_path" 2>/dev/null | awk '{print $1}')
  # Brew doctor output summary
  local doctor_summary=$(brew doctor 2>&1 | grep -A3 "Warning" | head -n 6)
  local doctor_status="OK"
  if [[ -n "$doctor_summary" ]]; then
    doctor_status="Warnings detected"
  fi
  # Brew services running count
  local services_running=$(brew services list 2>/dev/null | grep started | wc -l | tr -d ' ')
  echo "Path                  : $brew_path"
  echo "Version               : $brew_version"
  echo "Installed Formulae    : $installed_formulae"
  echo "Installed Casks       : $installed_casks"
  echo "Outdated Formulae     : $outdated_formulae"
  echo "Outdated Casks        : $outdated_casks"
  echo "Last Update           : $last_update"
  echo "Disk Usage (Cellar)   : ${disk_usage:-Unknown}"
  echo "Brew Doctor Status    : $doctor_status"
  echo "Brew Services Running : $services_running${RESET}"
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
print_box " clean-mac.zsh "
echo "${CYAN}"
echo "clean-mac.zsh is a free, all-in-one script for macOS that quickly cleans caches, logs,"
echo "temp files, old downloads, and Homebrew leftovers—helping you reclaim space and keep"
echo "your Mac running fast with just one command"
echo "${RESET}${GREEN}"
echo "$DATE"
echo "Version $VER"
echo "Author  $AUTHOR"
echo "${RESET}"
echo "${GREEN}Starting Mac cleanup${RESET}"
echo "${GREEN}You might be asked for your password to perform certain tasks${RESET}"
echo "${GREEN}For the smoothest experience, we recommend running this script directly in the macOS Terminal${RESET}"
echo "${RED}To exit the script at any time, press << control + C >>${RESET}"
echo ""

# Print system details
fancy_header " System Details "
echo "${GREEN}"
echo "Mac Model   : $MODEL"
echo "CPU         : $CPU"
echo "RAM         : $MEM"
echo "Storage     : $DISK_SIZE"
echo "Serial      : $SERIAL"
echo "OS Name     : $OS_NAME"
echo "OS Version  : $OS_VERSION"
echo "Build       : $OS_BUILD"
echo "Uptime      : $UPTIME"
echo "Interface   : $ACTIVE_IF"
echo "IP          : $IP"
echo "MAC         : $MAC"
echo "${RESET}"

# Check for required dependencies
check_mac_dependencies

# Ask for sudo once at the start
sudo -v

# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Measure free disk space before
space_before=$(get_free_space)

# Step 1: Clear user caches
fancy_header " Cleaning Caches "
print_info "Clearing user caches frees space, removes junk, and improves performance and stability"
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
    echo "${YELLOW}No iOS device backups found.${RESET}"
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
old_logs=("${(@f)$(sudo find "/private/var/log" -type f -mtime +7 2>/dev/null)}")
old_logs=(${old_logs:#""})  # Clean empty entries
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
clean_temp_files "/tmp" "system temporary directory"
clean_temp_files "/var/tmp" "variable temporary directory"
clean_temp_files "$HOME/Library/Caches/TemporaryItems" "user temporary items"
echo ""

# Step 8: Clean old Downloads
fancy_header " Cleaning Downloads "
print_info "The Downloads folder fills with old files, regularly deleting files frees space"
old_files=("${(@f)$(sudo find "${HOME}/Downloads" -type f -mtime +7 2>/dev/null)}")
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
  show_brew_info
  echo "${BLUE}Cleaning Homebrew${RESET}"
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
show_ram_summary
if command -v purge >/dev/null 2>&1; then
  sudo purge
  sleep 1
  echo "${GREEN}Cleared unused memory${RESET}"
  memory_purged=1
else
  echo "${RED}'purge' command not available, skipping process${RESET}"
  memory_purged=0
fi
echo ""

# Print the cleanup summary
SCRIPT_END_TIME=$(date +%s)
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