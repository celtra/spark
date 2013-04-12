#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="update"
MODULE_DESCRIPTION="Update Amazon CloudFormation Stack"

TEMPLATE=$($APP_ROOT/lib/stack-template)
PARAMETERS=$(aws_generate_parameters_json)

echo "Updating cluster $CFN_CLUSTER_NAME"
aws cloudformation update-stack --template-body "$TEMPLATE" --parameters "${PARAMETERS}" --stack-name $CFN_CLUSTER_NAME >/dev/null

aws_cfn_wait_for_quit_status "UPDATE_COMPLETE" "ROLLBACK_COMPLETE"