#!/bin/bash
###############################################################################
#
#   Filename: deploy-slurm-compute-node.sh
#
#   Functional Description:
#
#       Bash script which deploys Slurm Compute Node.
#
#   Usage:
#
#       ./deploy-slurm-compute-node.sh
#
###############################################################################


# Ensure running as root (not sudo)
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Slurm Compute Node...\n"


###############################################################################
# Notes
###############################################################################
#
# 1) This script requires files generated in the Slurm Controller Deployment
#    Guide.
#


###############################################################################
# Script Configuration Options
###############################################################################

# Cluster Subnet Mask (Firewall Rule)
CLUSTER_SUBNET_MASK="192.168.1.0/24"

# Slurm Version
SLURM_VERSION="22.05.6"

# Slurm User UID, GID
SLURMUSERID=64030
SLURMGROUPID=64030


###############################################################################
# Installation Commands
###############################################################################

# Verify required files are present
if [ ! -f slurm-${SLURM_VERSION}.rpm.tar.gz ]; then
    echo "ERROR: File slurm-${SLURM_VERSION}.rpm.tar.gz Not Found"
    exit 1
fi


# Install dependencies
echo -e "\nInstalling dependencies..."
dnf install -y munge munge-libs hwloc hwloc-libs ncurses curl rrdtool mariadb \
    mariadb-devel ibacm infiniband-diags

# Exclude DNF/Yum Slurm packages
echo -e "\nExcluding Slurm Packages..."
cat >> /etc/dnf/dnf.conf <<EOL

# Exclude slurm Packages
excludepkgs=slurm*

EOL

# Extract TAR
tar -xvf slurm-${SLURM_VERSION}.rpm.tar.gz


###############################################################################
# Munge
###############################################################################

echo -e "\nEnabling Munge..."

# Copy munge authentication key
mkdir -p /etc/munge
cp -f munge.key /etc/munge/munge.key

chmod 700 /etc/munge
chmod 600 /etc/munge/munge.key
chown -R munge:munge /etc/munge

# Enable Munge service
systemctl enable --now munge


###############################################################################
# Slurm
###############################################################################

echo -e "\nInstalling Slurm..."

# Create Slurm User and group
groupadd -g $SLURMGROUPID slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSERID -g slurm -s /bin/bash slurm

# Install RPMs
rpm -ivh \
    slurm-${SLURM_VERSION}-1.el8.x86_64.rpm \
    slurm-perlapi-${SLURM_VERSION}-1.el8.x86_64.rpm \
    slurm-slurmd-${SLURM_VERSION}-1.el8.x86_64.rpm \
    slurm-torque-${SLURM_VERSION}-1.el8.x86_64.rpm

# Copy Slurm configuration files:
mkdir -p /etc/slurm/

cp -f cgroup.conf /etc/slurm/
cp -f slurm.conf  /etc/slurm/
chmod 755 /etc/slurm/
chmod 644 /etc/slurm/cgroup.conf
chmod 644 /etc/slurm/slurm.conf
chown -R slurm:slurm /etc/slurm/

# Create Slurm log files:
mkdir -p /var/log/slurm/

touch /var/log/slurm/slurmd.log
chmod 755 /var/log/slurm/
chmod 644 /var/log/slurm/*.log
chown -R slurm:slurm /var/log/slurm

# Create Slurm spool files:
mkdir -p /var/spool/slurmd
chmod 700 /var/spool/slurmd
chown -R slurm:slurm /var/spool/slurmd

# Setup log rotation
cat >> /etc/logrotate.d/slurm <<EOL
/var/log/slurmd.log
{
    missingok
    notifempty
    rotate 4
    weekly
    create
}

EOL

chmod 644 /etc/logrotate.d/slurm


###############################################################################
# Configure firewalld Rules
###############################################################################

echo -e "\nEnabling firewalld rules..."

systemctl enable --now firewalld
firewall-cmd --zone=public --add-source=${CLUSTER_SUBNET_MASK} --permanent
firewall-cmd --zone=public --add-port={6817/tcp,6818/tcp} --permanent
firewall-cmd --reload


###############################################################################
# Slurm Compute Node Service
###############################################################################

echo -e "\nEnabling Slurm Compute Node Service..."

systemctl enable --now slurmd

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Slurm Compute Node Complete\n"
exit 0
