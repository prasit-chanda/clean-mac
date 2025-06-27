#!/bin/zsh

# ------------------------------------------------------------------------------
# Mac Cleanup Script
# Author: Prasit Chanda
# Platform: macOS
# Version: 1.5.0-20250627-XQLSQ
# Description: Safely cleans unused system/user cache, logs, temp files,
#              empties trash, clears Homebrew leftovers, and reports space freed
# Last Updated: 2025-06-27
# ------------------------------------------------------------------------------

# ───── Static Colors Variables ─────
# Use standard, high-contrast ANSI codes for best visibility on both dark and light backgrounds
BLUE=$'\e[94m'     # Bright Blue - Info/Action
CYAN=$'\e[36m'     # Bright Cyan - General Info
GREEN=$'\e[32m'    # Bright Green - Success
RED=$'\e[31m'      # Bright Red - Error/Failure
RESET=$'\e[0m'     # Reset all attributes
WHITE='\e[97m'     # Bright White - General Info
YELLOW=$'\e[33m'   # Bright Yellow - Warning/Skip

# ───── Static Text Variables ─────
SCRIPT_BOX_TITLE=" clean-mac.zsh "
SCRIPT_DESCRIPTION="clean-mac.zsh is a free, all-in-one script for macOS that quickly cleans caches, logs,
temp files, old downloads, and Homebrew leftovers—helping you reclaim space and keep
your Mac running fast with just one command"
SCRIPT_START_MSG="Starting clean-mac"
SCRIPT_SUDO_MSG=" ● You might be asked for your password to perform certain tasks"
SCRIPT_TERMINAL_MSG=" ● Run in macOS Terminal for best results"
SCRIPT_INTERNET_MSG=" ● You're going to need a stable internet connection for smooth execution"
SCRIPT_EXIT_MSG=" ● You can exit anytime by pressing control (⌃) + c"
SYSTEM_DETAILS_HEADER="System"
MODEL_LABEL="Mac Model   :"
CPU_LABEL="CPU         :"
RAM_LABEL="RAM         :"
STORAGE_LABEL="Storage     :"
SERIAL_LABEL="Serial      :"
OS_NAME_LABEL="OS Name     :"
OS_VERSION_LABEL="OS Version  :"
BUILD_LABEL="Build       :"
UPTIME_LABEL="Uptime      :"
INTERFACE_LABEL="Interface   :"
IP_LABEL="IP          :"
MAC_LABEL="MAC         :"
DEPENDENCIES_HEADER="Dependencies"
CLEANING_CACHES_HEADER="Caches "
CLEANING_CACHES_HINT="Clearing user caches frees space, removes junk, and improves performance and stability"
CLEANING_IOS_HEADER="Backups"
CLEANING_IOS_HINT="Removing old iOS device backups from MobileSync and Backup"
CLEANING_XCODE_HEADER="Xcode"
CLEANING_XCODE_HINT="Removing Xcode DerivedData and DeviceSupport to free up space"
CLEANING_DOCKER_HEADER="Docker"
CLEANING_DOCKER_HINT="Removing unused Docker images, containers, and volumes"
CLEANING_LOGS_HEADER="Logs"
CLEANING_LOGS_HINT="Cleaning logs older than 7 days to save disk space and improve performance"
CLEANING_TRASH_HEADER="Trash"
CLEANING_TRASH_HINT="Clearing Trash frees disk space and prevents clutter, vital for active users"
CLEANING_FILES_HEADER="Files"
CLEANING_FILES_HINT="Temporary files slow systems, cleaning unused files (3+ days) improves performance"
CLEANING_DOWNLOADS_HEADER="Downloads"
CLEANING_DOWNLOADS_HINT="The Downloads folder fills with old files, regularly deleting files frees space"
CLEANING_HOMEBREW_HEADER="Homebrew"
CLEANING_HOMEBREW_HINT="Homebrew is a popular macOS package manager for installing and managing software"
CLEANING_MEMORY_HEADER="Memory"
CLEANING_MEMORY_HINT="Freeing inactive memory to boost performance without closing any running applications"
NO_FILES_TO_CLEAN_MSG="no files to clean"
USER_CACHE_CLEANED_MSG="User Cache cleanup completed"
USER_CACHE_CLEAN_MSG="User Cache Directories are clean — no files to clean"
IOS_BACKUP_FOUND_MSG="Found"
IOS_BACKUP_REMOVED_MSG="All iOS device backups removed"
IOS_BACKUP_NONE_MSG="No iOS device backups found."
IOS_BACKUP_DIR_NONE_MSG="No iOS device backup directory found"
XCODE_DERIVED_CLEANED_MSG="Xcode DerivedData cleaned"
XCODE_DERIVED_NONE_MSG="No Xcode DerivedData found"
XCODE_DEVICE_CLEANED_MSG="Xcode DeviceSupport cleaned"
XCODE_DEVICE_NONE_MSG="No Xcode DeviceSupport found"
DOCKER_PRUNED_MSG="Docker system pruned"
DOCKER_NOT_INSTALLED_MSG="Docker not installed, skipping Docker cleanup"
LOG_CLEAN_MSG="LOG is clean — no files to clean"
LOG_FILE_CLEANED_MSG="old LOG files cleaned"
TRASH_CLEAN_MSG="User Trash is clean — no files to clean"
TRASH_FILE_CLEANED_MSG="files cleaned"
TRASH_USER_CLEANED_MSG="Trash for current user has been cleaned"
SYSTEM_TRASH_CLEAN_MSG="System Trash is already clean"
SYSTEM_TRASH_CLEANED_MSG="Trash for system has been cleaned"
SYSTEM_TRASH_NOT_ACCESSIBLE_MSG="System Trash folder not accessible"
TRASH_VOLUME_CLEAN_MSG="Trash already clean on volume:"
TRASH_VOLUME_CLEANED_MSG="Cleaned trash on volume:"
NO_MOUNTED_VOLUME_MSG="No Mounted Volume found"
DOWNLOADS_CLEAN_MSG="Downloads is clean — no files to clean"
DOWNLOADS_FILE_CLEANED_MSG="files cleaned"
HOMEBREW_CLEANED_MSG="Homebrew cleanup complete"
HOMEBREW_NOT_INSTALLED_MSG="Homebrew not installed, skipping process"
HOMEBREW_CLEANUP_SKIPPED_MSG="Homebrew cleanup skipped due to connection issues"
PURGE_CLEANED_MSG="Cleared unused memory"
PURGE_NOT_AVAILABLE_MSG="'purge' command not available, skipping process"

# ───── Global Variables ─────
ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface: / {print $2}') # First active interface
MAC=$(ifconfig "$ACTIVE_IF" 2>/dev/null | awk '/ether/ {print $2}') # MAC address
AUTHOR="Prasit Chanda" # Author info (dynamic)
CPU=$(sysctl -n machdep.cpu.brand_string) # CPU Info
DATE=$(date "+%a, %d %b %Y %H:%M:%S %p") # Date info
MAIN_DISK=$(diskutil info / | awk -F: '/Device Node/ {print $2}' | xargs) # Main disk
DISK_SIZE=$(diskutil info "$MAIN_DISK" | awk -F: '/Disk Size/ {print $2}' | cut -d'(' -f1 | xargs) # Disk size
IP=$(ipconfig getifaddr "$ACTIVE_IF" 2>/dev/null) # IP address
LF="clean-mac-${TS}.log" # Log file info
TS=$(date +"%Y%m%d%H%M%S") # Timestamp info
WD=$(pwd) # Working directory info
LOGFILE="${WD}/${LF}" # Log file path
MEM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))" GB" # RAM Info
MEM_BEFORE=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//') # Memory usage before cleanup
MEM_BEFORE_MB=$(( MEM_BEFORE * 4096 / 1024 / 1024 )) # Memory before in MB
MODEL=$(sysctl -n hw.model) # Hardware Model
OS_BUILD=$(sw_vers -buildVersion) # OS Build
OS_NAME=$(sw_vers -productName) # OS Name
OS_VERSION=$(sw_vers -productVersion) # OS Version
SCRIPT_START_TIME=$(date +%s) # Initialize cleanup counters
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ { print $4 }') # Serial Number
UPTIME=$(uptime | cut -d ',' -f1 | xargs) # Uptime
USER_EXITED=0 # Flag to indicate if user exited early
IOS_BACKUP_DIR="${HOME}/Library/Application Support/MobileSync/Backup" # iOS device backup directory
VER="1.5.0-$(date +"%Y%m%d")-XQLSQ" # Version info
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData" # Xcode DerivedData directory
XCODE_DEVICE_SUPPORT="${HOME}/Library/Developer/Xcode/iOS DeviceSupport" # Xcode DeviceSupport directory
# List of protected cache folders (these will not be deleted)
protected_caches=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)

# ───── Custom Methods ─────

# Function to ask user if they want to exit
ask_user_consent() {
  print -nP "%F{yellow}Do you want to continue running the script? (y/n)"
  read answer
  echo ""
  case "$answer" in
    [nN]* )
      echo "❌ ${RED}Execution of clean-mac.zsh cancelled by $(whoami)${RESET}"
      echo ""
      USER_EXITED=1 # Set the flag so summary knows user exited
      print_clean_summary # Print summary (will skip results if exited)
      exit 0
      ;;
    * )
      echo "${GREEN}$(whoami) gave the green light — launching clean-mac.zsh${RESET}"
      echo ""
      ;;
  esac
}

# Function to safely clean temp files in a directory older than 3 days
clean_temp_files() {
  local dir="$1"
  local description="$2"
  echo "${BLUE}Cleaning $description${RESET}"
  # Count files before deletion
  local files_count=$(sudo find "$dir" -type f -mtime +3 | wc -l)
  if [[ $files_count -gt 0 ]]; then
    # Use -delete for efficiency
    sudo find "$dir" -type f -mtime +3 -delete 2>/dev/null
    echo "${GREEN}Cleaned $files_count old files from $description${RESET}"
  else
    echo "${YELLOW}No old files found in $description${RESET}"
  fi
}

# Function to check execution dependencies (Homebrew, coreutils, osascript)
check_dependencies() {
  local dependencies_status=0
  fancy_text_header $DEPENDENCIES_HEADER
  echo ""
  # Check Homebrew
  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ ${RED}Homebrew is not installed${RESET}"
    dependencies_status=1
  else
    echo "${GREEN}Homebrew is installed${RESET}"
  fi
  # Check coreutils via Homebrew
  if ! brew list coreutils >/dev/null 2>&1; then
    echo "❌ ${RED}coreutils is not installed via Homebrew${RESET}"
    dependencies_status=1
  else
    echo "${GREEN}coreutils is installed${RESET}"
  fi
  # Check osascript (should always exist on macOS)
  if ! command -v osascript >/dev/null 2>&1; then
    echo "❌ ${RED}osascript is not available${RESET}"
    dependencies_status=1
  else
    echo "${GREEN}osascript is available${RESET}"
  fi
  # Final decision
  if [[ $dependencies_status -eq 0 ]]; then
    echo "${GREEN}Dependencies are in place${RESET}"
  else
    echo "${RED}Dependencies did not comply${RESET}"
    echo ""
  fi
  echo ""
}

# Function to check if the user has an internet connection
check_internet() {
  local host="8.8.8.8"  # Google DNS
  local timeout=2
  if ping -c 1 -W $timeout "$host" >/dev/null 2>&1; then
    echo "${GREEN}  ✔ Internet connection is active and stable${RESET}"
    return 0
  else
    echo "${RED}  ❌ You're offline or the connection is unstable${RESET}"
    return 1
  fi
}

# Custom Divider for section separation
fancy_line_divider() {
  # Total width of the divider
  local width=${1:-50}
  # Character or emoji to repeat
  local char="${2:-━}"
  local line=""
  while [[ ${(L)#line} -lt $width ]]; do
    line+="$char"
  done
  #print -Pn "%F{blue}"
  print -r -- "$line"
}

# Custom Text Box for section titles or highlights
fancy_title_box() {
  local content="$1"
  local padding=2
  local IFS=$'\n'
  local lines=($content)
  local max_length=0
  # Find the longest line for box width calculation
  for line in "${lines[@]}"; do
    (( ${#line} > max_length )) && max_length=${#line}
  done
  #print -Pn "%F{blue}"
  local box_width=$((max_length + padding * 2))
  local border_top="╔$(printf '═%.0s' $(seq 1 $box_width))╗"
  local border_bottom="╚$(printf '═%.0s' $(seq 1 $box_width))╝"
  echo "$border_top"
  for line in "${lines[@]}"; do
    local total_space=$((box_width - ${#line}))
    local left_space=$((total_space / 2))
    local right_space=$((total_space - left_space))
    # Print each line centered in the box
    printf "%*s%s%*s\n" "$left_space" "" "$line" "$right_space" ""
  done
  echo "$border_bottom"
}

# Custom Header for section titles
fancy_text_header() {
  local label="$1"
  local total_width=25
  local padding_width=$(( (total_width - ${#label} - 2) / 2 ))
  #print -Pn "%F{blue}"
  # Print a centered header with '=' padding
  printf '%*s' "$padding_width" '' | tr ' ' '='
  printf " %s " "$label"
  printf '%*s\n' "$padding_width" '' | tr ' ' '='
}

# Function to generate a random 5-character string (A-Z, 1-9)
generate_version_build() {
  local chars=( {A..Z} {1..9} )
  local num_chars=${#chars[@]}
  if (( num_chars == 0 )); then
    # echo "❌ Error: character array is empty!"
    return 1
  fi
  local str=""
  for _ in {1..5}; do
    str+="${chars[RANDOM % num_chars]}"
  done
  echo "$str"
}

# Function to get free disk space in bytes (for root volume)
get_free_space() {
  df -k / | tail -1 | awk '{print $4 * 1024}'
}

# Function to get simple uptime (returns "X days", "Y hours", etc.)
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

# Function to print info/hints about execution
print_hints() {
  local words=(${(z)1})  # split message into words
  local i=1
  print -Pn "\n%F{cyan} ⓘ "
  for word in $words; do
    print -n -P "$word "
    (( i++ % 20 == 0 )) && print
  done
  print -P "%f\n"
}

# Function to show Homebrew information (summary)
print_brew_info() {
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

# Function to print summary at the end of the script
print_clean_summary() {
  # Only show Results section if not exited by user
  if [[ "$USER_EXITED" -ne 1 ]]; then
    fancy_title_box "Clean Recap"
    echo ""
    echo "${CYAN}System Snapshot${RESET}${GREEN}"
    echo ""
    echo "  Model   $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    echo "  CPU     $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
    echo "  RAM     $(($(sysctl -n hw.memsize 2>/dev/null || echo 0)/1024/1024/1024)) GB"
    echo "  macOS   $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "  Uptime  $(get_uptime)"
    echo "${RESET}"
    echo "${CYAN}Here's what changed${RESET}"
    echo ""
    check_internet
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
      echo "${RED}  ❌ Homebrew not cleaned due to no install or no internet ${RESET}"
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
      echo "${RED}  ❌ Docker doesn’t seem to be installed on your system ${RESET}"

    # Results section
    # Measure memory and disk space freed
    space_after=$(get_free_space)
    space_freed=$(( space_after - space_before ))
    MEM_AFTER=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//')
    MEM_AFTER_MB=$(( MEM_AFTER * 4096 / 1024 / 1024 ))
    MEM_FREED_MB_RAW=$(echo "$MEM_AFTER_MB - $MEM_BEFORE_MB" | bc -l)
    MEM_FREED_MB=$(echo "$MEM_FREED_MB_RAW" | awk '{printf "%.3f", ($1 == int($1)) ? $1 : int($1)+1 + ($1-int($1))}')

    echo ""
    echo "${CYAN}Cleanup Outcome${RESET}"
    echo ""

    # Print memory freed
    if (( MEM_FREED_MB > 0 )); then
      echo "${GREEN}  RAM Cleaned  $MEM_FREED_MB Megabyte(MB)${RESET}"
    else
      echo "${YELLOW}  No additional RAM freed, possibly already optimized${RESET}"
    fi

    # Print disk space freed
    if (( space_freed > 0 )); then
      echo "${GREEN}  Disk Cleaned $(human_readable_space $space_freed)${RESET}"
    elif (( space_freed < 0 )); then
      echo "${YELLOW}  Disk space unchanged, possibly already optimized${RESET}"
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
  fi

  # Print Footer Contents
  echo ""
  echo "Log File $LOGFILE"
  echo "Script Version $VER"
  echo ""
  fancy_text_header " ${AUTHOR} © $(date +%Y) "
  echo ""

  # Flush filesystem buffers to ensure all changes are written to disk
  sync
  # Close file descriptors (for tee subshells)
  exec 1>&- 2>&-
  # Open the log file in Console (if available)
  if command -v open >/dev/null 2>&1; then
    open -a "Console" "${LOGFILE}" 2>/dev/null || echo "${YELLOW}Could not open log in Console.${RESET}"
  fi
}

# Function to show RAM summary (for display before/after purge)
print_ram_info() {
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

# ───── Script Starts ─────
clear

# Ensure the script is run with zsh
if [[ -z "$ZSH_VERSION" ]]; then
  echo "❌ ${RED}This clean-mac requires zsh to run. Please run it with zsh${RESET}" >&2
  USER_EXITED=1 # Set the flag so summary knows user exited
  print_clean_summary
  exit 0
fi

# Ensure the OS is macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ ${RED}Unsupported OS: clean-mac only works for macOS${RESET}" >&2
  USER_EXITED=1 # Set the flag so summary knows user exited
  print_clean_summary
  exit 1
fi

# Optimize globbing and file matching for safety and flexibility
setopt nullglob extended_glob

# Use stdbuf to ensure output is line-buffered for real-time logging
# Strip ANSI color codes and save clean output to log, while keeping colored output in terminal
# Need to install <brew install coreutils>
exec > >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' > "${LF}")) \
     2> >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "${LF}") >&2)

# Print the script Title in a fancy box with Details
fancy_title_box "$SCRIPT_BOX_TITLE"
echo "${CYAN}"
echo "$SCRIPT_DESCRIPTION"
echo "${RESET}${GREEN}"
echo "$DATE"
echo "Version $VER"
echo "Author  $AUTHOR"
echo "${RESET}"
echo "${GREEN}$SCRIPT_START_MSG${RESET}"
echo "${GREEN}$SCRIPT_SUDO_MSG${RESET}"
echo "${GREEN}$SCRIPT_TERMINAL_MSG${RESET}"
echo "${YELLOW}$SCRIPT_INTERNET_MSG${RESET}"
echo "${RED}$SCRIPT_EXIT_MSG${RESET}"
echo ""

# Print System Details
fancy_text_header "$SYSTEM_DETAILS_HEADER"
echo "${GREEN}"
echo "$MODEL_LABEL $MODEL"
echo "$CPU_LABEL $CPU"
echo "$RAM_LABEL $MEM"
echo "$STORAGE_LABEL $DISK_SIZE"
echo "$SERIAL_LABEL $SERIAL"
echo "$OS_NAME_LABEL $OS_NAME"
echo "$OS_VERSION_LABEL $OS_VERSION"
echo "$BUILD_LABEL $OS_BUILD"
echo "$UPTIME_LABEL $UPTIME"
echo "$INTERFACE_LABEL $ACTIVE_IF"
echo "$IP_LABEL $IP"
echo "$MAC_LABEL $MAC"
echo "${RESET}"

# Check for required dependencies before proceeding
check_dependencies

# Ask user for consent to continue (can exit here)
ask_user_consent

# Ask for sudo once at the start (will prompt for password if needed)
sudo -v

# Keep sudo session alive in the background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Measure free disk space before cleanup
space_before=$(get_free_space)

# Step 1: Clear User Caches
fancy_text_header "$CLEANING_CACHES_HEADER"
print_hints "$CLEANING_CACHES_HINT"
counter=0
find ~/Library/Caches -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  dirname=$(basename "$dir")
  # Skip protected cache folders
  if [[ ${protected_caches[(ie)$dirname]} -le ${#protected_caches} ]]; then
    echo "${YELLOW}Skipping Protected Cache Folder: $dir${RESET}"
  else
    echo "${BLUE}Cleaning User Cache: $dir${RESET}"
    sudo rm -rf "${dir:?}"/* 2>/dev/null || echo "${YELLOW}Warning: Failed to Clean $dir${RESET}"
    ((counter++))
  fi
done
if (( counter > 0 )); then
  echo "${GREEN}$USER_CACHE_CLEANED_MSG${RESET}"
  user_caches_cleaned=$counter
else
  echo "${YELLOW}$USER_CACHE_CLEAN_MSG${RESET}"
fi
echo ""

# Step 2: Clean iOS device Backups
fancy_text_header "$CLEANING_IOS_HEADER"
print_hints "$CLEANING_IOS_HINT"
if [[ -d "$IOS_BACKUP_DIR" ]]; then
  backup_count=$(find "$IOS_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
  if (( backup_count > 0 )); then
    echo "${BLUE}$IOS_BACKUP_FOUND_MSG $backup_count iOS device backup(s)${RESET}"
    sudo rm -rf "$IOS_BACKUP_DIR"/*
    echo "${GREEN}$IOS_BACKUP_REMOVED_MSG${RESET}"
    ios_backups_cleaned=$backup_count
  else
    echo "${YELLOW}$IOS_BACKUP_NONE_MSG${RESET}"
    ios_backups_cleaned=0
  fi
else
  echo "${YELLOW}$IOS_BACKUP_DIR_NONE_MSG${RESET}"
  ios_backups_cleaned=0
fi
echo ""

# Step 3: Clean Xcode DerivedData and device support
fancy_text_header "$CLEANING_XCODE_HEADER"
print_hints "$CLEANING_XCODE_HINT"
# Check for Xcode DerivedData
if [[ -d "$XCODE_DERIVED_DATA" ]]; then
  derived_count=$(find "$XCODE_DERIVED_DATA" -mindepth 1 -maxdepth 1 | wc -l | xargs)
  if [[ -n "$(ls -A "$XCODE_DERIVED_DATA")" ]]; then
    sudo rm -rf "$XCODE_DERIVED_DATA"/*
    echo "${GREEN}$XCODE_DERIVED_CLEANED_MSG ($derived_count items).${RESET}"
  else
    echo "${YELLOW}$XCODE_DERIVED_NONE_MSG${RESET}"
  fi
else
  echo "${YELLOW}$XCODE_DERIVED_NONE_MSG${RESET}"
fi
# Check for Xcode DeviceSupport
if [[ -d "$XCODE_DEVICE_SUPPORT" ]]; then
  device_support_count=$(find "$XCODE_DEVICE_SUPPORT" -mindepth 1 -maxdepth 1 | wc -l | xargs)
  sudo rm -rf "$XCODE_DEVICE_SUPPORT"/*
  echo "${GREEN}$XCODE_DEVICE_CLEANED_MSG ($device_support_count items)${RESET}"
else
  echo "${YELLOW}$XCODE_DEVICE_NONE_MSG${RESET}"
fi
echo ""

# Step 4: Clean Docker system (if installed)
fancy_text_header "$CLEANING_DOCKER_HEADER"
print_hints "$CLEANING_DOCKER_HINT"
if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes
  echo "${GREEN}$DOCKER_PRUNED_MSG${RESET}"
  docker_cleaned=1
else
  echo "${YELLOW}$DOCKER_NOT_INSTALLED_MSG${RESET}"
  docker_cleaned=0
fi
echo ""

# Step 5: Clean old System Logs older than 7 days
fancy_text_header "$CLEANING_LOGS_HEADER"
print_hints "$CLEANING_LOGS_HINT"
old_logs=("${(@f)$(sudo find "/private/var/log" -type f -mtime +7 2>/dev/null)}")
old_logs=(${old_logs:#""})  # Clean empty entries
if (( ${#old_logs[@]} == 0 )); then
  echo "${YELLOW}LOG is clean — $NO_FILES_TO_CLEAN_MSG${RESET}"
  logs_cleaned=0
else
  for file in "${old_logs[@]}"; do
    echo "${BLUE}Cleaning LOG File: $file${RESET}"
    sudo rm -f "$file"
  done
  echo "${GREEN}${#old_logs[@]} $LOG_FILE_CLEANED_MSG${RESET}"
  logs_cleaned=${#old_logs[@]}
fi
echo ""

# Step 6: Empty Trash/Bin for user, root, and all mounted volumes
fancy_text_header "$CLEANING_TRASH_HEADER"
print_hints "$CLEANING_TRASH_HINT"
trash_files=("${(@f)$(sudo ls -1 "${HOME}/.Trash" 2>/dev/null)}")
trash_files=(${trash_files:#""})
if (( ${#trash_files[@]} == 0 )); then
  echo "${YELLOW}$TRASH_CLEAN_MSG${RESET}"
else
  for file in "${trash_files[@]}"; do
    echo "${BLUE}Cleaning File: $file${RESET}"
  done
  osascript -e 'tell application "Finder" to empty trash' 2>/dev/null
  echo "${GREEN}${#trash_files[@]} $TRASH_FILE_CLEANED_MSG${RESET}"
  echo "${GREEN}$TRASH_USER_CLEANED_MSG${RESET}"
  trash_cleaned=${#trash_files[@]}
fi
system_trash="/private/var/root/.Trash"
if [[ -d "$system_trash" ]]; then
  if [[ -z "$(sudo ls -A "$system_trash" 2>/dev/null)" ]]; then
    echo "${YELLOW}$SYSTEM_TRASH_CLEAN_MSG${RESET}"
  else
    sudo rm -rf "$system_trash"/* 2>/dev/null
    echo "${GREEN}$SYSTEM_TRASH_CLEANED_MSG${RESET}"
    trash_cleaned=1
  fi
else
  echo "${YELLOW}$SYSTEM_TRASH_NOT_ACCESSIBLE_MSG${RESET}"
fi
found_volume=0
for volume in /Volumes/*; do
  trashes_dir="$volume/.Trashes"
  if [[ -d "$trashes_dir" ]]; then
    found_volume=1
    if [[ -z "$(sudo ls -A "$trashes_dir" 2>/dev/null)" ]]; then
      echo "${YELLOW}$TRASH_VOLUME_CLEAN_MSG $volume${RESET}"
    else
      sudo rm -rf "$trashes_dir"/* 2>/dev/null
      echo "${GREEN}$TRASH_VOLUME_CLEANED_MSG $volume${RESET}"
      trash_cleaned=1
    fi
  fi
done
if [[ $found_volume -eq 0 ]]; then
  echo "${YELLOW}$NO_MOUNTED_VOLUME_MSG${RESET}"
fi
echo ""

# Step 7: Clean Temporary Files older than 3 days
fancy_text_header "$CLEANING_FILES_HEADER"
print_hints "$CLEANING_FILES_HINT"
clean_temp_files "/tmp" "system temporary directory"
clean_temp_files "/var/tmp" "variable temporary directory"
clean_temp_files "$HOME/Library/Caches/TemporaryItems" "user temporary items"
echo ""

# Step 8: Clean old Downloads
fancy_text_header "$CLEANING_DOWNLOADS_HEADER"
print_hints "$CLEANING_DOWNLOADS_HINT"
old_files=("${(@f)$(sudo find "${HOME}/Downloads" -type f -mtime +7 2>/dev/null)}")
old_files=(${old_files:#""})
if (( ${#old_files[@]} == 0 )); then
  echo "${YELLOW}$DOWNLOADS_CLEAN_MSG${RESET}"
  downloads_cleaned=0
else
  for file in "${old_files[@]}"; do
    echo "${BLUE}Cleaning File: $file${RESET}"
    rm -f "$file"
  done
  echo "${GREEN}${#old_files[@]} $DOWNLOADS_FILE_CLEANED_MSG${RESET}"
  downloads_cleaned=${#old_files[@]}
fi
echo ""

# Step 9: Homebrew Cleanup
fancy_text_header "$CLEANING_HOMEBREW_HEADER"
print_hints "$CLEANING_HOMEBREW_HINT"
# Check for stable internet connectivity before running Homebrew cleanup
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    print_brew_info
    echo "${BLUE}Cleaning Homebrew${RESET}"
    brew cleanup -s
    echo "${RESET}${GREEN}$HOMEBREW_CLEANED_MSG${RESET}"
    homebrew_cleaned=1
  else
    echo "${YELLOW}$HOMEBREW_NOT_INSTALLED_MSG${RESET}"
    homebrew_cleaned=0
  fi
else
  echo "${YELLOW}$HOMEBREW_CLEANUP_SKIPPED_MSG${RESET}"
  homebrew_cleaned=0
fi
echo ""

# Step 10: Purge inactive memory (if possible)
fancy_text_header "$CLEANING_MEMORY_HEADER"
print_hints "$CLEANING_MEMORY_HINT"
print_ram_info
if command -v purge >/dev/null 2>&1; then
  sudo purge
  sleep 1
  echo "${GREEN}$PURGE_CLEANED_MSG${RESET}"
  memory_purged=1
else
  echo "${RED}$PURGE_NOT_AVAILABLE_MSG${RESET}"
  memory_purged=0
fi
echo ""

# Print the cleanup summary at the end
SCRIPT_END_TIME=$(date +%s)
print_clean_summary

exit 0