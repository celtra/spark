#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="destroy"
MODULE_DESCRIPTION="Destroy Cluster"

echo "Destroy cluster $CFN_CLUSTER_NAME"

read -p "Are you sure you want to destroy cluster $CFN_CLUSTER_NAME? [yes,NO]: "
if [ "x$REPLY" = "xyes" ]
then
    aws cloudformation delete-stack --stack-name $CFN_CLUSTER_NAME >/dev/null
    aws_cfn_wait_for_quit_status "DELETE_COMPLETE" "ROLLBACK_COMPLETE"
fi

