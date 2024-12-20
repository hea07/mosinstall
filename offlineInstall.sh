#!/bin/bash

# COLORS
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define variables
USB_DRIVE="/Users/user.name/Downloads/USBdrive"
SOURCE_FOLDER="$USB_DRIVE/Offlineinstaller" 
DEST_FOLDER="/tmp/Offlineinstaller"
LOG_FILE="/var/log/offlineinstaller.log"

# Function to display progress using rsync
copy_with_progress() {
    # need to look better
    rsync -ahz --progress "$SOURCE_FOLDER/" "$DEST_FOLDER/"
}

# Function to echoDate date
function echoDate() {
    echo "$(date "+%a %h %d %H:%M:%S") | $1"
}

# Check if script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
  echoDate "This script requires sudo privileges. Please run with sudo."
  exit 1
fi

# Check if USB drive is mounted
if [ ! -d "$USB_DRIVE" ]; then
  echoDate "USB drive not found at $USB_DRIVE. Please check the mount point."
  exit 1
fi

# Start logging
echoDate "Starting installation process at $(date)" > "$LOG_FILE"

# Step 1: Copy the folder with a real progress indicator
echoDate "Copying folder from USB to local machine..." | tee -a "$LOG_FILE"
if ! copy_with_progress; then
    echoDate "Error copying files. Please check the USB drive and try again." | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}############################${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}Copy completed successfully!${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}############################${NC}" | tee -a "$LOG_FILE"

# Step 2: Eject the USB drive
echoDate "Ejecting USB drive..." | tee -a "$LOG_FILE"
diskutil eject "$USB_DRIVE" | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}##############################################################${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}Failed to eject USB drive. You may need to remove it manually.${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}##############################################################${NC}" | tee -a "$LOG_FILE"
else

    # TODO prints sucess everytime, even when theres no disk
    echo -e "${GREEN}###################################${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}>>>>USB drive ejected successfully.${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}###################################${NC}" | tee -a "$LOG_FILE"
fi

# check if there a zip files in the folder and unzip
for zip_file in "$DEST_FOLDER"/*.zip; do
    if [[ -f "$zip_file" ]]; then # Check if the file exists
        zip_dir=$(dirname "$zip_file")
        unzipped_name=$(basename "$zip_file" .zip)
        echoDate "Unzipping $zip_file to $zip_dir"
        unzip -o -q "$zip_file" -d "$zip_dir" # Extract to the same directory
        /bin/rm -f "$zip_file"
        echoDate "Unzipped to $zip_dir/$unzipped_name"
    else
        echoDate "No ZIP files found in $DEST_FOLDER"
    fi
done

# Step 3: Install all .pkg files
PKG_FILES=("$DEST_FOLDER"/*.pkg)
if [ ${#PKG_FILES[@]} -eq 0 ]; then
    echoDate "No .pkg files found in the copied folder." | tee -a "$LOG_FILE"
else
    echoDate "------------------------"
    echoDate "Installing .pkg files..."
    echoDate "------------------------"
    for PKG in "${PKG_FILES[@]}"; do
        echoDate "Installing $PKG..." | tee -a "$LOG_FILE"
        sudo installer -pkg "$PKG" -target / | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            echoDate "Failed to install $PKG." | tee -a "$LOG_FILE"
        else
            echoDate "$PKG installed successfully." | tee -a "$LOG_FILE"
        fi
    done
    echoDate "------------------------"
    echoDate "Finished all .pkg files!"
    echoDate "------------------------"
fi

# Step 4: Execute scripts in the "Scripts" subfolder
SCRIPTS_FOLDER="$DEST_FOLDER/Scripts"
if [ -d "$SCRIPTS_FOLDER" ]; then
    echoDate "-----------------------------------------------------"
    echoDate "Executing scripts in $SCRIPTS_FOLDER..." | tee -a "$LOG_FILE"
    echoDate "-----------------------------------------------------"
    for SCRIPT in "$SCRIPTS_FOLDER"/*.sh; do
        if [ -f "$SCRIPT" ]; then
            echoDate "Running $SCRIPT..." | tee -a "$LOG_FILE"
            bash "$SCRIPT" | tee -a "$LOG_FILE"
            if [ $? -ne 0 ]; then
                echoDate "Error executing $SCRIPT." | tee -a "$LOG_FILE"
            else
                echoDate "$SCRIPT executed successfully." | tee -a "$LOG_FILE"
            fi
        fi
    done
    echoDate "---------------------"
    echoDate "Finished all scripts!"
    echoDate "---------------------"
else
    echoDate "Scripts folder not found. Skipping script execution." | tee -a "$LOG_FILE"
fi

# Final message
echoDate "Installation process completed at $(date). Check $LOG_FILE for details." | tee -a "$LOG_FILE"
