#!/usr/bin/env bash

function __check_os_version() {
    __log_debug "Checking OS compatability"
    export OS_VERSION="UNKNOWN"
    SUPPORTED_VERSIONS=("UNKNOWN")
    os=$1
    if [[ "$os" == "CENTOS" ]]; then
        OS_VERSION=$(awk '/^VERSION_ID=/{print $1}' /etc/os-release | awk -F"=" '{print $2}' | sed -e 's/^"//' -e 's/"//' | cut -c1-1)
        SUPPORTED_VERSIONS=("${CENTOS_OS_SUPPORTED_VERSIONS[@]}")
    elif [[ "$os" == "DEBIAN" ]]; then
        OS_VERSION=$(awk 'NR==1{print $3}' /etc/issue)
        SUPPORTED_VERSIONS=("${DEBIAN_OS_SUPPORTED_VERSIONS[@]}")
    elif [[ "$os" == "RHEL" ]]; then
        OS_VERSION=$(awk '/^VERSION_ID=/{print $1}' /etc/os-release | awk -F"=" '{print $2}' | sed -e 's/^"//' -e 's/"//' | cut -c1-1)
        SUPPORTED_VERSIONS=("${RHEL_OS_SUPPORTED_VERSIONS[@]}")
    elif [[ "$os" == "AMAZON" ]]; then
        OS_VERSION=$(awk '/^VERSION_ID=/{print $1}' /etc/os-release | awk -F"=" '{print $2}' | sed -e 's/^"//' -e 's/"$//')
        SUPPORTED_VERSIONS=("${AMAZON_LINUX_OS_SUPPORTED_VERSIONS[@]}")
    else
        OS_VERSION=$(awk 'NR==1{print $2}' /etc/issue | cut -c-5)
        SUPPORTED_VERSIONS=("${UBUNTU_OS_SUPPORTED_VERSIONS[@]}")
    fi
    __log_debug "OS version is: '${OS_VERSION}'"
    __log_debug "Supported Versions are: ${SUPPORTED_VERSIONS[*]}"
    supported=$(__elementIn "${OS_VERSION}" "${SUPPORTED_VERSIONS[@]}")
    __log_debug "Is supported: $supported"
    if [[ "$supported" == "1" ]]; then
        __log_error "This version of ${os} is not supported by Couchbase Server Enterprise Edition."
        exit 1
    fi
}

function __centos_prerequisites() {
    local sync_gateway=$1
    yum update -q -y
    yum install epel-release jq net-tools python2 wget -q -y
    python2 -m pip -q install httplib2
}

function __ubuntu_prerequisites() {
    local sync_gateway=$1
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

function __rhel_prerequisites() {
    local sync_gateway=$1
    yum update -q -y
    if [[ "$OS_VERSION" == 8* ]]; then
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -q -y
    else
        yum install epel-release -q -y
    fi
    yum install jq net-tools python2 wget -q -y
    python2 -m pip -q install httplib2
}

function __debian_prerequisites() {
    __ubuntu_prerequisites "$1"
}

function __amazon_prerequisites() {
    local sync_gateway=$1
    yum update -q -y
    amazon-linux-extras install epel
    yum install jq net-tools python2 python-pip wget -q -y
    python2 -m pip -q install httplib2
}

function __install_prerequisites() {
    local os=$1
    local sync_gateway=$2
    local env=$3
    __check_os_version "$os"
    __log_debug "Prequisites Installation"
    if [[ "$os" == "CENTOS" ]]; then
        __centos_prerequisites "$sync_gateway"
    elif [[ "$os" == "DEBIAN" ]]; then
        __debian_prerequisites "$sync_gateway"
    elif [[ "$os" == "RHEL" ]]; then
        __rhel_prerequisites "$sync_gateway"
    elif [[ "$os" == "AMAZON" ]]; then
        __amazon_prerequisites "$sync_gateway"
    else
        __ubuntu_prerequisites "$sync_gateway"
    fi

    __log_debug "Prequisites Complete"
}


# https://docs.couchbase.com/server/current/install/thp-disable.html
function __turnOffTransparentHugepages ()
{
    local os=$1
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
    if [[ "$os" == "CENTOS"  || "$os" == "RHEL" || "$os" == "AMAZON" ]]; then
        chkconfig --add disable-thp
    elif [[ "$os" == "DEBIAN" || "$os" == "UBUNTU" ]]; then
        update-rc.d disable-thp defaults
    fi
    service disable-thp start

    __log_debug "Transparent Hugepages have been disabled."
}

function __adjustTCPKeepalive ()
{
# Azure public IPs have some odd keep alive behaviour
# A summary is available here https://docs.mongodb.org/ecosystem/platforms/windows-azure/
    if [[ "$2" == "AZURE" ]] && [[ "$1" == "UBUNTU" || "$1" == "DEBIAN" ]] ; then
        __log_debug "Setting TCP keepalive..."
        sysctl -w net.ipv4.tcp_keepalive_time=120 -q

        __log_debug "Setting TCP keepalive permanently..."
        echo "net.ipv4.tcp_keepalive_time = 120
        " >> /etc/sysctl.conf
        __log_debug "TCP keepalive setting changed."
    fi

}

function __get_datadisk()
{
    echo "/datadisk"
}

function __formatDataDisk ()
{
    local os=$1
    local env=$2
    local sync_gateway=$3
    local disk=$4
    MOUNTPOINT="/datadisk"
    if [[ "$sync_gateway" -ne "0" ]]; then
        return
    fi

    # first, make mount point 
    __log_debug "Creating mountpoint: $MOUNTPOINT"
    mkdir -p $MOUNTPOINT

    # if we have a disk, format and mount
    if [[ -n "$disk" ]] &&  [[ -b "$disk" ]]; then
        __log_debug "Formatting data disk"
        DEVICE="$disk"
        mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "${DEVICE}"
        LINE="${DEVICE}\t${MOUNTPOINT}\text4\tdefaults,nofail\t0\t2"
        echo -e "${LINE}" >> /etc/fstab
        cat /etc/fstab
        mount -o discard,defaults "$DEVICE" "$MOUNTPOINT"
    fi
    # set ownership of the mount point
    __log_debug "Changing ownership of $MOUNTPOINT"
    chown couchbase $MOUNTPOINT -v
    __log_debug "Changing group of $MOUNTPOINT"
    chgrp couchbase $MOUNTPOINT -v
    __log_debug "Symbolic link logs directory to data disk"
    mkdir -p "$MOUNTPOINT/logs"
    ln -s "$MOUNTPOINT/logs" /opt/couchbase/var/lib/couchbase/logs

}

function __setSwappiness()
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

    sysctl vm.swappiness=${SWAPPINESS} -q

    __log_debug "Swappiness set to Zero"
}

# These are not exactly necessary.. But are here in case we need custom environment settings per OS
function __centos_environment() {
    __log_debug "Configuring CENTOS Specific Environment Settings"
}

function __debian_environment() {
    __log_debug "Configuring DEBIAN Specific Environment Settings"
}

function __ubuntu_environment() {
    __log_debug "Configuring UBUNTU Specific Environment Settings"
}

function __rhel_environment() {
    __log_debug "Configuring RHEL Specific Environment Settings"
}

function __amazon_environment() {
    __log_debug "Configuring Amazon Linux Specific Environment Settings"
}

function __configure_environment() {
    __log_debug "Setting up Environment"
    local env=$1
    local os=$2
    local sync_gateway=$3
    local disk=$4
    __log_debug "Setting up for environment: ${env}"
    __turnOffTransparentHugepages "$os" "$env" "$sync_gateway"
    __setSwappiness "$os" "$env" "$sync_gateway"
    __adjustTCPKeepalive "$os" "$env" "$sync_gateway"
    __formatDataDisk "$os" "$env" "$sync_gateway" "$disk"
    if [[ "$os" == "CENTOS" ]]; then
        __centos_environment "$env" "$sync_gateway"
    elif [[ "$os" == "DEBIAN" ]]; then
        __debian_environment "$env" "$sync_gateway"
    elif [[ "$os" == "RHEL" ]]; then
        __rhel_environment "$env" "$sync_gateway"
    elif [[ "$os" == "AMAZON" ]]; then
        __amazon_environment "$env" "$sync_gateway"
    else
        __ubuntu_environment "$env" "$sync_gateway"
    fi
}

function __install_syncgateway_centos() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Sync Gateway Enterprise Edition v${version}"
    __log_debug "Downloading installer to: ${tmp}"
    wget -O "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.rpm" "https://packages.couchbase.com/releases/couchbase-sync-gateway/${version}/couchbase-sync-gateway-enterprise_${version}_x86_64.rpm" --quiet
    __log_debug "Download complete. Beginning Unpacking"
    if ! rpm -i "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.rpm" > /dev/null; then
        __log_error "Error while installing ${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.rpm"
        exit 1
    fi

}
function __install_syncgateway_rhel() {
    __install_syncgateway_centos "$1" "$2"
}
function __install_syncgateway_amazon() {
    __install_syncgateway_centos "$1" "$2"
}

function __install_syncgateway_ubuntu() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Sync Gateway Enterprise Edition v${version}"
    __log_debug "Downloading installer to: ${tmp}"
    wget -O "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" "https://packages.couchbase.com/releases/couchbase-sync-gateway/${version}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" --quiet
    __log_debug "Download complete. Beginning Unpacking"
    if ! dpkg -i "${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb" > /dev/null ; then
        __log_error "Error while installing ${tmp}/couchbase-sync-gateway-enterprise_${version}_x86_64.deb"
        exit 1
    fi
}
function __install_syncgateway_debian() {
    __install_syncgateway_ubuntu "$1" "$2"
}
function __install_syncgateway() {
    local version=$1
    local tmp=$2
    local os=$3
    __log_debug "Installing Sync Gateway"
    __log_debug "Setting up sync gateway user"
    useradd sync_gateway
    __log_debug "Creating sync_gateway home directory"
    mkdir -p /home/sync_gateway/
    chown sync_gateway:sync_gateway /home/sync_gateway
    if [[ "$os" == "CENTOS" ]]; then
        __install_syncgateway_centos "$version" "$tmp"
    elif [[ "$os" == "DEBIAN" ]]; then
        __install_syncgateway_debian "$version" "$tmp"
    elif [[ "$os" == "RHEL" ]]; then
        __install_syncgateway_rhel "$version" "$tmp"
    elif [[ "$os" == "AMAZON" ]]; then
        __install_syncgateway_amazon "$version" "$tmp"        
    else
        __install_syncgateway_ubuntu "$version" "$tmp"
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

    # Need to restart sync gateway service to load the changes
    if [[ "$os" == "CENTOS" ]]; then
        service sync_gateway stop
        service sync_gateway start
    else
        systemctl stop sync_gateway
        systemctl start sync_gateway
    fi
}

function __install_couchbase_centos() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Server v${version}..."
    __log_debug "Downloading installer to: ${tmp}"
    local ARCH
    ARCH=$(uname -m)
    local file_path="${tmp}/couchbase-server-enterprise-${version}-centos${OS_VERSION}.x86_64.rpm"
    # example urls pulled from the couchbase.com website
    #https://packages.couchbase.com/releases/7.0.0-beta/couchbase-server-enterprise-7.0.0-beta-centos8.x86_64.rpm
    #https://packages.couchbase.com/releases/6.6.2/couchbase-server-enterprise-6.6.2-centos8.x86_64.rpm
    #https://packages.couchbase.com/releases/6.6.2/couchbase-server-enterprise-6.6.2-centos7.x86_64.rpm
    local download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise-${version}-centos${OS_VERSION}.x86_64.rpm"
    # New for 7.2.2+
    #https://packages.couchbase.com/releases/7.2.4/couchbase-server-enterprise-7.2.4-linux.x86_64.rpm
    local greaterThan722
    greaterThan722=$(__compareVersions "7.2.2" "$version")
    if [[ "$greaterThan722" -le "0" ]]; then
        download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise-${version}-linux.${ARCH}.rpm"
        file_path="${tmp}/couchbase-server-enterprise-${version}-linux.${ARCH}.rpm"
    fi 
    wget -O "$file_path" "$download_url" -q
    __log_debug "Beginning Installation"
    yum install "$file_path" -y -q
}

function __install_couchbase_rhel() {
    __install_couchbase_centos "$1" "$2"
}

function __install_couchbase_amazon() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Server v${version}..."
    __log_debug "Downloading installer to: ${tmp}"
    local ARCH
    ARCH=$(uname -m)
    local file_path="${tmp}/couchbase-server-enterprise-${version}-amzn2.${ARCH}.rpm"
    # examples from packages.couchbase.com
    #https://packages.couchbase.com/releases/7.0.0-beta/couchbase-server-enterprise-7.0.0-beta-amzn2.x86_64.rpm
    #https://packages.couchbase.com/releases/6.6.2/couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm
    #https://packages.couchbase.com/releases/6.6.2/couchbase-server-enterprise-7.1.3-amzn2.aarch64.rpm
    local download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise-${version}-amzn2.${ARCH}.rpm"
    local greaterThan722
    greaterThan722=$(__compareVersions "7.2.2" "$version")
    if [[ "$greaterThan722" -le "0" ]]; then
        download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise-${version}-linux.${ARCH}.rpm"
        file_path="${tmp}/couchbase-server-enterprise-${version}-linux.${ARCH}.rpm"
    fi
    wget -O "$file_path" "$download_url" -q
    __log_debug "Beginning Installation"
    yum install "$file_path" -y -q
}

function __install_couchbase_ubuntu() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Server v${version}..."
    __log_debug "Downloading installer to: ${tmp}"
    local ARCH
    ARCH=$(uname -m)
    local download_url="http://packages.couchbase.com/releases/${version}/couchbase-server-enterprise_${version}-ubuntu${OS_VERSION}_amd64.deb"
    local file_path="${tmp}/couchbase-server-enterprise_${version}-ubuntu${OS_VERSION}_amd64.deb"
    # Post 7.2.2
    #https://packages.couchbase.com/releases/7.2.2/couchbase-server-enterprise_7.2.2-linux_amd64.deb
    #https://packages.couchbase.com/releases/7.2.2/couchbase-server-enterprise_7.2.2-linux_arm64.deb
    if [[ "$ARCH" == "aarch64" ]]; then
        ARCH=arm64
    fi
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH=amd64
    fi
    local greaterThan722
    greaterThan722=$(__compareVersions "7.2.2" "$version")
    if [[ "$greaterThan722" -le "0" ]]; then
        download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise_${version}-linux_${ARCH}.deb"
        file_path="${tmp}/couchbase-server-enterprise-${version}-linux_${ARCH}.deb"
    fi
    __log_debug "Download link: $download_url"
    __log_debug "Download Path: $file_path"
    wget -O "$file_path" "$download_url" -q
    __log_debug "Download Complete.  Beginning Unpacking"
    until dpkg -i "$file_path" > /dev/null; do
        __log_error "Error while installing $file_path"
        sleep 1
    done
    __log_debug "Unpacking complete.  Beginning Installation"
    until apt-get update -qq > /dev/null; do
        __log_error "Error updating package repositories"
        sleep 1
    done
    until apt-get -y install couchbase-server -qq > /dev/null; do
        __log_error "Error while installing $file_path"
        sleep 1
    done
}

function __install_couchbase_debian() {
    local version=$1
    local tmp=$2
    __log_info "Installing Couchbase Server v${version}..."
    __log_debug "Downloading installer to: ${tmp}"
    local ARCH
    ARCH=$(uname -m)
    local download_url="http://packages.couchbase.com/releases/${version}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb"
    local file_path="${tmp}/couchbase-server-enterprise_${version}-debian${OS_VERSION}_amd64.deb"
    # Post 7.2.2
    #https://packages.couchbase.com/releases/7.2.2/couchbase-server-enterprise_7.2.2-linux_amd64.deb
    #https://packages.couchbase.com/releases/7.2.2/couchbase-server-enterprise_7.2.2-linux_arm64.deb
    #https://packages.couchbase.com/releases/7.2.4/couchbase-server-enterprise_7.2.4-linux_arm64.deb
    if [[ "$ARCH" == "aarch64" ]]; then
        ARCH=arm64
    fi
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH=amd64
    fi
    local greaterThan722
    greaterThan722=$(__compareVersions "7.2.2" "$version")
    if [[ "$greaterThan722" -le "0" ]]; then
        download_url="https://packages.couchbase.com/releases/${version}/couchbase-server-enterprise_${version}-linux_${ARCH}.deb"
        file_path="${tmp}/couchbase-server-enterprise-${version}-linux_${ARCH}.deb"
    fi

    wget -O "$file_path" "$download_url" -q
    __log_debug "Download Complete.  Beginning Unpacking"
    until dpkg -i "$file_path" > /dev/null; do
        __log_error "Error while installing $file_path"
        sleep 1
    done
    __log_debug "Unpacking complete.  Beginning Installation"
    until apt-get update -qq > /dev/null; do
        __log_error "Error updating package repositories"
        sleep 1
    done
    until apt-get -y install couchbase-server -qq > /dev/null; do
        __log_error "Error while installing $file_path"
        sleep 1
    done
}
function __install_couchbase() {
    local version=$1
    local tmp=$2
    local os=$3
    local sync_gateway=$4
    if [[ "$sync_gateway" -eq "1" ]]; then
        __install_syncgateway "$version" "$tmp" "$os"
        return 0
    fi
    __log_debug "Installing Couchbase on $os"
    if [[ "$os" == "CENTOS" ]]; then
        __install_couchbase_centos "$version" "$tmp"
    elif [[ "$os" == "DEBIAN" ]]; then
        __install_couchbase_debian "$version" "$tmp"
    elif [[ "$os" == "RHEL" ]]; then
        __install_couchbase_rhel "$version" "$tmp"
    elif [[ "$os" == "AMAZON" ]]; then
        __install_couchbase_amazon "$version" "$tmp"
    else
        __install_couchbase_ubuntu "$version" "$tmp"
    fi

    export CLI_INSTALL_LOCATION="/opt/couchbase/bin"

}
# This is a method to perform any final actions after the cluster has been created and/or joined
# Precipitated because GCP requires us to send a "Success" after we're done doing our work
function __post_install_finalization() {
    __log_debug "Beginning Post Install Finalization for environment $1"
}