#!/bin/bash
set -e

##
##  auto-updater.sh - auto update for Elrond TESTNET and DEVNET nodes
##
##  @frankf1957
##  Tue 28 Jun 2022 08:43:39 EDT
##
##  Information available from the API of the running node process
##
##  $ API_SERVER=http://localhost:8080
##  $ curl -s ${API_SERVER}/node/status | jq -r '.data.metrics.erd_app_version'
##  T1.3.29.0-0-g81905b785/go1.17.9/linux-amd64/ae0cae19fd
##
##  $ API_SERVER=http://localhost:8080
##  $ curl -s ${API_SERVER}/node/status | jq -r '.data.metrics.erd_latest_tag_software_version'
##  T1.3.30.0
##
##  @frankf1957
##  Fri 20 Jan 2023 09:45:01 PM UTC
##
##  support for rebranding from elrond-go-scripts to mx-chain-scripts
##


SCRIPTS_DIR=${HOME}/mx-chain-scripts
UPDATE_LOG=${HOME}/auto-updater-$(date +"%Y-%m-%d_%H:%M:%S").log


function log_message {
    local text="$@"
    local datetime=$(date +"%F %T %Z")
    printf "%s - %s\n" "$datetime" "$text"
}


function run_script_action {
    local action="$1"

    cd $SCRIPTS_DIR

    log_message "Running command: script.sh $action ..."
    echo "Y" |  ./script.sh "$action" 1>>$UPDATE_LOG 2>&1
}


function upgrade_node {
    log_message "Begin mx-chain node upgrade."
    log_message "Output from script.sh logged to file: $UPDATE_LOG"

    run_script_action "github_pull"
    run_script_action "stop"
    run_script_action "upgrade"

    START_TIME_SECONDS=$(cat ${HOME}/elrond-nodes/node-0/config/nodesSetup.json | awk -F'[ ":,]*' '/startTime/{print $3}')
    if [[ $START_TIME_SECONDS -gt $(date +"%s") ]]
    then
        run_script_action "remove_db"
    fi

    run_script_action "start"

    log_message "Finished mx-chain node upgrade."
}


## auto-updater starting
log_message "Start - auto-update for mx-chain nodes."

## mx-chain-scripts directory must exist, or exit
if [[ ! -d $SCRIPTS_DIR ]]
then
    log_message "Required directory: $SCRIPTS_DIR does not exist !"
    log_message "Cannot proceed with update !"
    exit 1
fi

## Get the current version from the API of the running node process
API_SERVER=http://localhost:8080
CURRENT_VER=$(curl -s ${API_SERVER}/node/status | jq -r '.data.metrics.erd_app_version')

## Get current available version from the API of the running node process
API_SERVER=http://localhost:8080
LATEST_VER=$(curl -s ${API_SERVER}/node/status | jq -r '.data.metrics.erd_latest_tag_software_version')


if [[ -z "$CURRENT_VER" ]] || [[ -z "$LATEST_VER" ]]
then
    log_message "Could not connect to node API at $API_SERVER"
    log_message "Node is not running or is currently not accepting connections on the API port"
    log_message "auto-update will exit now and try again later."
    printf "\n"
    exit
fi

log_message "Your current version is:  $CURRENT_VER"
log_message "Latest version available is:  $LATEST_VER"

if [[ $CURRENT_VER = *$LATEST_VER* ]]
then
    log_message "Nothing to do here, you are running the latest version !"
    log_message "auto-update will exit now and try again later."
    printf "\n"
    exit
fi 

##  There is a new version available - invoke the update
log_message "Triggering automated update !"
upgrade_node

## auto-updater finished
log_message "End - auto-update for mx-chain nodes."
printf "\n"

# vim: ts=4 sw=4 ai expandtab

