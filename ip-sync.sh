#!/bin/bash
#
# The RHEV manager is pretty finicky about its host name resolving to an IP
# and vice versa. To address this it's best to keep a local hosts entry 
# pointing at it in case there are issues with DNS etc. This is particularly
# important if in your PoC setup the RHEV-M is getting its IP from DHCP.
#
# This script, when run via cron, will detect if the IP in the current hosts
# entry differs from the one actually assigned on the specifed device and
# updates the entries accordingly both the hosts file, and a rhev specific
# dnsmasq configuration if one exists.

#
# Configurable values
#

# The device used for RHEV-M traffic.
DEVICE='eth0'

# The dnsmasq configuration file, leave blank if you don't
# have one or don't want to use this function. If specified
# the script will search and replace all instances of the previous
# IP address with the new one, as well as 'reverse' instances as
# they appear in a PTR record.
DNSMASQ='/etc/dnsmasq.d/rhev.conf'

#
# Non-configurable values.
#

# Retrieve hostname (used to determine which lines in hosts file to remove and
# then insert.
HOSTNAME=`hostname`

# Retrieve current IP as set in /etc/hosts
HOSTS_ADDR=`grep "${HOSTNAME}" /etc/hosts | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | uniq`

# Retrieve current IP as set on the device
CURRENT_ADDR=`/sbin/ip addr show ${DEVICE} | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"`

# Exit if the ip in /etc/hosts and the one in use on eth0 match,
# nothing to do.
if [ "$HOSTS_ADDR" = "$CURRENT_ADDR" ]; then
  exit 0
fi

# Exit if no current ip in use on eth0, indicates the link is down.
if [ -z "$CURRENT_ADDR" ]; then
  exit 1
fi

# Exit if no hosts entry found, indicates we stuffed something up!
if [ -z "$HOSTS_ADDR" ]; then
  exit 1
fi

# Generate reverse entries for PTR records in dnsmasq configuration.
OCTET1=`echo ${HOSTS_ADDR} | cut -d . -f 1`
OCTET2=`echo ${HOSTS_ADDR} | cut -d . -f 2`
OCTET3=`echo ${HOSTS_ADDR} | cut -d . -f 3`
OCTET4=`echo ${HOSTS_ADDR} | cut -d . -f 4`

HOSTS_ADDR_PTR="${OCTET4}.${OCTET3}.${OCTET2}.${OCTET1}"

OCTET1=`echo ${CURRENT_ADDR} | cut -d . -f 1`
OCTET2=`echo ${CURRENT_ADDR} | cut -d . -f 2`
OCTET3=`echo ${CURRENT_ADDR} | cut -d . -f 3`
OCTET4=`echo ${CURRENT_ADDR} | cut -d . -f 4`

CURRENT_ADDR_PTR="${OCTET4}.${OCTET3}.${OCTET2}.${OCTET1}"

# At this point, we're proceeding to change the hosts entries,
# first we remove the existing ones.
sed /.*${HOSTNAME/./\.}.*/d /etc/hosts > /etc/hosts.bak

# Create the forward lookup entry.
echo "${HOSTNAME} ${CURRENT_ADDR}" >> /etc/hosts.bak

# Create the reverse lookup entry.
echo "${CURRENT_ADDR} ${HOSTNAME}" >> /etc/hosts.bak

# Move the file back to /etc/hosts
mv /etc/hosts.bak /etc/hosts

# Echo to stdout so we get something in root's mail.
echo "IP changed from ${HOSTS_ADDR} to ${CURRENT_ADDR}, /etc/hosts updated."

# If a dnsmasq config isn't specified we are done.
if [ -z "${DNSMASQ}" ]; then
  exit 0
fi

# Otheriwse time to deal with our rhev dnsmasq entries.
sed s/${HOSTS_ADDR/./\.}/${CURRENT_ADDR/./\.}/ ${DNSMASQ} > ${DNSMASQ}.bak
sed s/${HOSTS_ADDR_PTR/./\.}/${CURRENT_ADDR_PTR/./\.}/ ${DNSMASQ}.bak > ${DNSMASQ}
rm ${DNSMASQ}.bak

echo "${DNSMASQ} updated."

service dnsmasq reload &
