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

# Rest of your script goes here


# ----------------
# SETUP
# ----------------

#
# MONTEREY
#
read -r montereyVersion montereyLink <<< "$(curl -s https://latest-monterey.hischem.de | tr '|' ' ')"
#montereyVersion="12.7.3"
#montereyLink="https://swcdn.apple.com/content/downloads/53/08/052-33037-A_AKHX79ZA4S/z7yb5wdcrk453a3hi7c3hc9n6zzju9di7f/InstallAssistant.pkg"

#
# VENTURA
#
read -r venturaVersion venturaLink <<< "$(curl -s https://latest-ventura.hischem.de | tr '|' ' ')"
#venturaVersion="13.6.4"
#venturaLink="https://swcdn.apple.com/content/downloads/32/13/052-33049-A_UX3Z28TPLL/702vi772ckrytq1r67eli9zrgsu8jxxoqw/InstallAssistant.pkg"

#
# SONOMA
#
read -r sonomaVersion sonomaLink <<< "$(curl -s https://latest-sonoma.hischem.de | tr '|' ' ')"
#sonomaVersion="14.3"
#sonomaLink="https://swcdn.apple.com/content/downloads/62/31/042-78233-A_YIMC5ZQM8T/yj7iay56cmvc2cux0qm55lfweb2u90euyo/InstallAssistant.pkg"

sonomaOldVersion="14.1.2 (non M3)"
sonomaOldVersionLink="https://swcdn.apple.com/content/downloads/24/37/052-09398-A_DIKZGBNOM0/y4rz9dued01dtyl65nxqgd08wj2ar5cr6v/InstallAssistant.pkg"

sonomaOldVersionM3="14.1.2 (only M3)"
sonomaOldVersionM3Link="https://swcdn.apple.com/content/downloads/54/47/052-09460-A_HHL1JV64MF/b7arop3bkdru7i7anbw4qdlij5tqoz20hp/InstallAssistant.pkg"
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
    echo -e "${RED}[INFO]: This script can remove all data on your computer!${NC}"
    echo -e "${RED}[INFO]: Press CTRL-Z to cancel this process anytime!${NC}"
    echo -e "${GREEN}[INFO]:${NC} Starting processes ..."

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

    echo -e "${GREEN}[INFO]:${NC} Destination disk is: ${diskPath}"
    echo
    echo -e "${RED}[CHOICE]: Do you want to delete all data on this computer? (y/n)${NC}"
    
    case $arg1 in

        "y" )
            code
            ;;

        "n" )
            code
            ;;

        * )
            echo -e "${GREEN}SKIPPING IN 5 SECONDS...${NC}"
            read -t 5 answer < /dev/tty || answer="n" # Timeout set to 5 seconds, default to no
            echo $@
            ;;
    esac
    
    if [ "$answer" != "${answer#[Yy]}" ];then

        echo -e "${GREEN}[INFO]:${NC} Ckecking Volumes ..."
        internalDisk=$(diskutil list | grep "synthesized" | awk -F " " {'print $1'} | awk -F "/" {'print $3'} | head -1)
        echo -e "${GREEN}[INFO]:${NC} APFS synthesized disk is: ${internalDisk}"
        DSK_MACINTOSH_HD=$(diskutil list $internalDisk | grep -i "${diskName}" |  grep -vi "data" | awk {'print $NF'} )
        echo -e "${GREEN}[INFO]:${NC} APFS Macintosh HD disk is: ${DSK_MACINTOSH_HD}"
        DSK_MACINTOSH_HD_DATA=$(diskutil list $internalDisk | grep -i "DATA" | awk {'print $NF'})
        
        if [ -z "$DSK_MACINTOSH_HD_DATA" ];then
            echo -e "${GREEN}[INFO]:${NC} APFS Data HD not found. Skipping."
        else
            echo -e "${GREEN}[INFO]:${NC} APFS Data HD disk is: ${DSK_MACINTOSH_HD_DATA}"
            umount -f /dev/${DSK_MACINTOSH_HD_DATA} /dev/null &> /dev/null
            echo -e "${GREEN}[INFO]:${NC} Deleting Data partition ..."
            diskutil apfs deleteVolume ${DSK_MACINTOSH_HD_DATA} &> /dev/null
        fi

        # erase volume, create new on called "Macintish HD"
        echo -e "${GREEN}[INFO]:${NC} Deleting Macintosh HD ..."
        diskutil apfs eraseVolume ${DSK_MACINTOSH_HD} -name "Macintosh HD" &> /dev/null
        diskPath='/Volumes/Macintosh HD'
        diskName='Macintosh HD'
        diskutil mount /dev/${DSK_MACINTOSH_HD} &> /dev/null

        if [[ $? -ne 0 ]]; then
            echo -e "${RED}[ERROR]:${NC} Error mounting Macintosh HD."
            echo -e "${RED}[ERROR]:${NC} Please delete the volume yourself."
            echo -e "${RED}[ERROR]:${NC} Exiting."
            exit
        fi
    else
        echo -e "${GREEN}[INFO]:${NC} Skipping disk deletion."
    fi

}



function downloadInstaller() {

    #
    # creates a Folder in /private/tmp
    # asks what macOS should be installed
    # downloads the installer
    #

    echo -e "${GREEN}[INFO]:${NC} Set up folder ..."
    # rm -rf "${diskPath}"/private/tmp/* >/dev/null 2>&1 ### This would delete manually downlaoded Installers ...
    mkdir -p "${diskPath}"/private/tmp
    cd "${diskPath}/private/tmp/"

    echo
    echo -e "${GREEN}[CHOICE]:${NC} Choose your macOS Version"
    echo
    echo -e "\t1. macOS Sonoma\t\t${sonomaVersion}"
    echo -e "\t2. macOS Ventura\t${venturaVersion}"
    echo -e "\t3. macOS Monterey\t${montereyVersion}"
    echo -e "\t4. macOS Sonoma\t\t${sonomaOldVersion}"
    echo -e "\t5. macOS Sonoma\t\t${sonomaOldVersionM3}"
    echo
    echo -e "${GREEN}[CHOICE]: Enter a number (1, 2 or 3)${NC}"
    
    case $arg2 in

        "1" )
            answer="1"
            ;;
        "2" )
            answer="2"
            ;;
        * )
            echo -e "${GREEN}DEFAULTS TO OPTION 1 IN 10 SECONDS...${NC}"
            read -t 10 answer < /dev/tty || answer="1" # Timeout set to 10 seconds, default to option 1
            echo
            ;;
            
    esac

    case $answer in

        "1" )
            macOSName="Sonoma"
            macOSVersion=${sonomaVersion}
            macOSUrl=${sonomaLink}
            ;;
        "2" )
            macOSName="Ventura"
            macOSVersion=${venturaVersion}
            macOSUrl=${venturaLink}
            ;;

        "3" )
            macOSName="Monterey"
            macOSVersion=${montereyVersion}
            macOSUrl=${montereyLink}
            ;;

        "4" )
            macOSName="Sonoma"
            macOSVersion=${sonomaOldVersion}
            macOSUrl=${sonomaOldVersionLink}
            ;;

        "5" )
            macOSName="Sonoma"
            macOSVersion=${sonomaOldVersionM3}
            macOSUrl=${sonomaOldVersionM3Link}
            ;;
        
        * )
            echo -e "${RED}[INFO]:${NC} Invalid selection, exiting now ..."
            exit
            ;;

    esac

    echo -e "${GREEN}[INFO]:${NC} You chose macOS ${macOSName} ${macOSVersion}"

    if [[ -f "InstallAssistant.pkg" ]]; then
        echo -e "${GREEN}[INFO]:${NC} InstallAssistant.pkg found, use that one? (Y/n)"
        read useIA < /dev/tty

        case $useIA in
            [Yy]* )
                echo -e "${GREEN}[INFO]:${NC} Using predownloaded Installer."
                return
                ;;
            
            [Nn]* )
                echo -e "${GREEN}[INFO]:${NC} Deleting ..."
                rm InstallAssistant.pkg >/dev/null 2>&1
                ;;
            
            * )
                echo -e "${GREEN}[INFO]:${NC} Invalid input, exiting ..."
                exit
                ;;
        esac
    fi 

    echo
    echo -e "${GREEN}[INFO]:${NC} Downloading files from Apple ..."
    curl -L --progress-bar  -f -o InstallAssistant.pkg ${macOSUrl}
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[INFO]:${NC} Download finished."
    else 
        echo -e "${RED}[ERROR]:${NC} Download failed. Exiting now!"
        exit
    fi

}



function expandAndSet() {

    #
    # Moving files to set up the InstallAssistant
    #

    echo -e "${GREEN}[INFO]:${NC} Expanding Installer ..."
    pkgutil --expand-full InstallAssistant.pkg Source
    echo -e "${GREEN}[INFO]:${NC} Copying in place ..."
    cp -R Source/Payload/Applications/"Install macOS ${macOSName}.app" "${diskPath}"/private/tmp/ &>/dev/null
    
    echo -e "${GREEN}[INFO]:${NC} Changing permissions ..."
    SSPATH="Install macOS ${macOSName}.app/Contents/SharedSupport"
    mkdir -p "$SSPATH"
    /bin/chmod 0755 "$SSPATH"
    mv InstallAssistant.pkg "$SSPATH"/SharedSupport.dmg
    /bin/chmod 0644 "$SSPATH"/SharedSupport.dmg
    /usr/sbin/chown -R root:wheel "$SSPATH"/SharedSupport.dmg
    /usr/bin/chflags -h norestricted "$SSPATH"/SharedSupport.dmg

    echo -e "${GREEN}[INFO]:${NC} Cleanup ..."
    rm -rf Source
    rm -rf InstallAssistant.pkg
    echo -e "${GREEN}[INFO]:${NC} Prerequisites done."

}



function unmountExternalDisks() {

    #
    # will check for external media and will unmount them before installation
    #
    
    echo -e "${GREEN}[INFO]:${NC} Looking for external drives and unmounting ..."
    externalDisk=$(diskutil list | grep external | awk -F " " {'print $1'})
    diskutil umountDisk $externalDisk 2> /dev/null

}



function main() {

    #
    # main runner
    #
    
    printInfo
    eraseDisk
    
    sleep 1

    downloadInstaller
    expandAndSet
    unmountExternalDisks

    echo -e "${GREEN}[INFO]:${NC} Starting installer ..."
    "${diskPath}/private/tmp/Install macOS ${macOSName}.app"/Contents/MacOS/InstallAssistant_springboard >/dev/null

}

main
