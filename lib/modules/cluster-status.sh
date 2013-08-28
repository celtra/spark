#!/bin/bash
set -eu -o pipefail

APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))
PATH=$APP_ROOT/lib:$APP_ROOT/bin:$PATH
source $APP_ROOT/config/config.sh
source $APP_ROOT/lib/common.sh

MODULE_NAME="status"
MODULE_DESCRIPTION="Display various Cluster stats"

set +e
# Get some stats
MASTER_URL=$(aws_get_instances "Master" | awk '{print $2}')
SLAVE_COUNT=$(aws_get_instances "Slave" | wc -l)
SLAVE_RUNNING=$(cluster run -q -r Slave "pgrep -fc 'java.*Worker'" | awk 'BEGIN {sum=0} { sum+=$1 } END {print sum}')
SLAVE_UTILIZATION=$( cluster run -q -r Slave 'pgrep -cf java.*Standalone' | awk 'BEGIN {sum=0} { sum+=$1 } END {print sum}')
CPU_COUNT=$(cluster run -r Slave -q cat /proc/cpuinfo  | grep "model name"  | awk '{ $1=$2=$3=$4=""; print $0;}' | sort | uniq -c | sed -e "s/^\s*//")
CPU_NUMBER=$(echo $CPU_COUNT | awk '{ print $1;}')
MEM_AVAILABLE=$(cluster run -r Slave -q cat /opt/spark/conf/spark-env.sh | grep SPARK_MEM | sed -ne "s/.*SPARK_MEM=\(.*\)\([mgMG]\)/\1\2/p" | awk 'BEGIN{sum=0} {  if ($2 == 'm') { sum=sum + ($1 * 1024*1024); } else if ($2 == 'g') { sum = sum + ($1 * 1024 * 1024 * 1024); }} END { printf("%.0f GB", sum/1024/1024/1024) }')
JOB_COUNT="?"
MEMORY_UTILIZATION=$(cluster run -r Slave ps aux | grep -P "java.*Schedule"  | awk '{ printf("    - %d. A:%.2fGB U:%.2fGB P:%.2f%%\n", NR, $6 / 1024 / 1024, $7/1024/1024, $7/$6 * 100);  } END { if (!NR) print "    - 0"; }')
CPU_UTILIZATION=$(cluster run -r Slave ps aux | grep -P "java.*Schedule" | awk '{ printf("    - %d. P:%.2f%%\n", NR, $4); } END { if (!NR) print "    - 0"; }')

# Do the printing
echo "Spark Cluster $CFN_CLUSTER_NAME"
echo "==========================="
echo "- Cluster Status:       $(aws_get_stack_status)"
echo "- Cluster ScalingGroup: $(aws cloudformation list-stack-resources --stack-name=$CFN_CLUSTER_NAME | $APP_ROOT/lib/jsawk -n 'if (this.ResourceType == "AWS::AutoScaling::AutoScalingGroup") { out(this.PhysicalResourceId);}')"
echo ""
echo "- Master"
echo "  - Master URL:          http://${MASTER_URL}:8080"
echo "  - Master Endpoint:     spark://${MASTER_URL}:7077"
echo ""
echo "- Slaves"
echo "  - Registered:          $SLAVE_COUNT"
echo "  - Alive:               $SLAVE_RUNNING"
echo "  - Utilized:            $SLAVE_UTILIZATION"
echo "  - Available CPUs:      $CPU_COUNT"
echo "  - Available Memory:    $MEM_AVAILABLE"
echo ""
echo "- Jobs"
echo "  - Running jobs:        $JOB_COUNT"
echo "  - Memory Utilization per slave"
echo "$MEMORY_UTILIZATION"
echo "  - CPU Utilization per slave"
echo "$CPU_UTILIZATION"
