#!/bin/bash
###############################################################################
#
#   Filename: deploy-mirror-server.sh
#
#   Functional Description:
#
#       Bash script which deploys DNF Mirror Server.
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

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF Mirror Server...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Repository Path
REPO_PATH="/srv/repos"

# Mirror OS Name / Version
RELEASE_NAME="almalinux"
RELEASE_VER="8"

# Set Host Name
HOST_NAME=$(hostname -f)

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

# Update System
dnf -y upgrade

# Install Dependencies
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
mkdir -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/{baseos,appstream,extras,ha,powertools}

# Create a Cron Job to synchronize repositories
cat > /etc/cron.daily/update-localrepos <<EOF
#!/bin/bash

/bin/dnf reposync --repoid=baseos        -g --delete --newest-only --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/
/bin/dnf reposync --repoid=appstream     -g --delete --newest-only --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/
/bin/dnf reposync --repoid=extras        -g --delete --newest-only --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/
/bin/dnf reposync --repoid=powertools    -g --delete --newest-only --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/
/bin/dnf reposync --repoid=ha            -g --delete --newest-only --download-metadata -p ${REPO_PATH}/${RELEASE_NAME}/${RELEASE_VER}/
/bin/dnf reposync --repoid=influxdb      -g --delete --newest-only --download-metadata -p ${REPO_PATH}/influxdb/rhel/${RELEASE_VER}/
/bin/dnf reposync --repoid=epel          -g --delete --newest-only --download-metadata -p ${REPO_PATH}/epel/${RELEASE_VER}/
/bin/dnf reposync --repoid=epel-modular  -g --delete --newest-only --download-metadata -p ${REPO_PATH}/epel/${RELEASE_VER}/
EOF

chmod 755 /etc/cron.daily/update-localrepos

# Synchronize repositories
/etc/cron.daily/update-localrepos

# Configure Nginx to server the repository over http
cat > /etc/nginx/conf.d/localrepos.conf <<EOF
server {
    listen      80;
    server_name ${HOST_NAME};
    root        ${REPO_PATH}/;
    index       index.html;
    location / {
        autoindex on;
    }
}
EOF

# SELinux security context (If locally hosted)
chcon -Rt httpd_sys_content_t ${REPO_PATH}/

# Allow httpd to use nfs (If NFS hosted)
setsebool -P httpd_use_nfs=1

# Enable nginx
systemctl enable --now nginx
systemctl status nginx

# Configure firewall rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF Mirror Server Complete\n"
exit 0
