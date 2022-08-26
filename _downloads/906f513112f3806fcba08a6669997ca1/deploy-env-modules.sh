#!/bin/bash
###############################################################################
#
#   Filename: deploy-env-modules.sh
#
#   Functional Description:
#
#       Bash script which deploys Environment Modules.
#
#   Usage:
#
#       ./deploy-env-modules.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Environment Modules...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Install user packages
dnf -y install environment-modules

# Create Environment Modules directory:
mkdir -p /apps/modulefiles/

# Add/Remove Environment Modules directories
cp /etc/environment-modules/initrc /etc/environment-modules/initrc.bak
cp /etc/environment-modules/modulespath /etc/environment-modules/modulespath.bak

sed -i 's|^module use|# module use|g' /etc/environment-modules/initrc

cat >> /etc/environment-modules/initrc <<EOF
module use --append {/apps/modulefiles}
EOF

sed -i \
    's|^/usr/share/Modules/modulefiles:/etc/modulefiles:/usr/share/modulefiles|# /usr/share/Modules/modulefiles:/etc/modulefiles:/usr/share/modulefiles|g' \
    /etc/environment-modules/modulespath

cat >> /etc/environment-modules/modulespath <<EOF
/apps/modulefiles
EOF

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Environment Modules Complete\n"
exit 0
