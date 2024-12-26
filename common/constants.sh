#!/usr/bin/env bash

# Main Constants
export HELP=0
export VERSION="7.6.3"
export OS="UBUNTU"
readonly AVAILABLE_OS_VALUES=("UBUNTU" "RHEL" "CENTOS" "DEBIAN" "AMAZON")
export AVAILABLE_OS_VALUES
export ENV="OTHER"
readonly AVAILABLE_ENV_VALUES=("AZURE" "AWS" "GCP" "DOCKER" "KUBERNETES" "OTHER")
export AVAILABLE_ENV_VALUES
export DEFAULT_USERNAME="couchbase"
export DEFAULT_PASSWORD=""
DEFAULT_PASSWORD=$(__generate_random_string)
export CB_USERNAME=$DEFAULT_USERNAME
export CB_PASSWORD=$DEFAULT_PASSWORD
export DAEMON=0
export STARTUP=0
export SYNC_GATEWAY=0
export WAIT=0
# Performs installation of couchbase server, but does not attempt to add the server to an existing cluster
export NO_CLUSTER=0
# Skips the installation and only performs the addition of a couchbase server to an existing cluster
export CLUSTER_ONLY=0
# Internal variable for determining whether to perform clustering or not
export DO_CLUSTER=0
export SERVICES=""
export DATA_QUOTA=0
DATA_QUOTA=$(__getTotalRam)
export DATA_QUOTA=$((DATA_QUOTA / 2)) #50% of available as default
export INDEX_QUOTA=0
INDEX_QUOTA=$(__getTotalRam)
export INDEX_QUOTA=$((15 * INDEX_QUOTA / 100 )) #15% of available as default
export SEARCH_QUOTA=256
export ANALYTICS_QUOTA=1024
export EVENTING_QUOTA=256
export DISK=""
export ALTERNATE_ADDRESS=""

#Installer Constants
readonly CENTOS_OS_SUPPORTED_VERSIONS=("8" "7")
readonly DEBIAN_OS_SUPPORTED_VERSIONS=("10" "9" "8")
readonly RHEL_OS_SUPPORTED_VERSIONS=("8" "7" "6")
readonly UBUNTU_OS_SUPPORTED_VERSIONS=("14.04" "16.04" "18.04" "20.04" "22.04" "24.04")
readonly AMAZON_LINUX_OS_SUPPORTED_VERSIONS=("2" "2023")

export CENTOS_OS_SUPPORTED_VERSIONS
export DEBIAN_OS_SUPPORTED_VERSIONS
export RHEL_OS_SUPPORTED_VERSIONS
export UBUNTU_OS_SUPPORTED_VERSIONS
export AMAZON_LINUX_OS_SUPPORTED_VERSIONS
