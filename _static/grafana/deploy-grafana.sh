#!/bin/bash
###############################################################################
#
#   Filename: deploy-grafana.sh
#
#   Functional Description:
#
#       Bash script which deploys Grafana.
#
#   Usage:
#
#       ./deploy-grafana.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Grafana...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Set Domain Name
DOMAIN_NAME="engwsc.example.com"

# Grafana Administrator Username
GRAFANA_ADMIN_USERNAME="admin"

# InfluxDB Administrator Password
GRAFANA_ADMIN_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`

# OpenSSL Country
OPENSSL_C="US"

# OpenSSL State
OPENSSL_ST="New York"

# OpenSSL Locality
OPENSSL_L="New York"

# OpenSSL Organization
OPENSSL_O="engwsc"

# OpenSSL Common Name
OPENSSL_CN="grafana.engwsc.example.com"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Add the Grafana Yum Repository
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Dependencies
dnf -y distro-sync
dnf -y install initscripts urw-fonts wget

# Install Grafana
dnf -y install grafana

# Create Self-signed certificates
# Country Name (2 letter code) [XX]:${OPENSSL_C}
# State or Province Name (full name) []:${OPENSSL_ST}
# Locality Name (eg, city) [Default City]:${OPENSSL_L}
# Organization Name (eg, company) [Default Company Ltd]:${OPENSSL_O}
# Organizational Unit Name (eg, section) []:
# Common Name (eg, your name or your server's hostname) []:${OPENSSL_CN}
# Email Address []:

openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "/etc/ssl/grafana-selfsigned.key" \
    -out "/etc/ssl/grafana-selfsigned.crt" \
    -subj "/CN=${OPENSSL_CN}/C=${OPENSSL_C}/ST=${OPENSSL_ST}/L=${OPENSSL_L}/O=${OPENSSL_O}" \
    -days 365

chgrp grafana /etc/ssl/grafana-selfsigned.key
chgrp grafana /etc/ssl/grafana-selfsigned.crt
chmod 440 /etc/ssl/grafana-selfsigned.key
chmod 440 /etc/ssl/grafana-selfsigned.key

# Set up Grafana
sed -i 's/^;protocol =.*/protocol = https/g' /etc/grafana/grafana.ini
sed -i "s/^;domain =.*/domain = ${DOMAIN_NAME}/g" /etc/grafana/grafana.ini
sed -i 's|^;cert_file =.*|cert_file = /etc/ssl/grafana-selfsigned.crt|g' /etc/grafana/grafana.ini
sed -i 's|^;cert_key =.*|cert_key = /etc/ssl/grafana-selfsigned.key|g' /etc/grafana/grafana.ini
sed -i 's|^;reporting_enabled =.*|reporting_enabled = false|g' /etc/grafana/grafana.ini
sed -i 's|^;disable_gravatar =.*|disable_gravatar = true|g' /etc/grafana/grafana.ini

sed -i "s|^;admin_user =.*|admin_user = ${GRAFANA_ADMIN_USERNAME}|g" /etc/grafana/grafana.ini
sed -i "s|^;admin_password =.*|admin_password = ${GRAFANA_ADMIN_PASSWORD}|g" /etc/grafana/grafana.ini

# Enable OpenSSH server daemon
systemctl daemon-reload
systemctl enable --now grafana-server

# Configure firewalld rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-port=3000/tcp --permanent
firewall-cmd --reload

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "****************************************************************************"  | tee    .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
echo   "**    Required for Grafana server access:                                 **"  | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
printf "**    Grafana Administrator Username: %-35s **\n" ${GRAFANA_ADMIN_USERNAME}    | tee -a .deploy-grafana-${timestamp}
printf "**    Grafana Administrator Password: %-35s **\n" ${GRAFANA_ADMIN_PASSWORD}    | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Grafana Complete\n"
exit 0
