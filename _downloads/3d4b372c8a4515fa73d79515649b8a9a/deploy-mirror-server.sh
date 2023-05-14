#!/bin/bash
###############################################################################
#
#   Filename: deploy-mirror-server.sh
#
#   Functional Description:
#
#       Bash script which deploys a local DNF/Yum Repository Server.
#
#   Usage:
#
#       ./deploy-mirror-server.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF/Yum Repository Server...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Repository Path
REPO_PATH="/srv/repos"

# Mirror OS Name / Version
RELEASE_NAME="almalinux"
RELEASE_VER="8"

# NFS Server Name
NFS_SERVER="nfs01.engwsc.example.com"

# NFS Server Name
NFS_SERVER_PATH="/srv/nfs/mirror"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Ensure ${REPO_PATH} is not already defined in /etc/fstab
if grep -Fq "${REPO_PATH}" /etc/fstab
then
    echo "ERROR: '${REPO_PATH}' is already defined in /etc/fstab"
    exit 1
fi

# Update system
dnf -y upgrade

# Install dependencies
dnf -y install nginx yum-utils

# Create local directory for the repositories
mkdir -p ${REPO_PATH}

# Configure NFS mount
cat >> /etc/fstab <<EOL

# Repository Mirror NFS Mount
${NFS_SERVER}:${NFS_SERVER_PATH} ${REPO_PATH} nfs4 defaults,tcp,soft,nfsvers=4 0 0
EOL

# Mount the mirror path
mount /srv/repos

# Create repository paths
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/BaseOS/x86_64/os/
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/AppStream/x86_64/os/
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/extras/x86_64/os/
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/PowerTools/x86_64/os/
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/HighAvailability/x86_64/os/

mkdir -p ${REPO_PATH}/epel/pub/epel/${RELEASE_VER}/Everything/x86_64/
mkdir -p ${REPO_PATH}/epel/pub/epel/${RELEASE_VER}/Modular/x86_64/

mkdir -p ${REPO_PATH}/gitlab/gitlab-ce/el/${RELEASE_VER}/x86_64/

mkdir -p ${REPO_PATH}/mongodb/yum/redhat/${RELEASE_VER}/mongodb-org/6.0/x86_64/
mkdir -p ${REPO_PATH}/elasticsearch/packages/oss-7.x/yum/
mkdir -p ${REPO_PATH}/graylog/repo/el/stable/4.3/x86_64/

mkdir -p ${REPO_PATH}/docker/linux/centos/${RELEASE_VER}/x86_64/stable/
mkdir -p ${REPO_PATH}/influxdb/rhel/${RELEASE_VER}/x86_64/stable/
mkdir -p ${REPO_PATH}/grafana/oss/rpm/

# Install Extra Packages for Enterprise Linux (EPEL) Repository
dnf -y install epel-release
dnf -y distro-sync
dnf -y clean all

# Add GitLab Repository

# Download and copy the GPG keys to the repository path
wget https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey \
    -O /srv/repos/RPM-GPG-KEY-gitlab

wget https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg \
    -O /srv/repos/RPM-GPG-KEY-gitlab-3D645A26AB9FBD22

# Import GPG key
rpm --import https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg

# Create repository file
cat > /etc/yum.repos.d/gitlab_gitlab-ce.repo <<EOF
[gitlab_gitlab-ce]
name=gitlab_gitlab-ce
baseurl=https://packages.gitlab.com/gitlab/gitlab-ce/el/\$releasever/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=0
gpgkey=https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey
       https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[gitlab_gitlab-ce-source]
name=gitlab_gitlab-ce-source
baseurl=https://packages.gitlab.com/gitlab/gitlab-ce/el/\$releasever/SRPMS
repo_gpgcheck=1
gpgcheck=1
enabled=0
gpgkey=https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey
       https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

# Disable this repository as it is not used locally
yum-config-manager --disable gitlab_gitlab-ce,gitlab_gitlab-ce-source

# Add Graylog Repositories

# MongoDB
#
# Download and copy the GPG key to the repository path
wget https://www.mongodb.org/static/pgp/server-6.0.asc \
    -O /srv/repos/RPM-GPG-KEY-mongodb

# Import GPG key
rpm --import https://www.mongodb.org/static/pgp/server-6.0.asc

# Create repository file
cat > /etc/yum.repos.d/mongodb-org-6.0.repo <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=0
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# Disable this repository as it is not used locally
yum-config-manager --disable mongodb-org-6.0

# ElasticSearch
#
# Download and copy the GPG key to the repository path
wget https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    -O /srv/repos/RPM-GPG-KEY-elasticsearch

# Import GPG key
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# Create repository file
cat > /etc/yum.repos.d/elasticsearch.repo <<EOF
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/oss-7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
EOF

# Disable this repository as it is not used locally
yum-config-manager --disable elasticsearch-7.x

# Graylog
#
# Install Graylog repository RPM
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-4.3-repository_latest.rpm

# Copy the GPG key to the repository path
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-graylog /srv/repos/RPM-GPG-KEY-graylog

# Import GPG key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-graylog

# Disable this repository as it is not used locally
yum-config-manager --disable graylog

# Add InfluxDB Repository

# Download and copy the GPG key to the repository path
wget https://repos.influxdata.com/influxdb.key \
    -O /srv/repos/RPM-GPG-KEY-influxdb

# Import GPG key
rpm --import https://repos.influxdata.com/influxdb.key

# Create repository file
# influxdb.key GPG Fingerprint: 05CE15085FC09D18E99EFB22684A14CF2582E0C5
cat > /etc/yum.repos.d/influxdb.repo <<EOF
[influxdb]
name=InfluxDB Repository - RHEL \$releasever
baseurl=https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://repos.influxdata.com/influxdb.key
EOF

# Enable this repository as it is used locally for telegraf
yum-config-manager --enable influxdb

# Add Grafana Repository

# Download and copy the GPG key to the repository path
wget https://rpm.grafana.com/gpg.key \
    -O /srv/repos/RPM-GPG-KEY-grafana

# Import GPG key
rpm --import https://rpm.grafana.com/gpg.key

# Create repository file
cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name = grafana
baseurl = https://rpm.grafana.com
repo_gpgcheck = 1
enabled = 0
gpgcheck = 1
gpgkey = https://rpm.grafana.com/gpg.key
sslverify = 1
sslcacert = /etc/pki/tls/certs/ca-bundle.crt
exclude = *beta*
EOF

# Disable this repository as it is not used locally
yum-config-manager --disable grafana

# Add Docker Repository

# Download and copy the GPG key to the repository path
wget https://download.docker.com/linux/centos/gpg \
    -O /srv/repos/RPM-GPG-KEY-docker

# Import GPG key
rpm --import https://download.docker.com/linux/centos/gpg

# Create repository file
yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# Disable this repository as it is not used locally
yum-config-manager --disable docker-ce-stable

# Create a Cron Job to synchronize repositories
cat > /etc/cron.daily/update-localrepos <<EOF
#!/bin/bash

/bin/dnf -y reposync --repoid=baseos            -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/BaseOS/x86_64/os/
/bin/dnf -y reposync --repoid=appstream         -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/AppStream/x86_64/os/
/bin/dnf -y reposync --repoid=extras            -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/extras/x86_64/os/
/bin/dnf -y reposync --repoid=powertools        -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/PowerTools/x86_64/os/
/bin/dnf -y reposync --repoid=ha                -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/HighAvailability/x86_64/os/

/bin/dnf -y reposync --repoid=epel              -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/epel/pub/epel/${RELEASE_VER}/Everything/x86_64/
/bin/dnf -y reposync --repoid=epel-modular      -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/epel/pub/epel/${RELEASE_VER}/Modular/x86_64/

/bin/dnf -y reposync --repoid=gitlab_gitlab-ce  -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/gitlab/gitlab-ce/el/8/x86_64/

/bin/dnf -y reposync --repoid=mongodb-org-6.0   -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/mongodb/yum/redhat/${RELEASE_VER}/mongodb-org/6.0/x86_64/
/bin/dnf -y reposync --repoid=elasticsearch-7.x -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/elasticsearch/packages/oss-7.x/yum/
/bin/dnf -y reposync --repoid=graylog           -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/graylog/repo/el/stable/4.3/x86_64/

/bin/dnf -y reposync --repoid=docker-ce-stable  -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/docker/linux/centos/${RELEASE_VER}/x86_64/stable/
/bin/dnf -y reposync --repoid=influxdb          -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/influxdb/rhel/${RELEASE_VER}/x86_64/stable/
/bin/dnf -y reposync --repoid=grafana           -g --delete --newest-only --norepopath --download-metadata -p ${REPO_PATH}/grafana/oss/rpm/
EOF

chmod 755 /etc/cron.daily/update-localrepos

# Synchronize repositories
dnf clean all
dnf -y distro-sync
/etc/cron.daily/update-localrepos

# Configure Nginx to server the repository over http
cat > /etc/nginx/conf.d/localrepos.conf <<EOF
server {
    listen      80;
    server_name mirror.engwsc.example.com;
    root        /srv/repos/;
    index       index.html;
    location / {
        autoindex on;
    }
}
EOF

# # If using local storage for /srv/repos/
# #
# # Permanently change the SELinux context of the local storage path
# semanage fcontext -a -t httpd_sys_content_t "/srv/repos(/.*)?"
#
# # Relabel files
# restorecon -F -R -v /srv/repos/

# If using NFS storage for /srv/repos/
#
# Set SELinux boolen to allow httpd to use nfs
setsebool -P httpd_use_nfs=1

# Enable Nginx service
systemctl enable --now nginx
systemctl status nginx

# Configure firewall rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF/Yum Repository Server Complete\n"
exit 0
