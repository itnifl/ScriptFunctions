#!/usr/bin/perl
use Getopt::Long;
use strict;

my ($help, $host, $username, $password, $warning, $critical, $guest, $mountpoint);

usage() if ( @ARGV < 1 or
          ! GetOptions('help|?' => \$help,
                'host=s' => \$host,
                'username=s' => \$username,
                'password=s' => \$password,
                'warning=i' => \$warning,
                'critical=i' => \$critical,
                'guest=s' => \$guest,
                'mountpoint=s' => \$mountpoint)
          or defined $help );

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: check_vm_disk.pl [--host ip] [--username USER] [--password PASS] [--warning SIZEMB] [--critical SIZEMB] [--guest GUEST] [--mountPoint C:] [--help|-?]\n";
  exit;
}

my @diskSize;
@diskSize = `(/usr/lib/vmware-vcli/apps/vm/guestinfo.pl --url https://$host:443/sdk/webService --username $username --password $password --vmname $guest --operation display | grep -A1 $mountpoint | grep -v '$mountpoint' | cut -d: -f3) | awk '{print \$0/1024/1024}'`;
if(scalar @diskSize > 0) {
        my $diskSizeScalar = $diskSize[0];
        chomp $diskSizeScalar;

        if($diskSizeScalar < $critical) {
                print "CRITICAL: $diskSizeScalar MB free space on $host";
                exit 2;
        } elsif($diskSizeScalar < $warning) {
                print "WARNING: $diskSizeScalar MB free space on $host";
                exit 1;
        } else {
                print "OK: $diskSizeScalar MB free space on $host";
                exit 0;
        }
} else {
        print "UNKNOWN: Free diskpace for $guest not defined";
        exit 3
}
