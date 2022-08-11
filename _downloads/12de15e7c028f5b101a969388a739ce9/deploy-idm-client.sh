#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi


###############################################################################
# Script Configuration Options
###############################################################################

# Timezone
TIME_ZONE="America/New_York"

# Domain Name
DOMAIN_NAME="engwsc.example.com"

# IdM Server Hostname
IDM_SERVER_FQDN="idm.${DOMAIN_NAME}"

# Hostname
HOST_NAME=`hostname -s`
HOST_NAME_FQDN="${HOST_NAME}.${DOMAIN_NAME}"

# Option #2: Host IPv4 Address
# HOST_NAME_IP="192.168.1.60"

# IdM Administrator Username
ADMIN_PRINCIPAL='admin'

# IdM Administrator Password
ADMIN_PASSWORD='XXXXXXXXXXXXXXXXXXXXXXXXX'


###############################################################################
# Installation Commands
###############################################################################

# Update System:
dnf -y update

# Ensure the timezone is properly set:
timedatectl set-timezone ${TIME_ZONE}
timedatectl set-local-rtc 0

# Optional, Verify the hostname’s FQDN resolves to an IPv4 address that is not
#           equal to the loopback (127.0.0.1) address:
# dig +short ${HOST_NAME_FQDN} A

# Optional, Verify reverse DNS configuration (PTR records):
# dig +short -x ${HOST_NAME_IP}

# Option #1: Set the hostname to a FQDN:
# hostnamectl set-hostname ${HOST_NAME_FQDN}

# Option #2: Add host name to ``/etc/hosts`` if DNS does not resolve the FQDN:
# cat >> /etc/hosts <<EOL
# ${HOST_NAME_IP} ${HOST_NAME_FQDN} ${HOST_NAME}
#
# EOL

# Verify idm module information:
dnf module info idm:DL1

# Enable the idm:DL1 stream and sync repositories:
dnf module -y enable idm:DL1
dnf distro-sync

# Install IdM server without an integrated DNS:
dnf module -y install idm:DL1/client

# Install IdM Client:
ipa-client-install \
  --mkhomedir \
  --server=${IDM_SERVER_FQDN} \
  --domain=${DOMAIN_NAME} \
  --principal=${ADMIN_PRINCIPAL} \
  --password=${ADMIN_PASSWORD} \
  --unattended

exit 0
