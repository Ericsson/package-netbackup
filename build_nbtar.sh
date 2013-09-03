#!/bin/sh
#
# build_nbtar.sh
#
# Script used to build NetBackup GNU tar package
#
# Requirements:
# - NetBackup GNU tar binary available
# - fpm installed (gem install fpm)
# - facter installed
#
# author: johan.x.wennerberg@ericsson.com
# version: 0.1

PATH="/opt/eis_cm/bin:/opt/csw/bin:/usr/bin:/bin"

# Package metadata
nbtar_version="7.5.0.0"
nbtar_release="1"
nbtar_arch=`uname -i`
netbackup_bin=/usr/openv/netbackup/bin

nbtar_path=$1
if [ ! -f "${nbtar_path}" ]; then
  echo "usage: `basename $0` <path-to-nb-tar>"
  exit 1
fi

osfamily=`facter osfamily`
if [ -z $osfamily ]; then
  echo "ERROR: Could not determine osfamily. Cannot continue"
  exit 1
fi

case $osfamily in
  RedHat)
    lsbmajdistrelease=`facter lsbmajdistrelease`
    os="el${lsbmajdistrelease}"
    package_name="nbtar-${nbtar_version}-${nbtar_release}.${os}.${nbtar_arch}.rpm"

    fpm -C `dirname $nbtar_path` -s dir -t rpm -n nbtar -p $package_name -v $nbtar_version --iteration ${nbtar_release}.${os} -a $nbtar_arch --prefix $netbackup_bin --description "NetBackup GNU tar" --epoch $nbtar_release `basename $nbtar_path`
  ;;
  Suse)
    lsbmajdistrelease=`facter lsbmajdistrelease`
    os="suse${lsbmajdistrelease}"
    package_name="nbtar-${nbtar_version}-${nbtar_release}.${os}.${nbtar_arch}.rpm"

    fpm -C `dirname $nbtar_path` -s dir -t rpm -n nbtar -p $package_name -v $nbtar_version --iteration ${nbtar_release}.${os} -a $nbtar_arch --prefix $netbackup_bin --description "NetBackup GNU tar" --epoch $nbtar_release `basename $nbtar_path`
  ;;
  Solaris)
    kernelrelease=`facter kernelrelease`
    if [ $kernelrelease = '5.10' ]; then
      os="sol10"
    else
      os=$kernelrelease
    fi
    if [ $nbtar_arch = "i86pc" ]; then
      arch="i386"
    else
      arch="sparc"
    fi
    package_name="nbtar-${nbtar_version}-${os}-${arch}.pkg"

    fpm -C `dirname $nbtar_path` -s dir -t solaris -n nbtar -p $package_name -v $nbtar_version -a ${nbtar_arch} --prefix $netbackup_bin --solaris-user root --solaris-group sys --description "NetBackup GNU tar" `basename $nbtar_path`
  ;;
  *)
    echo "Unsupported osfamily <${osfamily}>. Script supported on RedHat, Suse and Solaris."
    exit 1
  ;;
esac
