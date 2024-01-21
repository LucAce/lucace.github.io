#!/bin/bash
###############################################################################
#
#   Filename: deploy-telegraf.sh
#
#   Functional Description:
#
#       Bash script which deploys Telegraf Agent.
#
#   Usage:
#
#       ./deploy-idm-telegraf.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Telegraf Agent...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# InfluxDB Server URL
INFLUX_URL="https://influxdb.engwsc.example.com"

# InfluxDB Organization
INFLUX_ORGANIZATION="engwsc.example.com"

# InfluxDB Bucket
INFLUX_BUCKET="engwsc-cluster"

# InfluxDB Token
INFLUX_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Add the InfluxDB yum repository
#
# influxdb.key GPG Fingerprint: 05CE15085FC09D18E99EFB22684A14CF2582E0C5
cat > /etc/yum.repos.d/influxdb.repo <<EOF
[influxdb]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF

# Install Telegraf
dnf -y distro-sync
dnf -y install telegraf

# Create telegraf configuration file
telegraf config \
    --input-filter cpu:disk:diskio:kernel:mem:net:netstat:nfsclient:processes:smart:swap:system \
    --output-filter influxdb_v2 \
    --section-filter agent:inputs:outputs \
    > telegraf.conf

# Add the Influx API token to the telegraf user's environment file
cat > /etc/default/telegraf <<EOF
INFLUX_TOKEN=${INFLUX_TOKEN}
EOF

chmod 600 /etc/default/telegraf


#
# Configure telegraf.conf
#

# Set InfluxDB server URL
sed -i "s@urls = \[\"http://127.0.0.1:8086\"\]@urls = [\"${INFLUX_URL}\"]@g" telegraf.conf

# Set InfluxDB token
sed -i "s@token = \"\"@token = \"\${INFLUX_TOKEN}\"@g" telegraf.conf

# Set organization
sed -i "s@organization = \"\"@organization = \"${INFLUX_ORGANIZATION}\"@g" telegraf.conf

# Set bucket
sed -i "s@bucket = \"\"@bucket = \"${INFLUX_BUCKET}\"@g" telegraf.conf

# Disable SSL cert verification
sed -i "s@# insecure_skip_verify = false@insecure_skip_verify = true@g" telegraf.conf

# Enable collecting of cpu_time
sed -i "s@collect_cpu_time = false@collect_cpu_time = true@g" telegraf.conf

# Enable nfs client full stats
sed -i "s@## fullstat = false@fullstat = true@g" telegraf.conf

# Setting 'use_sudo' to true will make use of sudo to run smartctl or nvme-cli.
sed -i "s/# use_sudo = false/use_sudo = true/g" telegraf.conf

# Setting Gather all returned S.M.A.R.T. attribute
sed -i "s/# attributes = false/attributes = true/g" telegraf.conf

# Copy telegraf.conf
mv -f telegraf.conf /etc/telegraf/telegraf.conf

# Enable SUDO access to smartctl for telegraf user
cat > /etc/sudoers.d/telegraf <<EOF
Cmnd_Alias SMARTCTL = /usr/sbin/smartctl
telegraf ALL=(ALL) NOPASSWD: SMARTCTL
Defaults!SMARTCTL !logfile, !syslog, !pam_session
EOF

# Enable telegraf service
systemctl enable telegraf
systemctl restart telegraf

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Telegraf Agent Complete\n"
exit 0
