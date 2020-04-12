#!/bin/bash

rm -rf /etc/ssh/ssh_host*
rm -rf /etc/udev/rules.d/70-persistent-net.rules
rm -rf /etc/touchme

chmod -x /root/make-template.sh

/sbin/service rsyslog stop
/sbin/service auditd stop

/bin/package-cleanup --oldkernels --count=1

/usr/bin/yum clean all

/usr/sbin/logrotate -f /etc/logrotate.conf
/bin/rm -f /var/log/*-???????? /var/log/*.gz
/bin/rm -f /var/log/dmesg.old
/bin/rm -rf /var/log/anaconda

/bin/cat /dev/null > /var/log/audit/audit.log
/bin/cat /dev/null > /var/log/wtmp
/bin/cat /dev/null > /var/log/lastlog
/bin/cat /dev/null > /var/log/grubby

/bin/rm -f /etc/udev/rules.d/70*

/bin/sed -i '/^(HWADDR|UUID)=/d' /etc/sysconfig/network-scripts/ifcfg-eth0

/bin/rm -rf /tmp/*
/bin/rm -rf /var/tmp/*

/bin/rm -f /etc/ssh/*key*

/bin/rm -f ~root/.bash_history
unset HISTFILE

/bin/rm -rf ~root/.ssh/
/bin/rm -f ~root/anaconda-ks.cfg

/bin/rm -f /var/log/nagios/retention.dat
/bin/rm -f /var/log/nagios/nagios.log
/bin/rm -f /var/spool/mail/root
echo "" > /var/log/centreon-engine/rw/centengine.cmd
echo "" > /var/log/nagios/rw/nagios.cmd