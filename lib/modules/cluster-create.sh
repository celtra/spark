#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="create"
MODULE_DESCRIPTION="Create Cluster with Amazon CloutFormation Template"

PARAMETERS=$(aws_generate_parameters_json)
TEMPLATE=$($APP_ROOT/lib/stack-template)

echo "Creating cluster $CFN_CLUSTER_NAME"
if OUTPUT=$(aws cloudformation create-stack --template-body "$TEMPLATE" --parameters "${PARAMETERS}" --stack-name $CFN_CLUSTER_NAME)
then
    aws_cfn_wait_for_quit_status "CREATE_COMPLETE" "ROLLBACK_COMPLETE"
else
    error "$OUTPUT"
fi
