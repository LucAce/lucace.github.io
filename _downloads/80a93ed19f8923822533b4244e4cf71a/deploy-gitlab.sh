#!/bin/bash
###############################################################################
#
#   Filename: deploy-gitlab.sh
#
#   Functional Description:
#
#       Bash script which deploys GitLab.
#
#   Usage:
#
#       ./deploy-gitlab.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying GitLab...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# Configure which GitLab edition to use (Lower case)
# ce: Community Edition
# ee: Enterprise Edition
GITLAB_EDITION="ce"

# GitLab FQDN
GITLAB_FQDN='gitlab.engwsc.example.com'

# GitLab Initial URL, Use "http://"
GITLAB_EXTERNAL_URL="http://${GITLAB_FQDN}"

# Set Allowed IPv4 Addresses (Include subnet mask)
ALLOWED_IPV4="192.168.1.0/24"


###############################################################################
# Installation Commands
###############################################################################

# Ensure edition is lower case
GITLAB_EDITION=$(echo $GITLAB_EDITION | tr '[:upper:]' '[:lower:]')

# Update System
dnf -y upgrade

# Install and configure the necessary dependencies
dnf -y install curl policycoreutils openssh-server perl postfix yum-utils

# Enable OpenSSH server daemon
systemctl enable --now sshd

# Configure firewalld rules
systemctl enable --now firewalld
firewall-cmd --zone=public --add-service={http,https} --permanent
firewall-cmd --reload

# Enable postfix
systemctl enable --now postfix

# Add the GitLab package repository
echo "Configuring \"${GITLAB_EDITION}\" GitLab Edition"

tmp_dir=$(mktemp -d -t gitlab-XXXXXXXXXX --tmpdir=/tmp)
cd $tmp_dir
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-${GITLAB_EDITION}/script.rpm.sh -o $tmp_dir/script.rpm.sh
chmod 775 $tmp_dir/script.rpm.sh
cat $tmp_dir/script.rpm.sh
$tmp_dir/script.rpm.sh

# Install GitLab
EXTERNAL_URL=${GITLAB_EXTERNAL_URL} dnf install -y gitlab-${GITLAB_EDITION}

# Disable GitLab Yum Repositories
yum-config-manager --disable gitlab_gitlab-${GITLAB_EDITION}
yum-config-manager --disable gitlab_gitlab-${GITLAB_EDITION}-source

# Create Self-Signed SSL Certificate
mkdir -p /etc/gitlab/ssl/
chmod 755 /etc/gitlab/ssl/

openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "/etc/gitlab/ssl/${GITLAB_FQDN}.key" \
    -out "/etc/gitlab/ssl/${GITLAB_FQDN}.crt" \
    -subj "/CN=${GITLAB_FQDN}/C=US/ST=New York/L=New York/O=engwsc" \
    -days 365

# Set gitlab.rb options (Enable and force https, disable usage ping)
sed -i "s|external_url 'http://${GITLAB_FQDN}'|external_url 'https://${GITLAB_FQDN}'|g" /etc/gitlab/gitlab.rb
sed -i "s/^.*gitlab_rails\['usage_ping_enabled'\].*$/gitlab_rails['usage_ping_enabled'] = false/g" /etc/gitlab/gitlab.rb
sed -i "s/^.*nginx\['redirect_http_to_https'\].*$/nginx['redirect_http_to_https'] = true/g" /etc/gitlab/gitlab.rb
sed -i "s/^.*letsencrypt\['enable'\].*$/letsencrypt['enable'] = false/g" /etc/gitlab/gitlab.rb

# Reconfigure GitLab
gitlab-ctl reconfigure

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
echo
echo   "*************************************************************************"  | tee    .deploy-gitlab-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-gitlab-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-gitlab-${timestamp}
echo   "**    GitLab URL:                                                      **"  | tee -a .deploy-gitlab-${timestamp}
printf "**      https://%-54s **\n" ${GITLAB_FQDN}                                  | tee -a .deploy-gitlab-${timestamp}
echo   "**                                                                     **"  | tee -a .deploy-gitlab-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-gitlab-${timestamp}
echo   "*************************************************************************"  | tee -a .deploy-gitlab-${timestamp}
echo                                                                                | tee -a .deploy-gitlab-${timestamp}

echo -e "\nTemporary GitLab root user password:\n"                                  | tee -a .deploy-gitlab-${timestamp}
cat /etc/gitlab/initial_root_password                                               | tee -a .deploy-gitlab-${timestamp}
echo -e "\n"                                                                        | tee -a .deploy-gitlab-${timestamp}

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying GitLab Complete\n"
exit 0
