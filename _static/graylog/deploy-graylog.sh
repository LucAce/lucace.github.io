#!/bin/bash
###############################################################################
#
#   Filename: deploy-graylog.sh
#
#   Functional Description:
#
#       Bash script which deploys Graylog.
#
#   Usage:
#
#       ./deploy-graylog.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Graylog...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Set Host Name
HOST_NAME="graylog.engwsc.example.com"

# Graylog Bind Port
GRAYLOG_PORT="9000"

# Rsyslog Port
RSYSLOG_PORT="6514"

# Graylog Secret
GRAYLOG_SECRET=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 64 ;`

# Graylog Secret SHA256
GRAYLOG_SECRET_SHA256=`echo -n "${GRAYLOG_SECRET}" | tr -d '\n' | sha256sum | cut -d" " -f1`

# OpenSSL Country
OPENSSL_C="US"

# OpenSSL State
OPENSSL_ST="New York"

# OpenSSL Locality
OPENSSL_L="New York"

# OpenSSL Organization
OPENSSL_O="engwsc"

# OpenSSL Common Name
OPENSSL_CN="graylog.engwsc.example.com"

# OpenSSL IP Address
OPENSSL_IP="192.168.1.83"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Install Dependencies
dnf -y install epel-release

dnf -y distro-sync
dnf -y install pwgen java-1.8.0-openjdk-headless \
    checkpolicy policycoreutils selinux-policy-devel


#
# MongoDB
#

# Add the MongoDB Yum Repository
cat > /etc/yum.repos.d/mongodb-org-6.0.repo <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# Install MongoDB
dnf -y distro-sync
dnf -y install mongodb-org

# Add SELinux policy to permit access to cgroup
mkdir -p /etc/mongod/selinux/

cat > /etc/mongod/selinux/mongodb_cgroup_memory.te <<EOF
module mongodb_cgroup_memory 1.0;
require {
      type cgroup_t;
      type mongod_t;
      class dir search;
      class file { getattr open read };
}
#============= mongod_t ==============
allow mongod_t cgroup_t:dir search;
allow mongod_t cgroup_t:file { getattr open read };
EOF

checkmodule -M -m \
    -o /etc/mongod/selinux/mongodb_cgroup_memory.mod \
    /etc/mongod/selinux/mongodb_cgroup_memory.te

semodule_package \
    -o /etc/mongod/selinux/mongodb_cgroup_memory.pp \
    -m /etc/mongod/selinux/mongodb_cgroup_memory.mod

semodule -i /etc/mongod/selinux/mongodb_cgroup_memory.pp

# Add SELinux policy to permit access to netstat
cat > /etc/mongod/selinux/mongodb_proc_net.te <<EOF
module mongodb_proc_net 1.0;
require {
    type proc_net_t;
    type mongod_t;
    class file { open read };
}
#============= mongod_t ==============
allow mongod_t proc_net_t:file { open read };
EOF

checkmodule -M -m \
    -o /etc/mongod/selinux/mongodb_proc_net.mod \
    /etc/mongod/selinux/mongodb_proc_net.te

semodule_package \
    -o /etc/mongod/selinux/mongodb_proc_net.pp \
    -m /etc/mongod/selinux/mongodb_proc_net.mod

semodule -i /etc/mongod/selinux/mongodb_proc_net.pp

# Start MongoDB
systemctl daemon-reload
systemctl enable --now mongod


#
# ElasticSearch
#

# Add the ElasticSearch Yum Repository
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

cat > /etc/yum.repos.d/elasticsearch.repo <<EOF
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/oss-7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# Install ElasticSearch
dnf -y distro-sync
dnf -y install elasticsearch-oss

# Configure ElasticSearch for Graylog
tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOT
cluster.name: graylog
action.auto_create_index: false
EOT

# Start ElasticSearch
systemctl daemon-reload
systemctl enable --now elasticsearch


#
# Graylog
#
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-4.3-repository_latest.rpm

dnf -y distro-sync
dnf -y install graylog-server

# Set Graylog Secrets
sed -i "s|password_secret =.*|password_secret = ${GRAYLOG_SECRET}|g" /etc/graylog/server/server.conf
sed -i "s|root_password_sha2 =.*|root_password_sha2 = ${GRAYLOG_SECRET_SHA256}|g" /etc/graylog/server/server.conf

# Configure SELinux
setsebool -P httpd_can_network_connect 1
semanage port -a -t http_port_t -p tcp ${GRAYLOG_PORT}

# Start Graylog
systemctl daemon-reload
systemctl enable --now graylog-server


#
# NGINX
#

# Install NGINX
dnf -y distro-sync
dnf -y install nginx

# Create directory structure
mkdir -p  /etc/pki/nginx/
chmod 755 /etc/pki/nginx/

# Create OpenSSL configuration file
mkdir -p /etc/pki/nginx/
cat > /etc/pki/nginx/graylog.engwsc.example.com.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

# Details about the issuer of the certificate
[req_distinguished_name]
C = ${OPENSSL_C}
ST = ${OPENSSL_ST}
L = ${OPENSSL_L}
O = ${OPENSSL_O}
CN = ${OPENSSL_CN}

[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

# IP addresses and DNS names the certificate should include
# Use IP.### for IP addresses and DNS.### for DNS names,
# with "###" being a consecutive number.
[alt_names]
IP.1 = ${OPENSSL_IP}
DNS.1 = ${OPENSSL_CN}
EOF

# Create certificate
openssl req -x509 -days 365 -nodes -newkey rsa:4096 \
    -config /etc/pki/nginx/graylog.engwsc.example.com.cnf \
    -keyout /etc/pki/nginx/graylog.engwsc.example.com.key \
    -out    /etc/pki/nginx/graylog.engwsc.example.com.crt

# Set permissions
chown graylog:graylog /etc/pki/nginx/graylog.engwsc.example.com.key
chown graylog:graylog /etc/pki/nginx/graylog.engwsc.example.com.crt
chmod 600 /etc/pki/nginx/graylog.engwsc.example.com.key

# Configure NGINX
mkdir -p /etc/nginx/conf.d/
cat > /etc/nginx/conf.d/graylog.conf <<EOF
server {
    listen 80;
    server_name graylog.engwsc.example.com;
    root /nowhere;
    rewrite ^ https://\$server_name\$request_uri permanent;
}
server
{
    listen      443 ssl http2;
    server_name graylog.engwsc.example.com;

    ssl_certificate "/etc/pki/nginx/graylog.engwsc.example.com.crt";
    ssl_certificate_key "/etc/pki/nginx/graylog.engwsc.example.com.key";
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 10m;
    ssl_ciphers PROFILE=SYSTEM;
    ssl_prefer_server_ciphers on;

    location /
    {
      proxy_set_header Host \$http_host;
      proxy_set_header X-Forwarded-Host \$host;
      proxy_set_header X-Forwarded-Server \$host;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Graylog-Server-URL https://\$server_name/;
      proxy_pass       http://127.0.0.1:9000;
    }
}
EOF

# Enable NGINX service
systemctl daemon-reload
systemctl enable --now nginx

# Set firewalld rules
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-port=${RSYSLOG_PORT}/tcp --permanent
firewall-cmd --reload

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "*****************************************************************************************"  | tee    .deploy-graylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-graylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-graylog-${timestamp}
echo   "**    Required for Graylog server access:                                              **"  | tee -a .deploy-graylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-graylog-${timestamp}
echo   "**    Graylog Administrator User: admin                                                **"  | tee -a .deploy-graylog-${timestamp}
printf "**    Graylog Secret: %-64s **\n" ${GRAYLOG_SECRET}                                         | tee -a .deploy-graylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-graylog-${timestamp}
echo   "**    Graylog Dashboard:                                                               **"  | tee -a .deploy-graylog-${timestamp}
printf "**      https://%-70s **\n" "${HOST_NAME}"                                                  | tee -a .deploy-graylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-graylog-${timestamp}
printf "**    Rsyslog Server Port: %-60s**\n" "${RSYSLOG_PORT}"                                     | tee -a .deploy-graylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-graylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-graylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-graylog-${timestamp}
echo

echo "REQUIRED: Create RSyslog Input in Web Interface (https://${HOST_NAME})"
echo

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Graylog Complete\n"
exit 0
