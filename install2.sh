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
os_ver=$(sw_vers -productVersion)
dstDiskPath='/Volumes/Macintosh HD'

UnpackPKGfromTMP=("installer" "-pkg" "${TMPDIR}${PKG}" "-target" "/")
CopyCache2Tmp=("cp" "${CACHEDISK}${PKG}" "${dstDiskPath}"/private/tmp/)

cd "${dstDiskPath}${TMPDIR}"

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
    else
        echo -e "${GREEN}[INFO]:${NC} Skipping disk deletion."
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

function checkForCache() {

    #
    # Checks if a USB cache is connected and if it has a IA.pkg on it OR if a local IA.pkg exists
    #

    # check if USB is present

    if [[ -d ${CACHEDISK} ]]; then
        echo -e "${GREEN}[INFO]:${NC} Found a cache USB!"
        echo -e "${GREEN}[INFO]:${NC} Looking for InstallAssistant.pkg..."

        # check if IA.pkg on USB is present

        if [ -f ${CACHEDISK}${PKG} ]; then

            echo -e "${GREEN}[INFO]:${NC} Found InstallAssistant.pkg on the USB!"
            echo -e "${GREEN}(y) CHECK if it's the newest version? (This may take a while)"
            echo -e "${GREEN}      OR"
            echo -e "${GREEN}(n) INSTALL this one, without knowing it's version"
            read answer </dev/tty

            if [ "$answer" != "${answer#[Yy]}" ]; then

                # version prüfen

                echo -e "${GREEN}[INFO]:${NC} Checking the version on the cache USB..."
                "${CopyCache2Tmp[@]}" &>/dev/null
                "${UnpackPKGfromTMP[@]}" &>/dev/null

                versionChecker

                if [ "$versIsOld" == "true" ]; then
                    #Cleanup
                    rm -rf "${dstDiskPath}${TMPDIR}${PKG}" >/dev/null
                    rm -rf "${dstDiskPath}${TMPDIR}/Install macOS Ventura.app" >/dev/null
                    downloadForCacheUSB
                fi

            else

                # Version nicht prüfen

                echo -e "${GREEN}[INFO]:${NC} Copying the PKG from USB to this machine..."
                "${CopyCache2Tmp[@]}" &>/dev/null
                expandAndSet
                return

            fi

        else

            echo -e "${GREEN}[INFO]:${NC} No InstallAssistant.pkg on the macOSCache found."
            echo -e "${GREEN}[CHOICE]:${NC} Do you want to download it to the USB? (y/n)"
            read answer </dev/tty

            if [ "$answer" != "${answer#[Yy]}" ]; then

                downloadForCacheUSB

            else

                echo -e "${GREEN}[INFO]:${NC} Starting Onlineinstall..."
                downloadInstaller
                expandAndSet

            fi

        fi

    elif [[ -f ${TMPDIR}${PKG} ]]; then

        echo -e "${GREEN}[INFO]:${NC} Found a local PKG"
        echo -e "${GREEN}[INFO]:${NC} Checking if the local PKG is up to date..."
        "${UnpackPKGfromTMP[@]}" &>/dev/null

        versionChecker

        # when the version is old it should call downloadInstaller and expandAndSet
        if [ "$versIsOld" == "true" ]; then
            downloadInstaller
        fi
        expandAndSet

    else

        # Wird ausgeführt, wenn weder USB noch Local vorhanden ist

        downloadInstaller
        expandAndSet

    fi
}

function versionChecker() {

    #
    # checks the version of the selected PKG
    #

    versIsOld=""

    ### we have to install the cached Package at first because otherwise we cannot get the version
    echo -e "${GREEN}[INFO]:${NC} comparing macOS versions.."
    # TODO gucken ob das vom recovery gelsen werden kann
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

            versIsOld="true"

            echo -e "${GREEN}[INFO]:${NC} The cached installer is not uptodate. It is Version ${checkDMGVersion}."

            # Was soll hier bei altem localen PKG passieren? downloadInstaller
            # Was soll hier bei altem cacheUSB passieren? downloadForCacheUSB vlt?
            #downloadForCacheUSB
        fi
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

function downloadForCacheUSB() {

    echo -n "Do you want to download the latest version to your cache disk (y/n)? "
    read answer </dev/tty
    if [ "$answer" != "${answer#[Yy]}" ]; then
        downloadInstaller
        rm -rf ${CACHEDISK}${PKG} >/dev/null # echo -e "${GREEN}[INFO]:${NC} Copying to ${CACHEDISK}..."
        rsync --progress "${TMPDIR}${PKG}" ${CACHEDISK}${PKG}
        echo -e "${GREEN}[INFO]:${NC} Downloaded InstallAssistant.pkg has been copied to ${CACHEDISK}"
        echo -e "${GREEN}[INFO]:${NC} Unpacking Install macOS ${macOSName}.app..."
        #"${UnpackPKGfromTMP[@]}" &>/dev/null

        expandAndSet
    else
        #something to continue after a no, else theres just gonna be weird error messages
        echo -e "${RED}[INFO]:${NC} You chose to not download the latest version to your cache disk."
        echo -e "${RED}[INFO]:${NC} STARTING OVER"
        main
        exit 1
    fi

}

function expandAndSet() {

    #
    # Moving files to set up the InstallAssistant
    #

    echo -e "${GREEN}[INFO]:${NC} Expanding Installer ..."
    pkgutil --expand-full InstallAssistant.pkg Source
    echo -e "${GREEN}[INFO]:${NC} Copying in place ..."
    cp -R Source/Payload/Applications/"Install macOS ${macOSName}.app" "${dstDiskPath}"/private/tmp/ &>/dev/null

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
    versionChooser           # just sets macOSName, macOSVersion, macOSUrl variables
    checkForCache

    unmountExternalDisks

    echo -e "${GREEN}[INFO]:${NC} Starting installer ..."
    "${dstDiskPath}/private/tmp/Install macOS ${macOSName}.app"/Contents/MacOS/InstallAssistant_springboard >/dev/null
}

main

####### Tests ######
# USBcache no versioncheck                                                          successful
# USBcache with versioncheck (already latest Version)                               successful
# USBcache with versioncheck (use old vers anyway / dont downloadForCacheUSB)       successful
# USBcache with versioncheck (downloadForCacheUSB)                                  successful
# Local PKG (already latest Version)                                                successful
# Local PKG (not the latest Version)                                                not tested (maybe useless irl)
# online only version                                                               not tested funzt bestimmt eh
#
# USBcache with an empty drive works. It downloads and starts the installer
# USBcache with an older version doesnt work. it starts an incomplete installer. Now works
