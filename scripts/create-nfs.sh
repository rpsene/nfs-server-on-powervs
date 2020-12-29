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

function install_dependencies () {

    echo "Installing dependencies on Linux..."
    OS=$(cat /etc/os-release | grep -w "ID" | awk -F "=" '{print $2}' | tr -d "\"")

    if [ $OS == "centos" ]; then
        dnf install -y nfs-utils
    elif [ $OS == "rhel" ]; then
        RH_REGISTRATION=$(subscription-manager identity 2> /tmp/rhsubs.out; cat /tmp/rhsubs.out; rm -f /tmp/rhsubs.out)
        if [[ "$RH_REGISTRATION" == *"not yet registered"* ]]; then
            echo "ERROR: ensure your system is subscribed to RedHat."
            exit 1
        else
            dnf install -y nfs-utils
        fi
    else
        echo "This operating system is not supported yet."
        exit 1
    fi
}

function enable_services () {

    systemctl enable rpcbind
    systemctl enable nfs-server
    systemctl start rpcbind
    systemctl start nfs-server
}

function create (){

    DEVICE=$1
    NFS_DIR="/data/nfs-storage"

    mkfs.ext4 /dev/mapper/$DEVICE
    mkdir -p $NFS_DIR
    mount /dev/mapper/$DEVICE $NFS_DIR
    chmod -R 755 $NFS_DIR

    echo "$NFS_DIR *(rw,sync,no_root_squash)" >> /etc/exports
    exportfs -rav
    systemctl restart nfs-server

    echo "/dev/mapper/$DEVICE   $NFS_DIR    ext4    defaults    0   1" >> /etc/fstab
}

run () {

    if [ -z $1 ]; then
        echo
        echo "ERROR: please set the correct device that will be"
        echo "       formated and used as NFS storage."
        echo
        exit 1
    fi

    install_dependencies
    enable_services
    create $1
}

### Main Execution ###
run "$@"