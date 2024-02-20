# Couchbase Marketplace Installation Scripts

These scripts are intended for usage to install and cluster multiple VM's, containers, etc.

## Getting Started

These scripts are bundled into a single output file with [bash_bunder](https://github.com/malscent/bash_bundler).  It can be installed with 
```
go install github.com/malscent/bash_bundler@latest
```

Bundling:

```bash_bundler bundle -e ./main.sh -o ./build/couchbase_installer.sh```

This project uses [BATS](https://bats-core.readthedocs.io/en/latest/) for unit tests.  

## Parameters

### ```-v|--version```

**Usage**:  ```./main.sh -v 6.6.1```

**Purpose**: Specifies the version of couchbase to install

### ```-os|--operating-system```
**Usage**: ```./main.sh -os UBUNTU```

**Purpose**:  Specifies the Operating System the script is being used to install to.  

**Options**: ```UBUNTU, MACOS, OSX, RHEL, CENTOS, DEBIAN, AMAZON```

### ```-ch|--cluster-host```

**Usage**: ```./main.sh -ch <CLUSTERHOST>```

**Purpose**: Specifies the cluster host name or ip address

### ```-u|--user```

**Usage**: ```./main.sh -u couchbase```

**Purpose**: Specifies the username to be used for both the couchbase install and the cluster join mechanism

### ```-p|--password```

**Usage**: ```./main.sh -p foo123!```

**Purpose**:  Specifies the password to be used for both the couchbase install and the cluster join mechanism

### ```-d|--debug```

**Usage**: ```./main.sh -d```

**Purpose**: Specifies that the script should be executed in debug mode, increasing output information to assist in debugging the script.

### ```-g|--sync-gateway```

**Usage**: ```./main.sh -g```

**Purpose**: Specifies that the script should install the Couchbase Sync Gateway instead of Couchbase Server

### ```-r|--run-continuously```

**Usage**: ```./main.sh -r```

**Purpose**: Specifies that the script should run forever to maintain container execution after script completes.  Used mainly for testing purposes.

### ```-c|--no-color```

**Usage**: ```./main.sh -c```

**Purpose**: Specifies that the script should run in a no-color mode. This is for environments where colored output can be a net negative to execution.

### ```-e|--environment```

**Usage**: ```./main.sh -e AZURE```

**Purpose**: Specifies the environment that the script is being run in.  Allows installer to execute specific commands depending on where the script is being run.

**Options**:  ```AZURE, AWS, GCP, DOCKER, KUBERNETES, OTHER```

### ```-s|--startup```

**Usage**:  ```./main.sh -s```

**Purpose**: Specifies the install script to run in a mode that is intended to run on every boot of the server

### ```-w|--wait-nodes```

**Usage**: ```./main.sh -w 5

**Purpose**: Specifies that the script should not report success until it sees N nodes in the cluster.  This is used for GCP notifications on completion

### ```-n|--no-cluster```

**Usage**: ```./main.sh -n 

**Purpose**: Specifies that in a Couchbase Server installation, it should not take any actions to cluster the server after installing couchbase

### ```-dm|--data-memory```

**Usage**: ```./main.sh -dm 50MiB

**Purpose**: Specifies the amount of memory to allocate to the data service within the cluster.  Values can be MiB, GiB or TiB. No suffix will result in MiB. Defaults to 50% of the available memory.

### ```-im|--index-memory```

**Usage**: ```./main.sh -im 15MiB

**Purpose**: Specifies the amount of memory to allocate to the index service within the cluster.  Values can be MiB, GiB or TiB. No suffix will result in MiB. Defaults to 15% of the available memory.

### ```-em|--eventing-memory```

**Usage**: ```./main.sh -em 5MiB

**Purpose**: Specifies the amount of memory to allocate to the eventing service within the cluster.  Values can be MiB, GiB or TiB. No suffix will result in MiB. Defaults to 256MiB.

### ```-sm|--search-memory```

**Usage**: ```./main.sh -fm 15MiB

**Purpose**: Specifies the amount of memory to allocate to the search service within the cluster.  Values can be MiB, GiB or TiB. No suffix will result in MiB. Defaults to 256MiB.

### ```-am|--analytics-memory```

**Usage**: ```./main.sh -am 1GiB

**Purpose**: Specifies the amount of memory to allocate to the query service within the cluster.  Values can be MiB, GiB or TiB. No suffix will result in MiB. Defaults to 1GiB.

### ```-sv|--services```

**Usage**: ```./main.sh --services data,fts,index,query,eventing,analytics

**Purpose**: Specifies the services that will be enabled on the Couchbase server

### ```-h|--help```

**Usage**: ```./main.sh -h```

**Purpose**:  Prints help regarding the parameters to pass to this script

### ```-co|--cluster-only```

**Usage**: ```./main.sh --cluster-only```

**Purpose**: This is for situations where an existing couchbase server needs added to an existing couchbase cluster, but the instllation does not need to be performed

## Build Containers for test

```
 docker build -t couchbase/ubuntu -f ./test_scripts/ubuntu/Dockerfile .
```

## Using Containers with arguments for testing

Docker containers are intended for usage testing and are not representative of the expected use case. Docker Containers only use the latest image of the OS,  We do not try to test in older docker images.  If you want to use Couchbase Server inside a docker container, see the approved docker container images at [DockerHub](https://hub.docker.com/_/couchbase)

### Create Network
First you need to create a network to join your nodes to.
```
docker network create --driver bridge cb-net
```

### Clusterhost
Create a clusterhost 
```
docker run --privileged --hostname clusterhost --expose=8091 -ti --rm --network cb-net --name clusterhost  couchbase/ubuntu --version 6.6.1 -u couchbase -p foo123! -ch clusterhost -d -os UBUNTU -r
```

### Node
Create N nodes.
```
docker run --privileged --hostname nodehost1 -p 8091 -ti --network cb-net --name nodehost1  couchbase/ubuntu --version 6.6.1 -u couchbase -p foo123! -ch clusterhost -d -os UBUNTU -r -e DOCKER
```

## Using Docker Compose

To create a cluster for testing use:

```
docker-compose -f ./compose-files/<OS SPECIFIC FILE>.yml up
```

You can then reach the containers on http://localhost:8080 (RallyNode), http://localhost:8081 (NodeOne) and http://localhost:8082 (NodeTwo)

To take down the cluster:

```
docker-compose -f ./compose-files/<OS SPECIFIC FILE>.yml down
```

## Development Considerations

* Use Wget not Curl