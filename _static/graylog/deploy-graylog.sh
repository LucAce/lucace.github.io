#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo
echo "*****************************"
echo "*****************************"
echo "**                         **"
echo "**    Deploying Graylog    **"
echo "**                         **"
echo "*****************************"
echo "*****************************"
echo


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
dnf -y update

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

# Create directory structure
mkdir -p  /etc/graylog/ssl/
chmod 755 /etc/graylog/ssl

# Create OpenSSL configuration file
cat > /etc/graylog/ssl/graylog.engwsc.example.com.cnf <<EOF
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
    -config /etc/graylog/ssl/graylog.engwsc.example.com.cnf \
    -keyout /etc/graylog/ssl/graylog.engwsc.example.com.key \
    -out    /etc/graylog/ssl/graylog.engwsc.example.com.crt

# Set permissions
chown graylog:graylog /etc/graylog/ssl/graylog.engwsc.example.com.key
chown graylog:graylog /etc/graylog/ssl/graylog.engwsc.example.com.crt
chmod 600 /etc/graylog/ssl/graylog.engwsc.example.com.key

# Import certificate into java Key Store:
keytool -importcert -noprompt \
    -keystore /etc/pki/java/cacerts \
    -storepass changeit \
    -alias graylog-self-signed \
    -file /etc/graylog/ssl/graylog.engwsc.example.com.crt

# Set Graylog Secrets
sed -i "s|password_secret =.*|password_secret = ${GRAYLOG_SECRET}|g" /etc/graylog/server/server.conf
sed -i "s|root_password_sha2 =.*|root_password_sha2 = ${GRAYLOG_SECRET_SHA256}|g" /etc/graylog/server/server.conf
sed -i "s|#http_bind_address =.*|http_bind_address = ${HOST_NAME}:${GRAYLOG_PORT}|g" /etc/graylog/server/server.conf

sed -i "s|#http_enable_tls =.*|http_enable_tls = true|g" /etc/graylog/server/server.conf
sed -i "s|#http_tls_cert_file =.*|http_tls_cert_file = /etc/graylog/ssl/graylog.engwsc.example.com.crt|g" /etc/graylog/server/server.conf
sed -i "s|#http_tls_key_file =.*|http_tls_key_file = /etc/graylog/ssl/graylog.engwsc.example.com.key|g" /etc/graylog/server/server.conf

# Configure SELinux
setsebool -P httpd_can_network_connect 1
semanage port -a -t http_port_t -p tcp ${GRAYLOG_PORT}

# Start Graylog
systemctl daemon-reload
systemctl enable --now graylog-server

# Set firewalld rules
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-port=${GRAYLOG_PORT}/tcp --permanent
firewall-cmd --zone=public --add-port=${RSYSLOG_PORT}/tcp --permanent
firewall-cmd --reload

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "*****************************************************************************************"  | tee    .deploy-greylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-greylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-greylog-${timestamp}
echo   "**    Required for Graylog server access:                                              **"  | tee -a .deploy-greylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-greylog-${timestamp}
echo   "**    Graylog Administrator User: admin                                                **"  | tee -a .deploy-greylog-${timestamp}
printf "**    Graylog Secret: %-64s **\n" ${GRAYLOG_SECRET}                                         | tee -a .deploy-greylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-greylog-${timestamp}
echo   "**    Graylog Dashboard:                                                               **"  | tee -a .deploy-greylog-${timestamp}
printf "**      https://%-70s **\n" "${HOST_NAME}:${GRAYLOG_PORT}"                                  | tee -a .deploy-greylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-greylog-${timestamp}
printf "**    Rsyslog Server Port: %-60s**\n" "${RSYSLOG_PORT}"                                     | tee -a .deploy-greylog-${timestamp}
echo   "**                                                                                     **"  | tee -a .deploy-greylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-greylog-${timestamp}
echo   "*****************************************************************************************"  | tee -a .deploy-greylog-${timestamp}
echo

echo "REQUIRED: Create RSyslog Input in Web Interface (https://${HOST_NAME}:${GRAYLOG_PORT})"
echo

exit 0
