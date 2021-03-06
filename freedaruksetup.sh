#!/bin/bash

#####################################################################################
#                        Freedar.UK SETUP SCRIPT FORKED                         #
#####################################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


## CHECK IF SCRIPT WAS RAN USING SUDO

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

## CHECK FOR PACKAGES NEEDED BY THIS SCRIPT

echo -e "\033[33m"
echo "Checking for packages needed to run this script..."

if [ $(dpkg-query -W -f='${STATUS}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing the curl package..."
    echo -e "\033[37m"
    sudo apt-get update
    sudo apt-get install -y curl
fi
echo -e "\033[37m"

## ASSIGN VARIABLES

LOGDIRECTORY="$PWD/logs"
MLATCLIENTVERSION="0.2.6"
MLATCLIENTTAG="v0.2.6"

## WHIPTAIL DIALOGS

BACKTITLETEXT="FreedarUK Setup Script"

whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "Thanks for choosing to share your data with Freedar.UK!\n\nFreedarUK is a co-op of ADS-B/Mode S/MLAT feeders from around the world. This script will configure your current your ADS-B receiver to share your feeders data with FreedarUK.\n\nWould you like to continue setup?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

FREEDARUKUSERNAME=$(whiptail --backtitle "$BACKTITLETEXT" --title "FREEDARUK User Name" --nocancel --inputbox "\nPlease enter your FREEDARUK user name.\n\nIf you have more than one receiver, this username should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
RECEIVERLATITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Latitude" --nocancel --inputbox "\nEnter your receivers latitude." 9 78 3>&1 1>&2 2>&3)
RECEIVERLONGITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Longitude" --nocancel --inputbox "\nEnter your recivers longitude." 9 78 3>&1 1>&2 2>&3)
RECEIVERALTITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Longitude" --nocancel --inputbox "\nEnter your recivers atitude." 9 78 "`curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=$RECEIVERLATITUDE,$RECEIVERLONGITUDE | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];"`" 3>&1 1>&2 2>&3)
RECEIVERPORT=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Feed Port" --nocancel --inputbox "\nChange only if you were assigned a custom feed port.\nFor most all users it is required this port remain set to port 30005." 10 78 "30005" 3>&1 1>&2 2>&3)


whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "We are now ready to begin setting up your receiver to feed FreedarUK.\n\nDo you wish to proceed?" 9 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

## BEGIN SETUP

{

    # Make a log directory if it does not already exist.
    if [ ! -d "$LOGDIRECTORY" ]; then
        mkdir $LOGDIRECTORY
    fi
    LOGFILE="$LOGDIRECTORY/image_setup-$(date +%F_%R)"
    touch $LOGFILE

    echo 4
    sleep 0.25

    # BUILD AND CONFIGURE THE MLAT-CLIENT PACKAGE

    echo "INSTALLING PREREQUISITE PACKAGES" >> $LOGFILE
    echo "--------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE


    # Check that the prerequisite packages needed to build and install mlat-client are installed.
    if [ $(dpkg-query -W -f='${STATUS}' build-essential 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y build-essential >> $LOGFILE  2>&1
    fi

    echo 10
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' debhelper 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y debhelper >> $LOGFILE  2>&1
    fi

    echo 16
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' python 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y python >> $LOGFILE  2>&1
    fi
    
    if [ $(dpkg-query -W -f='${STATUS}' python3-dev 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y python3-dev >> $LOGFILE  2>&1
    fi

    echo 22
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' socat 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y socat >> $LOGFILE  2>&1
    fi

    echo 28
    sleep 0.25

    echo "" >> $LOGFILE
    echo " BUILD AND INSTALL MLAT-CLIENT" >> $LOGFILE
    echo "-----------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE

    # Check if the mlat-client git repository already exists.
    if [ -d mlat-client ] && [ -d mlat-client/.git ]; then
        # If the mlat-client repository exists update the source code contained within it.
        cd mlat-client >> $LOGFILE
        git pull >> $LOGFILE 2>&1
        git checkout tags/$MLATCLIENTTAG >> $LOGFILE 2>&1
    else
        # Download a copy of the mlat-client repository since the repository does not exist locally.
        git clone https://github.com/mutability/mlat-client.git >> $LOGFILE 2>&1
        cd mlat-client >> $LOGFILE 2>&1
        git checkout tags/$MLATCLIENTTAG >> $LOGFILE 2>&1
    fi

    echo 34
    sleep 0.25

    # Build and install the mlat-client package.
    dpkg-buildpackage -b -uc >> $LOGFILE 2>&1
    cd .. >> $LOGFILE
    sudo dpkg -i mlat-client_${MLATCLIENTVERSION}*.deb >> $LOGFILE

    echo 40
    sleep 0.25

    echo "" >> $LOGFILE
    echo " CREATE AND CONFIGURE MLAT-CLIENT STARTUP SCRIPTS" >> $LOGFILE
    echo "------------------------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE

    # Create the mlat-client maintenance script.
    tee freedaruk-mlat_maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type dump1090 --input-connect localhost:30005 --lat $RECEIVERLATITUDE --lon $RECEIVERLONGITUDE --alt $RECEIVERALTITUDE --user $FREEDARUKUSERNAME --server mlat.virtualradaruk.com:41112 --no-udp --results beast,connect,localhost:30104
  done
EOF

    echo 46
    sleep 0.25

    # Set execute permissions on the mlat-client maintenance script.
    chmod +x freedaruk-mlat_maint.sh >> $LOGFILE

    echo 52
    sleep 0.25

    # Add a line to execute the mlat-client maintenance script to /etc/rc.local so it is started after each reboot if one does not already exist.
    if ! grep -Fxq "$PWD/freedaruk-mlat_maint.sh &" /etc/rc.local; then
        LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
        ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i $PWD/freedaruk-mlat_maint.sh &\n" /etc/rc.local >> $LOGFILE
    fi

    echo 58
    sleep 0.25

    echo "" >> $LOGFILE
    echo " CREATE AND CONFIGURE NETCAT STARTUP SCRIPTS" >> $LOGFILE
    echo "-------------------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE

    # Kill any currently running instances of the freedaruk-mlat_maint.sh script.
    PIDS=`ps -efww | grep -w "freedaruk.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOGFILE
        sudo kill -9 $PIDS >> $LOGFILE
    fi

    echo 64
    sleep 0.25

    # Execute the mlat-client maintenance script.
    sudo nohup $PWD/freedaruk-mlat_maint.sh > /dev/null 2>&1 & >> $LOGFILE

    echo 70
    sleep 0.25

    # SETUP NETCAT TO SEND DUMP1090 DATA TO Freedar.uk

    # Create the netcat maintenance script.
    tee freedaruk-netcat_maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
    #/bin/nc 127.0.0.1 30005 | /bin/nc mlat.virtualradaruk.com $RECEIVERPORT
    /usr/bin/socat -u TCP:localhost:30005 TCP:mlat.virtualradaruk.com:$RECEIVERPORT
  done
EOF

    echo 76
    sleep 0.25

    # Set permissions on the file freedaruk-netcat_maint.sh.
    chmod +x freedaruk-netcat_maint.sh >> $LOGFILE

    echo 82
    sleep 0.25

    # Add a line to execute the netcat maintenance script to /etc/rc.local so it is started after each reboot if one does not already exist.
    if ! grep -Fxq "$PWD/freedaruk-netcat_maint.sh &" /etc/rc.local; then
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $PWD/freedaruk-netcat_maint.sh &\n" /etc/rc.local >> $LOGFILE
    fi

    echo 88
    sleep 0.25

    # Kill any currently running instances of the freedaruk-netcat_maint.sh script.
    PIDS=`ps -efww | grep -w "freedaruk-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOGFILE
        sudo kill -9 $PIDS >> $LOGFILE
    fi

    echo 94
    sleep 0.25

    # Execute the netcat maintenance script.
    sudo nohup $PWD/freedaruk-netcat_maint.sh > /dev/null 2>&1 & >> $LOGFILE
    echo 100
    sleep 0.25

} | whiptail --backtitle "$BACKTITLETEXT" --title "Setting Up FreedarUK Feed"  --gauge "\nSetting up your receiver to feed Freedar.uk.\nThe setup process may take awhile to complete..." 8 60 0

## SETUP COMPLETE

# Display the thank you message box.
whiptail --title "Freedar.uk Setup Script" --msgbox "\nSetup is now complete.\n\nYour feeder should now be feeding data to Freedaruk.\nThanks again for choosing to share your data with Freedar.uk!\n\nIf you have questions or encountered any issues while using this script feel free to post them to one of the following places.\n\nhttp://www.facebook.com/freedaruk/" 17 73

exit 0
