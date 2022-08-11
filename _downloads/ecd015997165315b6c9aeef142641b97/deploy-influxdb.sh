#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi


###############################################################################
# Script Configuration Options
###############################################################################

# Set Domain Name
DOMAIN_NAME="engwsc.example.com"

# InfluxDB Default Bucket
INFLUXDB_DEFAULT_BUCKET="engwsc-cluster"

# InfluxDB Administrator Username
INFLUXDB_ADMIN_USERNAME="admin"

# InfluxDB Administrator Password
INFLUXDB_ADMIN_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`

# OpenSSL Country
OPENSSL_C="US"

# OpenSSL State
OPENSSL_ST="New York"

# OpenSSL Locality
OPENSSL_L="New York"

# OpenSSL Organization
OPENSSL_O="engwsc"

# OpenSSL Common Name
OPENSSL_CN="influxdb.engwsc.example.com"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y update

# Add the InfluxDB yum repository
#
# influxdb.key GPG Fingerprint: 05CE15085FC09D18E99EFB22684A14CF2582E0C5
cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF

# Install InfluxDB
dnf -y distro-sync
dnf -y install influxdb2 influxdb2-cli telegraf

# Disable InfluxData Telemetry
sed -i 's@/usr/bin/influxd@/usr/bin/influxd --reporting-disabled@g' /usr/lib/influxdb/scripts/influxd-systemd-start.sh

# Create Self-signed certificates
# Country Name (2 letter code) [XX]:${OPENSSL_C}
# State or Province Name (full name) []:${OPENSSL_ST}
# Locality Name (eg, city) [Default City]:${OPENSSL_L}
# Organization Name (eg, company) [Default Company Ltd]:${OPENSSL_O}
# Organizational Unit Name (eg, section) []:
# Common Name (eg, your name or your server's hostname) []:${OPENSSL_CN}
# Email Address []:

openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "/etc/ssl/influxdb-selfsigned.key" \
    -out "/etc/ssl/influxdb-selfsigned.crt" \
    -subj "/CN=${OPENSSL_CN}/C=${OPENSSL_C}/ST=${OPENSSL_ST}/L=${OPENSSL_L}/O=${OPENSSL_O}" \
    -days 365

# Set permissions and ownership on the Self-signed certificates
chmod 644 /etc/ssl/influxdb-selfsigned.crt
chmod 600 /etc/ssl/influxdb-selfsigned.key
chown influxdb:influxdb /etc/ssl/influxdb-selfsigned.crt
chown influxdb:influxdb /etc/ssl/influxdb-selfsigned.key

# Add certificates to InfluxDB configuration file
echo 'tls-cert = "/etc/ssl/influxdb-selfsigned.crt"' >> /etc/influxdb/config.toml
echo 'tls-key = "/etc/ssl/influxdb-selfsigned.key"'  >> /etc/influxdb/config.toml

# Start the InfluxDB service
systemctl enable --now influxdb

# [Optional] Verify TLS Connection
# curl -vk https://localhost:8086/api/v2/ping

# Setup InfluxDB
# ? Please type your primary username: ${INFLUXDB_ADMIN_USERNAME}
# ? Please type your password: ${INFLUXDB_ADMIN_PASSWORD}
# ? Please type your password again: ${INFLUXDB_ADMIN_PASSWORD}
# ? Please type your primary organization name: ${DOMAIN_NAME}
# ? Please type your primary bucket name: ${INFLUXDB_DEFAULT_BUCKET}
# ? Please type your retention period in hours, or 0 for infinite (0): 0
# ? Setup with these parameters?
#   Username:          ${INFLUXDB_SEVERADMIN_USERNAME}
#   Organization:      ${DOMAIN_NAME}
#   Bucket:            ${INFLUXDB_DEFAULT_BUCKET}
#   Retention Period:  infinite
#  (y/N) y

influx setup --force --skip-verify \
    --host "https://localhost:8086" \
    --org "${DOMAIN_NAME}" \
    --bucket "${INFLUXDB_DEFAULT_BUCKET}" \
    --username "${INFLUXDB_ADMIN_USERNAME}" \
    --password "${INFLUXDB_ADMIN_PASSWORD}" \
    --retention "0"

# Configure firewalld rules:
systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-port=8086/tcp --permanent
firewall-cmd --reload

echo
echo   "****************************************************************************"
echo   "****************************************************************************"
echo   "**                                                                        **"
echo   "**    Required for InfluxDB server access:                                **"
echo   "**                                                                        **"
printf "**    InfluxDB Administrator Username: %-34s **\n" ${INFLUXDB_ADMIN_USERNAME}
printf "**    InfluxDB Administrator Password: %-34s **\n" ${INFLUXDB_ADMIN_PASSWORD}
printf "**    InfluxDB Default Bucket:         %-34s **\n" ${INFLUXDB_DEFAULT_BUCKET}
echo   "**                                                                        **"
echo   "****************************************************************************"
echo   "****************************************************************************"
echo

exit 0
