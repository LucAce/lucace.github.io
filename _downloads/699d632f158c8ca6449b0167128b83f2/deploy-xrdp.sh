#!/bin/bash
###############################################################################
#
#   Filename: deploy-xrdp.sh
#
#   Functional Description:
#
#       Bash script which deploys xrdp.
#
#   Usage:
#
#       ./deploy-xrdp.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying xrdp...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# xrdp Port
XRDP_PORT="3389"

# OpenSSL Country
OPENSSL_C="US"

# OpenSSL State
OPENSSL_ST="New York"

# OpenSSL Locality
OPENSSL_L="New York"

# OpenSSL Organization
OPENSSL_O="engwsc"

# OpenSSL Common Name
OPENSSL_CN=$(hostname -f)


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Install Extra Packages for Enterprise Linux (EPEL) Repository
dnf -y install epel-release
dnf -y distro-sync

# Install xrdp
dnf -y install xorgxrdp xrdp

# Create Self-signed SSL certificate

# Country Name (2 letter code) [XX]:US
# State or Province Name (full name) []:New York
# Locality Name (eg, city) [Default City]:New York
# Organization Name (eg, company) [Default Company Ltd]:engwsc
# Organizational Unit Name (eg, section) []:
# Common Name (eg, your name or your server's hostname) []:user01.engwsc.example.com
# Email Address []:
mkdir -p /etc/xrdp/ssl/
openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "/etc/xrdp/ssl/xrdp-selfsigned.key" \
    -out "/etc/xrdp/ssl/xrdp-selfsigned.crt" \
    -subj "/CN=${OPENSSL_CN}/C=${OPENSSL_C}/ST=${OPENSSL_ST}/L=${OPENSSL_L}/O=${OPENSSL_O}" \
    -days 365

chmod 600 /etc/xrdp/ssl/xrdp-selfsigned.key
chmod 644 /etc/xrdp/ssl/xrdp-selfsigned.crt

# Set default options
sed -i "s|certificate=|certificate=/etc/xrdp/ssl/xrdp-selfsigned.crt|g" /etc/xrdp/xrdp.ini
sed -i "s|key_file=|key_file=/etc/xrdp/ssl/xrdp-selfsigned.key|g" /etc/xrdp/xrdp.ini
sed -i "s/security_layer=negotiate/security_layer=tls/g" /etc/xrdp/xrdp.ini

# Set firewalld rules
firewall-cmd --zone=public --add-port=${XRDP_PORT}/tcp --permanent
firewall-cmd --reload

# Restart xrdp service
systemctl enable xrdp
systemctl restart xrdp

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying xrdp Complete\n"
exit 0
