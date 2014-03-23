#!/bin/bash -ex

export LOGFILE=/tmp/$0_script.log

export CENTOS_BASE_CONTAIR_NAME="centos-base"
export CENTOS_MIRROR_URL="http://isoredirect.centos.org/centos/6.5/os/x86_64/"
export CENTOS_MIRROR_URL_UPDATES="http://isoredirect.centos.org/centos/6.5/updates/x86_64/"

export DOCKER_WORKSPACE=/var/lib/docker/workspace
export TARGET=${DOCKER_WORKSPACE}/${CENTOS_BASE_CONTAIR_NAME}


echo CentOS_BasicOS-ContainerImage Create Start `date` >> ${LOGFILE}

cd ${DOCKER_WORKSPACE}

rm -rf "${TARGET}"
mkdir -p "${TARGET}"

#-------------------------------------------------------------------------------
# CentOS 6.x base rpmfiles
#
# Were selected with reference to the RHEL-AMI(Amazon Machine Image) the package group
# https://bugzilla.redhat.com/show_bug.cgi?id=947174
# https://bugzilla.redhat.com/buglist.cgi?component=ec2-images&list_id=2335882&product=Red%20Hat%20Enterprise%20Linux%206
#-------------------------------------------------------------------------------
time /usr/bin/febootstrap centos ${CENTOS_BASE_CONTAIR_NAME} ${CENTOS_MIRROR_URL} \
                          --updates=${CENTOS_MIRROR_URL_UPDATES} \
                          --groupinstall="base" \
                          --groupinstall="client-mgmt-tools" \
                          --groupinstall="console-internet" \
                          --groupinstall="core" \
                          --groupinstall="debugging" \
                          --groupinstall="directory-client" \
                          --groupinstall="hardware-monitoring" \
                          --groupinstall="java-platform" \
                          --groupinstall="large-systems" \
                          --groupinstall="network-file-system-client" \
                          --groupinstall="performance" \
                          --groupinstall="perl-runtime" \
                          --groupinstall="server-platform" \
                          --groupinstall="server-policy" \
                          >> ${LOGFILE}

echo CentOS_BasicOS-ContainerImage Create Complete `date` >> ${LOGFILE}


echo CentOS_BasicOS-ContainerImage Customize Start `date` >> ${LOGFILE}

#mkdir -m 0755 "${TARGET}"/dev/pts
#mkdir -m 1777 "${TARGET}"/dev/shm

mknod -m 600 "${TARGET}"/dev/initctl   p
#mknod -m 666 "${TARGET}"/dev/null      c 1 3
#mknod -m 666 "${TARGET}"/dev/zero      c 1 5
#mknod -m 666 "${TARGET}"/dev/tty       c 5 0
mknod -m 620 "${TARGET}"/dev/tty0      c 4 0
mknod -m 620 "${TARGET}"/dev/tty1      c 4 1
mknod -m 620 "${TARGET}"/dev/tty2      c 4 2
mknod -m 620 "${TARGET}"/dev/tty3      c 4 3
mknod -m 620 "${TARGET}"/dev/tty4      c 4 4
#mknod -m 600 "${TARGET}"/dev/console   c 5 1
#mknod -m 666 "${TARGET}"/dev/full      c 1 7
#mknod -m 666 "${TARGET}"/dev/random    c 1 8
#mknod -m 444 "${TARGET}"/dev/urandom   c 1 9
#mknod -m 666 "${TARGET}"/dev/ptmx      c 5 2

chown root:tty "${TARGET}"/dev/tty*

# Change Root User Password
chroot "${TARGET}" bash -e -c "echo root:docker | chpasswd"

# Default Network Settings
cat > "${TARGET}"/etc/sysconfig/network << EOF
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=localhost.localdomain
EOF

cat > "${TARGET}"/etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
TYPE=Ethernet
USERCTL=yes
PEERDNS=yes
IPV6INIT=no
EOF

# Create a dummy file required by the system service
touch "${TARGET}"/etc/resolv.conf
touch "${TARGET}"/etc/fstab
touch "${TARGET}"/etc/mtab

#touch "${TARGET}"/sbin/init


#-------------------------------------------------------------------------------
# CentOS 6.x customize rpmfiles
#-------------------------------------------------------------------------------

# Chef-Client RPM Package
# http://www.getchef.com/chef/install/

export CHEF_RPM="https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.10.4-1.el6.x86_64.rpm"
yum -c "${TARGET}"/etc/yum.conf --nogpgcheck --installroot="${TARGET}" -y localinstall ${CHEF_RPM} >> ${LOGFILE}

# EPEL Repository RPM Package
# http://ftp.riken.jp/Linux/fedora/epel/6/x86_64/repoview/epel-release.html
# http://dl.fedoraproject.org/pub/epel/6/x86_64/repoview/

export EPEL_RPM="http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"
yum -c "${TARGET}"/etc/yum.conf --nogpgcheck --installroot="${TARGET}" -y localinstall ${EPEL_RPM} >> ${LOGFILE}


# Add a package of minimum for troubleshooting tools

yum --config="${TARGET}"/etc/yum.conf \
    --nogpgcheck \
    --installroot="${TARGET}" \
    -y install yum-plugin-changelog \
               yum-plugin-fastestmirror \
               yum-plugin-priorities \
               yum-plugin-versionlock \
               yum-utils \
               git \
               bash-completion \
               jq \
               zsh \
               ps_mem \
               tree \
               arpwatch \
               dropwatch \
               wireshark \
               supervisor \
               >> ${LOGFILE}

yum -c "${TARGET}"/etc/yum.conf --nogpgcheck --installroot="${TARGET}" -y update >> ${LOGFILE}
yum -c "${TARGET}"/etc/yum.conf --nogpgcheck --installroot="${TARGET}" -y clean all >> ${LOGFILE}

time /usr/bin/febootstrap-minimize "${TARGET}" \
                                   --all \
                                   --keep-locales \
                                   --keep-zoneinfo \
                                   --keep-rpmdb \
                                   --keep-yum-cache \
                                   --keep-services \
                                   --keep-sln \
                                   --keep-ldconfig \
                                   >> ${LOGFILE}

echo CentOS_BasicOS-ContainerImage Customize Complete `date` >> ${LOGFILE}



echo CentOS_BasicOS-ContainerImage Archive Start `date` >> ${LOGFILE}

# Delete if the file exists
rm -rf ${DOCKER_WORKSPACE}/${CENTOS_BASE_CONTAIR_NAME}.tar.xz


#-------------------------------------------------------------------------------
# tar Command Options
#     -C, --directory=DIR        change to directory DIR
#     -J, --xz                   filter the archive through xz
#     -c, --create               create a new archive
#         --acls                 Save the ACLs to the archive
#         --numeric-owner        always use numbers for user/group names
#     -f, --file=ARCHIVE         use archive file or device ARCHIVE
#     -p, --preserve-permissions, --same-permissions
#                                extract information about file permissions
#                                (default for superuser)
#     -s, --preserve-order, --same-order
#                                sort names to extract to match archive
#     -v, --verbose              verbosely list files processed
#-------------------------------------------------------------------------------

time tar --file=${DOCKER_WORKSPACE}/${CENTOS_BASE_CONTAIR_NAME}.tar.xz \
         --xz \
         --create \
         --acls \
         --numeric-owner \
         --preserve-permissions \
         --preserve-order \
         --verbose \
         --directory=${TARGET} . \
         >> ${LOGFILE}

echo CentOS_BasicOS-ContainerImage Archive Complete `date` >> ${LOGFILE}


echo CentOS_BasicOS-ContainerImage Import Start `date` >> ${LOGFILE}

time cat ${DOCKER_WORKSPACE}/${CENTOS_BASE_CONTAIR_NAME}.tar.xz | docker import - ${CENTOS_BASE_CONTAIR_NAME}:initial

echo CentOS_BasicOS-ContainerImage Import Complete `date` >> ${LOGFILE}


echo CentOS_BasicOS-ContainerImage InitialTest Start `date` >> ${LOGFILE}

docker run -i -t ${CENTOS_BASE_CONTAIR_NAME}:initial echo success >> ${LOGFILE}

echo CentOS_BasicOS-ContainerImage InitialTest Complete `date` >> ${LOGFILE}


