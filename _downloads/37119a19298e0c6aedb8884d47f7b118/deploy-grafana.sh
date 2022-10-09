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
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Grafana...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Set Domain Name
DOMAIN_NAME="engwsc.example.com"

# Grafana Administrator Username
GRAFANA_ADMIN_USERNAME="admin"

# Grafana Administrator Password
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
cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name = grafana
baseurl = https://packages.grafana.com/oss/rpm
repo_gpgcheck = 1
enabled = 1
gpgcheck = 1
gpgkey = https://packages.grafana.com/gpg.key
sslverify = 1
sslcacert = /etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Dependencies
dnf -y distro-sync
dnf -y install initscripts urw-fonts wget

# Install Grafana
dnf -y install grafana

# Set up Grafana
sed -i "s/^;domain =.*/domain = ${DOMAIN_NAME}/g" /etc/grafana/grafana.ini
sed -i 's|^;reporting_enabled =.*|reporting_enabled = false|g' /etc/grafana/grafana.ini
sed -i 's|^;disable_gravatar =.*|disable_gravatar = true|g' /etc/grafana/grafana.ini

sed -i "s|^;admin_user =.*|admin_user = ${GRAFANA_ADMIN_USERNAME}|g" /etc/grafana/grafana.ini
sed -i "s|^;admin_password =.*|admin_password = ${GRAFANA_ADMIN_PASSWORD}|g" /etc/grafana/grafana.ini

# Start the Grafana service
systemctl daemon-reload
systemctl enable --now grafana-server

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
cat > /etc/nginx/conf.d/grafana.conf <<EOF
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
        proxy_pass       http://127.0.0.1:3000;
    }
}
EOF

# Configure SELinux
setsebool -P httpd_can_network_connect 1
semanage port -a -t http_port_t -p tcp 3000

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
echo   "****************************************************************************"  | tee    .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
echo   "**    Grafana:                                                            **"  | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
printf "**    Administrator Username: %-43s **\n" ${GRAFANA_ADMIN_USERNAME}            | tee -a .deploy-grafana-${timestamp}
printf "**    Administrator Password: %-43s **\n" ${GRAFANA_ADMIN_PASSWORD}            | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
echo   "**    Server URL:                                                         **"  | tee -a .deploy-grafana-${timestamp}
printf "**      https://%-57s **\n" "${OPENSSL_CN}"                                    | tee -a .deploy-grafana-${timestamp}
echo   "**                                                                        **"  | tee -a .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo   "****************************************************************************"  | tee -a .deploy-grafana-${timestamp}
echo

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Grafana Complete\n"
exit 0
