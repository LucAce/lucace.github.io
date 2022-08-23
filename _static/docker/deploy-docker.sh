#!/bin/bash
###############################################################################
#
#   Filename: deploy-docker.sh
#
#   Functional Description:
#
#       Bash script which deploys Docker.
#
#   Usage:
#
#       ./deploy-docker.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Docker...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y update

# Install Dependencies
dnf -y install yum-utils

# Remove Conflicting Packages
dnf -y remove docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    cockpit-podman \
    runc

# Add the Docker Yum Repository
# Docker GPG key fingerprint: 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker CE
dnf -y distro-sync
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start the Docker service
systemctl daemon-reload
systemctl enable --now docker

# Verify Docker is Operating
docker run hello-world

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Docker Complete\n"
exit 0
