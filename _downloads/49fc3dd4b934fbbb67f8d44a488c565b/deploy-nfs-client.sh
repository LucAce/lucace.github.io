#!/bin/bash
###############################################################################
#
#   Filename: deploy-nfs-client.sh
#
#   Functional Description:
#
#       Bash script which deploys NFS Client.
#
#   Usage:
#
#       ./deploy-nfs-client.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying NFS Client...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Set Domain Name
DOMAIN_NAME="engwsc.example.com"

# NFS Server Name
NFS_SERVER="nfs01"


###############################################################################
# Installation Commands
###############################################################################

# Ensure /app is not already defined in /etc/fstab
if grep -Fq '/app' /etc/fstab
then
    echo "ERROR: '/app' is already defined in /etc/fstab"
    exit 1
fi

# Ensure /home is not already defined in /etc/fstab
if grep -Fq '/home' /etc/fstab
then
    echo "ERROR: '/home' is already defined in /etc/fstab"
    exit 1
fi

# Ensure /scratch is not already defined in /etc/fstab
if grep -Fq '/scratch' /etc/fstab
then
    echo "ERROR: '/scratch' is already defined in /etc/fstab"
    exit 1
fi

# Update System
dnf -y upgrade

# Install NFS Utilities
dnf -y install nfs-utils

# Set the NFS Domain Name
sed -i "s/#Domain = local.domain.edu/Domain = ${DOMAIN_NAME}/g" /etc/idmapd.conf

# Create local directories
mkdir -p /app
mkdir -p /home
mkdir -p /scratch

# Enable mounts at boot
cat >> /etc/fstab <<EOL

# NFS Mounts
${NFS_SERVER}.${DOMAIN_NAME}:/srv/nfs/app     /app     nfs4 defaults,tcp,soft,nfsvers=4 0 0
${NFS_SERVER}.${DOMAIN_NAME}:/srv/nfs/home    /home    nfs4 defaults,tcp,soft,nfsvers=4 0 0
${NFS_SERVER}.${DOMAIN_NAME}:/srv/nfs/scratch /scratch nfs4 defaults,tcp,soft,nfsvers=4 0 0

EOL

# Mount paths
mount /app
mount /home
mount /scratch

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying NFS Client Complete\n"
exit 0
