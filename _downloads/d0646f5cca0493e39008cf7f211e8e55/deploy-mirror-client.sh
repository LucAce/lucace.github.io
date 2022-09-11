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
dnf -y distro-sync
dnf -y upgrade

# Create repository configuration file
cat > /etc/yum.repos.d/local.repo <<EOF
[local-baseos]
name=Local AlmaLinux \$releasever Repository - BaseOS
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/baseos
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[local-appstream]
name=Local AlmaLinux \$releasever Repository - AppStream
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/appstream
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[local-extras]
name=Local AlmaLinux \$releasever Repository - Extras
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/extras
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[local-powertools]
name=Local AlmaLinux \$releasever Repository - PowerTools
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/powertools
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[local-ha]
name=Local AlmaLinux \$releasever Repository - High Availability
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/ha
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[local-influxdb]
name=Local InfluxDB Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/influxdb/rhel/\$releasever/influxdb
gpgcheck=1
enabled=0
countme=0
gpgkey=https://repos.influxdata.com/influxdb.key

[local-epel-modular]
name=Local EPEL Modular Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/epel/\$releasever/epel
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever

[local-epel]
name=Local EPEL Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/epel/\$releasever/epel
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever
EOF

# Disable remote repositories:
yum-config-manager --disable baseos
yum-config-manager --disable appstream
yum-config-manager --disable extras
yum-config-manager --disable powertools
yum-config-manager --disable ha

# Enable local repositories:
yum-config-manager --enable local-baseos
yum-config-manager --enable local-appstream
yum-config-manager --enable local-extras
yum-config-manager --enable local-powertools
yum-config-manager --enable local-ha

# **Optional** EPEL and InfluxDB/Telegraf repositories:
yum-config-manager --disable influxdb
yum-config-manager --disable epel-modular
yum-config-manager --disable epel

yum-config-manager --enable local-influxdb
yum-config-manager --enable local-epel-modular
yum-config-manager --enable local-epel

# Clean the DNF cache:
dnf clean all

# Test mirror:
dnf -y distro-sync
dnf -y upgrade

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF Mirror Client Complete\n"
exit 0
