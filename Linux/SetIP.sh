#!/bin/bash
##Atle Holm - Januar 2016
##Version 1.1.2
IP=$1
MASK=$2
BROADCAST=$3
MAC=$4
GATEWAY=$5

if [ -z "$IP" ] || [ -z "$MASK" ] || [ -z "$BROADCAST" ] || [ -z "$MAC" ]; then
	echo -e "\e[31mError: Missing arguments $0 \e[0m"
	echo -e "Example usage: $0 10.81.65.254 255.255.255.192 10.81.65.255 15:7E:54:BF:4A:B1 <GATEWAY>"
	echo -e "This is: $0 IP MASK BROADCAST MAC-OF-INTERFACE"
	echo -e "Sets the IP settings of NIC with MAC address specified."
	exit 1
fi
NIC=`ifconfig | grep -i $MAC | cut -d" " -f1`
if [ -z "$NIC" ]; then
	echo -e "\e[31mDid not find NIC with the mac address specified: $MAC\e[0m"
	exit 1
fi

ifconfig $NIC $IP netmask $MASK broadcast $BROADCAST && ifconfig $NIC up

if [ -f "/etc/redhat-release" ] || [ -f "/etc/centos-release" ]; then
	NETFILE="/etc/sysconfig/network-scripts/ifcfg-$NIC"
	echo "DEVICE=$NIC" > $NETFILE
	echo "BOOTPROTO=static" >> $NETFILE
	echo "HWADDR=$MAC" >> $NETFILE
	echo "IPADDR=$IP" >> $NETFILE
	echo "NETMASK=$MASK" >> $NETFILE
	echo "ONBOOT=yes" >> $NETFILE
	echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network
	`route add default gw $GATEWAY $NIC`
else
	NETFILE="/etc/network/interfaces"
	echo "auto $NIC" > $NETFILE
	echo "iface $NIC inet static" >> $NETFILE
	echo "  address $IP" >> $NETFILE
	echo "  netmask $MASK" >> $NETFILE
	echo "  broadcast $BROADCAST" >> $NETFILE
	echo "  gateway $GATEWAY" >> $NETFILE
	echo "" >> $NETFILE
	`route add default gw $GATEWAY $NIC`
fi
