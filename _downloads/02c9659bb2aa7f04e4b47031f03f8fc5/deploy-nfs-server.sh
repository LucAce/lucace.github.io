#!/bin/bash
###############################################################################
#
#   Filename: deploy-nfs-server.sh
#
#   Functional Description:
#
#       Bash script which deploys NFS Server.
#
#   Usage:
#
#       ./deploy-nfs-server.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying NFS Server...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Set Domain Name
DOMAIN_NAME="engwsc.example.com"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Install NFS Utilities
dnf -y install nfs-utils

# Enable Cockpit
dnf -y remove cockpit-podman
systemctl enable --now cockpit.socket

# Set the NFS Domain Name
sed -i "s/#Domain = local.domain.edu/Domain = ${DOMAIN_NAME}/g" /etc/idmapd.conf

# Create directories that will be exported
mkdir -p /srv/nfs/app
mkdir -p /srv/nfs/backup
mkdir -p /srv/nfs/home
mkdir -p /srv/nfs/mirror
mkdir -p /srv/nfs/scratch

# Set owner to root
chown -R root:root /srv/nfs/app
chown -R root:root /srv/nfs/backup
chown -R root:root /srv/nfs/home
chown -R root:root /srv/nfs/mirror
chown -R root:root /srv/nfs/scratch

chmod 755 /srv/nfs/app
chmod 755 /srv/nfs/backup
chmod 755 /srv/nfs/home
chmod 755 /srv/nfs/mirror
chmod 755 /srv/nfs/scratch

chcon -R -t user_home_dir_t /srv/nfs/home
semanage fcontext -a -t user_home_dir_t /srv/nfs/home

# Create exports file
cat >> /etc/exports <<EOL
# NFS Exports
/srv/nfs/app     ${ALLOWED_IPV4}(rw,sync,secure,wdelay,subtree_check,no_root_squash)
/srv/nfs/backup  ${ALLOWED_IPV4}(rw,sync,secure,wdelay,subtree_check,no_root_squash)
/srv/nfs/home    ${ALLOWED_IPV4}(rw,sync,secure,wdelay,subtree_check,no_root_squash)
/srv/nfs/mirror  ${ALLOWED_IPV4}(rw,sync,secure,wdelay,subtree_check,no_root_squash)
/srv/nfs/scratch ${ALLOWED_IPV4}(rw,sync,secure,wdelay,subtree_check,no_root_squash)

EOL

# Start nfs server daemon
systemctl enable --now rpcbind nfs-server

# Configure firewall rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${ALLOWED_IPV4} --permanent
firewall-cmd --zone=public --add-service=cockpit --permanent
firewall-cmd --zone=public --add-service=nfs --permanent
firewall-cmd --reload

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying NFS Server Complete\n"
exit 0
