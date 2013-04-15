#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="update"
MODULE_DESCRIPTION="Update Amazon CloudFormation Stack"

TEMPLATE=$($APP_ROOT/lib/stack-template)

TMP_DIR=/tmp/$(basename $0).$$
mkdir -p $TMP_DIR
cleanup() {
    rm -fr $TMP_DIR
}
trap cleanup EXIT

echo "Updating cluster $CFN_CLUSTER_NAME"

# Local AMI Hash
AMI_HASH_ID=$($APP_ROOT/ami/base-ami-hash)
# Currently deployed AMI_ID
AMI_BUCKET_ID=$(aws ec2 describe-images --filters "[ { \"name\": \"is-public\", \"values\": [ \"false\" ] },{ \"name\": \"name\", \"values\": [ \"spark-0.6.2-${AMI_HASH_ID}\" ] } ]" | \
                $APP_ROOT/lib/jsawk -n 'if (typeof this.Images[0] != "undefined") { out(this.Images[0].ImageId); }')

if [ "$AMI_BUCKET_ID" == "" ]
then
    sudo_cmd $APP_ROOT/ami/build-ami -b -B $S3_AMI_BUCKET -o $TMP_DIR/ami.id
    AMI_ID=$(cat $TMP_DIR/ami.id | awk '{ print $2; }')
else
    AMI_ID=$AMI_BUCKET_ID
fi

CFN_PARAMS['ami']=$AMI_ID
PARAMETERS=$(aws_generate_parameters_json)

if OUTPUT=$(aws cloudformation update-stack --template-body "$TEMPLATE" --parameters "${PARAMETERS}" --stack-name $CFN_CLUSTER_NAME)
then
    aws_cfn_wait_for_quit_status "UPDATE_COMPLETE" "ROLLBACK_COMPLETE"
else
    error "$OUTPUT"
fi
