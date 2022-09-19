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


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit 1
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying IdM/FreeIPA Accounts...\n"


###############################################################################
# Script Configuration Options
###############################################################################

SYS_ADMIN_ACCOUNT="adm0001"
SYS_ADMIN_GROUP="sysadmins"

AUTOMATION_ACCOUNT="ansible"
AUTOMATION_GROUP="ansible"

USER_ACCOUNT="usr0001"
USER_GROUP="users"


###############################################################################
# Deployment Commands
###############################################################################

# Login using Kerberos authentication protocol
# Prompt for password will occur
kinit admin

# Create a default user group
ipa group-add --desc="Default Linux Users group" ${USER_GROUP}

# Configure Default shell and group
ipa config-mod \
    --defaultshell="/bin/bash"  \
    --defaultgroup="${USER_GROUP}"


#
# Administrator Account
#

# Create a System Administrator group named sysadmins
ipa group-add --desc="System administrators group" ${SYS_ADMIN_GROUP}

# Create a System Administrator account named adm0001
ipa user-add \
    --first="John" \
    --last="Doe" \
    --shell="/bin/bash" \
    --random \
    --noprivate \
    ${SYS_ADMIN_ACCOUNT}

# Add System Administrator account adm0001 to sysadmins group
ipa group-add-member ${SYS_ADMIN_GROUP} --users="${SYS_ADMIN_ACCOUNT}"

# Create a Sudo rule for System Adminstrators
ipa sudorule-add sudo_all \
    --hostcat="all" \
    --runasusercat="all" \
    --runasgroupcat="all" \
    --cmdcat="all"

# Add the sysadmins group to the Sudo rule sudo_all
ipa sudorule-add-user sudo_all --group="${SYS_ADMIN_GROUP}"

# Create System Adminstrators Home directory
cp -r /etc/skel /home/${SYS_ADMIN_ACCOUNT}
chown -R ${SYS_ADMIN_ACCOUNT}:${SYS_ADMIN_GROUP} /home/${SYS_ADMIN_ACCOUNT}
chmod 700 /home/${SYS_ADMIN_ACCOUNT}


#
# Ansible Account
#

# Create a Automation group named ansible
ipa group-add --desc="Automation group" ${AUTOMATION_GROUP}

# Create a Automation account named ansible
ipa user-add \
    --first="Ansible" \
    --last="Automation" \
    --shell="/bin/bash" \
    --random \
    --noprivate \
    ${AUTOMATION_ACCOUNT}

# Add Automation account ansible to ansible group
ipa group-add-member ${AUTOMATION_GROUP} --users="${AUTOMATION_ACCOUNT}"

# Create a Sudo rule for Automation account
ipa sudorule-add sudo_all_nopasswd \
    --hostcat="all" \
    --runasusercat="all" \
    --runasgroupcat="all" \
    --cmdcat="all"

# Enable passwordless Sudo for the Automation Sudo rule
ipa sudorule-add-option sudo_all_nopasswd --sudooption='!authenticate'

# Add the ansible group to the Sudo rule sudo_all_nopasswd
ipa sudorule-add-user sudo_all_nopasswd --group="${AUTOMATION_GROUP}"

# Create Ansible's Home directory
cp -r /etc/skel /home/${AUTOMATION_ACCOUNT}
chown -R ${AUTOMATION_ACCOUNT}:${AUTOMATION_GROUP} /home/${AUTOMATION_ACCOUNT}
chmod 700 /home/${AUTOMATION_ACCOUNT}


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
    ${USER_ACCOUNT}

# Add User account usr0001 to users group
ipa group-add-member ${USER_GROUP} --users="${USER_ACCOUNT}"

# Create User's Home directory
cp -r /etc/skel /home/${USER_ACCOUNT}
chown -R ${USER_ACCOUNT}:${USER_GROUP} /home/${USER_ACCOUNT}
chmod 700 /home/${USER_ACCOUNT}


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
ipa hbacrule-add-user allow_sysadmins --group="${SYS_ADMIN_GROUP}"
ipa hbacrule-add-user allow_sysadmins --group="${AUTOMATION_GROUP}"

# Create allow_users HBAC rule
ipa hbacrule-add \
    --desc="Allow Users to access user nodes" \
    --servicecat="all" \
    allow_users

# Add Users group to allow_users HBAC rule
ipa hbacrule-add-user allow_users --group="${USER_GROUP}"

# Add usernodes Host Group to allow_users HBAC rule
ipa hbacrule-add-host allow_users --hostgroups="usernodes"

# Disable Default allow_all HBAC rule
ipa hbacrule-disable allow_all

# Test Access
ipa hbactest --host idm.engwsc.example.com --service sshd --user ${SYS_ADMIN_ACCOUNT}
ipa hbactest --host idm.engwsc.example.com --service sshd --user ${AUTOMATION_ACCOUNT}
ipa hbactest --host idm.engwsc.example.com --service sshd --user ${USER_ACCOUNT}

ipa hbactest --host user01.engwsc.example.com --service sshd --user ${SYS_ADMIN_ACCOUNT}
ipa hbactest --host user01.engwsc.example.com --service sshd --user ${AUTOMATION_ACCOUNT}
ipa hbactest --host user01.engwsc.example.com --service sshd --user ${USER_ACCOUNT}


echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying Deploying IdM/FreeIPA Accounts Complete\n"
exit 0
