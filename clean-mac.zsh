#!/bin/zsh

# ------------------------------------------------------------------------------
# Mac Cleanup Script
# Author: Prasit Chanda
# macOS: Sequoia
# Version: 1.0.0
# Description: Safely removes unused system/user cache, logs, temp files,
#              empties trash, clears Homebrew leftovers, and reports space freed.
# Last Updated: 2025-06-04
# ------------------------------------------------------------------------------

clear

# Colors for output
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
RED=$'\e[1;31m'
BLUE=$'\e[1;34m'
CYAN=$'\e[1;36m'
RESET=$'\e[0m'

# Function to get free disk space in bytes
get_free_space() {
  df -k / | tail -1 | awk '{print $4 * 1024}'
}

# Function to convert bytes to human-readable format
human_readable_space() {
  local bytes=$1
  if (( bytes < 1024 )); then
    echo "${bytes} B"
  elif (( bytes < 1024 * 1024 )); then
    echo "$(( bytes / 1024 )) KB"
  elif (( bytes < 1024 * 1024 * 1024 )); then
    echo "$(( bytes / 1024 / 1024 )) MB"
  else
    echo "$(( bytes / 1024 / 1024 / 1024 )) GB"
  fi
}

echo "${CYAN}Starting cleanup for your MacBook Air M4 (macOS Sequoia)...${RESET}"
echo "${YELLOW}You may be prompted for your password to authorize system operations.${RESET}"
echo ""

# Measure free disk space before
space_before=$(get_free_space)

# Ask for sudo once at the start
sudo -v

# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Step 1: Clear user caches
echo "${BLUE}Step 1:${RESET} Clearing user cache files (excluding protected folders)..."
for dir in ~/Library/Caches/*; do
  case "$(basename "$dir")" in
    CloudKit|com.apple.CloudPhotosConfiguration|com.apple.Safari.SafeBrowsing)
      echo "${YELLOW}Skipping protected cache folder: $dir${RESET}"
      ;;
    *)
      rm -rf "$dir" 2>/dev/null || echo "${RED}Warning: Failed to remove $dir${RESET}"
      ;;
  esac
done
echo "${GREEN}User caches cleared.${RESET}"
echo ""

# Step 2: Remove old system logs
echo "${BLUE}Step 2:${RESET} Removing system log files older than 7 days..."
sudo find /private/var/log -type f -mtime +7 -exec rm -f {} \;
echo "${GREEN}Old system logs removed.${RESET}"
echo ""

# Step 3: Empty Trash
echo "${BLUE}Step 3:${RESET} Emptying your Trash folder..."
rm -rf ~/.Trash/* 2>/dev/null || echo "${RED}Warning: Could not fully empty Trash.${RESET}"
echo "${GREEN}Trash emptied.${RESET}"
echo ""

# Step 4: Clean temporary files older than 3 days
echo "${BLUE}Step 4:${RESET} Removing temporary files older than 3 days..."
sudo find /tmp -type f -mtime +3 -exec rm -f {} \;
sudo find /var/tmp -type f -mtime +3 -exec rm -f {} \;
echo "${GREEN}Temporary files removed.${RESET}"
echo ""

# Step 5: Clean old Downloads
echo "${BLUE}Step 5:${RESET} Removing files older than 30 days in Downloads..."
find ~/Downloads -type f -mtime +30 -exec rm -f {} \;
echo "${GREEN}Old files in Downloads removed.${RESET}"
echo ""

# Step 6: Homebrew cleanup
echo "${BLUE}Step 6:${RESET} Cleaning up Homebrew cache and outdated packages..."
if command -v brew >/dev/null 2>&1; then
  brew cleanup -s
  echo "${GREEN}Homebrew cleanup complete.${RESET}"
else
  echo "${YELLOW}Homebrew not installed. Skipping this step.${RESET}"
fi
echo ""

# Step 7: Purge inactive memory (if possible)
echo "${BLUE}Step 7:${RESET} Attempting to purge inactive memory..."
if command -v purge >/dev/null 2>&1; then
  sudo purge
  echo "${GREEN}Inactive memory purged.${RESET}"
else
  echo "${YELLOW}'purge' command not available. Skipping.${RESET}"
fi
echo ""

# Measure free disk space after
space_after=$(get_free_space)
space_freed=$(( space_after - space_before ))

# Display result
echo "${CYAN}Cleanup complete.${RESET}"

if (( space_freed > 0 )); then
  echo "${GREEN}Disk space freed: $(human_readable_space $space_freed)${RESET}"
elif (( space_freed < 0 )); then
  echo "${YELLOW}Note: Disk space decreased by $(human_readable_space $(( -space_freed ))) — likely due to background system activity.${RESET}"
else
  echo "${YELLOW}No change in free disk space detected.${RESET}"
fi
echo "Version 1.0.0-2025060423"
echo "Prasit Chanda © $(date +%Y)"
