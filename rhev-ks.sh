#!/bin/sh

TIMEZONE="America/Toronto"

# TODO:
# - Create Data and Export domain shares.

# REPO URLs go here.
LATEST_BUILD=""
RHEV_REPO=""
JEAP_REPO=""

# Basic VM options, RAM in MB, no. of CPUs, disk space in GB.
INSTANCE_RAM=1024
INSTANCE_CPU=1
INSTANCE_DSK=20

# Name of the instance, this will be used for the hostname as well as the name of the VM.
NAME="rhevm"
MAC="00:16:3e:77:e2:ed"

EXISTING=`virsh list --all --name | grep ${NAME}`

if [ ! -z "${EXISTING}" ]; then
  echo "ERROR: Virtual machine '${NAME}' already exists, please remove it and try again."
  exit 1
fi

# Find a virtual bridge name that is not in use.
BRIDGE=""
for N in {1..99}; do
	ip addr show virbr${N} &> /dev/null
	RESULT=$?
	if [ $RESULT -eq 0 ]; then
		continue
	else BRIDGE="virbr${N}"
		break
	fi
done

# Define network example.com with only one IP available, which will be assigned to
# ${NAME}.example.com. This network config is what provides for the rhevm server
# having valid forward and reverse lookups.
echo "<network>
  <name>example</name>
  <bridge name='${BRIDGE}' />
  <forward mode='nat' />
  <domain name='example.com' />
  <dns>
    <host ip='192.168.200.1'>
      <hostname>${NAME}.example.com</hostname>
    </host>
  </dns> 
  <ip address='192.168.200.254' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.200.1' end='192.168.200.254' />
      <host mac='${MAC}' name='${NAME}.example.com' ip='192.168.200.1' />
    </dhcp>
  </ip>
</network>" > /tmp/example.com-network.xml

# It's just as easy to always attempt the network create rather than check
# if it is already defined or not. 
virsh net-define /tmp/example.com-network.xml
virsh net-autostart example
virsh net-start example

echo "install
text
firewall --disabled
network --activate --bootproto=dhcp --device=${MAC}
rootpw Redhat123
auth  --useshadow  --passalgo=md5
autopart
clearpart --all
keyboard us
lang en_US
selinux --enforcing
skipx
logging --level=info
timezone ${TIMEZONE}
bootloader --location=mbr
firstboot --disable
repo --name=RHEL --baseurl=${RHEL_REPO}
repo --name=RHEV --baseurl=${RHEV_REPO}
repo --name=JEAP --baseurl=${JEAP_REPO}
reboot

%packages
@base
rhevm

%post --log=/root/ks-post-log
echo '[RHEL]
name=Red Hat Enterprise Linux
baseurl=${RHEL_REPO}
gpgcheck=0
enabled=1' > /etc/yum.repos.d/rhel.repo

echo '[JEAP]
name=JBoss Enterprise Application Platform
baseurl=${JEAP_REPO}
gpgcheck=0
enabled=1' > /etc/yum.repos.d/jeap.repo

echo '[RHEV-${LATEST_BUILD}]
name=Red Hat Enterprise Virtualization ${LATEST_BUILD} 
baseurl=${RHEV_REPO}
gpgcheck=0
enabled=1' > /etc/yum.repos.d/rhel.repo
%end
" > /tmp/ks.cfg

virt-install --name ${NAME} \
             --ram ${INSTANCE_RAM} \
             --vcpus ${INSTANCE_CPU} \
             --cpu host \
             --location "${RHEL_REPO}" \
             --os-type="linux" \
             --os-variant="rhel6" \
             --disk path=/var/lib/libvirt/images/${NAME}.img,size=${INSTANCE_DSK},bus=virtio,sparse=true \
             --network network:example \
             --mac="${MAC}" \
             --graphics spice \
             --initrd-inject=/tmp/ks.cfg --extra-args "ks=file:/ks.cfg" \
; 
             
             
