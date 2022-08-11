#!/bin/bash

### Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root\n"
  exit
fi


###############################################################################
# Required Configuration Options
###############################################################################

# Bridge Configuration
ETHERNET_INTERFACE="eno1"
BRIDGE_NAME="vmbr0"

# VMM IPv4 Address
IP_ADDRESS="192.168.1.52"

# DNS Server
IP_DNS="192.168.1.1"

# IPv4 Gateway
IP_GATEWAY="192.168.1.1"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y update

# Install RPM Packages
dnf -y install tar openssl-devel cockpit cockpit-packagekit \
  cockpit-pcp cockpit-storaged cockpit-system cockpit-ws \
  cockpit-machines qemu-kvm qemu-kvm-block-iscsi \
  qemu-kvm-block-curl qemu-kvm-common qemu-kvm-block-ssh \
  qemu-kvm-block-iscsi lm_sensors lm_sensors-devel lm_sensors-libs \
  virt-install libosinfo

# Enable Cockpit
systemctl enable --now cockpit.socket
firewall-cmd --zone=public --add-service=cockpit --permanent
systemctl reload firewalld


# Configure KVM

# Create KVM Directories
mkdir -p /srv/kvm
mkdir    /srv/kvm/iso
mkdir    /srv/kvm/img
mkdir    /srv/tmp

# Create guest_images storage pool
virsh pool-define-as "guest_images" dir - - - - "/srv/kvm/img/"
virsh pool-build 'guest_images'
virsh pool-start 'guest_images'
virsh pool-autostart 'guest_images'

# Create storage volumes
GUEST_IMAGE_PATH="/srv/kvm/img"
qemu-img create -f qcow2 -o preallocation=off ${GUEST_IMAGE_PATH}/indfuxdb.qcow2 96G
qemu-img create -f qcow2 -o preallocation=off ${GUEST_IMAGE_PATH}/grafana.qcow2  96G
qemu-img create -f qcow2 -o preallocation=off ${GUEST_IMAGE_PATH}/docker.qcow2   2T
qemu-img create -f qcow2 -o preallocation=off ${GUEST_IMAGE_PATH}/icinga.qcow2   96G
qemu-img create -f qcow2 -o preallocation=off ${GUEST_IMAGE_PATH}/legacy.qcow2   96G


# Create Virtual Machine Bridge

# List Interfaces
ip addr

# List Active Network Connections
nmcli conn show

# Create a bridge interface
nmcli connection add type bridge con-name ${BRIDGE_NAME} ifname ${BRIDGE_NAME}

# Add static IP address
nmcli conn modify ${BRIDGE_NAME} ipv4.addresses "${IP_ADDRESS}/24"
nmcli conn modify ${BRIDGE_NAME} ipv4.gateway "${IP_GATEWAY}"
nmcli conn modify ${BRIDGE_NAME} ipv4.dns "${IP_DNS}"
nmcli conn modify ${BRIDGE_NAME} ipv4.method manual

# Assign the interfaces to the bridge
nmcli connection add type ethernet slave-type bridge autoconnect yes \
    con-name bridge-${BRIDGE_NAME} ifname ${ETHERNET_INTERFACE} master ${BRIDGE_NAME}

# Bring up or activate the bridge connection
nmcli conn up ${BRIDGE_NAME}

# Bring down wired connection
nmcli conn down ${ETHERNET_INTERFACE}

# Display the network interfaces
nmcli device status

# List Interfaces
ip addr

# Show Bridge Details
nmcli -f bridge con show ${BRIDGE_NAME}

# Declaring the KVM Bridged Network
virsh net-list --all

cat << 'EOL' > /tmp/bridge.xml
<network>
  <name>vmbr0</name>
  <forward mode="bridge"/>
  <bridge name="vmbr0"/>
</network>
EOL

virsh net-define /tmp/bridge.xml
virsh net-start ${BRIDGE_NAME}
virsh net-autostart ${BRIDGE_NAME}

exit 0
