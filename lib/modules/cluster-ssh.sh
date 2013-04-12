#!/bin/bash
##
# Open ssh to stack
#
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="ssh"
MODULE_DESCRIPTION="SSH to specific cluster node"

TMPDIR=/tmp/$(basename $0).$$
mkdir -p $TMPDIR
ROLES=( 'Master' 'Slave' )
INSTANCES=()
INSTANCE=${1:-}
N=0

usage() {
    cat <<EOF
Open ssh to specified instance.
Usage: $(basename $0) <instance>
EOF
    exit 1
}

cleanup() {
    rm -fr $TMPDIR
}
trap cleanup EXIT

[ $# -gt 1 ] && usage

if [ "$INSTANCE" = "" ]
then
    cat <<EOF
Displaying all stack $CFN_CLUSTER_NAME instances
=====================================
EOF
    for role in "${ROLES[@]}"
    do
        # Funky one liner to get instances in array
        if aws_get_instances $role | sort > $TMPDIR/instances
        then
            echo "$role instances"
            while read instance
            do
                INSTANCES[$N]="$instance"
                echo "  ${N}) ${INSTANCES[$N]}"
                N=$(( $N + 1 ))
            done < $TMPDIR/instances
        fi
    done

    read -p "Pick an instance: "
    INDEX=$REPLY
else
    if INSTANCES[0]=$(aws_get_instance_by_id $1)
    then
        INDEX=0
    else
        INDEX=
    fi
fi

if [ "x$INDEX" != "x" ] && [[ "$INDEX" =~ ^[0-9]+$ ]] && [ $INDEX -lt ${#INSTANCES[@]} ]
then
    echo "Connecting to instance: ${INSTANCES[$INDEX]}"
    ssh -o StrictHostKeyChecking=no -l root $(echo ${INSTANCES[$INDEX]} | awk '{print $2}')
else
    echo "None picked"
fi
