#!/bin/bash

# COLORS
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

USB_DRIVE="/Volumes/USBdrive"
SOURCE_FOLDER="$USB_DRIVE/Offlineinstaller DEV" 
DEST_FOLDER="/tmp/Offlineinstaller"
LOG_FILE="/var/log/offlineinstaller.log"

function copy_with_progress() {
    rsync -ahzEP --progress "$SOURCE_FOLDER/" "$DEST_FOLDER/"
}

function echoDate() {
    echo "$(date "+%a %h %d %H:%M:%S") | $1"
}

echoDate "Starting installation process at $(date)" > "$LOG_FILE"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}This script requires sudo privileges. Please run with sudo.${NC}" | tee -a "$LOG_FILE"
  exit 1
fi

if [ ! -d "$USB_DRIVE" ]; then
  echo -e "${RED}USB drive not found at $USB_DRIVE. Please check the mount point.${NC}" | tee -a "$LOG_FILE"
  echo -e "${RED}Tip: You can adjust the path in the variables at the top of the script if you are using a different volume or folder for the packages and scripts.${NC}"
  exit 1
fi

# Copy the folder with a real progress indicator
echoDate "Copying folder from USB to local machine..." | tee -a "$LOG_FILE"
if ! copy_with_progress; then
    echoDate "Error copying files. Please check the USB drive and try again." | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}############################${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}Copy completed successfully!${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}############################${NC}" | tee -a "$LOG_FILE"

# Eject the USB drive
echoDate "Ejecting USB drive..." | tee -a "$LOG_FILE"
if [ -d "$USB_DRIVE" ]; then
    diskutil eject "$USB_DRIVE" | tee -a "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}###################################${NC}" | tee -a "$LOG_FILE"
        echo -e "${RED}Failed to eject USB drive. You may need to remove it manually.${NC}" | tee -a "$LOG_FILE"
        echo -e "${RED}###################################${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}###################################${NC}" | tee -a "$LOG_FILE"
        echo -e "${GREEN}>>>> USB drive ejected successfully.${NC}" | tee -a "$LOG_FILE"
        echo -e "${GREEN}###################################${NC}" | tee -a "$LOG_FILE"
    fi
else
    echo -e "${BLUE}###################################${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}USB drive not found in /Volumes. Nothing to eject.${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}###################################${NC}" | tee -a "$LOG_FILE"
fi

# check if there are zip files in the folder and unzip
for zip_file in "$DEST_FOLDER"/*.zip; do
    if [[ -f "$zip_file" ]]; then # Check if the file exists
        unzipped_name=$(basename "$zip_file" .zip)
        echoDate "Unzipping $zip_file to $DEST_FOLDER" | tee -a "$LOG_FILE"
        unzip -o -q "$zip_file" -d "$DEST_FOLDER" | tee -a "$LOG_FILE"
        /bin/rm -f "$zip_file" | tee -a "$LOG_FILE"
        echoDate "Unzipped to $DEST_FOLDER/$unzipped_name" | tee -a "$LOG_FILE"
    else
        echoDate "No ZIP files found in $DEST_FOLDER" | tee -a "$LOG_FILE"
    fi
done

# Install all .pkg files
PKG_FILES=("$DEST_FOLDER"/*.pkg)
if [ ${#PKG_FILES[@]} -eq 0 ]; then
    echo -e "${RED}No .pkg files found in the copied folder.${NC}" | tee -a "$LOG_FILE"
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
    echo -e "${RED}Scripts folder not found. Skipping script execution.${NC}" | tee -a "$LOG_FILE"
fi

# Final message
echoDate "Installation process completed at $(date). Check $LOG_FILE for details." | tee -a "$LOG_FILE"
