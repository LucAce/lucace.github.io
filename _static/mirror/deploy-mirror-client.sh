#!/bin/bash
###############################################################################
#
#   Filename: deploy-mirror-client.sh
#
#   Functional Description:
#
#       Bash script which deploys DNF Mirror Client.
#
#   Usage:
#
#       ./deploy-mirror-client.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF Mirror Client...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Create repository configuration file
cat > /etc/yum.repos.d/localmirror.repo <<EOF
[localrepo-baseos]
name=Local AlmaLinux 8 - BaseOS
baseurl=http://mirror.engwsc.example.com/almalinux/8/baseos
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[localrepo-appstream]
name=Local AlmaLinux 8 - AppStream
baseurl=http://mirror.engwsc.example.com/almalinux/8/appstream
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[localrepo-extras]
name=Local AlmaLinux 8 - Extras
baseurl=http://mirror.engwsc.example.com/almalinux/8/extras
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[localrepo-powertools]
name=Local AlmaLinux 8 - PowerTools
baseurl=http://mirror.engwsc.example.com/almalinux/8/powertools
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

EOF

# Disable Primary repositories
sed -i "s|enabled=1|enabled=0|g" /etc/yum.repos.d/almalinux.repo

# Clean the DNF cache
dnf clean all

# Test the system
dnf -y upgrade

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF Mirror Client Complete\n"
exit 0
