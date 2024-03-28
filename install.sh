#!/bin/bash
# ORIGINAL FILE FROM https://github.com/macBerlin/macOS_erase/blob/main/macOS_erase_Monterey
# THIS WAS CHANGED TO WORK WITH ALL VRESIONS: MONTEREY, VENTURA
# NO WARRANTY OR HELP FROM ME

# Check if arguments were provided
if [ "$#" -eq 0 ]; then
    echo "No arguments provided."
else
    echo "Arguments provided: $@"
fi

arg1="$1"
arg2="$2"

# ----------------
# SETUP
# ----------------

#
# SONOMA (14)
#
read -r sonomaVersion sonomaLink <<<"$(curl -s https://latest-sonoma.hischem.de | tr '|' ' ')"
#sonomaVersion="14.3"
#sonomaLink="https://swcdn.apple.com/content/downloads/62/31/042-78233-A_YIMC5ZQM8T/yj7iay56cmvc2cux0qm55lfweb2u90euyo/InstallAssistant.pkg"

sonomaOldVersion="14.1.2 (non M3)"
sonomaOldVersionLink="https://swcdn.apple.com/content/downloads/24/37/052-09398-A_DIKZGBNOM0/y4rz9dued01dtyl65nxqgd08wj2ar5cr6v/InstallAssistant.pkg"

sonomaOldVersionM3="14.1.2 (M3 only)"
sonomaOldVersionM3Link="https://swcdn.apple.com/content/downloads/54/47/052-09460-A_HHL1JV64MF/b7arop3bkdru7i7anbw4qdlij5tqoz20hp/InstallAssistant.pkg"

#
# VENTURA (13)
#
read -r venturaVersion venturaLink <<<"$(curl -s https://latest-ventura.hischem.de | tr '|' ' ')"
#venturaVersion="13.6.4"
#venturaLink="https://swcdn.apple.com/content/downloads/32/13/052-33049-A_UX3Z28TPLL/702vi772ckrytq1r67eli9zrgsu8jxxoqw/InstallAssistant.pkg"

#
# MONTEREY (12)
#
read -r montereyVersion montereyLink <<<"$(curl -s https://latest-monterey.hischem.de | tr '|' ' ')"
#montereyVersion="12.7.3"
#montereyLink="https://swcdn.apple.com/content/downloads/53/08/052-33037-A_AKHX79ZA4S/z7yb5wdcrk453a3hi7c3hc9n6zzju9di7f/InstallAssistant.pkg"

#
# COLORS
#
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function printInfo() {

    #
    # print info for user when starting
    #

    echo
    echo -e "${GREEN}##########################################################${NC}"
    echo -e "${GREEN} #                                                      #${NC}"
    echo -e "${GREEN}  #    This script let's you download and install a    #${NC}"
    echo -e "${GREEN}  #  macOS Version of your choice from Apple's Server  #${NC}"
    echo -e "${GREEN} #                                                      #${NC}"
    echo -e "${GREEN}##########################################################${NC}"
    #echo -e "${GREEN}  #   THIS SCRIPT CAN REMOVE ALL DATA ON YOUR COMPUTER!  #${NC}"
    #echo -e "${GREEN}  #                                                      #${NC}"
    #echo -e "${GREEN} #                                                        #${NC}"
    #echo -e "${GREEN}############################################################${NC}"
    #echo

}

function eraseDisk() {

    #
    # Asks if drive should be deleted, does so if "Yy" was typed
    # checks erased disks
    #

    if [[ -d '/Volumes/Untitled' ]]; then
        diskPath='/Volumes/Untitled'
        diskName="Untitled"
    fi

    if [[ -d '/Volumes/Macintosh HD' ]]; then
        diskPath='/Volumes/Macintosh HD'
        diskName="Macintosh HD"
    fi

    #echo -e "${GREEN}Destination disk is: ${diskPath}${NC}"
    echo
    

    case $arg1 in

        [YyNn])
            answer="$arg1"
            ;;

        *)
            echo -e "${RED}##########################################################${NC}"
            echo -e "${RED}#                                                        #${NC}"
            echo -e "${RED}# DO YOU WANT TO DELETE ALL DATA ON THIS COMPUTER? (Y/N) #${NC}"
            echo -e "${RED}#                                                        #${NC}"
            echo -e "${RED}#                SKIPPING IN 5 SECONDS...                #${NC}"
            echo -e "${RED}#                                                        #${NC}"
            echo -e "${RED}##########################################################${NC}"
            read -t 5 answer </dev/tty || answer="n" # Timeout set to 5 seconds, defaults to "no"
            echo $@
            ;;
    esac

    if [ "$answer" != "${answer#[Yy]}" ]; then

        echo -e "${GREEN}Ckecking Volumes...${NC}"
        internalDisk=$(diskutil list | grep "synthesized" | awk -F " " {'print $1'} | awk -F "/" {'print $3'} | head -1)
        echo -e "${GREEN}APFS synthesized disk is: ${internalDisk}${NC}"
        DSK_MACINTOSH_HD=$(diskutil list $internalDisk | grep -i "${diskName}" | grep -vi "data" | awk {'print $NF'})
        echo -e "${GREEN}APFS Macintosh HD disk is: ${DSK_MACINTOSH_HD}${NC}"
        DSK_MACINTOSH_HD_DATA=$(diskutil list $internalDisk | grep -i "DATA" | awk {'print $NF'})

        if [ -z "$DSK_MACINTOSH_HD_DATA" ]; then
            echo -e "${GREEN}APFS Data HD not found. Skipping.${NC}"
        else
            echo -e "${GREEN}APFS Data HD disk is: ${DSK_MACINTOSH_HD_DATA}${NC}"
            umount -f /dev/${DSK_MACINTOSH_HD_DATA} /dev/null &>/dev/null
            echo -e "${GREEN}Deleting Data partition...${NC}"
            diskutil apfs deleteVolume ${DSK_MACINTOSH_HD_DATA} &>/dev/null
        fi

        # erase volume, create new one called "Macintosh HD"
        echo -e "${GREEN}Deleting Macintosh HD...${NC}"
        diskutil apfs eraseVolume ${DSK_MACINTOSH_HD} -name "Macintosh HD" &>/dev/null
        diskPath='/Volumes/Macintosh HD'
        diskName='Macintosh HD'
        diskutil mount /dev/${DSK_MACINTOSH_HD} &>/dev/null

        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Error mounting Macintosh HD.${NC}"
            echo -e "${RED}Please delete the volume yourself.${NC}"
            echo -e "${RED}Exiting${NC}"
            exit
        fi

    else
        echo -e "${GREEN}Skipping disk deletion.${NC}"
    fi

}

function downloadInstaller() {

    #
    # creates a Folder in /private/tmp
    # asks what macOS should be installed
    # downloads the installer
    #

    #echo -e "${GREEN}Setting up folder...${NC}"
    mkdir -p "${diskPath}"/private/tmp
    cd "${diskPath}/private/tmp/"

    echo
    echo -e "${NC}Choose your macOS Version:${NC}"
    echo
    echo -e "\t1. macOS Sonoma\t\t${sonomaVersion}"
    echo -e "\t2. macOS Ventura\t${venturaVersion}"
    echo -e "\t3. macOS Monterey\t${montereyVersion}"
    echo
    echo -e "\t4. macOS Sonoma\t\t${sonomaOldVersion}"
    echo -e "\t5. macOS Sonoma\t\t${sonomaOldVersionM3}"
    echo
    #echo -e "${GREEN}Please enter the number of your choice:${NC}"

    case $arg2 in
    [1-5])
        answer="$arg2"
        ;;
    *)
        echo -e "${NC}(DEFAULTS TO OPTION 1 IN 10 SECONDS...)${NC}"
        read -t 10 answer </dev/tty || answer="1" # Timeout set to 10 seconds, default to option 1
        echo
        ;;
    esac

    case $answer in
    "1" | "14")
        macOSName="Sonoma"
        macOSVersion=${sonomaVersion}
        macOSUrl=${sonomaLink}
        ;;
    "2" | "13")
        macOSName="Ventura"
        macOSVersion=${venturaVersion}
        macOSUrl=${venturaLink}
        ;;

    "3" | "12")
        macOSName="Monterey"
        macOSVersion=${montereyVersion}
        macOSUrl=${montereyLink}
        ;;

    "4")
        macOSName="Sonoma"
        macOSVersion=${sonomaOldVersion}
        macOSUrl=${sonomaOldVersionLink}
        ;;

    "5")
        macOSName="Sonoma"
        macOSVersion=${sonomaOldVersionM3}
        macOSUrl=${sonomaOldVersionM3Link}
        ;;

    *)
        echo -e "${RED}Invalid selection, exiting...${NC}"
        exit
        ;;
    esac

    echo -e "${GREEN}You chose macOS ${macOSName} ${macOSVersion}${NC}"

    if [[ -f "InstallAssistant.pkg" ]]; then
        echo -e "${GREEN}Existing InstallAssistant.pkg found, use that one? (Y/n)${NC}"
        read useIA </dev/tty

        case $useIA in
        [Yy]*)
            echo -e "${GREEN}Using predownloaded Installer.${NC}"
            return
            ;;

        [Nn]*)
            echo -e "${GREEN}Deleting...${NC}"
            rm InstallAssistant.pkg >/dev/null 2>&1
            ;;

        *)
            echo -e "${GREEN}Invalid input, exiting...${NC}"
            exit
            ;;
        esac
    fi

    echo
    echo -e "${GREEN}Downloading files from Apple...${NC}"
    curl -L --progress-bar -f -o InstallAssistant.pkg ${macOSUrl}

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Download finished.${NC}"
    else
        echo -e "${RED}Download failed. Exiting now!${NC}"
        exit
    fi

}

function expandAndSet() {

    #
    # Moving files to set up the InstallAssistant
    #

    echo -e "${GREEN}Expanding Installer...${NC}"
    pkgutil --expand-full InstallAssistant.pkg Source

    echo -e "${GREEN}Copying in place...${NC}"
    cp -R Source/Payload/Applications/"Install macOS ${macOSName}.app" "${diskPath}"/private/tmp/ &>/dev/null

    echo -e "${GREEN}Changing permissions...${NC}"
    SSPATH="Install macOS ${macOSName}.app/Contents/SharedSupport"
    mkdir -p "$SSPATH"
    /bin/chmod 0755 "$SSPATH"
    mv InstallAssistant.pkg "$SSPATH"/SharedSupport.dmg
    /bin/chmod 0644 "$SSPATH"/SharedSupport.dmg
    /usr/sbin/chown -R root:wheel "$SSPATH"/SharedSupport.dmg
    /usr/bin/chflags -h norestricted "$SSPATH"/SharedSupport.dmg

    echo -e "${GREEN}Cleanup...${NC}"
    rm -rf Source
    rm -rf InstallAssistant.pkg
    echo -e "${GREEN}Prerequisites done.${NC}"

}

function unmountExternalDisks() {

    #
    # will check for external media and will unmount them before installation
    #

    echo -e "${GREEN}Looking for external drives and unmounting...${NC}"
    externalDisk=$(diskutil list | grep external | awk -F " " {'print $1'})
    diskutil umountDisk $externalDisk 2>/dev/null

}

function main() {

    #
    # main runner
    #

    printInfo
    #eraseDisk

    sleep 1

    downloadInstaller
    expandAndSet
    unmountExternalDisks

    echo -e "${GREEN}Starting installer...${NC}"
    "${diskPath}/private/tmp/Install macOS ${macOSName}.app"/Contents/MacOS/InstallAssistant_springboard >/dev/null

}

main
