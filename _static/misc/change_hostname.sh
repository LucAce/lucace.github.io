#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi


###############################################################################
# Script Configuration Options
###############################################################################

# New Hostname (ex idm)
NEW_HOST_NAME="XXXXX"


###############################################################################
# Script Commands
###############################################################################

echo
echo -e    "Host Name: `hostname`"
echo -e    "FQDN:      `hostname -f`\n"
read -r -p "Change Host Name To: \"${NEW_HOST_NAME}\" (Y/N)? " input

case $input in
  [yY])
    hostnamectl set-hostname ${NEW_HOST_NAME}
    echo "Host Name Changed"
    ;;
  *)
    echo "Host Name Not Changed"
    ;;
esac
