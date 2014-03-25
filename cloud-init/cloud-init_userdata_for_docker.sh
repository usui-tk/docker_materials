#! /bin/bash -v
LOGFILE=/tmp/cloud-init_script.log

echo cloud-init Execute START `date` >> ${LOGFILE}

echo cloud-init RHEL yum update Start `date` >> ${LOGFILE}
yum update -y rh-amazon-rhui-client >> ${LOGFILE}
yum-config-manager --enable rhui-REGION-rhel-server-supplementary  >> ${LOGFILE}
yum install -y yum-plugin-fastestmirror yum-plugin-changelog yum-plugin-priorities yum-plugin-versionlock yum-utils >> ${LOGFILE}
yum clean all >> ${LOGFILE}
yum install -y git >> ${LOGFILE}
yum update -y >> ${LOGFILE}
echo cloud-init RHEL yum update Complete `date` >> ${LOGFILE}

echo cloud-init Custom yum update Start `date` >> ${LOGFILE}
yum clean all >> ${LOGFILE}
yum localinstall -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm >> ${LOGFILE}
yum clean all >> ${LOGFILE}
yum localinstall -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm >> ${LOGFILE}
yum clean all >> ${LOGFILE}
yum localinstall -y https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.10.4-1.el6.x86_64.rpm >> ${LOGFILE}
yum clean all >> ${LOGFILE}
yum update -y >> ${LOGFILE}
echo cloud-init Custom yum update Complete `date` >> ${LOGFILE}

echo cloud-init RHEL TimeZone Setting Start `date` >> ${LOGFILE}
date >> ${LOGFILE}
/bin/cp -fp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
date >> ${LOGFILE}
/usr/sbin/ntpdate 0.rhel.pool.ntp.org >> ${LOGFILE}
date >> ${LOGFILE}
/sbin/chkconfig ntpd on >> ${LOGFILE}
/sbin/service ntpd start >> ${LOGFILE}
sleep 5
/usr/sbin/ntpq -p >> ${LOGFILE}
date >> ${LOGFILE}
echo cloud-init RHEL TimeZone Setting Complete `date` >> ${LOGFILE}

echo cloud-init RHEL Server Basic Setting Start `date` >> ${LOGFILE}
yum install -y jq sdparm sg3_utils lsscsi x86info diffstat ps_mem arpwatch dropwatch wireshark screen conman logwatch zsh expect pexpect tree hardlink bash-completion tuned tuned-utils >> ${LOGFILE}
/sbin/service tuned start >> ${LOGFILE}
/usr/sbin/tuned-adm profile throughput-performance >> ${LOGFILE}
/usr/sbin/tuned-adm active >> ${LOGFILE}
/sbin/service tuned restart >> ${LOGFILE}
/sbin/chkconfig tuned on >> ${LOGFILE}
echo cloud-init RHEL Server Basic Setting Complate `date` >> ${LOGFILE}

echo cloud-init RHEL Enabled IP Forward Start `date` >> ${LOGFILE}
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
/sbin/sysctl -p
/sbin/sysctl -a | grep -ie "net.ipv4.ip_forward" >> ${LOGFILE}
echo cloud-init RHEL Disabled IPv6 Function Complete `date` >> ${LOGFILE}

echo cloud-init RHEL Disabled IPv6 Function Start `date` >> ${LOGFILE}
echo "# Custom sysctl Parameter for ipv6 disable" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
/sbin/sysctl -p
/sbin/sysctl -a | grep -ie "local_port" -ie "ipv6" | sort >> ${LOGFILE}
echo "options ipv6 disable=1" >> /etc/modprobe.d/ipv6.conf
echo cloud-init RHEL Disabled IPv6 Function Complete `date` >> ${LOGFILE}

echo cloud-init DockerDaemon_and_DockerRegistry Server Install Start `date` >> ${LOGFILE}
yum install -y docker-io fedora-dockerfiles bash-completion >> ${LOGFILE}
yum install -y docker-registry python-jinja2 redis >> ${LOGFILE}
yum install -y febootstrap xz pxz >> ${LOGFILE}
echo cloud-init DockerDaemon_and_DockerRegistry Server Install Complete `date` >> ${LOGFILE}

echo cloud-init DockerDaemon_and_DockerRegistry Server Settings Start `date` >> ${LOGFILE}
sed -i 's/other_args=/#other_args=/g' /etc/sysconfig/docker
echo "other_args=\"--debug=true --daemon=true --icc=true\"" >> /etc/sysconfig/docker
/sbin/service docker start >> ${LOGFILE}
/sbin/chkconfig docker on >> ${LOGFILE}
/sbin/service redis start >> ${LOGFILE}
/sbin/chkconfig redis on >> ${LOGFILE}
/sbin/service docker-registry start >> ${LOGFILE}
/sbin/chkconfig docker-registry on >> ${LOGFILE}
/usr/bin/curl -v http://localhost:5000 >> ${LOGFILE}
echo cloud-init DockerDaemon_and_DockerRegistry Server Settings Complete `date` >> ${LOGFILE}

echo cloud-init Root Disk Partition Resize Start `date` >> ${LOGFILE}
/sbin/fdisk -l >> ${LOGFILE}
/sbin/fdisk /dev/xvda << __EOF__ >> ${LOGFILE}
p
d
p
n
p
1
16

w
__EOF__
/sbin/fdisk -l >> ${LOGFILE}
echo cloud-init Root Disk Partition Resize Complete `date` >> ${LOGFILE}

echo cloud-init Data Disk Partition Create Start `date` >> ${LOGFILE}
/sbin/fdisk -l >> ${LOGFILE}
/sbin/fdisk /dev/xvdb << __EOF__
p
n
p
1
1

w
__EOF__
/sbin/fdisk -l >> ${LOGFILE}
echo cloud-init Data Disk Partition Create Complete `date` >> ${LOGFILE}

echo cloud-init Data Disk FileSystem Create Start `date` >> ${LOGFILE}
time /sbin/mkfs.ext4 -T largefile -m 0 /dev/xvdb1 >> ${LOGFILE}
cat /etc/fstab >> ${LOGFILE}
sed -i 's@/dev/xvdb@#/dev/xvdb@g' /etc/fstab
mkdir -p -m 755 /var/lib/docker/workspace
echo "/dev/xvdb1      /var/lib/docker/workspace   ext4   defaults   0 0" >> /etc/fstab
cat /etc/fstab >> ${LOGFILE}
echo cloud-init Data Disk FileSystem Create Complete `date` >> ${LOGFILE}

echo cloud-init Swap File Create Start `date` >> ${LOGFILE}
/sbin/swapon -s >> ${LOGFILE}
/usr/bin/free >> ${LOGFILE}
/usr/bin/time dd if=/dev/zero of=/mnt/swap bs=1M count=1024 >> ${LOGFILE}
/sbin/mkswap /mnt/swap >> ${LOGFILE}
/sbin/swapon /mnt/swap >> ${LOGFILE}
/sbin/swapon -s >> ${LOGFILE}
/usr/bin/free >> ${LOGFILE}
cat /etc/fstab >> ${LOGFILE}
echo "/mnt/swap  swap      swap    defaults        0 0" >> /etc/fstab
cat /etc/fstab >> ${LOGFILE}
echo cloud-init Swap File Create Complete `date` >> ${LOGFILE}

echo cloud-init Execute Complete `date` >> ${LOGFILE}

/sbin/reboot >> ${LOGFILE}

