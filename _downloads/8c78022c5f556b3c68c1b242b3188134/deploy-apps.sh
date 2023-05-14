#!/bin/bash
###############################################################################
#
#   Filename: deploy-tool.sh
#
#   Functional Description:
#
#       Bash script which deploys tool.
#
#   Usage:
#
#       ./deploy-tool.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying tool...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Install Extra Packages for Enterprise Linux (EPEL) Repository
dnf -y install epel-release
dnf -y distro-sync

# Install user packages
dnf -y install \
    filezilla emacs meld geany \
    vim-X11 cmake p7zip \
    ncurses ncurses-devel \
    lm_sensors lm_sensors-devel \
    hwloc hwloc-libs gnome-tweaks

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying tool Complete\n"
exit 0
