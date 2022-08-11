#!/bin/bash

# Ensure running as root (not sudo)
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root\n"
  exit 1
fi


###############################################################################
# Notes
###############################################################################
#
# 1) This script generates random passwords that are required for the
#    Slurm Compute Node Deployment Guide.
#
# 2) This script requires the following files be present before execution.
#    - slurm-${SLURM_VERSION}.tar.bz2
#    - cgroup.conf
#    - slurm.conf
#    - slurmdbd.conf
#
# 3) Slurm Configuration References:
#    - Slurm Configuration Tool: https://slurm.schedmd.com/configurator.html
#    - cgroup.conf: https://slurm.schedmd.com/cgroup.conf.html
#    - slurm.conf: https://slurm.schedmd.com/slurm.conf.html
#    - slurmdbd.conf: https://slurm.schedmd.com/slurmdbd.conf.html
#


###############################################################################
# Script Configuration Options
###############################################################################

# Cluster and hostname
CLUSTER_NAME="engwsc"
SLURM_HOSTNAME="slurm.engwsc.example.com"

# Cluster Subnet Mask (Firewall Rule)
CLUSTER_SUBNET_MASK="192.168.1.0/24"

# Slurm Version
SLURM_VERSION="22.05.2"

# Slurm User UID, GID
SLURMUSERID=64030
SLURMGROUPID=64030

# MariaDB
MARIADB_ROOT_PASSWD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`
MARIADB_SLURM_DATABASE='slurm_acct_db'
MARIADB_SLURM_USER='slurm'
MARIADB_SLURM_USER_PASSWD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ;`


###############################################################################
# Installation Commands
###############################################################################

# Verify required files are present
if [ ! -f /root/tmp/slurm-${SLURM_VERSION}.tar.bz2 ]; then
    echo "ERROR: File slurm-${SLURM_VERSION}.tar.bz2 Not Found"
    exit 1
fi
if [ ! -f /root/tmp/cgroup.conf ]; then
    echo "ERROR: File cgroup.conf Not Found"
    exit 1
fi
if [ ! -f /root/tmp/slurm.conf ]; then
    echo "ERROR: File slurm.conf Not Found"
    exit 1
fi
if [ ! -f /root/tmp/slurmdbd.conf ]; then
    echo "ERROR: File slurmdbd.conf Not Found"
    exit 1
fi

# Update System
dnf -y update


###############################################################################
# Build Setup
###############################################################################

echo -e "\nEnabling Repositories..."
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

# Install dependencies
echo -e "\nInstalling dependencies..."
dnf install -y gcc binutils ncurses-devel automake autoconf \
    rpm-devel rpm-build pam-devel readline-devel python3 \
    perl-ExtUtils-MakeMaker mariadb-server mariadb-devel \
    mariadb-connector-odbc openssl-devel pkgconf-pkg-config \
    zlib bzip2 bzip2-devel make hwloc-devel hwloc hwloc-libs \
    hwloc-plugins munge munge-devel munge-libs lua lua-devel \
    lua-json lua-libs lua-posix lua-socket rrdtool-lua \
    lua-filesystem rrdtool rrdtool-devel python3-rrdtool \
    rrdtool-perl mailx lz4 lz4-libs lz4-devel libcurl \
    libcurl-devel infiniband-diags-devel ibacm


echo -e "\nConfiguring Slurm..."

#
# Modify /root/tmp/slurm.conf with the configuration of the cluster
#
echo    "Reminder: Modify /root/tmp/slurm.conf with the configuration of the cluster"
echo -e "\nWaiting 15 seconds, press CTRL-C to abort...\n"
sleep 15


#
# Set a database password for Slurm Accounting
#
sed -i "s/StoragePass=.*/StoragePass=${MARIADB_SLURM_USER_PASSWD}/g" /root/tmp/slurmdbd.conf

#
# Set a ClusterName, SlurmctldHost, and AccountingStorageHost
#
sed -i "s/ClusterName=.*/ClusterName=${CLUSTER_NAME}/g" /root/tmp/slurm.conf
sed -i "s/SlurmctldHost=.*/SlurmctldHost=${SLURM_HOSTNAME}/g" /root/tmp/slurm.conf
sed -i "s/AccountingStorageHost=.*/AccountingStorageHost=${SLURM_HOSTNAME}/g" /root/tmp/slurm.conf


###############################################################################
# Enabling Munge
###############################################################################

echo -e "\nEnabling Munge..."

# Create a munge authentication key
mkdir -p /etc/munge
chown -R munge:munge /etc/munge
chmod 700 /etc/munge
/usr/sbin/create-munge-key -f
chmod 600 /etc/munge/munge.key

# Enable Munge service
systemctl enable --now munge


###############################################################################
# Building Slurm
###############################################################################

echo -e "\nBuilding Slurm..."

# Create Slurm User and group
groupadd -g $SLURMGROUPID slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSERID -g slurm -s /bin/bash slurm

# Build Slurm RPM
rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2


# Install RPMs
echo -e "\nInstalling Slurm RPMs..."
rpm -ivh \
    /root/rpmbuild/RPMS/x86_64/slurm-${SLURM_VERSION}-1.el8.x86_64.rpm \
    /root/rpmbuild/RPMS/x86_64/slurm-example-configs-${SLURM_VERSION}-1.el8.x86_64.rpm \
    /root/rpmbuild/RPMS/x86_64/slurm-perlapi-${SLURM_VERSION}-1.el8.x86_64.rpm \
    /root/rpmbuild/RPMS/x86_64/slurm-slurmctld-${SLURM_VERSION}-1.el8.x86_64.rpm \
    /root/rpmbuild/RPMS/x86_64/slurm-slurmdbd-${SLURM_VERSION}-1.el8.x86_64.rpm \
    /root/rpmbuild/RPMS/x86_64/slurm-torque-${SLURM_VERSION}-1.el8.x86_64.rpm

# Copy configs to Slurm RPMs path for future reference:
cp /etc/munge/munge.key /root/rpmbuild/RPMS/x86_64/
cp cgroup.conf          /root/rpmbuild/RPMS/x86_64/
cp slurm.conf           /root/rpmbuild/RPMS/x86_64/
cp slurmdbd.conf        /root/rpmbuild/RPMS/x86_64/

# Copy RPMs
EXEC_PWD=`pwd`

cd /root/rpmbuild/RPMS/x86_64/
tar -cf ${EXEC_PWD}/slurm-${SLURM_VERSION}.rpm.tar slurm-*.rpm cgroup.conf slurm.conf slurmdbd.conf munge.key

cd ${EXEC_PWD}
gzip -9 slurm-${SLURM_VERSION}.rpm.tar
sha256sum -b slurm-${SLURM_VERSION}.rpm.tar.gz > slurm-${SLURM_VERSION}.rpm.tar.gz.sha256

# Copy Slurm configuration files:
mkdir -p /etc/slurm/

cp cgroup.conf   /etc/slurm/
cp slurm.conf    /etc/slurm/
cp slurmdbd.conf /etc/slurm/

chmod 755 /etc/slurm/
chmod 644 /etc/slurm/cgroup.conf
chmod 644 /etc/slurm/slurm.conf
chmod 600 /etc/slurm/slurmdbd.conf

chown -R slurm:slurm /etc/slurm/

# Create Slurm log files:
mkdir -p /var/log/slurm/

touch /var/log/slurm/slurm.jobcomp.log
touch /var/log/slurm/slurmctld.log
touch /var/log/slurm/slurmdbd.log

chmod 755 /var/log/slurm/
chmod 644 /var/log/slurm/*.log

chown -R slurm:slurm /var/log/slurm

# Create Slurm spool files:
mkdir -p /var/spool/slurmctld
mkdir -p /var/spool/slurmdbd

chmod 700 /var/spool/slurmctld
chmod 700 /var/spool/slurmdbd

chown -R slurm:slurm /var/spool/slurmctld
chown -R slurm:slurm /var/spool/slurmdbd

# Setup log rotation
cat >> /etc/logrotate.d/slurm <<EOL
/var/log/slurm/slurm.jobcomp.log
/var/log/slurm/slurmctld.log
/var/log/slurm/slurmdbd.log
{
    missingok
    notifempty
    rotate 4
    weekly
    create
}

EOL

chmod 644 /etc/logrotate.d/slurm


echo -e "\nWaiting 15 seconds, press CTRL-C to abort...\n"
sleep 15


###############################################################################
# MariaDB
###############################################################################

# Enable MariaDB service
echo -e "\nEnabling MariaDB..."
systemctl enable --now mariadb

# Secure MariaDB
#
# When asked "Enter current password for root (enter for none):" hit enter for none
# Set root password? [Y/n] y
# New password: ${MARIADB_ROOT_PASSWD}
# Re-enter new password: ${MARIADB_ROOT_PASSWD}
# Remove anonymous users? [Y/n] y
# Disallow root login remotely? [Y/n] y
# Remove test database and access to it? [Y/n] y
# Reload privilege tables now? [Y/n] y
echo -e "\nSecuring MariaDB...\n"

echo "Respond with:"
echo "Enter current password for root (enter for none): <enter>"
echo "Set root password? [Y/n] y"
echo "New password: ${MARIADB_ROOT_PASSWD}"
echo "Re-enter new password: ${MARIADB_ROOT_PASSWD}"
echo "Remove anonymous users? [Y/n] y"
echo "Disallow root login remotely? [Y/n] y"
echo "Remove test database and access to it? [Y/n] y"
echo -e "Reload privilege tables now? [Y/n] y\n"

mysql_secure_installation

# Modify the innodb configuration
mkdir -p /etc/my.cnf.d
cat >> /etc/my.cnf.d/innodb.cnf <<EOL
[mysqld]
 innodb_buffer_pool_size=1024M
 innodb_log_file_size=64M
 innodb_lock_wait_timeout=900

EOL

# Stop MariaDB
systemctl stop mariadb

# Delete MariaDB log files
rm -f /var/lib/mysql/ib_logfile?

# Restart MariaDB
systemctl start mariadb

# Create database for slurm
mysql -u root -p${MARIADB_ROOT_PASSWD} --execute "grant all on ${MARIADB_SLURM_DATABASE}.* TO '${MARIADB_SLURM_USER}'@'localhost' identified by '${MARIADB_SLURM_USER_PASSWD}' with grant option;"
mysql -u root -p${MARIADB_ROOT_PASSWD} --execute "create database ${MARIADB_SLURM_DATABASE};"


###############################################################################
# Configure Firewalld Rules
###############################################################################

echo -e "\nEnabling firewalld rules..."

systemctl enable --now firewalld
firewall-cmd --remove-port=3306/tcp --permanent
firewall-cmd --remove-port=3306/udp --permanent

firewall-cmd --zone=public --add-source=${CLUSTER_SUBNET_MASK} --permanent
firewall-cmd --zone=public --add-port={6817/tcp, 6818/tcp, 6819/tcp} --permanent
firewall-cmd --reload


###############################################################################
# Slurm Controller Services
###############################################################################

echo -e "\nEnabling Slurm Controller Services..."

systemctl enable --now slurmdbd
systemctl enable --now slurmctld


###############################################################################
# Slurm Administration Message
###############################################################################

echo
echo   "*************************************************************************"
echo   "*************************************************************************"
echo   "**                                                                     **"
echo   "**    Required for Slurm administration:                               **"
echo   "**                                                                     **"
printf "**    MariaDB Root Password:  %-40s **\n" ${MARIADB_ROOT_PASSWD}
printf "**    MariaDB Slurm Database: %-40s **\n" ${MARIADB_SLURM_DATABASE}
printf "**    MariaDB Slurm Username: %-40s **\n" ${MARIADB_SLURM_USER}
printf "**    MariaDB Slurm Password: %-40s **\n" ${MARIADB_SLURM_USER_PASSWD}
echo   "**                                                                     **"
echo   "*************************************************************************"
echo   "*************************************************************************"
echo

exit 0
