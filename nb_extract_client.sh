#!/bin/bash
#
# nb_extract_client.sh
#
# Script used to extract client packages from a NetBackup Master server.
#
# Requirements:
# - NetBackup Master server with supported clients available
# - fpm installed (gem install fpm)
# - rpmrebuild installed -- http://rpmrebuild.sourceforge.net/
#
# author: johan.x.wennerberg@ericsson.com
# version: 0.1

usage()
{
  echo "usage: `basename $0` <osfamily>"
  echo ; echo "Supported osfamilies: redhat, suse, solaris10, solaris10x86"
}

#-----------------------------------------------
# Main
#-----------------------------------------------

osfamily=$1
[ -z $osfamily ] && (usage ; exit 1)

PATH="/bin:/usr/bin"
netbackup_clients=/usr/openv/netbackup/client
netbackup_bin=/usr/openv/netbackup/bin

nb_packages="SYMCnbclt:client_bin.tar.gz \
SYMCnbjre:JRE.tar.gz \
SYMCnbjava:NB-Java.tar.gz \
VRTSpbx:PBX.tar.gz \
SYMCpddea:pddeagent.tar.gz"

case $osfamily in
  redhat)
    package_type='rpm'
    client_dir="${netbackup_clients}/Linux/RedHat2.6.18"
    os='el'
  ;;
  suse)
    package_type='rpm'
    client_dir="${netbackup_clients}/Linux/SuSE2.6.16"
    os=$osfamily
  ;;
  solaris10)
    package_type='solaris'
    client_dir="${netbackup_clients}/Solaris/Solaris10"
    os=$osfamily
  ;;
  solaris10x86)
    package_type='solaris'
    client_dir="${netbackup_clients}/Solaris/Solaris_x86_10_64"
    os=$osfamily
    nb_packages="SYMCnbclt:client_bin.tar.gz \
SYMCnbjre:JRE.tar.gz \
SYMCnbjava:NB-Java.tar.gz \
VRTSpbx:PBX.tar.gz"
  ;;
  *)
  usage ; exit 1
  ;;
esac

destdir=`mktemp -d /tmp/nbclient.XXX`

for p in $nb_packages; do
  name=`echo $p | cut -f1 -d:`
  targz=`echo $p |cut -f2 -d:`

  echo "Extracting package ${name}"

  if [ ! -f "${client_dir}/${targz}" ]; then
    echo "ERROR: Could not find archive ${client_dir}/${targz}."
    continue
  fi

  cd $destdir
  tar xf "${client_dir}/${targz}"

  if [ $package_type = 'rpm' ]; then
    if [ $name = 'SYMCnbclt' ]; then
      nbclt_version=`rpm -qp --qf "%{VERSION}" ${destdir}/${name}*.rpm`
      nbclt_release=`rpm -qp --qf "%{RELEASE}" ${destdir}/${name}*.rpm`
      nbclt_arch=`rpm -qp --qf "%{ARCH}" ${destdir}/${name}*.rpm`
    fi
    package_name=`rpm -qp --qf "%{NAME}-%{VERSION}-%{RELEASE}.${os}.%{ARCH}.rpm" ${destdir}/${name}*.rpm`
    mv ${destdir}/${name}*.rpm ${destdir}/${package_name}

  elif [ $package_type = 'solaris' ]; then
    echo "Creating solaris adminfile"
    cat >> ${destdir}/admin << EOF
mail=
instance=unique
partial=nocheck
runlevel=quit
idepend=quit
rdepend=nocheck
space=quit
setuid=nocheck
conflict=nocheck
action=nocheck
basedir=default
EOF
  fi
done

# Build additional nbtar package
nbtar_version=$nbclt_version
nbtar_release=$nbclt_release
nbtar_arch=$nbclt_arch
echo "Building package nbtar"
if [ -d $client_dir ]; then
  fpm -C $client_dir -s dir -t $package_type -n nbtar -p ${destdir}/nbtar-${nbtar_version}-${nbtar_release}.${os}.${nbtar_arch}.${package_type} -v $nbtar_version --iteration ${nbtar_release}.${os} -a ${nbtar_arch} --prefix $netbackup_bin --description "NetBackup GNU tar" --epoch $nbtar_release tar
else
  echo "ERROR: Could not find client directory ${client_dir}"
fi

echo "Client packages written to ${destdir}"

if [ "$package_type" != "rpm" ]; then
  exit 0
fi

# Repackaging SYMCnbclt
echo 'Repackaging SYMCnbclt'
nbclt_rpm=${destdir}/SYMCnbclt*.rpm
nbclt_rpmrebuild_modify=${destdir}/rpmrebuild-modify.sh
nbclt_rpmrebuild_change_spec_files=${destdir}/rpmrebuild-change-spec-files.sh
mv $nbclt_rpm ${nbclt_rpm}.orig
cat > $nbclt_rpmrebuild_modify <<EOD
#!/bin/bash
cp -p ${client_dir}/version \
  \$RPMREBUILD_TMPDIR/work/root/${netbackup_bin}/
EOD
chmod +x $nbclt_rpmrebuild_modify
cat > $nbclt_rpmrebuild_change_spec_files <<EOD
#!/bin/bash
cat
echo '%attr(0444, root, bin) "${netbackup_bin}/version"'
EOD
chmod +x $nbclt_rpmrebuild_change_spec_files

# rebuild the rpm
rpmrebuild --change-spec-files=$nbclt_rpmrebuild_change_spec_files \
  --modify=$nbclt_rpmrebuild_modify -b -p ${nbclt_rpm}.orig

# cleaning up
rm -f $nbclt_rpmrebuild_modify $nbclt_rpmrebuild_change_spec_files

echo "Please find the SYMCnbclt package in your rpmbuild/RPMS directory"
