rhev-environment-scripts
========================

Collection of scripts for working with a minimal RHEV or oVirt environment.

add-user.py
===========

Given a UPN, add the user to the RHEV environment (if it hasn't already been added). The operation assumes that RHEV has already been attached to the relevant domain.

    $ python add-user.py <user@domain>

ip-sync.sh
==========

RHEV Manager / oVirt Engine expect a static IP address with an associated fully qualified domain attached. In Proof of Concept environments it may be desirable to use a DHCP allocated address, and dynamic DNS (usually due to constraints imposed on the network setup).

To support this it is possible to run a local dnsmasq instance on themanagement machine, providing it with the forward and reverse lookups for itself that it expects to see. To maintain this when DHCP changes the assigned IP this must be reflected in the hosts file, and depending on configuration the dnsmasq configuration. This is where ip-sync comes in.

The ip-sync is intended to be run as a regular cron job, it detects when the IP listed for the host in /etc/hosts differs from that attached to the specified device. When this happens the script updates the /etc/hosts entries and, optionally, the dnsmasq configuration.

In the default configuration the DEVICE is eth0, and the DNSMASQ configuration is /etc/dnsmasq.d/rhev.conf. The script expects the hosts entries for the hostname (detected at run time) to be on their own lines, for example:

    192.0.43.10 rhev.example.com
    rhev.example.com 192.0.43.10

In the dnsmasq configuration all instances of the old IP will be replaced by the new IP, reverse entries as they appear in PTR records will also be replaced correctly.

Usage is currently `sh ip-sync.sh`, no arguments are parsed from command line. Instead user configurable values must be set for the host that ip-sync is deployed on in the header of the script itself.

rhev-ks.sh
==========

Kickstart a RHEV-M installation inside a virtual machine on the local KVM host. Useful for quickly testing new builds. To use, edit the script and insert your local enterprise linux, oVirt/RHEV, and JBoss repositories.
