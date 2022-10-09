#!/bin/bash
###############################################################################
#
#   Filename: deploy-influxdb.sh
#
#   Functional Description:
#
#       Bash script which deploys InfluxDB.
#
#   Usage:
#
#       ./deploy-influxdb.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying InfluxDB...\n"


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
dnf -y upgrade

# Add the InfluxDB Yum Repository
#
# influxdb.key GPG Fingerprint: 05CE15085FC09D18E99EFB22684A14CF2582E0C5
cat > /etc/yum.repos.d/influxdb.repo <<EOF
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

# Start the InfluxDB service
systemctl daemon-reload
systemctl enable --now influxdb

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
    --host "http://localhost:8086" \
    --org "${DOMAIN_NAME}" \
    --bucket "${INFLUXDB_DEFAULT_BUCKET}" \
    --username "${INFLUXDB_ADMIN_USERNAME}" \
    --password "${INFLUXDB_ADMIN_PASSWORD}" \
    --retention "0"

# Install NGINX
dnf -y distro-sync
dnf -y install nginx

# Create directory structure
mkdir -p  /etc/pki/nginx/
chmod 755 /etc/pki/nginx/

# Create Self-Signed SSL Certificate
#
# Country Name (2 letter code) [XX]:${OPENSSL_C}
# State or Province Name (full name) []:${OPENSSL_ST}
# Locality Name (eg, city) [Default City]:${OPENSSL_L}
# Organization Name (eg, company) [Default Company Ltd]:${OPENSSL_O}
# Organizational Unit Name (eg, section) []:
# Common Name (eg, your name or your server's hostname) []:${OPENSSL_CN}
# Email Address []:
openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "/etc/pki/nginx/${OPENSSL_CN}.key" \
    -out    "/etc/pki/nginx/${OPENSSL_CN}.crt" \
    -subj   "/CN=${OPENSSL_CN}/C=${OPENSSL_C}/ST=${OPENSSL_ST}/L=${OPENSSL_L}/O=${OPENSSL_O}" \
    -days   365

# Set certificate permissions
chown root:root /etc/pki/nginx/${OPENSSL_CN}.key
chown root:root /etc/pki/nginx/${OPENSSL_CN}.crt
chmod 600       /etc/pki/nginx/${OPENSSL_CN}.key

# Configure NGINX
mkdir -p /etc/nginx/conf.d/
cat > /etc/nginx/conf.d/influxdb.conf <<EOF
server {
    listen 80;
    server_name ${OPENSSL_CN};
    root /nowhere;
    rewrite ^ https://\$server_name\$request_uri permanent;
}
server
{
    listen      443 ssl http2;
    server_name ${OPENSSL_CN};

    ssl_certificate "/etc/pki/nginx/${OPENSSL_CN}.crt";
    ssl_certificate_key "/etc/pki/nginx/${OPENSSL_CN}.key";
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 10m;
    ssl_ciphers PROFILE=SYSTEM;
    ssl_prefer_server_ciphers on;

    location /
    {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass       http://127.0.0.1:8086;
    }
}
EOF

# Configure SELinux
setsebool -P httpd_can_network_connect 1
semanage port -a -t http_port_t -p tcp 8086

# Enable NGINX service
systemctl daemon-reload
systemctl enable --now nginx

# Set firewalld rules
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --reload

# Create server info file
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "****************************************************************************"  | tee    .deploy-influxdb-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-influxdb-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-influxdb-${timestamp}
echo   "**    InfluxDB:                                                           **"  | tee -a .deploy-influxdb-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-influxdb-${timestamp}
printf "**    Administrator Username: %-43s **\n" ${INFLUXDB_ADMIN_USERNAME}           | tee -a .deploy-influxdb-${timestamp}
printf "**    Administrator Password: %-43s **\n" ${INFLUXDB_ADMIN_PASSWORD}           | tee -a .deploy-influxdb-${timestamp}
printf "**    Default Bucket:         %-43s **\n" ${INFLUXDB_DEFAULT_BUCKET}           | tee -a .deploy-influxdb-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-influxdb-${timestamp}
echo   "**    Server URL:                                                         **"  | tee -a .deploy-influxdb-${timestamp}
printf "**      https://%-57s **\n" "${OPENSSL_CN}"                                    | tee -a .deploy-influxdb-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-influxdb-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-influxdb-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-influxdb-${timestamp}
echo

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying InfluxDB Complete\n"
exit 0
