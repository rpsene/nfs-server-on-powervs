#!/usr/bin/env bash

: '
    Copyright (C) 2020 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "bye!"
    exit 1
}

VOLUME_ID=""
SERVER_NAME=""

function check_dependencies() {

    DEPENDENCIES=(ibmcloud jq)
    check_connectivity
    for i in "${DEPENDENCIES[@]}"
    do
        if ! command -v $i &> /dev/null; then
            echo "$i could not be found, exiting!"
            exit 1
        fi
    done
}

function check_connectivity() {

    if ! curl --output /dev/null --silent --head --fail http://cloud.ibm.com; then
        echo
        echo "ERROR: please, check your internet connection."
        exit 1
    fi
}

function  create_additional_volume () {

    if [ -z $2 ]; then
        echo "ERROR: please, set the volume size and try again."
        exit 1
    fi

    local VNAME="volume-$1"
    local VSIZE=$2

    ibmcloud pi volume-create $VNAME --type tier1 --size $VSIZE --json >> ./volume.log

    VOLUME_ID=$(cat ./volume.log | jq -r ".volumeID")
    echo
    echo "  $VNAME with $VSIZE G was created with ID $VOLUME_ID"

    echo "VOLUME_ID=$VOLUME_ID" >> ./server-build.log
    echo "VOLUME_NAME=$VNAME" >> ./server-build.log
}

function create_nfs_server () {

    SERVER_ID=$1
    SERVER_IMAGE=$2
    PRIVATE_NETWORK=$3
    PUBLIC_NETWORK=$4
    SSH_KEY_NAME=$5

    # Default values.
    SERVER_MEMORY=$6
    SERVER_PROCESSOR=$7
    SERVER_SYS_TYPE=$8

    ibmcloud pi instance-create $SERVER_NAME --image $SERVER_IMAGE --memory $SERVER_MEMORY --network $PUBLIC_NETWORK --network $PRIVATE_NETWORK  --processors $SERVER_PROCESSOR --processor-type shared --key-name $SSH_KEY_NAME --sys-type $SERVER_SYS_TYPE --volumes $VOLUME_ID --json >> server.log

    NFS_SERVER_ID=$(cat ./server.log | jq -r ".[].pvmInstanceID")
    NFS_SERVER_NAME=$(cat ./server.log | jq -r ".[].serverName")

    echo "  $NFS_SERVER_NAME was created with the ID $NFS_SERVER_ID"

    echo "NFS_SERVER_ID=$NFS_SERVER_ID" >> ./server-build.log
    echo "NFS_SERVER_NAME=$NFS_SERVER_NAME" >> ./server-build.log

    echo "  deploying the server $NFS_SERVER_NAME, hold on please."
    STATUS=$(ibmcloud pi in $NFS_SERVER_ID --json | jq -r ".status")

    printf "%c" "    "
    while [[ "$STATUS" != "ACTIVE" ]]
    do
        sleep 5s
        STATUS=$(ibmcloud pi in $NFS_SERVER_ID --json | jq -r ".status")
        printf "%c" "."
    done

    if [[ "$STATUS" == "ERROR" ]]; then
        echo "ERROR: a new VM could not be created, destroy the allocated resources..."
        ibmcloud pi instance-delete $NFS_SERVER_ID
        ibmcloud pi volume-delete $VOLUME_ID
    fi

    if [[ "$STATUS" == "ACTIVE" ]]; then
        echo
        echo "  $NFS_SERVER_NAME is now ACTIVE."
        echo "  waiting for the network availability, hold on please."

        EXTERNAL_IP=$(ibmcloud pi in $NFS_SERVER_ID --json | jq -r '.addresses[0].externalIP')
        printf "%c" "    "
        while [[ -z "$EXTERNAL_IP" ]]; do 
            printf "%c" "."
            EXTERNAL_IP=$(ibmcloud pi in $NFS_SERVER_ID --json | jq -r '.addresses[0].externalIP')
            INTERNAL_IP=$(ibmcloud pi in $NFS_SERVER_ID --json | jq -r '.addresses[0].ip')
            sleep 5s
        done

        echo "SERVER_EXTERNAL_IP=$EXTERNAL_IP" >> ./server-build.log
        echo "SERVER_INTERNAL_IP=$INTERNAL_IP" >> ./server-build.log
    fi
    printf "%c" "    "
    while ! ping -c 1 $EXTERNAL_IP &> /dev/null
    do
        sleep 10s
        printf "%c" "."
    done
    echo
    echo "  copying the NFS builder script..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ../../scripts/create-nfs.sh root@$EXTERNAL_IP:

    echo "  $NFS_SERVER_NAME is ready, access it using ssh root@$EXTERNAL_IP."
}

function run (){

    echo "*****************************************************"
    SERVER_ID=$(openssl rand -hex 5)
    SERVER_NAME="nfs-server-$SERVER_ID"

    mkdir -p ./servers/"$SERVER_NAME"
    cd ./servers/$SERVER_NAME

    ### Set this variables accordingly
    VOLUME_SIZE=200
    SERVER_IMAGE=CentOS83-12142020
    PRIVATE_NETWORK=03c86ee8-a323-4deb-97fe-856e092a4944
    PUBLIC_NETWORK=77aad4d9-9483-49d9-ab48-ed025b8b970c
    SSH_KEY_NAME=rpsene
    SERVER_MEMORY=4
    SERVER_PROCESSOR=1
    SERVER_SYS_TYPE=s922
    ####

    check_dependencies
    check_connectivity
    create_additional_volume $SERVER_ID $VOLUME_SIZE
    create_nfs_server $SERVER_ID $SERVER_IMAGE $PRIVATE_NETWORK $PUBLIC_NETWORK $SSH_KEY_NAME $SERVER_MEMORY $SERVER_PROCESSOR $SERVER_SYS_TYPE
    echo "*****************************************************"
}

### Main Execution ###
run "$@"
