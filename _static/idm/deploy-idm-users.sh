#!/bin/bash
###############################################################################
#
#   Filename: deploy-idm-users.sh
#
#   Functional Description:
#
#       Bash script which creates IdM/FreeIPA accounts.
#
#   Usage:
#
#       ./deploy-idm-users.sh
#
###############################################################################


# Ensure running as user
if [ "$EUID" -eq 0 ]; then
  echo -e "ERROR: Please run as a user\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying IdM/FreeIPA Accounts...\n"


###############################################################################
# Deployment Commands
###############################################################################

# Login using Kerberos authentication protocol
# Prompt for password will occur
kinit admin

#
# Administrator Account
#

# Create a System Administrator group named sysadmins
ipa group-add --desc="System administrators group" sysadmins

# Create a System Administrator account named adm0001
ipa user-add \
    --first="John" \
    --last="Doe" \
    --shell="/bin/bash" \
    --random \
    --noprivate \
    adm0001

# Add System Administrator account adm0001 to sysadmins group
ipa group-add-member sysadmins --users="adm0001"

# Create a Sudo rule for System Adminstrators
ipa sudorule-add sudo_all \
    --hostcat="all" \
    --runasusercat="all" \
    --runasgroupcat="all" \
    --cmdcat="all"

# Add the sysadmins group to the Sudo rule sudo_all
ipa sudorule-add-user sudo_all --group="sysadmins"

# Create System Adminstrators Home directory
cp -r /etc/skel /home/adm0001
chown -R adm0001:sysadmins /home/adm0001
chmod 700 /home/adm0001


#
# Ansible Account
#

# Create a Automation group named ansible
ipa group-add --desc="Automation group" ansible

# Create a Automation account named ansible
ipa user-add \
    --first="Ansible" \
    --last="Automation" \
    --shell="/bin/bash" \
    --random \
    --noprivate \
    ansible

# Add Automation account ansible to ansible group
ipa group-add-member ansible --users="ansible"

# Create a Sudo rule for Automation account
ipa sudorule-add sudo_all_nopasswd \
    --hostcat="all" \
    --runasusercat="all" \
    --runasgroupcat="all" \
    --cmdcat="all"

# Enable passwordless Sudo for the Automation Sudo rule
ipa sudorule-add-option sudo_all_nopasswd --sudooption='!authenticate'

# Add the ansible group to the Sudo rule sudo_all_nopasswd
ipa sudorule-add-user sudo_all_nopasswd --group="ansible"

# Create Ansible's Home directory
cp -r /etc/skel /home/ansible
chown -R ansible:ansible /home/ansible
chmod 700 /home/ansible


#
# User Account
#

# Create a User account named usr0001
ipa user-add \
    --first="John" \
    --last="Doe" \
    --shell="/bin/bash" \
    --random \
    --noprivate \
    usr0001

# Add User account usr0001 to users group
ipa group-add-member users --users="usr0001"

# Create User's Home directory
cp -r /etc/skel /home/usr0001
chown -R usr0001:users /home/usr0001
chmod 700 /home/usr0001


#
# Host Group / HBAC Rules
#

# Create usernodes Host Group
ipa hostgroup-add        --desc="User Accessible Nodes"      usernodes

# Add members to usernodes Host Group
ipa hostgroup-add-member --hosts="slurm.engwsc.example.com"  usernodes
ipa hostgroup-add-member --hosts="user01.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="user02.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="user03.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="user04.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="comp01.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="comp02.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="comp03.engwsc.example.com" usernodes
ipa hostgroup-add-member --hosts="comp04.engwsc.example.com" usernodes

# Create allow_sysadmins HBAC Rule
ipa hbacrule-add \
    --desc="Allow System Administrators to access all nodes" \
    --servicecat="all" \
    --hostcat="all" \
    allow_sysadmins

# Add System Administrator and Ansible groups to allow_sysadmins HBAC rule
ipa hbacrule-add-user allow_sysadmins --group="sysadmins"
ipa hbacrule-add-user allow_sysadmins --group="ansible"

# Create allow_users HBAC rule
ipa hbacrule-add \
    --desc="Allow Users to access user nodes" \
    --servicecat="all" \
    allow_users

# Add Users group to allow_users HBAC rule
ipa hbacrule-add-user allow_users --group="users"

# Add usernodes Host Group to allow_users HBAC rule
ipa hbacrule-add-host allow_users --hostgroups="usernodes"

# Disable Default allow_all HBAC rule
ipa hbacrule-disable allow_all

# Test Access
ipa hbactest --host idm.engwsc.example.com --service sshd --user adm0001
ipa hbactest --host idm.engwsc.example.com --service sshd --user ansible
ipa hbactest --host idm.engwsc.example.com --service sshd --user usr0001

ipa hbactest --host user01.engwsc.example.com --service sshd --user adm0001
ipa hbactest --host user01.engwsc.example.com --service sshd --user ansible
ipa hbactest --host user01.engwsc.example.com --service sshd --user usr0001


echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Deploying IdM/FreeIPA Accounts Complete\n"
exit 0
