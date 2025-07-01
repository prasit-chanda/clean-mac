#!/bin/zsh

# Stricter error handling: exit on error, unset variable, or failed pipeline
#set -euo pipefail

# Optimize globbing and file matching for safety and flexibility
setopt nullglob extended_glob localoptions no_nomatch

# ------------------------------------------------------------------------------
# clean-mac.zsh — macOS cleanup utility
# Author: Prasit Chanda
# Version: 2.0.0-20250702-P60AS
# License: Apache-2.0
# Description: Cleans caches, logs, temp files, old downloads, Homebrew leftovers
# Usage: Run in Terminal with zsh. Requires: Homebrew, coreutils, osascript
# ------------------------------------------------------------------------------

# ───── Static Colors Variables ─────
BLUE=$'\e[94m'     # Bright Blue - Info/Action
CYAN=$'\e[96m'     # Bright Cyan - General Info
GREEN=$'\e[92m'    # Bright Green - Success
RED=$'\e[91m'      # Bright Red - Error/Failure
RESET=$'\e[0m'     # Reset all attributes
YELLOW=$'\e[93m'   # Bright Yellow - Warning/Skip

# ───── Global Variables ─────
ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface: / {print $2}')
: ${ACTIVE_IF:="No active interface"}
AUTHOR="Prasit Chanda"
CPU=$(sysctl -n machdep.cpu.brand_string)
DNS_SERVER="1.1.1.1"
DATE=$(date "+%a, %d %b %Y %I:%M:%S %p")
MAIN_DISK=$(diskutil info / | awk -F: '/Device Node/ {print $2}' | xargs)
DISK_SIZE=$(diskutil info "$MAIN_DISK" | awk -F: '/Disk Size/ {print $2}' | cut -d'(' -f1 | xargs)
TS=$(date +"%Y%m%d%H%M%S")
LF="clean-mac-${TS}.log"
WD=$(pwd)
LOGFILE="${WD}/${LF}"
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
OS_BUILD=$(sw_vers -buildVersion)
OS_NAME=$(sw_vers -productName)
OS_VERSION=$(sw_vers -productVersion)
SCRIPT_START_TIME=$(date +%s)
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ { print $4 }')
UPTIME=$(uptime | cut -d ',' -f1 | xargs)
USER_EXITED=0
IOS_BACKUP_DIR="${HOME}/Library/Application Support/MobileSync/Backup"
IP=$(ipconfig getifaddr "$ACTIVE_IF" 2>/dev/null)
if [[ -z "$IP" ]]; then
  IP="IP not found"
fi
VER="2.0.0-20250702-P60AS"
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
XCODE_DEVICE_SUPPORT="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"
protected_caches=(
  "CloudKit"
  "com.apple.CloudPhotosConfiguration"
  "com.apple.Safari.SafeBrowsing"
  "com.apple.WebKit.WebContent"
  "com.apple.Messages"
)

# ───── Static Text Variables ─────
CLEANING_CACHES_HEADER="Caches"
CLEANING_CACHES_HINT="Because your Mac clearly enjoys hoarding nonsense"
CLEANING_DOCKER_HEADER="Docker"
CLEANING_DOCKER_HINT="Time to nuke those containers you totally meant to delete"
CLEANING_DOWNLOADS_HEADER="Downloads"
CLEANING_DOWNLOADS_HINT="Old installers, cat memes, and zip files you never opened"
CLEANING_FILES_HEADER="Files"
CLEANING_FILES_HINT="Temporary junk that somehow thinks it's permanent"
CLEANING_HOMEBREW_HEADER="Homebrew"
CLEANING_HOMEBREW_HINT="Installs fast, leaves crumbs everywhere. Let's clean that up"
CLEANING_IOS_HEADER="Backups"
CLEANING_IOS_HINT="Say goodbye to iPhone backups older than your last breakup"
CLEANING_LOGS_HEADER="Logs"
CLEANING_LOGS_HINT="No one’s reading these unless you’re in IT support hell"
CLEANING_MEMORY_HEADER="Memory"
CLEANING_MEMORY_HINT="Let’s free up some RAM and pretend it makes things faster"
CLEANING_TRASH_HEADER="Trash"
CLEANING_TRASH_HINT="Taking out digital garbage—because you won’t"
CLEANING_XCODE_HEADER="Xcode"
CLEANING_XCODE_HINT="Xcode builds mountains of trash. Let’s demolish them"
CLEANUP_MSG="Clean Recap"
DD_NONE="  ● No Xcode DerivedData found to clean"
DEPENDENCIES_HEADER="Dependencies"
DEPENDENCIES_NOT_MSG="Missing stuff. Good luck running anything"
DEPENDENCIES_OK_MSG="Everything’s where it should be. That’s rare"
DISK_SPACE_UNCHANGED_MSG="  Disk space didn’t budge. You might be *too* clean"
DL_NONE="  ● Downloads are clean. Who even are you?"
DOCKER_NONE="  ✖ No Docker. Skipped that drama"
DOCKER_NOT_INSTALLED_MSG="Docker’s not here — guess we can skip that drama"
DOCKER_OK="  ✓ Docker’s junk is gone"
DOCKER_PRUNED_MSG="Docker junk has been sent to the void"
DOWNLOADS_CLEAN_MSG="Wow, nothing to delete. Miracles happen"
DOWNLOADS_FILE_CLEANED_MSG="Old downloads thrown out. You're welcome"
DS_NONE="  ● Xcode DeviceSupport folder is clean too"
HOMEBREW_CLEANED_MSG="Homebrew leftovers swept. That felt good"
HOMEBREW_CLEANUP_SKIPPED_MSG="Skipped. No Homebrew or no internet. Not your day"
HOMEBREW_CLEAN_HEADER_MSG="Cleaning Homebrew"
HOMEBREW_INFO_HEADER_MSG="Homebrew Information"
HOMEBREW_INSTALL_ATTEMPT_MSG="Trying to install Homebrew. Brace yourself."
HOMEBREW_INSTALL_COREUTIL_ASK_MSG="Install coreutils via Homebrew? (y/n) "
HOMEBREW_INSTALL_COREUTIL_FAIL_MSG="Tried. Failed. coreutils still missing."
HOMEBREW_INSTALL_FAILED_MSG="Nope. Homebrew install failed. Do it manually: https://brew.sh/"
HOMEBREW_INSTALL_SUCCESS_MSG="Homebrew is in. Shocking, right?"
HOMEBREW_INSTALLED_COREUTIL_DENIAL_MSG="No coreutils. You’ll need to DIY it"
HOMEBREW_INSTALLED_COREUTIL_MSG="coreutils is installed. You fancy now"
HOMEBREW_INSTALLED_MSG="Homebrew's already lurking in your system"
HOMEBREW_NONE="  ✖ Couldn’t clean Homebrew. It's either missing or offline"
HOMEBREW_NOT_INSTALLED_COREUTIL_MSG="coreutils is missing—blame Homebrew"
HOMEBREW_NOT_INSTALLED_MSG="No Homebrew? Who even are you?"
HOMEBREW_OK="  ✓ Homebrew mess cleaned up"
INTERNET_AVAILABLE="✓ Active"
INTERNET_AVAILABLE_MSG="  ✓ Internet works. Celebrate the small things"
INTERNET_UNAVAILABLE="✖ Down"
INTERNET_UNAVAILABLE_MSG="  ✖ Internet’s down. So is your productivity"
IOS_BACKUP_DIR_NONE_MSG="What backup folder? It doesn’t even exist"
IOS_BACKUP_FOUND_MSG="Look at you, hiding those old iOS backups"
IOS_BACKUP_NONE_MSG="No iOS junk found. Gold star"
IOS_BACKUP_REMOVED_MSG="Old backups deleted. Your phone won’t miss them"
IOS_NONE="  ● No iOS baggage found. You’re evolving"
LOG_CLEAN_MSG="Logs already cleaned. Suspiciously efficient"
LOG_FILE_CLEANED_MSG="Old logs destroyed. We made history disappear"
LOG_NONE="  ● No old logs. This feels suspicious"
MEM_NONE="  ● Nothing to free up — RAM’s chill"
MEM_OK="  ✓ Memory cleared like a champ"
MEMORY_SPACE_UNCHANGED_MSG="No change in memory space. Already efficient, or just stubborn"
NO_FILES_TO_CLEAN_MSG="You’re oddly tidy today. Nice"
NO_MOUNTED_VOLUME_MSG="No extra volumes found. Boring"
NOT_ZSH_MSG="You're not using Zsh? Rookie move"
OSASCRIPT_AVAILABLE_MSG="osascript is available. Let’s abuse it"
OSASCRIPT_INSTALL_ASK_MSG="Install osascript via Homebrew? (y/n) "
OSASCRIPT_INSTALL_CANT_MSG="osascript can’t be installed automatically. You get to suffer"
OSASCRIPT_INSTALL_FAILED_MSG="Failed to install osascript. You’re on your own"
OSASCRIPT_INSTALL_SKIPPED_MSG="Skipped osascript install. Manual mode it is"
OSASCRIPT_INSTALL_SUCCESS_MSG="osascript installed. Cue applause"
OSASCRIPT_NOT_INSTALLED_MSG="osascript missing — this Mac is extra"
PROMPT_USER_CONSENT_APPROVAL="✓ $(whoami) approved this chaos. Proceeding"
PROMPT_USER_CONSENT_DENIAL="✖ $(whoami) backed out. Quitting politely"
PROMPT_USER_CONSENT_MSG="%F{11}Let this script wreak some havoc? (y/n) %f"
PROMPT_VALIDATE_MSG="It’s yes or no. Not rocket science"
PURGE_CLEANED_MSG="RAM cleared. Your Mac just sighed in relief"
PURGE_NOT_AVAILABLE_MSG="'purge' command missing. How 2009 of you"
SCRIPT_BOX_TITLE="clean-mac.zsh"
SCRIPT_DESCRIPTION="One script to wipe it all — caches, logs, downloads, guilt"
SCRIPT_EXIT_MSG=" ● Press ⌃ + C anytime if you lose your nerve"
SCRIPT_INTERNET_MSG=" ● Needs internet. Don’t argue"
SCRIPT_START_MSG="Running clean-mac — this might hurt"
SCRIPT_SUDO_MSG=" ● Might ask for your password. Don’t panic"
SCRIPT_TERMINAL_MSG=" ● Run this in macOS native Terminal, not Notes. Please"
SUMMARY_SUB_TITLE_1_MSG="System Snapshot"
SUMMARY_SUB_TITLE_2_MSG="What Got Nuked"
SUMMARY_SUB_TITLE_3_MSG="Aftermath"
SYSTEM_DETAILS_HEADER="System"
SYSTEM_TRASH_CLEAN_MSG="System Trash is already pristine. Wow"
SYSTEM_TRASH_CLEANED_MSG="System Trash obliterated"
SYSTEM_TRASH_NOT_ACCESSIBLE_MSG="macOS says no. Can't touch System Trash"
TRASH_CLEAN_MSG="User Trash emptied. Like your will to adult"
TRASH_FILE_CLEANED_MSG="Deleted. No tears shed"
TRASH_NONE="  ● Trash is already empty. Have you been cleaning?"
TRASH_USER_CLEANED_MSG="Trash taken out like it’s garbage day"
TRASH_VOLUME_CLEAN_MSG="Volume Trash is clean. For now"
TRASH_VOLUME_CLEANED_MSG="Volume Trash removed. Sweet emptiness"
UNSUPPORTED_OS_MSG="✖ Nope. This only runs on macOS. Nice try"
USER_CACHE_CLEAN_MSG="User cache already empty. Who are you?"
USER_CACHE_CLEANED_MSG="User cache wiped. That felt productive"
USER_CACHE_NONE="  ● No junk in user cache. Color me surprised"
XCODE_DERIVED_CLEANED_MSG="DerivedData gone. So much pointless build junk"
XCODE_DERIVED_NONE_MSG="Nothing to clean. Shocking for Xcode"
XCODE_DEVICE_CLEANED_MSG="Device leftovers cleaned. So long, simulators"
XCODE_DEVICE_NONE_MSG="No devices to clean. Go you"

# ───── Custom Methods ─────

# This function asks the user for consent to continue
ask_user_consent() {
  while true; do
    print -nP "$PROMPT_USER_CONSENT_MSG"
    read answer
    echo ""
    case "$answer" in
      [yY][eE][sS]|[yY])
        echo "${GREEN}$PROMPT_USER_CONSENT_APPROVAL${RESET}"
        echo ""
        break
        ;;
      [nN][oO]|[nN])
        echo "${RED}$PROMPT_USER_CONSENT_DENIAL${RESET}"
        echo ""
        USER_EXITED=1       # Set the flag so summary knows user exited
        print_clean_summary # Print summary (will skip results if exited)
        exit 0
        ;;
      *)
        echo "${YELLOW}$PROMPT_VALIDATE_MSG${RESET}"
        ;;
    esac
  done
}

# Cleanup function: kills background jobs and syncs log file
cleanup() {
  trap - EXIT
  kill $(jobs -p) 2>/dev/null
  sync
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
    echo "${RED}$HOMEBREW_NOT_INSTALLED_MSG${RESET}"
    echo "${YELLOW}$HOMEBREW_INSTALL_ATTEMPT_MSG${RESET}"
    # Try to install Homebrew non-interactively
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if command -v brew >/dev/null 2>&1; then
      echo "${GREEN}$HOMEBREW_INSTALL_SUCCESS_MSG${RESET}"
    else
      echo "${RED}$HOMEBREW_INSTALL_FAILED_MSG${RESET}"
      dependencies_status=1
    fi
  else
    echo "${GREEN}$HOMEBREW_INSTALLED_MSG${RESET}"
  fi
  # Check coreutils via Homebrew
  if ! brew list coreutils >/dev/null 2>&1; then
    echo "${RED}$HOMEBREW_NOT_INSTALLED_COREUTIL_MSG${RESET}"
    # Ask user if they want to install coreutils
    while true; do
      print -nP "${YELLOW}$HOMEBREW_INSTALL_COREUTIL_ASK_MSG${RESET}"
      read coreutil_answer
      case "$coreutil_answer" in
        [yY][eE][sS]|[yY])
          brew install coreutils
          if brew list coreutils >/dev/null 2>&1; then
            echo "${GREEN}$HOMEBREW_INSTALLED_COREUTIL_MSG${RESET}"
          else
            echo "${RED}$HOMEBREW_INSTALL_COREUTIL_FAIL_MSG${RESET}"
            dependencies_status=1
          fi
          break
          ;;
        [nN][oO]|[nN])
          echo "${YELLOW}$HOMEBREW_INSTALLED_COREUTIL_DENIAL_MSG${RESET}"
          dependencies_status=1
          break
          ;;
        *)
          echo "${YELLOW}$PROMPT_VALIDATE_MSG${RESET}"
          ;;
      esac
    done
  else
    echo "${GREEN}$HOMEBREW_INSTALLED_COREUTIL_MSG${RESET}"
  fi
  # Check osascript (should always exist on macOS)
  if ! command -v osascript >/dev/null 2>&1; then
    echo "${RED}$OSASCRIPT_NOT_INSTALLED_MSG${RESET}"
    # Try to install osascript via Homebrew if possible, else prompt user
    if command -v brew >/dev/null 2>&1 && brew search osascript | grep -q osascript; then
      while true; do
        print -nP "${YELLOW}$OSASCRIPT_INSTALL_ASK_MSG${RESET}"
        read osascript_answer
        case "$osascript_answer" in
          [yY][eE][sS]|[yY])
            brew install osascript
            if command -v osascript >/dev/null 2>&1; then
              echo "${GREEN}$OSASCRIPT_INSTALL_SUCCESS_MSG${RESET}"
            else
              echo "${RED}$OSASCRIPT_INSTALL_FAILED_MSG${RESET}"
              dependencies_status=1
            fi
            break
            ;;
          [nN][oO]|[nN])
            echo "${YELLOW}$OSASCRIPT_INSTALL_SKIPPED_MSG${RESET}"
            dependencies_status=1
            break
            ;;
          *)
            echo "${YELLOW}$PROMPT_VALIDATE_MSG${RESET}"
            ;;
        esac
      done
    else
      echo "${YELLOW}$OSASCRIPT_INSTALL_CANT_MSG${RESET}"
      dependencies_status=1
    fi
  else
    echo "${GREEN}$OSASCRIPT_AVAILABLE_MSG${RESET}"
  fi
  # Final decision
  if [[ $dependencies_status -eq 0 ]]; then
    echo "${GREEN}$DEPENDENCIES_OK_MSG${RESET}"
  else
    echo "${RED}$DEPENDENCIES_NOT_MSG${RESET}"
    echo ""
  fi
  echo ""
}

# Function to check if the user has an internet connection
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
  #print -Pn "%F{blue}"
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
  #print -Pn "%F{blue}"
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
}

# This function prints a centered header with padding
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
# This is used for unique scan IDs
# It generates a string like "A1B2C-3D4E-F5G6-H7I8-J9K0"
generate_random_string() {
  local chars=( {A..Z} {0..9})
  local num_chars=${#chars[@]}
  if (( num_chars == 0 )); then
    # echo "✖ Error: character array is empty!"
    return 1
  fi
  local str=""
  for i in {1..25}; do
    str+="${chars[RANDOM % num_chars]}"
    if (( i % 5 == 0 && i != 25 )); then
      str+="-"
    fi
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
  echo "${BLUE}$HOMEBREW_INFO_HEADER_MSG${RESET}"
  # simple facts
  local brew_path=${commands[brew]}
  local brew_version=$(brew --version | head -n1)
  # one JSON hit for everything installed 
  local json_installed
  json_installed=$(brew info --json=v2 --installed)          
  # you need jq (brew install jq) — it’s orders of magnitude faster than 4–5 more brew calls
  local installed_formulae=$(jq '.formulae | length' <<<"$json_installed")
  local installed_casks=$(jq '.casks    | length' <<<"$json_installed")
  # one JSON hit for everything outdated
  local json_outdated
  json_outdated=$(brew outdated --json=v2)                  
  local outdated_formulae=$(jq '.formulae | length' <<<"$json_outdated")
  local outdated_casks=$(jq '.casks    | length' <<<"$json_outdated")
  # last Git update (cheap)
  # Just stat the FETCH_HEAD rather than walking history
  local brew_repo=$(brew --repository)
  local fetch_head="$brew_repo/.git/FETCH_HEAD"
  local last_update
  local last_update=$(git -C "$(brew --repo)" log -1 --format="%cd" --date=short 2>/dev/null || echo "Unavailable")
  # disk usage  
  local cellar_path=$(brew --cellar)
  local disk_usage=$(du -sh "$cellar_path" 2>/dev/null | awk '{print $1}')
  # health check
  # `brew doctor --quiet` exits 0 if OK, 1 if warnings — no parsing needed
  brew doctor --quiet &>/dev/null
  local doctor_status=$([[ $? -eq 0 ]] && echo "OK" || echo "Warnings detected")
  # Brew services running count
  local services_running=$(brew services list 2>/dev/null | awk '$2 == "started" {count++} END {print count+0}')
  # Print the Homebrew summary
  echo "${GREEN}"
  echo "Path                  : $brew_path"
  echo "Version               : $brew_version"
  echo "Installed Formulae    : $installed_formulae"
  echo "Installed Casks       : $installed_casks"
  echo "Outdated Formulae     : $outdated_formulae"
  echo "Outdated Casks        : $outdated_casks"
  echo "Last Update           : $last_update"
  echo "Disk Usage    : ${disk_usage:-Unknown}"
  echo "Brew Doctor Status    : $doctor_status"
  echo "Brew Services Running : $services_running"
  echo "${RESET}"
}

# Function to print summary at the end of the script
print_clean_summary() {
  # Only show Results section if not exited by user
  if [[ "$USER_EXITED" -ne 1 ]]; then
    fancy_title_box "$CLEANUP_MSG"
    echo ""
    echo "${CYAN}$SUMMARY_SUB_TITLE_1_MSG${RESET}${GREEN}"
    echo ""
    echo "  Model   $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    echo "  CPU     $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
    echo "  RAM     $(($(sysctl -n hw.memsize 2>/dev/null || echo 0)/1024/1024/1024)) GB"
    echo "  macOS   $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "  Uptime  $(get_uptime)"
    echo "${RESET}"
    echo "${CYAN}$SUMMARY_SUB_TITLE_2_MSG${RESET}"
    echo ""
    check_internet
    [[ $user_caches_cleaned -gt 0 ]] && \
      echo "${GREEN}  ✓ User caches cleaned ($user_caches_cleaned folders) ${RESET}" || \
      echo "${YELLOW}$USER_CACHE_NONE${RESET}"
    [[ $logs_cleaned -gt 0 ]] && \
      echo "${GREEN}  ✓ Old log files cleaned ($logs_cleaned files) ${RESET}" || \
      echo "${YELLOW}$LOG_NONE${RESET}"
    [[ $trash_cleaned -gt 0 ]] && \
      echo "${GREEN}  ✓ Trash cleaned ($trash_cleaned files) ${RESET}" || \
      echo "${YELLOW}$TRASH_NONE${RESET}"
    [[ $downloads_cleaned -gt 0 ]] && \
      echo "${GREEN}  ✓ Old Downloads cleaned ($downloads_cleaned files) ${RESET}" || \
      echo "${YELLOW}$DL_NONE${RESET}"
    [[ $homebrew_cleaned == 1 ]] && \
      echo "${GREEN}$HOMEBREW_OK${RESET}" || \
      echo "${RED}$HOMEBREW_NONE${RESET}"
    [[ $memory_purged == 1 ]] && \
      echo "${GREEN}$MEM_OK${RESET}" || \
      echo "${YELLOW}$MEM_NONE${RESET}"
    [[ ${ios_backups_cleaned:-0} -gt 0 ]] && \
      echo "${GREEN}  ✓ iOS device backups cleaned ($ios_backups_cleaned) ${RESET}" || \
      echo "${YELLOW}$IOS_NONE${RESET}"
    [[ ${derived_count:-0} -gt 0 ]] && \
      echo "${GREEN}  ✓ Xcode DerivedData cleaned ($derived_count items) ${RESET}" || \
      echo "${YELLOW}$DD_NONE${RESET}"
    [[ ${device_support_count:-0} -gt 0 ]] && \
      echo "${GREEN}  ✓ Xcode DeviceSupport cleaned ($device_support_count items) ${RESET}" || \
      echo "${YELLOW}$DS_NONE${RESET}"
    [[ ${docker_cleaned:-0} -eq 1 ]] && \
      echo "${GREEN}$DOCKER_OK${RESET}" || \
      echo "${RED}$DOCKER_NONE${RESET}"
    # Results section
    # Measure memory and disk space freed
    space_after=$(get_free_space)
    space_freed=$(( space_after - space_before ))
    MEM_AFTER=$(vm_stat | awk '/Pages free/ { print $3 }' | sed 's/\\.//')
    MEM_AFTER_MB=$(( MEM_AFTER * 4096 / 1024 / 1024 ))
    MEM_FREED_MB_RAW=$(echo "$MEM_AFTER_MB - $MEM_BEFORE_MB" | bc -l)
    MEM_FREED_MB=$(echo "$MEM_FREED_MB_RAW" | awk '{printf "%.3f", ($1 == int($1)) ? $1 : int($1)+1 + ($1-int($1))}')
    echo ""
    echo "${CYAN}$SUMMARY_SUB_TITLE_3_MSG${RESET}"
    echo ""
    # Print memory freed
    if (( MEM_FREED_MB > 0 )); then
      echo "${GREEN}  RAM Cleaned  $MEM_FREED_MB Megabyte(MB)${RESET}"
    else
      echo "${YELLOW}$MEMORY_SPACE_UNCHANGED_MSG${RESET}"
    fi
    # Print disk space freed
    if (( space_freed > 0 )); then
      echo "${GREEN}  Disk Cleaned $(human_readable_space $space_freed)${RESET}"
    elif (( space_freed < 0 )); then
      echo "${YELLOW}$DISK_SPACE_UNCHANGED_MSG${RESET}"
    else
      echo "${YELLOW}$DISK_SPACE_UNCHANGED_MSG${RESET}"
    fi
    # Add execution time
    SCRIPT_END_TIME=$(date +%s)
    if [[ -n "$SCRIPT_START_TIME" && -n "$SCRIPT_END_TIME" ]]; then
      local elapsed=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
      local hours=$((elapsed / 3600))
      local mins=$(( (elapsed % 3600) / 60 ))
      local secs=$((elapsed % 60))
      local formatted_time=$(printf "%02d:%02d:%02d" $hours $mins $secs)
      echo "${GREEN}  Script Execution Time ${formatted_time}${RESET}"
    fi
    echo ""
  fi
  # Print Footer Contents
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
  echo "${GREEN}"
  echo "Total RAM  : ${total_gb} GB"
  echo "Free RAM   : ${free_mb} MB"
  echo "Active     : ${active_mb} MB"
  echo "Inactive   : ${inactive_mb} MB"
  echo "Wired      : ${wired_mb} MB"
  echo "Compressed : ${compressed_mb} MB"
  echo "Memory     : ${pressure} FREE"
  echo "${RESET}"
}

# ───── Script Starts ─────
clear

# Create log file and redirect output
exec > >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' > "${LF}")) \
     2> >(stdbuf -oL tee >(stdbuf -oL sed 's/\x1B\[[0-9;]*[JKmsu]//g' >> "${LF}") >&2)

# Ensure the script is run with zsh
if [[ -z "$ZSH_VERSION" ]]; then
  echo "${RED}$NOT_ZSH_MSG${RESET}" >&2
  USER_EXITED=1
  print_clean_summary
  exit 0
fi

# Ensure the OS is macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "${RED}$UNSUPPORTED_OS_MSG${RESET}" >&2
  USER_EXITED=1
  print_clean_summary
  exit 0
fi

# Ensure the script is run with sudo privileges
trap cleanup EXIT INT TERM

# Print the script Title in a fancy box with Details
fancy_title_box "$SCRIPT_BOX_TITLE"
echo "${CYAN}"
echo "$SCRIPT_DESCRIPTION"
echo "${RESET}${GREEN}"
echo "$DATE"
echo "SCAN ID $(generate_random_string)"
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
echo "Model     $MODEL"
echo "CPU       $CPU"
echo "RAM       $MEM"
echo "Storage   $DISK_SIZE"
echo "Serial    $SERIAL"
echo "OS        $OS_NAME"
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
if ping -c 1 -W 2 $DNS_SERVER >/dev/null 2>&1; then
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

# Ensure all background jobs are killed on exit
trap 'kill $(jobs -p) 2>/dev/null' EXIT

exit 0