# ----------------
# SETUP
# ----------------

#
# MONTEREY
#
read -r montereyVersion montereyLink <<<"$(curl -s https://latest-monterey.hischem.de | tr '|' ' ')"

#
# VENTURA
#
read -r venturaVersion venturaLink <<<"$(curl -s https://latest-ventura.hischem.de | tr '|' ' ')"

#
# COLORS
#
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CACHEDISK="/Volumes/macOSCache"
PKG="/InstallAssistant.pkg"
TMPDIR="/private/tmp"

function printInfo() {

    #
    # print info for user when starting
    #

    echo
    echo -e "${RED}[INFO]: This script can remove all data on your computer!${NC}"
    echo -e "${RED}[INFO]: Press CTRL-Z to cancel this process anytime!${NC}"
    echo -e "${GREEN}[INFO]:${NC} Starting processes ..."

}

function checkIntelOrAppleSilicon() {

    #
    # check if we're on Intel or Apple Silicon (M1 etc.)
    #

    CPU_TYPE=$(sysctl -a | grep machdep.cpu.brand_string | awk -F": " {'print $2'})
    if [[ $CPU_TYPE == *"Apple M1"* ]]; then
        echo -e "${GREEN}[INFO]:${NC} Machine has a Apple CPU."
        eraseDisk "as"
    else
        echo -e "${GREEN}[INFO]:${NC} Machine has Intel CPU."
        eraseDisk "intel"
    fi
}

function eraseDisk() {

    #
    # format the internal drive
    #

    if [[ -d '/Volumes/Untitled' ]]; then
        dstDisk='/Volumes/Untitled'
        dstDiskName="Untitled"
    fi

    if [[ -d '/Volumes/Macintosh HD' ]]; then
        dstDisk='/Volumes/Macintosh HD'
        dstDiskName="Macintosh HD"
    fi

    echo -e "${GREEN}[INFO]:${NC} Destination disk is: ${dstDisk}"
    echo -e "${RED}"
    echo -n "Do you want to delete all data on this computer? (y/n) :"
    echo -e "${NC}"
    read answer </dev/tty
    if [ "$answer" != "${answer#[Yy]}" ]; then
        if [ "$1" == "intel" ]; then
            internalDisk=$(diskutil list | grep "synthesized" | tail -1 | awk -F " " {'print $1'} | awk -F "/" {'print $3'} | head -1)
        else
            internalDisk=$(diskutil list | grep "synthesized" | awk -F " " {'print $1'} | awk -F "/" {'print $3'} | head -1)
        fi
        internalDisk=$(diskutil list | grep "synthesized" | awk -F " " {'print $1'} | awk -F "/" {'print $3'} | head -1)
        echo -e "${GREEN}[INFO]:${NC} APFS synthesized disk is: ${internalDisk}"
        DSK_MACINTOSH_HD=$(diskutil list $internalDisk | grep -i "${dstDiskName}" | grep -vi "data" | awk {'print $NF'})
        echo -e "${GREEN}[INFO]:${NC} APFS Macintosh HD disk is: ${DSK_MACINTOSH_HD}"
        DSK_MACINTOSH_HD_DATA=$(diskutil list $internalDisk | grep -i "DATA" | awk {'print $NF'})

        umount -f /Volume/"${dstDiskName}"

        if [ -z "$DSK_MACINTOSH_HD_DATA" ]; then
            echo -e "${BLUE}[INFO]:${NC} APFS Data HD not found."
        else
            echo -e "${GREEN}[INFO]:${NC} APFS Data HD disk is: ${DSK_MACINTOSH_HD_DATA}"
            umount -f /dev/${DSK_MACINTOSH_HD_DATA} /dev/null &>/dev/null
            #### delete DATA Volume
            diskutil apfs deleteVolume ${DSK_MACINTOSH_HD_DATA} &>/dev/null
        fi

        diskutil apfs eraseVolume ${DSK_MACINTOSH_HD} -name "Macintosh HD" &>/dev/null
        dstDisk='/Volumes/Macintosh HD'
        dstDiskName='Macintosh HD'
        diskutil mount /dev/${DSK_MACINTOSH_HD}
    fi

    sleep 1
}

function downloadInstaller() {

    #
    # creates a Folder in /private/tmp
    # asks what macOS should be installed
    # downloads the installer
    #

    echo -e "${GREEN}[INFO]:${NC} Set up folder ..."
    mkdir -p "${diskPath}${TMPDIR}"
    cd "${diskPath}${TMPDIR}"

    echo
    echo -e "${GREEN}[CHOICE]:${NC} Choose your macOS Version"
    echo
    echo -e "\t1. macOS Ventura\t${venturaVersion}"
    echo -e "\t2. macOS Monterey\t${montereyVersion}"
    echo
    echo -e "${GREEN}[CHOICE]: Enter a number (1 or 2)${NC}"
    read answer </dev/tty
    echo

    if [ -z "$answer" ]; then
        answer="1"
    fi

    case $answer in

    "1")
        macOSName="Ventura"
        macOSVersion=${venturaVersion}
        macOSUrl=${venturaLink}
        ;;

    "2")
        macOSName="Monterey"
        macOSVersion=${montereyVersion}
        macOSUrl=${montereyLink}
        ;;

    *)
        echo -e "${RED}[INFO]:${NC} Nothing selected, exiting now ..."
        exit
        ;;

    esac

    echo -e "${GREEN}[INFO]:${NC} You chose macOS ${macOSName} ${macOSVersion}"

    #checkusb
    ## additional stuff
    #os_ver not needed
    # ServerVersion = macOSVersion
    #

    if [[ -f ${CACHEDISK}${PKG} ]]; then

        os_ver=$(sw_vers -productVersion)
        echo -e "${GREEN}[INFO]:${NC} Found macOS ${macOSName} on external cache disk.."
        installer -pkg ${CACHEDISK}${PKG} -target / >/dev/null

        ### we have to install the cached Package at first because otherwise we cannot get the version
        echo -e "${GREEN}[INFO]:${NC} comparing macOS versions.."
        checkInstallerVersion=$(defaults read /Applications/Install\ macOS\ ${macOSName}.app/Contents/Info.plist DTPlatformVersion)

        if [ "$macOSVersion" = "$checkInstallerVersion" ]; then
            echo -e "${GREEN}[INFO]:${NC} The cached installer is on latest version ${checkInstallerVersion}."
        else

            #### Additonal check becasue i saw in the past that the Info.Plist e.q. macOS 11.2.1 return just 11.2 instead of 11.2.1
            # Attach Installation Source
            SilentAttach=$(hdiutil attach -quiet -noverify /Applications/Install\ macOS\ ${macOSName}.app/Contents/SharedSupport/SharedSupport.dmg)
            checkDMGVersion=$(cat /Volumes/Shared\ Support/com_apple_MobileAsset_MobileSoftwareUpdate_MacUpdateBrain/com_apple_MobileAsset_MobileSoftwareUpdate_MacUpdateBrain.xml | grep -A1 "OSVersion" | grep string | cut -f2 -d ">" | cut -f1 -d "<")
            SilentUnmount=$(diskutil umount force /Volumes/Shared\ Support >/dev/null)

            if [ "$macOSVersion" = "$checkDMGVersion" ]; then
                ## second check -> now it seems the cached and server version match
                echo -e "${GREEN}[INFO]:${NC} The cached installer is on latest version ${checkDMGVersion}."
            else
                ## still not match - ask user for download new version
                echo -e "${BLUE}[INFO]:${NC} The cached installer does not match with server version."
                echo -e "${BLUE}[INFO]:${NC} Cached: ${checkInstallerVersion}"
                echo -e "${BLUE}[INFO]:${NC} Server: ${macOSVersion}"
                echo -n "Do you want to save the server version to your cache disk (y/n)? "
                read answer </dev/tty
                if [ "$answer" != "${answer#[Yy]}" ]; then
                    curl --progress-bar -O $macOSUrl
                    rm -f ${CACHEDISK}${PKG} / >/dev/null
                    rsync --progress "${TMPDIR}${PKG}" ${CACHEDISK}${PKG}
                    echo -e "${GREEN}[INFO]:${NC} Install macOS ${macOSName}.app from cache disk.."
                    installer -pkg "${TMPDIR}${PKG}" -target / >/dev/null
                fi
            fi
        fi
    else
        if [[ -f "InstallAssistant.pkg" ]]; then
            echo -e "${GREEN}[INFO]:${NC} InstallAssistant.pkg found, use that one? (Y/n)"
            read useIA </dev/tty

            case $useIA in
            [Yy]*)
                echo -e "${GREEN}[INFO]:${NC} Using predownloaded Installer."
                return # todo
                ;;

            [Nn]*)
                echo -e "${GREEN}[INFO]:${NC} Deleting ..."
                rm InstallAssistant.pkg >/dev/null 2>&1
                ;;

            *)
                echo -e "${GREEN}[INFO]:${NC} Invalid input, exiting ..."
                exit
                ;;
            esac
        fi

        echo
        echo -e "${GREEN}[INFO]:${NC} Downloading files from Apple ..."
        curl -L --progress-bar -f -o InstallAssistant.pkg ${macOSUrl}

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}[INFO]:${NC} Download finished."
        else
            echo -e "${RED}[ERROR]:${NC} Download failed. Exiting now!"
            exit
        fi
    fi

    #starting the cached installer
    # TODO test this on recovery
    case "$os_ver" in
    10.*)
        options="--agreetolicense --eraseinstall --forcequitapps --newvolumename 'Macintosh HD'"
        ;;
    11.* | 1[2-9].*) # every Version from 11-19
        options="--agreetolicense --eraseinstall --newvolumename 'Macintosh HD' --forcequitapps --passprompt"
        ;;
    *)
        echo "unknown macOS Version"
        exit 1
        ;;
    esac

    "/Applications/Install macOS ${macOSName}.app/Contents/Resources/startosinstall" $options >/dev/null 2>&1

}

function expandAndSet() {

    #
    # Moving files to set up the InstallAssistant
    #

    echo -e "${GREEN}[INFO]:${NC} Expanding Installer ..."
    pkgutil --expand-full InstallAssistant.pkg Source
    echo -e "${GREEN}[INFO]:${NC} Copying in place ..."
    cp -R Source/Payload/Applications/"Install macOS ${macOSName}.app" "${diskPath}${TMPDIR}" &>/dev/null

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
    diskutil umountDisk $externalDisk 2>/dev/null

}

function main() {
    printInfo
    checkIntelOrAppleSilicon # calls eraseDisk function
    downloadInstaller
    #expandAndSet
    #unmountExternalDisks
}

main
