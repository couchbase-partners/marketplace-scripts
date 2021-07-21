#!/usr/bin/env bash

#  Generates a 13 character random string
function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')
    echo "${NEW_UUID}"
}

error_exit() {
    line=$1
    shift 1
    __log_error "non zero return code from line: $line - $*"
    exit 1
}

# Checks to see if a value is contained by an array
function __elementIn() {
    local match
    match=$(echo "$1" | tr '[:lower:]' '[:upper:]' | xargs)
    shift 1
    if [ "$#" == "1" ]; then
        new=$(echo "$1" | tr '[:lower:]' '[:upper:]' | xargs)
        case "$match" in
            "$new" ) echo "0" && return
        esac
    fi
    while (( "$#" )); do
            new=$(echo "$1" | tr '[:lower:]' '[:upper:]' | xargs)
            case "$match" in
                "$new" ) echo "0" && return
            esac
        shift
    done
    echo 1
}

# Upper cases text
function __toUpper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'    
}

function __compareVersions() {
    if [[ $1 == "$2" ]]
    then
        echo 0
        return
    fi
    local IFS=.

    local i ver1 ver2
    read -r -a ver1 <<< "$1"
    read -r -a ver2 <<< "$2"
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo -1
            return
        fi
    done
    echo 0
    return
}

function __findClosestVersion() {
    local requestedVersion=$1
    shift
    compatibleVersions=( "$@" )
    # moved check to see if version exists first for situations where 
    # the version (e.g. 7.0.0-beta) don't fit the standard version format
    local contained
    contained=$(__elementIn "${requestedVersion}" "$@")
    if [[ "$contained" == "0" ]]; then 
        echo "${requestedVersion}"
        return
    fi
    
    if [[ ! "${requestedVersion}" =~  ^[0-9]{1,2}.[0-9]{1,2}.[0-9]{1,2}$ ]]; then
        __log_error "${requestedVersion} is not in the correct version format."
        return 1
    fi


    selectedVersion="${compatibleVersions[0]}"
    for i in "${compatibleVersions[@]}"; do
        comparison=$(__compareVersions "$requestedVersion" "$i")
        selectedComparison=$(__compareVersions "$selectedVersion" "$i")
        if [[ "$comparison" == "1" && "$selectedComparison" == "-1" ]]; then
            # our selected version is greater than the requested so we go with it
            selectedVersion=$i

        fi
    done
    
    echo "$selectedVersion"
    return
}

function __getTotalRam() {
    # check for free, which is part of gnu core-utils which is 
    # present on almost every distro, but not macOS
    if which free > /dev/null; then
        # not all free versions support --mebi but the ones that don't support -m and require --si for megabytes
        free -m | awk 'NR==2{print $2}'
        return
    fi
    # here we grab the memsize in bytes then convert to MiB
    # this works on macOS - Big Sur
    size=$(sysctl hw.memsize | cut -d ' ' -f 2)
    echo $((size / 1024 / 1024))
    return
}

function __convertToMiB() {
    local value
    value=$(__toUpper "${1}")
    local default=0
    if [ $# -eq 2 ]; then
        default=$(__convertToMiB "$2")
    fi
    local gib=0
    local tib=0
    local totalRAM=0
    totalRAM=$(__getTotalRam)
    # for suffixes TiB, TIB, or tib
    if [[ "$value" == *TIB ]]; then
        gib=1
        tib=1
        value="${value%TIB}"
    fi
    # for suffixes TI, Ti, or ti
    if [[ "$value" == *TI ]]; then
        gib=1
        tib=1
        value="${value%TI}"

    fi
    # for suffixes GiB or GIB or gib
    if [[ "$value" == *GIB ]]; then
        gib=1
        value="${value%GIB}"
    fi
    # for suffixes GI or Gi or gi
    if [[ "$value" == *GI ]]; then
        gib=1
        value="${value%GI}"
    fi
    # for suffixes of MIB, MiB, mIB, miB or mib
    if [[ "$value" == *MIB ]]; then
        value="${value%MIB}"
    fi
    # for suffixes off MI, mI, Mi, or mi
    if [[ "$value" == *MI ]]; then
        value="${value%MI}"
    fi
    # confirm it's actually a number after we strip the suffix
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$default"
        return 0
    fi
    # If it's a tib, we need to convert to GiB for next conversion
    if [[ "$tib" == "1" ]]; then
        value=$((value * 1024))
    fi
    # if it's a gib, we need to swap it over to MiB
    if [[ "$gib" == "1" ]]; then
        value=$((value * 1024))
    fi
    # If our value is greater than the total ram, we return default
    if [[ $value -gt $totalRAM ]]; then
        echo "$default"
    else
        echo "$value"
    fi
    return 0
}

function __allExists {
    local oifs=$IFS
    needles=()
    IFS="," read -r -a needles <<< "$1"
    IFS=$oifs
    shift
    haystack=("$@")
    for x in "${needles[@]}"
    do
        output=$(__elementIn "$x" "${haystack[@]}")
        if [[ "$output" == "1" ]]; then
            echo "$output"
            return 1
        fi
    done
    return 0
}