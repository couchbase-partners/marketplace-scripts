#!/usr/bin/env bash

formatDataDisk ()
{
    # This script formats and mounts the drive on lun0 as /datadisk
    # This is azure specific?  
    DISK="/dev/disk/azure/scsi1/lun0"
    PARTITION="/dev/disk/azure/scsi1/lun0-part1"
    MOUNTPOINT="/datadisk"

    __log_debug "Partitioning the disk."
    echo "n
    p
    1
    t
    83
    w"| fdisk ${DISK}

    __log_debug "Waiting for the symbolic link to be created..."
    udevadm settle --exit-if-exists=$PARTITION

    __log_debug "Creating the filesystem."
    mkfs -j -t ext4 ${PARTITION}

    __log_debug "Updating fstab"
    LINE="${PARTITION}\t${MOUNTPOINT}\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1\t2"
    echo -e ${LINE} >> /etc/fstab

    __log_debug "Mounting the disk"
    mkdir -p $MOUNTPOINT
    mount -a

    __log_debug "Changing permissions"
    chown couchbase $MOUNTPOINT
    chgrp couchbase $MOUNTPOINT
}

adjustTCPKeepalive ()
{
# Azure public IPs have some odd keep alive behaviour
# A summary is available here https://docs.mongodb.org/ecosystem/platforms/windows-azure/
    
    __log_debug "Setting TCP keepalive..."
    #sysctl -w net.ipv4.tcp_keepalive_time=120 -q

    __log_debug "Setting TCP keepalive permanently..."
    echo "net.ipv4.tcp_keepalive_time = 120
    " >> /etc/sysctl.conf
    __log_debug "TCP keepalive setting changed."
}

#https://docs.couchbase.com/server/current/install/thp-disable.html
turnOffTransparentHugepages ()
{
    __log_debug "Disabling Transparent Hugepages"
    echo "#!/bin/bash
### BEGIN INIT INFO
# Provides:          disable-thp
# Required-Start:    \$local_fs
# Required-Stop:
# X-Start-Before:    couchbase-server
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable THP
# Description:       Disables transparent huge pages (THP) on boot, to improve
#                    Couchbase performance.
### END INIT INFO

case \$1 in
  start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
      return 0
    fi

    echo 'never' > \${thp_path}/enabled
    echo 'never' > \${thp_path}/defrag

    re='^[0-1]+$'
    if [[ \$(cat \${thp_path}/khugepaged/defrag) =~ \$re ]]
    then
      # RHEL 7
      echo 0  > \${thp_path}/khugepaged/defrag
    else
      # RHEL 6
      echo 'no' > \${thp_path}/khugepaged/defrag
    fi

    unset re
    unset thp_path
    ;;
esac
    " > /etc/init.d/disable-thp
    chmod 755 /etc/init.d/disable-thp
    service disable-thp start
    update-rc.d disable-thp defaults
    __log_debug "Transparent Hugepages have been disabled."
}

setSwappiness()
{
    KERNEL_VERSION=$(uname -r)
    RET=$(__compareVersions "$KERNEL_VERSION" "3.5.0")
    SWAPPINESS=0
    if [[ "$RET" == "1" ]]; then
        SWAPPINESS=1
    fi
    __log_debug "Setting Swappiness to Zero"
    echo "
    # Required for Couchbase
    vm.swappiness = ${SWAPPINESS}
    " >> /etc/sysctl.conf
    __log_debug "Swappiness set to Zero"
}

DEBIAN_OS_SUPPORTED_VERSIONS=("10" "9" "8")
DEBIAN_10_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1")
DEBIAN_9_SUPPORTED_VERSIONS=("5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1")
DEBIAN_8_SUPPORTED_VERSIONS=("5.0.1" "5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1")
DEBIAN_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0")

OS_VERSION=$(awk 'NR==1{print $3}' /etc/issue)

# Prerequisite installation
# This is called by the main.sh to set up all necessary libaries
function __install_prerequisites() {

    # Here we are unlocking dpkg should it be locked by another process
    # FILE="/var/lib/dpkg/lock-frontend"
    # DB="/var/lib/dpkg/lock"
    # if [[ -f "$FILE" ]]; then
    # PID=$(lsof -t $FILE)
    # echo "lock-frontend locked by $PID"
    # echo "Killing $PID"
    # kill -9 "${PID##p}"
    # echo "$PID Killed"
    # rm $FILE
    # PID=$(lsof -t $DB)
    # echo "DB locked by $PID"
    # kill -9 "${PID##p}"
    # rm $DB
    # dpkg --configure -a
    # fi

    __log_debug "Checking OS compatability"
    __log_debug "OS version is: ${OS_VERSION}"
    __log_debug "Supported Versions are: ${DEBIAN_OS_SUPPORTED_VERSIONS[*]}"
    supported=$(__elementIn "$OS_VERSION" "${DEBIAN_OS_SUPPORTED_VERSIONS[@]}")
    if [[ "$supported" == 1 ]]; then
        __log_error "This version of DEBIAN is not supported by Couchbase Server Enterprise Edition."
        exit 1
    fi
    __log_info "Installing prerequisites..."
    
    __log_debug "Updating package repositories"
    until apt-get update > /dev/null; do
        __log_error "Error performing package repository update"
        sleep 2
    done
    # shellcheck disable=SC2034
    DEBIAN_FRONTEND=noninteractive
    __log_debug "Installing Prequisites"
    until apt-get install --assume-yes apt-utils dialog python-httplib2 jq net-tools wget lsb-release  -qq > /dev/null; do
        __log_error "Error during pre-requisite installation"
        sleep 2
    done
    __log_debug "Prequisitie Installation complete"
}

# Main Installer function.  This actually performs the download of the binaries
# This is called by main.sh for installation.
function __install_couchbase() {
    version=$1
    if [[ "$OS_VERSION" == "8" ]]; then
        version=$(__findClosestVersion "$1" "${DEBIAN_8_SUPPORTED_VERSIONS[@]}")
    fi
    if [[ "$OS_VERSION" == "9" ]]; then
        version=$(__findClosestVersion "$1" "${DEBIAN_9_SUPPORTED_VERSIONS[@]}")
    fi
    if [[ "$OS_VERSION" == "10" ]]; then
        version=$(__findClosestVersion "$1" "${DEBIAN_10_SUPPORTED_VERSIONS[@]}")
    fi
    tmp=$2
    __log_info "Installing Couchbase Server v${version}..."
    __log_debug "Downloading installer to: ${tmp}"
    wget -O "${tmp}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb" "http://packages.couchbase.com/releases/${version}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb" -q
    __log_debug "Download Complete.  Beginning Unpacking"
    until dpkg -i "${tmp}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb" > /dev/null; do
        __log_error "Error while installing ${tmp}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb"
        sleep 1
    done
    __log_debug "Unpacking complete.  Beginning Installation"
    until apt-get update -qq > /dev/null; do
        __log_error "Error updating package repositories"
        sleep 1
    done
    until apt-get -y install couchbase-server -qq > /dev/null; do
        __log_error "Error while installing ${tmp}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb"
        sleep 1
    done

    #return the location of where the couchbase cli is installed
    export CLI_INSTALL_LOCATION="/opt/couchbase/bin"

}

# Sync Gateway Installer,  For when the script is to be used to install sync gateway and not CBS
function __install_syncgateway() {
    version=$1
    tmp=$2
    version=$(__findClosestVersion "$1" "${DEBIAN_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}")
    echo "Setting up sync gateway user"
    useradd sync_gateway
    echo "Creating sync_gateway home directory"
    mkdir -p /home/sync_gateway/
    chown sync_gateway:sync_gateway /home/sync_gateway

    __log_info "Installing Couchbase Sync Gateway Enterprise Edition v${version}"
    __log_debug "Downloading installer to: ${tmp}"
    wget -O "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" "https://packages.couchbase.com/releases/couchbase-sync-gateway/${version}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" --quiet
    __log_debug "Download complete. Beginning Unpacking"
    if ! dpkg -i "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" > /dev/null; then
        __log_error "Error while installing ${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb"
        exit 1
    fi

    __log_info "Installation Complete. Configuring Couchbase Sync Gateway"

    file="/home/sync_gateway/sync_gateway.json"
    echo '
    {
    "interface": "0.0.0.0:4984",
    "adminInterface": "0.0.0.0:4985",
    "log": ["*"]
    }
    ' > ${file}
    chmod 755 ${file}
    chown sync_gateway ${file}
    chgrp sync_gateway ${file}

    # Need to restart to load the changes
    systemctl stop sync_gateway
    systemctl start sync_gateway
}

# Post install this method is called to make changes to the system based on the environment being installed to
#  env can be AZURE, AWS, GCP, DOCKER, KUBERNETES, OTHER
function __configure_environment() {
    __log_debug "Configuring Environment"
    env=$1
    __log_debug "Setting up for environment: ${env}"
    if [[ "$env" == "AZURE" ]]; then
        formatDataDisk
    fi
    turnOffTransparentHugepages
    setSwappiness
    adjustTCPKeepalive
}