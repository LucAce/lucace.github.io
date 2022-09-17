#!/bin/bash
###############################################################################
#
#   Filename: deploy-mirror-client.sh
#
#   Functional Description:
#
#       Bash script which deploys DNF Mirror Client.
#
#   Usage:
#
#       ./deploy-mirror-client.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF/Yum Repository Client...\n"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y distro-sync
dnf -y upgrade

# Disable existing repositories
mv /etc/yum.repos.d/almalinux-ha.repo               /etc/yum.repos.d/almalinux-ha.repo.disabled
mv /etc/yum.repos.d/almalinux-nfv.repo              /etc/yum.repos.d/almalinux-nfv.repo.disabled
mv /etc/yum.repos.d/almalinux-plus.repo             /etc/yum.repos.d/almalinux-plus.repo.disabled
mv /etc/yum.repos.d/almalinux-powertools.repo       /etc/yum.repos.d/almalinux-powertools.repo.disabled
mv /etc/yum.repos.d/almalinux.repo                  /etc/yum.repos.d/almalinux.repo.disabled
mv /etc/yum.repos.d/almalinux-resilientstorage.repo /etc/yum.repos.d/almalinux-resilientstorage.repo.disabled
mv /etc/yum.repos.d/almalinux-rt.repo               /etc/yum.repos.d/almalinux-rt.repo.disabled
mv /etc/yum.repos.d/docker-ce.repo                  /etc/yum.repos.d/docker-ce.repo.disabled
mv /etc/yum.repos.d/elasticsearch.repo              /etc/yum.repos.d/elasticsearch.repo.disabled
mv /etc/yum.repos.d/epel-modular.repo               /etc/yum.repos.d/epel-modular.repo.disabled
mv /etc/yum.repos.d/epel.repo                       /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing-modular.repo       /etc/yum.repos.d/epel-testing-modular.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo               /etc/yum.repos.d/epel-testing.repo.disabled
mv /etc/yum.repos.d/gitlab_gitlab-ce.repo           /etc/yum.repos.d/gitlab_gitlab-ce.repo.disabled
mv /etc/yum.repos.d/grafana.repo                    /etc/yum.repos.d/grafana.repo.disabled
mv /etc/yum.repos.d/graylog.repo                    /etc/yum.repos.d/graylog.repo.disabled
mv /etc/yum.repos.d/influxdb.repo                   /etc/yum.repos.d/influxdb.repo.disabled
mv /etc/yum.repos.d/mongodb-org-6.0.repo            /etc/yum.repos.d/mongodb-org-6.0.repo.disabled

# Create repository configuration file
cat > /etc/yum.repos.d/local-mirror.repo <<EOF
[baseos]
name=Local AlmaLinux \$releasever Repository - BaseOS
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/BaseOS/x86_64/os/
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[appstream]
name=Local AlmaLinux \$releasever Repository - AppStream
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/AppStream/x86_64/os/
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[extras]
name=Local AlmaLinux \$releasever Repository - Extras
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/extras/x86_64/os/
gpgcheck=1
enabled=1
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[powertools]
name=Local AlmaLinux \$releasever Repository - PowerTools
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/PowerTools/x86_64/os/
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[ha]
name=Local AlmaLinux \$releasever Repository - High Availability
baseurl=http://mirror.engwsc.example.com/almalinux/\$releasever/HighAvailability/x86_64/os/
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[epel]
name=Local EPEL Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/epel/pub/epel/\$releasever/Everything/x86_64
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever

[epel-modular]
name=Local EPEL Modular Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/epel/pub/epel/\$releasever/Modular/x86_64
gpgcheck=1
enabled=0
countme=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever

[gitlab_gitlab-ce]
name=gitlab_gitlab-ce
baseurl=http://mirror.engwsc.example.com/gitlab/gitlab-ce/el/$releasever/$basearch
gpgcheck=1
enabled=0
countme=0
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-gitlab
       http://mirror.engwsc.example.com/RPM-GPG-KEY-gitlab-3D645A26AB9FBD22

[mongodb-org-6.0]
name=MongoDB Repository
baseurl=http://mirror.engwsc.example.com/mongodb/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=0
countme=0
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-mongodb

[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=http://mirror.engwsc.example.com/elasticsearch/packages/oss-7.x/yum/
gpgcheck=1
enabled=0
countme=0
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-elasticsearch

[graylog]
name=graylog
baseurl=http://mirror.engwsc.example.com/elasticsearch/packages/oss-7.x/yum/
gpgcheck=1
repo_gpgcheck=0
enabled=0
countme=0
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-graylog

[influxdb]
name=Local InfluxDB Repository - RHEL \$releasever
baseurl=http://mirror.engwsc.example.com/influxdb/rhel/\$releasever/influxdb
gpgcheck=1
enabled=0
countme=0
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-influxdb

[grafana]
name=grafana
baseurl=http://mirror.engwsc.example.com/grfana/oss/rpm
repo_gpgcheck=1
enabled=0
gpgcheck=1
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-grafana

[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=http://mirror.engwsc.example.com/docker/linux/centos/\$releasever/\$basearch/stable
enabled=0
gpgcheck=1
gpgkey=http://mirror.engwsc.example.com/RPM-GPG-KEY-docker
EOF

# Enable local repositories:
yum-config-manager --enable baseos
yum-config-manager --enable appstream
yum-config-manager --enable extras
# yum-config-manager --enable powertools
# yum-config-manager --enable ha
# yum-config-manager --enable epel
# yum-config-manager --enable epel-modular
# yum-config-manager --enable mongodb-org-6.0
# yum-config-manager --enable elasticsearch-7.x
# yum-config-manager --enable gitlab_gitlab-ce
# yum-config-manager --enable graylog
# yum-config-manager --enable docker-ce-stable
# yum-config-manager --enable influxdb
# yum-config-manager --enable grafana

# Clean the DNF cache:
dnf clean all

# Test mirror:
dnf -y distro-sync
dnf -y upgrade

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying DNF/Yum Repository Client Complete\n"
exit 0
