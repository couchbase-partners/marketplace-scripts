#!/usr/bin/env bash

set -eou pipefail
# These variables are utilized by logging
export DEBUG=0
export NO_COLOR=0
# get script directory to reference
# SCRIPT_SOURCE=${BASH_SOURCE[0]/%main.sh/}
# shellcheck disable=SC1091
# shellcheck source=common/loggers.sh
source './common/loggers.sh'
# shellcheck disable=SC1091
# shellcheck source=common/utils.sh
source './common/utils.sh'
# shellcheck disable=SC1091
# shellcheck source=common/constants.sh
source "./common/constants.sh"
# shellcheck disable=SC1091
# shellcheck source=common/help.sh
source './common/help.sh'
# shellcheck disable=SC1091
# shellcheck source=installers.installer.sh
source "./installers/installer.sh"


# Print header
print_header


# Here we're setting up a handler for unexpected errors during operations
function handle_exit() {
    __log_error "Error occurred during execution."
    exit 1
}

trap handle_exit SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

# Process Command Line Arguments
# View Readme.md for explanations
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -v|--version)
      # Version of couchbase server/sync gateway to install
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        VERSION=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -os|--operating-system)
      # Operating system (UBUNTU, RHEL, AMAZON). See AVAILABLE_OS_VALUES for full list
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        useful=$(__elementIn "${2}" "${AVAILABLE_OS_VALUES[@]}")
        if [ "$useful" == 1 ]; then
            __log_error "Invalid OS Option choose one of:" "${AVAILABLE_OS_VALUES[@]}"
            exit 1
        fi
        OS=$(__toUpper "$2")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -ch|--cluster-host)
      # Rally point url.  This is the hostname of the server determined to be used to create the cluster
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        CLUSTER_HOST=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -u|--user)
      # Username for creating/joining cluster, defaults to "couchbase"
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        CB_USERNAME=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -p|--password)
     # Password for creating/joining cluster.  Will default to DEFAULT_PASSWORD which is a randomly generating string
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        CB_PASSWORD=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -g|--sync-gateway)
      # Flag to toggle gateway install
      SYNC_GATEWAY=1
      shift
    ;;
    -d|--debug)
      # Sets debug mode for additional log levels
    export DEBUG=1
    shift # past argument
    ;;
    -r|--run-continuously)
      # Runs in perpetuity, useful for disposable containers
    DAEMON=1
    shift
    ;;    
    -s|--startup)
      # Indicates that this script will be run at every boot and should check for installation before continuing
    STARTUP=1
    shift
    ;;
    -c|--no-color)
      # Turns off ANSI color for terminals that do not support it
    export NO_COLOR=1
    shift
    ;;
    -e|--environment)
      # Environment that this script is being run in (Azure, AWS, GCP, Docker, etc)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        useful=$(__elementIn "${2}" "${AVAILABLE_ENV_VALUES[@]}")
        if [ "$useful" == 1 ]; then
            __log_error "Invalid Environment Option choose one of:" "${AVAILABLE_ENV_VALUES[@]}"
            exit 1
        fi
        ENV=$(__toUpper "$2")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi;
    ;;
    -w|--wait-nodes)
      # Indicate that this script should wait until it sees N nodes in the cluster before completing
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        WAIT=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing" >&2
        exit 1
      fi; #past argment
    ;;
    -n|--no-cluster)
      # Don't cluster the couchbase server nodes, only install
      NO_CLUSTER=1
      shift
    ;;
    -co|--cluster-only)
      # Don't install couchbase server, only perform the clustering
      CLUSTER_ONLY=1
      shift
    ;;
    -sv|--services)
      # Comma delimited list of services to run on this node
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ] && __allExists "$2" "${DEFAULT_7_SERVICES[@]}" ; then
        SERVICES=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -aa|--alternate-address)
      # Adds alternate address to the couchbase node
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        ALTERNATE_ADDRESS=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -fd|--format-disk)
      # Specifies disk to use and format for Couchbase, if left blank, no disk will be formatted
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        DISK=$2
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -sm|--search-memory)
      # indicates the amount of memory to allocate to the fts service
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      SEARCH_QUOTA=$(__convertToMiB "$2" "$SEARCH_QUOTA")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -am|--analytics-memory)
      # indicates the amount of memory to allocate to the analytics service
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        ANALYTICS_QUOTA=$(__convertToMiB "$2" "$ANALYTICS_QUOTA")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -em|--eventing-memory)
      # indicates the amount of memory to allocate to the eventing service
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        EVENTING_QUOTA=$(__convertToMiB "$2" "$EVENTING_QUOTA")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -im|--index-memory)
      # indicates the amount of memory to allocate to the index service
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        INDEX_QUOTA=$(__convertToMiB "$2" "$INDEX_QUOTA")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -dm|--data-memory)
      # indicates the amount of memory to allocate to the data service
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        DATA_QUOTA=$(__convertToMiB "$2" "$DATA_QUOTA")
        shift 2
      else
        __log_error "Error: Argument for $1 is missing, or incorrect" >&2
        exit 1
      fi;
    ;;
    -h|--help)
    # prints help
    HELP=1
    shift # past argument
    ;;
    *)    # unknown option
    shift # past argument
    ;;
esac
done

if [[ "$HELP" == 1 ]]; then
    print_help
    exit 0
fi

# we need to determine the default services here.  So if they were not passed in, we figure it out based on the version
if [[ "$SERVICES" == "" ]]; then
  __log_debug "Retrieving default services."
  SERVICES=$(__get_default_services "$VERSION")
  __log_debug "Default Services retrieved $SERVICES"
fi


__log_info "Installing Couchbase Version ${VERSION}"
__log_info "Beginning execution"
__log_info "Installing on OS: ${OS}"
__log_info "Configuring for Environment: ${ENV}"
if [[ "$SYNC_GATEWAY" != "1" ]]; then
  __log_info "Services to be intialized: $SERVICES"
  __log_info "Memory Quotas - Data: $DATA_QUOTA, Index: $INDEX_QUOTA, Analytics: $ANALYTICS_QUOTA, Eventing: $EVENTING_QUOTA, Search: $SEARCH_QUOTA"
fi
# if -s is passed, that means this script is being run at every startup, so we have to check to see
# if the work has already been completed.  If it has, we just want to exit gracefully
if [[ "$STARTUP" == "1" ]]; then
  __log_info "Checking for Couchbase Server Install"
  if [ -d "/opt/couchbase" ]; then
    # If we're not cluster only.. just exit
    if [[ "$CLUSTER_ONLY" == "0" ]]; then
      __log_info "Couchbase is already installed and part of a membership.  Exiting"
      exit;
    fi
    # try to get the cluster membership and if it is active, we don't need to do anything, even if we are cluster only
    CLUSTER_MEMBERSHIP=$(wget --http-user="$CB_USERNAME" --http-password="$CB_PASSWORD" -O - http://127.0.0.1:8091/pools/default -q | jq -r '') || CLUSTER_MEMBERSHIP="unknown pool"
    if [[ "$CLUSTER_MEMBERSHIP" != "unknown pool" ]]; then
      __log_info "Couchbase is already installed and part of a membership.  Exiting"
      exit;
    fi
  fi
fi

#installing prerequisites from installer
__install_prerequisites "$OS" "$ENV" "$SYNC_GATEWAY"

#Getting information to determine whether this is the cluster host or not.
LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
HOST=$(hostname) || hostnamectl
# Do a reverse DNS lookup on the cluster host and see if it is this local ip
PUBLIC_HOST_DNS=$(dig +short "$CLUSTER_HOST")
PUBLIC_IP=$(wget -nv --quiet -O - ifconfig.me)
__log_debug "Hostname:  ${HOST}"
__log_debug "Local IP: ${LOCAL_IP}"
__log_debug "ReverseDNS: ${PUBLIC_HOST_DNS}"
__log_debug "Public IP: ${PUBLIC_IP}"

# Check if host is cluster host, or local ip, or if the clusterhost contains the host for FQDN on GCP

if [[ "$CLUSTER_HOST" == "$HOST" ]] || [[ "$CLUSTER_HOST" == "$LOCAL_IP" ]] || [[ "$CLUSTER_HOST" == *"$HOST"* ]] || [[ "$PUBLIC_HOST_DNS" == "$LOCAL_IP" ]] || [[ "$PUBLIC_IP" == "$PUBLIC_HOST_DNS" ]]; then
    __log_info "${CLUSTER_HOST} is host and is this machine"
    DO_CLUSTER=1
fi

if [[ "$SYNC_GATEWAY" == 1 ]] || [[ "$NO_CLUSTER" == 1 ]]; then
    DO_CLUSTER=0
fi

__log_debug "The username is ${CB_USERNAME}"

if [[ "$CB_PASSWORD" == "$DEFAULT_PASSWORD" ]]; then
  __log_debug "The password is ${CB_PASSWORD}"
fi

#Slap a warning if the user did not specify a username/passsword
if [[ "$CB_USERNAME" == "$DEFAULT_USERNAME" ]] && [[ "$CB_PASSWORD" == "$DEFAULT_PASSWORD" ]]; then
    __log_warning "Default user name and password detected.  You should immediately log into the web console and change the password on the couchbase user!"
fi


if [[ "$CLUSTER_ONLY" == "0" ]]; then
  tmp_dir=$(mktemp -d)
  __log_info "Temp directory will be ${tmp_dir}"

  __install_couchbase "$VERSION" "${tmp_dir}" "$OS" "$SYNC_GATEWAY"
fi

__log_debug "Adding an entry to /etc/hosts to simulate split brain DNS..."
echo "
# Simulate split brain DNS for Couchbase
127.0.0.1 ${HOST}
" >> /etc/hosts

__log_debug "Performing Post Installation Configuration"
__configure_environment "$ENV" "$OS" "$SYNC_GATEWAY" "$DISK"
__log_debug "Completed Post Installation Configuration"

if [[ "$SYNC_GATEWAY" == 0 ]]; then

  __log_debug "CLI Installed to:  ${CLI_INSTALL_LOCATION}"

  __log_debug "Prior to initialization.  Let's hit the UI and make sure we get a response"

  until wget --server-response --spider "http://localhost:8091/ui/index.html" 2> /dev/null; do
    sleep 1
  done
  LOCAL_HOST_GET=$(wget --server-response --spider "http://localhost:8091/ui/index.html" 2>&1 | awk '/^  HTTP/{a=$2} END{print a}')
  __log_debug "LOCALHOST http://localhost:8091/ui/index.html: $LOCAL_HOST_GET"

  LOOPBACK_GET=$(wget  --server-response --spider "http://127.0.0.1:8091/ui/index.html" 2>&1 | awk '/^  HTTP/{a=$2} END{print a}')
  __log_debug "LOOPBACK http://127.0.0.1:8091/ui/index.html: $LOOPBACK_GET"

  HOSTNAME_GET=$(wget  --server-response --spider "http://${HOST}:8091/ui/index.html" 2>&1 | awk '/^  HTTP/{a=$2} END{print a}')
  __log_debug "HOST http://${HOST}:8091/ui/index.html:  $HOSTNAME_GET"

  IP_GET=$(wget --server-response --spider "http://${LOCAL_IP}:8091/ui/index.html" 2>&1 | awk '/^  HTTP/{a=$2} END{print a}')
  __log_debug "IP http://${LOCAL_IP}:8091/ui/index.html: $IP_GET"

  cd "${CLI_INSTALL_LOCATION}"

  DISK_PATH=$(__get_datadisk "$ENV")
  __log_debug "Node intialization with disk path $DISK_PATH"
  resval=$(./couchbase-cli node-init \
    --cluster="${LOCAL_IP}" \
    --node-init-hostname="${LOCAL_IP}" \
    --node-init-data-path="${DISK_PATH}/data" \
    --node-init-index-path="${DISK_PATH}/index" \
    --node-init-analytics-path="${DISK_PATH}/data" \
    --node-init-eventing-path="${DISK_PATH}/data" \
    --username="$CB_USERNAME" \
    --password="$CB_PASSWORD") || __log_error "Error during Node Initialization"
  __log_debug "node-init result: \'$resval\'"

  # if we have an alternate address, we should add it here
  if [[ -n "$ALTERNATE_ADDRESS" ]]; then
    __log_debug "Adding Alternate address."
    resval=$(./couchbase-cli setting-alternate-address \
              --cluster="${LOCAL_IP}" \
              --username="$CB_USERNAME" \
              --password="$CB_PASSWORD" \
              --set \
              --hostname "$ALTERNATE_ADDRESS" \
              --node "${LOCAL_IP}" ) || __log_error "Error during addition of an alternate address: \'$ALTERNATE_ADDRESS\'"
    __log_debug "Added address: $ALTERNATE_ADDRESS"
    __log_debug "setting-alternate-address result: \'$resval\'"
  fi
fi

if [[ $DO_CLUSTER == 1 ]]
then
  __log_debug "Running couchbase-cli cluster-init"
  result=$(./couchbase-cli cluster-init \
    --cluster="$CLUSTER_HOST" \
    --cluster-ramsize="$DATA_QUOTA" \
    --cluster-index-ramsize="$INDEX_QUOTA" \
    --cluster-fts-ramsize="$SEARCH_QUOTA" \
    --cluster-eventing-ramsize="$EVENTING_QUOTA" \
    --cluster-analytics-ramsize="$ANALYTICS_QUOTA" \
    --cluster-username="$CB_USERNAME" \
    --cluster-password="$CB_PASSWORD" \
    --services="$SERVICES") || __log_error "Error during Cluster Initialization"
__log_debug "cluster-init result: \'$result\'"
elif [[ $SYNC_GATEWAY == 0 ]] && [[ $NO_CLUSTER == 0 ]]; 
then
  __log_debug "Running couchbase-cli server-add"
  output=""
  while [[ $output != "Server $LOCAL_IP:8091 added" && $output != *"Node is already part of cluster."* ]]
  do
    __log_debug "In server add loop"
    # See MB-38001 - Must pass http:// and port 8091 to get it to not try to use tls in 7.0.0+
    # Since we have to be backward compatible, we're going to fall back to http only for now and
    # remove in the future
    # The future has come.  We're going to check version and if 7.1.0+ we're going to use https
    greaterThan71=$(__compareVersions 7.1.0 "$VERSION")
    cluster="http://$CLUSTER_HOST:8091"
    serverAdd="http://$LOCAL_IP:8091"
    sslVerify=""
    if [[ "$greaterThan71" -le "0" ]]; then
      cluster="https://$CLUSTER_HOST"
      serverAdd="https://$LOCAL_IP"
      sslVerify="--no-ssl-verify"
    fi
    if output=$(./couchbase-cli server-add \
      --cluster="$cluster" \
      --username="$CB_USERNAME" \
      --password="$CB_PASSWORD" \
      --server-add="$serverAdd" \
      --server-add-username="$CB_USERNAME" \
      --server-add-password="$CB_PASSWORD" \
      --services="$SERVICES" $sslVerify 2>&1); then
      output="Server $LOCAL_IP:8091 added"
    else
      __log_error "Error during Server Add"
    fi 
    __log_debug "server-add output \'$output\'"
    sleep 10
  done

  __log_debug "Running couchbase-cli rebalance"
  output=""
  while [[ ! $output =~ "SUCCESS" ]]
  do
    if ./couchbase-cli rebalance \
      --cluster="$CLUSTER_HOST" \
      --username="$CB_USERNAME" \
      --password="$CB_PASSWORD"; then
      output="SUCCESS"
      else
        __log_error "Error during Rebalance"
      fi
    __log_debug "rebalance output \'$output\'"
    sleep 10
  done
fi
__log_debug "Waiting for $WAIT nodes"

if [[ "$WAIT" -ne "0" && "$SYNC_GATEWAY" -ne "1" ]]; then
  __log_info "Beginning wait for cluster to have $WAIT nodes"
  healthy=0
  checks=0

  until [[ "$healthy" -eq "$WAIT" ]] || [[ "$checks" -ge "50" ]]; do
    __log_debug "Healthy node check - $healthy/$WAIT"
    healthy=$(wget -O -  \
                   --user "$CB_USERNAME" \
                   --password "$CB_PASSWORD" \
                   http://localhost:8091/pools/nodes \
                   -q \
                   | jq '[.nodes[] | select(.status == "healthy")] | length')
    (( checks += 1 ))
    sleep 3
  done
  __log_info "All nodes are healty - $healthy/$WAIT"
fi

__post_install_finalization "$ENV"
__log_info "Installation of Couchbase v${VERSION} is complete."



if [[ "$DAEMON" == 1 ]]; then
    __log_info "Going into daemon mode.  Will continue execution until cancelled."
    sleep infinity
fi