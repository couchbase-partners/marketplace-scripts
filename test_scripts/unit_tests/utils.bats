setup() {
    load '/usr/local/lib/bats-support/load.bash'
    load '/usr/local/lib/bats-assert/load.bash'

    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd)"
    PATH="$DIR/../../common:$PATH"
    export NO_COLOR=1
    source "$DIR/../../common/utils.sh"
    source "$DIR/../../common/loggers.sh"
}

@test "generates a random string" {
    var1=$(__generate_random_string)
    var2=$(__generate_random_string)
    refute [ "$var1" == "$var2" ]
}

@test "finds value in array" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    city="PARIS"
    var=$(__elementIn "$city" "${cities[@]}" )
    assert [ "$var" == 0 ]
}

@test "elementIn return 0 if value is present and only item" {
    values=("2")
    run __elementIn "2" "${values[@]}"
    assert_output "0"
    assert_success
}

@test "finds value not case sensitive on needle" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    city="paris"
    var=$(__elementIn "$city" "${cities[@]}" )
    assert [ "$var" == 0 ]
}

@test "Works with ubuntu versions" {
    SUPPORTED_VERSIONS=("14.04" "16.04" "18.04" "20.04")
    NEW_SUPPORTED_VERSIONS=("${SUPPORTED_VERSIONS[@]}")

    OS_VERSION="18.04"
    run __elementIn "$OS_VERSION" "${NEW_SUPPORTED_VERSIONS[@]}"
    assert_success
    assert_output "0"
}

@test "finds value not case sensitive on haystack" {
    cities=("CHICAGO" "LONDON" "paris" "NEW YORK" "SAN FRANCISCO")
    city="PARIS"
    var=$(__elementIn "$city" "${cities[@]}" )
    assert [ "$var" == 0 ]
}

@test "does not find value in array" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    city="MIAMI"
    var=$(__elementIn "$city" "${cities[@]}" )
    assert [ "$var" == 1 ]
}

@test "Compare versions outputs zero for same version" {
    output=$(__compareVersions 2.0.0 2.0.0)
    assert [ "$output" == 0 ]
}

@test "Compare versions outputs 1 for greater version" {
    output=$(__compareVersions 2.0.1 2.0.0)
    assert [ "$output" == 1 ]
}

@test "Compare versions outputs -1 for lesser version" {
    output=$(__compareVersions 2.0.0 3.0.0)
    assert [ "$output" == "-1" ]
}

@test "Compare versions outputs 0 for improper formatted version" {
    output=$(__compareVersions 2X0 3.0.0)
    assert [ "$output" == "0" ]
}

@test "Compare versions outputs 0 for improper formatted comparison version" {
    output=$(__compareVersions 2.0.0 3X0)
    assert [ "$output" == "0" ]
}

@test "Finds closest version of same version" {
    UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
    output=$(__findClosestVersion 2.8.2 "${UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}")
    assert [ "$output" == "2.8.2" ]
}

@test "Finds closest version of next smaller version than requested" {
    UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
    output=$(__findClosestVersion 2.8.1 "${UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}")
    assert [ "$output" == "2.8.0" ]
}

@test "Finds closest version of next smaller version than requested by semantic versioning" {
    UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
    output=$(__findClosestVersion 2.2.0 "${UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}")
    assert [ "$output" == "2.1.3" ]
}

@test "errors on incorrectly formatted request version" {
    UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2")
    run __findClosestVersion Apple "${UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}"
    assert [ "$status" == "1" ]
    assert_output --partial "Apple is not in the correct version format."
}

@test "works on beta version" {
    UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS=("1.5.1" "1.5.2" "2.0.0" "2.1.0" "2.1.1" "2.1.2" "2.1.3" "2.5.0" "2.5.1" "2.6.0" "2.6.1" "2.7.0" "2.7.1" "2.7.2" "2.7.3" "2.7.4" "2.8.0" "2.8.2" "7.0.0-beta")
    output=$(__findClosestVersion "7.0.0-beta" "${UBUNTU_SUPPORTED_SYNC_GATEWAY_VERSIONS[@]}")
    assert [ "$output" == "7.0.0-beta" ]
}

@test "Gets total ram" {
    run __getTotalRam
    assert_success
    assert [ "$output" -gt 0 ]   
}

@test "Converts a value from TiB to raw number" {
    run __convertToMiB 1TiB 256
    assert_success
    assert_output "256"   
}

@test "Converts a value from Ti to raw number" {
    run __convertToMiB 1Ti 256
    assert_success
    assert_output "256"   
}

@test "Converts a value from GiB to raw number" {
    run __convertToMiB 2GiB 256
    assert_success
    assert_output "2048"   
}

@test "Converts a value from Gi to raw number" {
    run __convertToMiB 2Gi 256
    assert_success
    assert_output "2048"   
}

@test "Returns default if first value too big" {
    run __convertToMiB 76GiB 256
    assert_success
    assert_output "256"   
}

@test "Returns zero if both values are too big" {
    run __convertToMiB 76GiB 76GiB
    assert_success
    assert_output "0"   
}

@test "Converts from MiB to raw number" {
    run __convertToMiB 76MiB 256
    assert_success
    assert_output "76"   
}

@test "Converts from Mi to raw number" {
    run __convertToMiB 76Mi 256
    assert_success
    assert_output "76"   
}

@test "convertToMiB does not error with no second parameter" {
    run __convertToMiB 76Mi
    assert_success
    assert_output "76"
}

@test "supports both raw number parameters" {
    run __convertToMiB 76 256
    assert_success
    assert_output "76"   
}

@test "onlyContains returns 0 if csv list only has values in array" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    run __allExists "PARIS,LONDON,NEW YORK" "${cities[@]}"
    assert_success
}

@test "onlyContains is not case sensitive on needles" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    run __allExists "San Francisco,london,new york" "${cities[@]}"
    assert_success
}

@test "onlyContains is not case sensitive on Haystack" {
    cities=("Chicago" "London" "Paris" "New York" "san FRANcisco")
    run __allExists "San Francisco,london,new york" "${cities[@]}"
    assert_success
}

@test "onlyContains returns 1 if a value is not in the list" {
    cities=("CHICAGO" "LONDON" "PARIS" "NEW YORK" "SAN FRANCISCO")
    run __allExists "PARIS,LONDON,CHICAGO,SANTIAGO" "${cities[@]}"
    assert_failure
}

@test "__get_default_services returns correct services for CBS 7.0.0" {
    run __get_default_services "7.0.0"
    assert_output "data,index,analytics,eventing,fts,query,backup"
}

@test "__get_default_services returns correct services for CBS 6.6.3" {
    run __get_default_services "6.6.3"
    assert_output "data,index,analytics,eventing,fts,query"
}

@test "__get_default_services returns correct services for CBS 7.0.2" {
    run __get_default_services "7.0.2"
    assert_output "data,index,analytics,eventing,fts,query,backup"
}