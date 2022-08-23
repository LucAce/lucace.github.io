#!/bin/bash
###############################################################################
#
#   Filename: change_ip_address.sh
#
#   Functional Description:
#
#       Bash script which changes the system IPv4 address.
#
#   Usage:
#
#       ./change_ip_address.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi


###############################################################################
# Script Configuration Options
###############################################################################

# Network Device Name (ex ens18)
NETWORK_DEVICE_NAME="XXXXX"

# New Hostname (ex 192.168.1.100)
NEW_IPV4_ADDRESS="XXX.XXX.XXX.XXX"


###############################################################################
# Script Commands
###############################################################################

CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-${NETWORK_DEVICE_NAME}"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo -e "ERROR: Network Configuration File (ifcfg-${NETWORK_DEVICE_NAME}) Not Found\n"
  exit
fi

read -r -p "Change IPv4 Address To: \"${NEW_IPV4_ADDRESS}\" (Y/N)? " input

case $input in
  [yY])
    sed -i "s@IPADDR=.*@IPADDR=${NEW_IPV4_ADDRESS}@g" ${CONFIG_FILE}
    cat ${CONFIG_FILE}
    echo -e "\nIPv4 Address Changed"
    echo -e "\nNOTICE: Reboot Required\n"
    ;;
  *)
    echo -e "\nIPv4 Address Not Changed"
    ;;
esac

exit
