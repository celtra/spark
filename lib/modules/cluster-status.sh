#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="status"
MODULE_DESCRIPTION="Display various Cluster stats"

MASTER_URL=$(aws_get_instances "Master" | awk '{print $2}')
SLAVE_COUNT=$(aws_get_instances "Slave" | wc -l)
SLAVE_RUNNING=0
for i in $($APP_ROOT/bin/cluster run -q -r Slave "pgrep -fc 'java.*Worker'")
do
    SLAVE_RUNNING=$(( $SLAVE_RUNNING + $i))
done
echo "Spark Cluster $CFN_CLUSTER_NAME"
echo "==========================="
echo "Cluster Status:  $(aws_get_stack_status)"
echo "Master URL:      http://${MASTER_URL}:8080"
echo "Master Endpoint: spark://${MASTER_URL}:7077"
echo "Slave Nodes:     $SLAVE_RUNNING/$SLAVE_COUNT"
#echo "Slave CPUs:  $SLAVE_CPUS"
#echo "Slave MEM:   $SLAVE_MEM"