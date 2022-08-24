#!/bin/bash
###############################################################################
#
#   Filename: deploy-idm-server.sh
#
#   Functional Description:
#
#       Bash script which deploys IdM/FreeIPA Server.
#
#   Usage:
#
#       ./deploy-idm-server.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying IdM Server...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Timezone
TIME_ZONE="America/New_York"

# Realm Name
REALM_NAME="engwsc.example.com"

# Domain Name
DOMAIN_NAME="engwsc.example.com"

# IdM FQDN Host Name
IDM_HOST_NAME="idm"
IDM_HOST_NAME_FQDN="${IDM_HOST_NAME}.${DOMAIN_NAME}"

# IdM IPv4 Subnet
IDM_SUBNET="192.168.1.0/24"

# IdM IPv4 Address
IDM_HOST_IP="192.168.1.80"

# Directory Manager Password
DM_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`

# IdM Administrator Username
ADMIN_PRINCIPAL='admin'

# IdM Administrator Password
ADMIN_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`

echo -e "\nDeploying IdM Server...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System:
dnf -y update

# Install the Random Number Generator
dnf -y install rng-tools

# Start rng service
systemctl enable --now rngd

# Set the hostname to a FQDN:
hostnamectl set-hostname ${IDM_HOST_NAME_FQDN}

# Ensure the timezone is properly set:
timedatectl set-timezone ${TIME_ZONE}
timedatectl set-local-rtc 0

# # Optional: Add host name to ``/etc/hosts`` if DNS does not resolve the FQDN:
# cat >> /etc/hosts <<EOL
# ${IDM_HOST_IP} ${IDM_HOST_NAME_FQDN} ${IDM_HOST_NAME}
#
# EOL

# Verify host name resolves to an IPv4 address that is not loopback:
dig +short ${IDM_HOST_NAME_FQDN} A

# Verify reverse DNS configuration (PTR records)
dig +short -x ${IDM_HOST_IP}

# Install Chrony NTP server
dnf -y install chrony

# Configure Chrony to allow remote clients
sed -i "s@#allow 192.168.0.0/16@allow ${IDM_SUBNET}@g" /etc/chrony.conf

# Restart chrondy service
systemctl restart chronyd

# Verify idm module information:
dnf module info idm:DL1

# Enable the idm:DL1 stream and sync repositories:
dnf module -y enable idm:DL1
dnf distro-sync

# Install IdM server without an integrated DNS:
dnf module -y install idm:DL1/server

# Suppress Negotiate headers (Prevents HTML Log In Box Popup in Windows):
mkdir -p /etc/httpd/conf.d/
cat > /etc/httpd/conf.d/gssapi.conf <<EOF
BrowserMatch Windows gssapi-no-negotiate
EOF

# Install IdM Server:
REALM_NAME_UC=$(echo ${REALM_NAME} | tr '[:lower:]' '[:upper:]')
ipa-server-install \
  --domain=${DOMAIN_NAME} \
  --realm=${REALM_NAME_UC} \
  --ds-password=${DM_PASSWORD} \
  --admin-password=${ADMIN_PASSWORD} \
  --unattended

# Configure firewalld rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${IDM_SUBNET} --permanent
firewall-cmd --zone=public --add-service={http,https,ntp,freeipa-4} --permanent
firewall-cmd --reload

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "*************************************************************************"  | tee    .deploy-idm-server-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-idm-server-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-idm-server-${timestamp}
echo   "**    Required for client deployments:                                 **"  | tee -a .deploy-idm-server-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-idm-server-${timestamp}
printf "**    Directory Manager Password:  %-35s **\n" ${DM_PASSWORD}               | tee -a .deploy-idm-server-${timestamp}
printf "**    IdM Administrator Username:  %-35s **\n" ${ADMIN_PRINCIPAL}           | tee -a .deploy-idm-server-${timestamp}
printf "**    IdM Administrator Password:  %-35s **\n" ${ADMIN_PASSWORD}            | tee -a .deploy-idm-server-${timestamp}
printf "**    IdM Domain Name:             %-35s **\n" ${DOMAIN_NAME}               | tee -a .deploy-idm-server-${timestamp}
printf "**    IdM Realm:                   %-35s **\n" ${REALM_NAME_UC}             | tee -a .deploy-idm-server-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-idm-server-${timestamp}
echo   "**    IdM Management Dashboard:                                        **"  | tee -a .deploy-idm-server-${timestamp}
printf "**      https://%-54s **\n" ${IDM_HOST_NAME_FQDN}                           | tee -a .deploy-idm-server-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-idm-server-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-idm-server-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-idm-server-${timestamp}
echo

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying IdM Server Complete\n"
exit 0
