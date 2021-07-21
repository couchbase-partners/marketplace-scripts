#!/usr/bin/env bash

# Main Constants
export HELP=0
export VERSION="6.6.1"
export OS="UBUNTU"
export readonly AVAILABLE_OS_VALUES=("UBUNTU" "RHEL" "CENTOS" "DEBIAN" "AMAZON")
export ENV="OTHER"
export readonly AVAILABLE_ENV_VALUES=("AZURE" "AWS" "GCP" "DOCKER" "KUBERNETES" "OTHER")
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
export readonly DEFAULT_SERVICES=("data" "index" "analytics" "eventing" "fts" "query")
export SERVICES="${DEFAULT_SERVICES[*]}"
export SERVICES="${SERVICES// /,}"
export DATA_QUOTA=0
DATA_QUOTA=$(__getTotalRam)
export DATA_QUOTA=$((DATA_QUOTA / 2)) #50% of available as default
export INDEX_QUOTA=0
INDEX_QUOTA=$(__getTotalRam)
export INDEX_QUOTA=$((15 * INDEX_QUOTA / 100 )) #15% of available as default
export SEARCH_QUOTA=256
export ANALYTICS_QUOTA=1024
export EVENTING_QUOTA=256

#Installer Constants
export readonly CENTOS_OS_SUPPORTED_VERSIONS=("8" "7")
export readonly CENTOS_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly CENTOS_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
export readonly DEBIAN_OS_SUPPORTED_VERSIONS=("10" "9" "8")
export readonly DEBIAN_10_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly DEBIAN_9_SUPPORTED_VERSIONS=("5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly DEBIAN_8_SUPPORTED_VERSIONS=("5.0.1" "5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2")
export readonly DEBIAN_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
export readonly RHEL_OS_SUPPORTED_VERSIONS=("8" "7" "6")
export readonly RHEL_8_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly RHEL_7_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly RHEL_6_SUPPORTED_VERSIONS=("5.0.1" "5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4")
export readonly RHEL_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
export readonly UBUNTU_OS_SUPPORTED_VERSIONS=("14.04" "16.04" "18.04" "20.04")
export readonly UBUNTU_14_SUPPORTED_VERSIONS=("5.0.1" "5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1")
export readonly UBUNTU_16_SUPPORTED_VERSIONS=("5.0.1" "5.1.0" "5.1.1" "5.1.2" "5.1.3" "5.5.0" "5.5.1" "5.5.2" "5.5.3" "5.5.4" "5.5.5" "5.5.6" "6.0.0" "6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2")
export readonly UBUNTU_18_SUPPORTED_VERSIONS=("6.0.1" "6.0.2" "6.0.3" "6.0.4" "6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly UBUNTU_20_SUPPORTED_VERSIONS=("7.0.0")
export readonly UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
export readonly AMAZON_LINUX_OS_SUPPORTED_VERSIONS=("2")
export readonly AMAZON_LINUX_SUPPORTED_VERSIONS=("6.5.0" "6.5.1" "6.6.0" "6.6.1" "6.6.2" "7.0.0")
export readonly AMAZON_LINUX_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
