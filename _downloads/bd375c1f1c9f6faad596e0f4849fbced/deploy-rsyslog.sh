#!/bin/bash

# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo
echo "*****************************"
echo "*****************************"
echo "**                         **"
echo "**    Deploying RSyslog    **"
echo "**                         **"
echo "*****************************"
echo "*****************************"
echo


###############################################################################
# Script Configuration Options
###############################################################################

# Set Host Name
GRAYLOG_SERVER="graylog.engwsc.example.com"

# Rsyslog Port
RSYSLOG_PORT="6514"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y update

# Install Dependencies
dnf -y install rsyslog

# Create rsyslog configuration file
cat > /etc/rsyslog.d/graylog.conf <<EOF
*.* action(
   Action.resumeInterval="10"
   RebindInterval="10000"
   Queue.Size="100000"
   Queue.DiscardMark="97500"
   Queue.HighWaterMark="80000"
   Queue.Type="LinkedList"
   Queue.FileName="rsyslogqueue"
   Queue.CheckpointInterval="100"
   Queue.MaxDiskSpace="2g"
   Action.ResumeRetryCount="-1"
   Queue.SaveOnShutdown="on"
   Queue.TimeoutEnqueue="10"
   Queue.DiscardSeverity="0"
   type="omfwd"
   target="${GRAYLOG_SERVER}"
   protocol="tcp"
   port="${RSYSLOG_PORT}"
   template="RSYSLOG_SyslogProtocol23Format"
   StreamDriver="gtls"
   StreamDriverMode="1"
   StreamDriverAuthMode="anon"
)
EOF

# Restart Rsyslog service
systemctl enable --now rsyslog

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo "$timestamp" | tee .deploy-rsyslog-${timestamp}

exit 0
