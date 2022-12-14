#!/bin/bash
###############################################################################
#
#   Filename: deploy-passwordless-ssh.sh
#
#   Functional Description:
#
#       Bash script which deploys passwordless ssh.
#
#   Usage:
#
#       ./deploy-passwordless-ssh.sh
#
###############################################################################


# Ensure running as user
if [ "$EUID" -eq 0 ]; then
  echo -e "ERROR: Please run as a user\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Passwordless SSH...\n"


###############################################################################
# Installation Commands
###############################################################################

# Generate public/private RSA key pair
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# Copy Public key to Authorized keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Disable strict host key checking
cat >> ~/.ssh/config <<EOL
StrictHostKeyChecking no
EOL

# Ensure proper permissions on files:
chmod 644 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/config
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
touch     ~/.ssh/known_hosts
chmod 644 ~/.ssh/known_hosts
chmod 700 ~/.ssh

# Upload Public Key to IdM / FreeIPA
ipa user-mod ${USER} --sshpubkey="$(cat ~/.ssh/id_rsa.pub)"

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Deploying Passwordless SSH Complete\n"
exit 0
