#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y update

#
# Enable Red Hat Enterprise Linux Codeready Repository
#
# subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
# dnf distro-sync

#
# Enable AlmaLinux PowerTools/CRB Repository
#
dnf config-manager --set-enabled powertools
dnf distro-sync

# Install EPEL
dnf -y install epel-release

# Install Ansible
dnf -y install ansible

# Install Ansible command shell completion
python3 -m pip install --user argcomplete
activate-global-python-argcomplete

# Create a default configuration file
mv /etc/ansible/ansible.cfg /etc/ansible/ansible.cfg.old
ansible-config init --disabled > /etc/ansible/ansible.cfg

# Set default options
sed -i "s/;nocows=.*/nocows=True/g" /etc/ansible/ansible.cfg

exit 0
