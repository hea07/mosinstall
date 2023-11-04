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
cd ${TMPDIR}
os_ver=$(sw_vers -productVersion)
dstDiskPath='/Volumes/Macintosh HD'

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

    # dstDisk* wird nur in eraseDisk() verwendet.
    #### evtl zu diskPath umbenennen
    if [[ -d '/Volumes/Untitled' ]]; then
        dstDiskPath='/Volumes/Untitled'
        dstDiskName="Untitled"
    fi

    if [[ -d '/Volumes/Macintosh HD' ]]; then
        dstDiskPath='/Volumes/Macintosh HD'
        dstDiskName="Macintosh HD"
    fi

    echo -e "${GREEN}[INFO]:${NC} Destination disk is: ${dstDiskPath}"
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
        dstDiskPath='/Volumes/Macintosh HD'
        dstDiskName='Macintosh HD'
        diskutil mount /dev/${DSK_MACINTOSH_HD}
    fi

    sleep 1
}

function versionChooser() {
    echo -e "${GREEN}[INFO]:${NC} Set up folder ..."
    mkdir -p "${dstDiskPath}${TMPDIR}"
    cd "${dstDiskPath}${TMPDIR}"

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
        export macOSName="Ventura"
        export macOSVersion=${venturaVersion}
        export macOSUrl=${venturaLink}
        ;;

    "2")
        export macOSName="Monterey"
        export macOSVersion=${montereyVersion}
        export macOSUrl=${montereyLink}
        ;;

    *)
        echo -e "${RED}[INFO]:${NC} Nothing selected, exiting now ..."
        exit
        ;;

    esac

    echo -e "${GREEN}[INFO]:${NC} You chose macOS ${macOSName} ${macOSVersion}"
}

function checkforLocalInstaller() {
    # check for existing InstallAssistant.pkg on the machine.
    if [[ -f "InstallAssistant.pkg" ]]; then
        # TODO Maybe implement version check
        echo -e "${GREEN}[INFO]:${NC} InstallAssistant.pkg found, use that one? (Y/n)"
        read useIA </dev/tty

        case $useIA in
        [Yy]*)
            echo -e "${GREEN}[INFO]:${NC} Using predownloaded Installer."
            expandAndSet
            return
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
}

function downloadInstaller() {

    #
    # Download the installer from Apple
    #

    echo
    echo -e "${GREEN}[INFO]:${NC} Downloading files from Apple ..."
    curl --progress-bar -o InstallAssistant.pkg ${macOSUrl}

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[INFO]:${NC} Download finished."
    else
        echo -e "${RED}[ERROR]:${NC} Download failed. Exiting now!"
        exit
    fi
}

function startLocalInstaller() {
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

    # does the path work in recovery?
    "/Applications/Install macOS ${macOSName}.app/Contents/Resources/startosinstall" $options >/dev/null 2>&1
}

function checkForPKGversion() {

    #
    # Checks if theres a cacheUSB or a local PKG and then checks if they are uptodate.
    #

    if [[ -f ${CACHEDISK}${PKG} ]]; then
        echo -e "${GREEN}[INFO]:${NC} Found a cache USB"
        echo -e "${GREEN}[INFO]:${NC} Do you want me to CHECK, if it is the newest Version \n or \njust USE this one? \nThis may take a while depending on the speed of the thumbdrive (y/n)"
        echo -e "${GREEN}CHECK if it's the newest version? \nThis may take a while (y)"
        echo -e "${GREEN}OR"
        echo -e "${GREEN}USE this one, without knowing it's version (n)"
        read answer </dev/tty
        if [ "$answer" != "${answer#[Yy]}" ]; then
            installer -pkg ${CACHEDISK}${PKG} -target / >/dev/null
        else
            cd ${CACHEDISK}
            expandAndSet
            return
        fi
    elif [[ -f ${TMPDIR}${PKG} ]]; then
        echo -e "${GREEN}[INFO]:${NC} Found a local PKG"
        echo -e "${GREEN}[INFO]:${NC} Checking if the local PKG is up to date..."
        installer -pkg ${TMPDIR}${PKG} -target / >/dev/null
    else
        downloadInstaller
    fi

    ### we have to install the cached Package at first because otherwise we cannot get the version
    echo -e "${GREEN}[INFO]:${NC} comparing macOS versions.."
    export checkInstallerVersion=$(defaults read /Applications/Install\ macOS\ ${macOSName}.app/Contents/Info.plist DTPlatformVersion)

    if [ "$macOSVersion" = "$checkInstallerVersion" ]; then
        echo -e "${GREEN}[INFO]:${NC} The cached installer is on latest version ${checkInstallerVersion}."
        expandAndSet
    else

        #### Additonal check becasue i saw in the past that the Info.Plist e.q. macOS 11.2.1 return just 11.2 instead of 11.2.1
        # Attach Installation Source
        SilentAttach=$(hdiutil attach -quiet -noverify /Applications/Install\ macOS\ ${macOSName}.app/Contents/SharedSupport/SharedSupport.dmg)
        export checkDMGVersion=$(cat /Volumes/Shared\ Support/com_apple_MobileAsset_MobileSoftwareUpdate_MacUpdateBrain/com_apple_MobileAsset_MobileSoftwareUpdate_MacUpdateBrain.xml | grep -A1 "OSVersion" | grep string | cut -f2 -d ">" | cut -f1 -d "<")
        SilentUnmount=$(diskutil umount force /Volumes/Shared\ Support >/dev/null)

        if [ "$macOSVersion" = "$checkDMGVersion" ]; then
            ## second check -> now it seems the cached and server version match
            echo -e "${GREEN}[INFO]:${NC} The cached installer is on latest version ${checkDMGVersion}."
            expandAndSet
        else
            # warum hier downloadForCacheUSB und nicht downloadInstaller?
            # hier landet man nur, wenn weder der USB-Stick noch ein lokales PKG vorhanden wäre (das aber nicht uptodate ist)
            downloadForCacheUSB
        fi
    fi
}

function downloadForCacheUSB() {
    ## still not match - ask user for download new version
    echo -e "${BLUE}[INFO]:${NC} The cached installer does not match with server version."
    echo -e "${BLUE}[INFO]:${NC} Cached: ${checkInstallerVersion}"
    echo -e "${BLUE}[INFO]:${NC} Server: ${macOSVersion}"
    echo -n "Do you want to download the latest version to your cache disk (y/n)? "
    read answer </dev/tty
    if [ "$answer" != "${answer#[Yy]}" ]; then
        downloadInstaller
        rm -f ${CACHEDISK}${PKG} / >/dev/null
        rsync --progress "${TMPDIR}${PKG}" ${CACHEDISK}${PKG}
        echo -e "${GREEN}[INFO]:${NC} Downloaded InstallAssistant.pkg has been copied to ${CACHEDISK}"
        echo -e "${GREEN}[INFO]:${NC} Unpacking Install macOS ${macOSName}.app..."
        #installer -pkg "${TMPDIR}${PKG}" -target / >/dev/null

        expandAndSet
    fi
}

function expandAndSet() {

    #
    # Moving files to set up the InstallAssistant
    #

    Source = "${dstDiskPath}/Source"

    echo -e "${GREEN}[INFO]:${NC} Expanding Installer ..."
    pkgutil --expand-full InstallAssistant.pkg "${Source}"
    echo -e "${GREEN}[INFO]:${NC} Copying in place ..."
    cp -R "${Source}"/Payload/Applications/"Install macOS ${macOSName}.app" "${dstDiskPath}${TMPDIR}" &>/dev/null

    echo -e "${GREEN}[INFO]:${NC} Changing permissions ..."
    SSPATH="Install macOS ${macOSName}.app/Contents/SharedSupport"
    mkdir -p "$SSPATH"
    /bin/chmod 0755 "$SSPATH"
    mv InstallAssistant.pkg "$SSPATH"/SharedSupport.dmg
    /bin/chmod 0644 "$SSPATH"/SharedSupport.dmg
    /usr/sbin/chown -R root:wheel "$SSPATH"/SharedSupport.dmg
    /usr/bin/chflags -h norestricted "$SSPATH"/SharedSupport.dmg

    echo -e "${GREEN}[INFO]:${NC} Cleanup ..."
    rm -rf "${Source}"
    rm -rf InstallAssistant.pkg
    echo -e "${GREEN}[INFO]:${NC} Prerequisites done."

    echo -e "${GREEN}[INFO]:${NC} Starting installer ..."
    "${dstDiskPath}${TMPDIR}/Install macOS ${macOSName}.app"/Contents/MacOS/InstallAssistant_springboard #>/dev/null

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
    versionChooser
    checkForPKGversion
    #unmountExternalDisks
    echo test
}

main
