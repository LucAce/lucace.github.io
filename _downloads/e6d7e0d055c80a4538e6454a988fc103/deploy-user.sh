#!/bin/bash
###############################################################################
#
#   Filename: deploy-user.sh
#
#   Functional Description:
#
#       Bash script which deploys user and compute nodes.
#
#   Usage:
#
#       ./deploy-user.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying User/Compute Node...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

#
# Disable online account integration
#

# Make sure gnome-online-accounts is installed
dnf -y install gnome-online-accounts

# Create the user profile:
mkdir -p /etc/dconf/profile/
cat > /etc/dconf/profile/user <<EOL
user-db:user
system-db:local
EOL

# Disable all providers:
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/00-goa <<EOL
[org/gnome/online-accounts]
whitelisted-providers= ['']
EOL

# Prevent the user from overriding these settings:
mkdir -p /etc/dconf/db/local.db/locks/
cat > /etc/dconf/db/local.db/locks/goa <<EOL
# Lock the list of providers that are allowed to be loaded
/org/gnome/online-accounts/whitelisted-providers
EOL

# Update the system databases:
dconf update

# Set firewalld rules:
systemctl enable --now firewalld
firewall-cmd --add-service=ssh --permanent
firewall-cmd --reload

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying User/Compute Node Complete\n"
exit 0
