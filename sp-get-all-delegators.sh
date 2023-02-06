#!/bin/bash


INDEX_SERVER=https://index.multiversx.com
LC_NUMERIC=en_US
PRECISION=4


# Maple Leaf Network
CONTRACT_ADDRESS="erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqpp8llllscdsdm4"


function decorate {
    printf "%'.${PRECISION}f\n" "${1}"
}


function denominate {
    printf "%s" "$(echo "scale=${PRECISION}; ${1} / 10 ^ 18" | bc)"
}


function get_all_delegators {
    local size=1000  # number of results to return from query
    response=$(curl -sk --ipv4 "${INDEX_SERVER}"'/delegators/_search?q=contract:'"${CONTRACT_ADDRESS}"'&size='"${size}")
    printf "%s" "${response}"
}


function short_address {
    local address=${1}
    local head_address=$(echo $address | head -c14)
    local tail_address=$(echo $address | tail -c14)
    printf "%s...%s" "$head_address" "${tail_address}"
}


# run the query
response=$(get_all_delegators)

# count the number of entries in the list of all delegators
count=$(echo ${response} | jq '.hits.hits | length')

printf "Showing delegation amount for %s delegator wallets\n\n" "${count}"

# print the results
for i in $(seq 0 $(( $count -1 )))
do
    address=$(echo $response | jq -r ".hits.hits[$i]._source.address")
    active_stake=$(echo $response | jq -r ".hits.hits[$i]._source.activeStake")

    if [[ "${address}" == "" ]]
    then
        address="no _source.address returned by api"
    else
        address=$(short_address "${address}")
    fi

    printf "%s: %s EGLD\n" \
        "${address}" \
        "$(decorate $(denominate "${active_stake}"))"
done

