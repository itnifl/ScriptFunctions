#!/bin/bash
##Atle Holm - September 2015
##Version 1.0.1
NTPSERVER1=$1
NTPSERVER2=$2
NTPSERVER3=$3

if [ -z "$NTPSERVER1" ]; then
	echo -e "\e[31mError: Missing arguments $0 \e[0m"
	echo -e "Example usage: $0 172.20.100.10"
	echo -e "This is: $0 NTPSERV1 [NTPSERV2, NTPSERV3]"
	echo -e "Sets the NTP Servers that the system uses for time configuration."
	exit 1
else
	if [ -f "/etc/redhat-release" ] || [ -f "/etc/centos-release" ]; then
		echo "#yum -y install ntp"
	else
		echo "#apt-get -y install ntp"
	fi
	echo "server $NTPSERVER1" > /etc/ntp.conf
fi
if [ ! -z "$NTPSERVER2" ]; then
	echo "server $NTPSERVER2" >> /etc/ntp.conf
fi
if [ ! -z "$NTPSERVER3" ]; then
	echo "server $NTPSERVER3" >> /etc/ntp.conf
fi

if [ -f "/etc/redhat-release" ] || [ -f "/etc/centos-release" ]; then
	/etc/init.d/ntpd restart
else
	service ntp reload
fi
